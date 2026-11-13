--[[
    ForeverPath - Integrations/QuestieData.lua

    Read-only adapter over QuestieDB's public library, `LibQuestieDB`.

    Only the documented, contract-versioned API is used (Quest/Npc/Object/
    Item `.Get`, `Quest.GetAllIds`, `Enum.raceMaskById`, `Enum.classKeys`,
    `RequireContract`). If QuestieDB is missing or its contract changes,
    every function here degrades to "no data" and the guide falls back to
    quests already in the player's log.

    When the full Questie addon is also loaded, its own availability check
    (QuestieDB.IsDoable, which knows about hidden and event quests) is
    preferred over ours. That module is internal to Questie, so it is only
    called through pcall.
]]

local _, ns = ...

local QuestieData = {}
ns.QuestieData = QuestieData

-- The LibQuestieDB contract this file was written against.
QuestieData.REQUIRED_CONTRACT = 4

-- Default level window when a mode doesn't set one: quests more than
-- GREY_LEVEL_GAP below you are grey, more than LEVELS_ABOVE above too hard.
local GREY_LEVEL_GAP = 6
local LEVELS_ABOVE = 2
-- Quests scanned per frame while building the index.
local SCAN_BATCH = 250

local state = {
    status = "unknown",   -- "unknown" | "missing" | "incompatible" | "indexing" | "ready"
    candidates = {},      -- list of { id, requiredLevel, questLevel }
    trainers = {},        -- list of NpcIds for the player's class trainer
}

---------------------------------------------------------------------------
-- Library access
---------------------------------------------------------------------------

local questArea -- defined with the index code below

local function lib()
    local l = _G.LibQuestieDB
    if type(l) == "table" and type(l.Quest) == "table" then return l end
    return nil
end

local function get(entity, id, field)
    local l = lib()
    if not l or not l[entity] or type(l[entity].Get) ~= "function" then return nil end
    local ok, value = pcall(l[entity].Get, id, field)
    if ok then return value end
    return nil
end

--- Questie's own availability check, if the full addon is loaded.
local function questieIsDoable(questID)
    local loader = _G.QuestieLoader
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end
    local ok, db = pcall(loader.ImportModule, loader, "QuestieDB")
    if not ok or type(db) ~= "table" or type(db.IsDoable) ~= "function" then return nil end
    local ok2, doable = pcall(db.IsDoable, questID)
    if not ok2 then return nil end
    return doable and true or false
end

--- Check the library is present and speaks a contract we understand.
function QuestieData.Detect()
    if state.status == "ready" or state.status == "indexing" then
        return state.status
    end
    local l = lib()
    if not l then
        state.status = "missing"
    elseif type(l.RequireContract) == "function" then
        local ok, supported = pcall(l.RequireContract, QuestieData.REQUIRED_CONTRACT)
        state.status = (ok and supported) and "unknown" or "incompatible"
    else
        state.status = "unknown"
    end
    return state.status
end

function QuestieData.Status()
    return state.status
end

function QuestieData.IsReady()
    return state.status == "ready"
end

---------------------------------------------------------------------------
-- Eligibility
---------------------------------------------------------------------------

local function raceAllowed(mask, raceID)
    if not mask or mask == 0 then return true end
    local l = lib()
    local bitForRace = l and l.Enum and l.Enum.raceMaskById and l.Enum.raceMaskById[raceID]
    if not bitForRace then return true end -- unknown race: don't hide quests
    return ns.Util.HasFlag(mask, bitForRace)
end

local function classAllowed(mask, classID)
    if not mask or mask == 0 or not classID then return true end
    -- Same encoding Questie uses: class ID n is bit 2^(n-1).
    return ns.Util.HasFlag(mask, 2 ^ (classID - 1))
end

--- Static filters that never change for a character: race and class.
local function suitsCharacter(questID, profile)
    return raceAllowed(get("Quest", questID, "requiredRaces"), profile.raceID)
        and classAllowed(get("Quest", questID, "requiredClasses"), profile.classID)
end

local function anyDone(ids, ctx)
    if type(ids) ~= "table" then return false end
    for _, id in ipairs(ids) do
        if ctx.isCompleted(id) or ctx.log[id] then return true end
    end
    return false
end

-- Requirements we can't check reliably; quests with them are left out
-- rather than sending the player somewhere they can't pick anything up.
local UNCHECKED_REQUIREMENTS = {
    "requiredSkill", "requiredMinRep", "requiredMaxRep", "requiredSpell",
    "requiredSpecialization", "requiredSourceItems", "requiredRanks",
}

--- Can the character pick up this quest right now?
-- @param ctx { level, faction, log, isCompleted(id) }
function QuestieData.IsDoable(questID, ctx)
    if ctx.log[questID] or ctx.isCompleted(questID) then return false end

    local fromQuestie = questieIsDoable(questID)
    if fromQuestie ~= nil then return fromQuestie end

    local maxLevel = get("Quest", questID, "requiredMaxLevel")
    if maxLevel and maxLevel > 0 and ctx.level > maxLevel then return false end

    for _, field in ipairs(UNCHECKED_REQUIREMENTS) do
        local v = get("Quest", questID, field)
        if v ~= nil and v ~= 0 and not (type(v) == "table" and next(v) == nil) then
            return false
        end
    end

    -- Every quest in preQuestGroup must be done.
    local group = get("Quest", questID, "preQuestGroup")
    if type(group) == "table" then
        for _, id in ipairs(group) do
            if not ctx.isCompleted(id) then return false end
        end
    end
    -- At least one quest in preQuestSingle must be done.
    local single = get("Quest", questID, "preQuestSingle")
    if type(single) == "table" and #single > 0 then
        local found = false
        for _, id in ipairs(single) do
            if ctx.isCompleted(id) then found = true; break end
        end
        if not found then return false end
    end

    if anyDone(get("Quest", questID, "exclusiveTo"), ctx) then return false end

    local nextInChain = get("Quest", questID, "nextQuestInChain")
    if nextInChain and nextInChain ~= 0 and anyDone({ nextInChain }, ctx) then return false end

    local untilDone = get("Quest", questID, "availableUntilCompleted")
    if untilDone and ctx.isCompleted(untilDone) then return false end

    local startingWith = get("Quest", questID, "availableStartingWith")
    if startingWith and startingWith ~= 0 and not anyDone({ startingWith }, ctx) then return false end

    local disabledBy = get("Quest", questID, "disabledByQuest")
    if disabledBy and ctx.log[disabledBy] then return false end

    local breadcrumbTarget = get("Quest", questID, "breadcrumbForQuestId")
    if breadcrumbTarget and breadcrumbTarget ~= 0 and anyDone({ breadcrumbTarget }, ctx) then return false end

    return true
end

---------------------------------------------------------------------------
-- Locations
---------------------------------------------------------------------------

local FACTION_CODE = { Alliance = "A", Horde = "H" }

local function friendlyTo(npcID, faction)
    local friendly = get("Npc", npcID, "friendlyToFaction")
    local code = FACTION_CODE[faction]
    if not friendly or not code then return true end
    return friendly:find(code, 1, true) ~= nil
end

-- Spawn points are memoised so their world positions are only worked out
-- once per session (Sources caches them on the point tables).
local spawnCache = {}

--- Spawn points for an NPC or object as map points.
local function spawnsOf(entity, id)
    local cacheKey = entity .. ":" .. id
    if spawnCache[cacheKey] then return spawnCache[cacheKey] end
    local points = {}
    spawnCache[cacheKey] = points
    local spawns = get(entity, id, "spawns")
    if type(spawns) ~= "table" then return points end
    for areaID, coords in pairs(spawns) do
        for _, c in ipairs(coords) do
            local p = ns.ZoneMap.ToMapPoint(areaID, c[1], c[2])
            if p then points[#points + 1] = p end
        end
    end
    return points
end

--- People and objects that matter for a quest, each with its spawn points.
-- @param field "startedBy" | "finishedBy"
local function actors(questID, field, faction)
    local result = {}
    local value = get("Quest", questID, field)
    if type(value) ~= "table" then return result end

    for _, npcID in ipairs(value[1] or {}) do
        if friendlyTo(npcID, faction) then
            result[#result + 1] = {
                kind = "npc", id = npcID,
                name = get("Npc", npcID, "name") or ("NPC " .. npcID),
                points = spawnsOf("Npc", npcID),
            }
        end
    end
    for _, objectID in ipairs(value[2] or {}) do
        result[#result + 1] = {
            kind = "object", id = objectID,
            name = get("Object", objectID, "name") or ("Object " .. objectID),
            points = spawnsOf("Object", objectID),
        }
    end
    return result
end

function QuestieData.GetStarters(questID, faction)
    return actors(questID, "startedBy", faction)
end

function QuestieData.GetFinishers(questID, faction)
    return actors(questID, "finishedBy", faction)
end

--- Where to go for a quest's objectives: creatures to kill, objects to
--- use, and creatures that drop the items it needs.
function QuestieData.GetObjectiveTargets(questID)
    local result = {}
    local objectives = get("Quest", questID, "objectives")
    if type(objectives) ~= "table" then return result end

    local function add(kind, entity, id, forItem)
        result[#result + 1] = {
            kind = kind, id = id,
            name = get(entity, id, "name") or "",
            points = spawnsOf(entity, id),
            forItem = forItem, -- item name when this drops a quest item
        }
    end
    for _, creature in ipairs(objectives[1] or {}) do
        add("npc", "Npc", creature[1])
    end
    for _, object in ipairs(objectives[2] or {}) do
        add("object", "Object", object[1])
    end
    for _, item in ipairs(objectives[3] or {}) do
        local itemName = get("Item", item[1], "name")
        for _, npcID in ipairs(get("Item", item[1], "npcDrops") or {}) do
            add("npc", "Npc", npcID, itemName)
        end
        for _, objectID in ipairs(get("Item", item[1], "objectDrops") or {}) do
            add("object", "Object", objectID, itemName)
        end
    end
    return result
end

function QuestieData.GetQuestName(questID)
    return get("Quest", questID, "name")
end

--- The quest that follows this one in its chain, if any.
function QuestieData.NextInChain(questID)
    local nextID = get("Quest", questID, "nextQuestInChain")
    if type(nextID) == "number" and nextID > 0 then return nextID end
    return nil
end

--- True when the quest continues a chain (it has prerequisite quests).
function QuestieData.IsFollowUp(questID)
    for _, field in ipairs({ "preQuestSingle", "preQuestGroup" }) do
        local list = get("Quest", questID, field)
        if type(list) == "table" and #list > 0 then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Candidate index
---------------------------------------------------------------------------

--- Quests in the level window that pass the static race/class filter.
-- @param rules optional mode rules ({ greyGap, levelsAbove })
function QuestieData.GetCandidates(level, rules)
    local greyGap = rules and rules.greyGap or GREY_LEVEL_GAP
    local above = rules and rules.levelsAbove or LEVELS_ABOVE
    local result = {}
    for _, q in ipairs(state.candidates) do
        local qLevel = q.questLevel or q.requiredLevel or 1
        if (q.requiredLevel or 1) <= level
            and qLevel <= level + above
            and qLevel >= level - greyGap then
            result[#result + 1] = q.id
        end
    end
    return result
end

--- Class trainers for the player's class: list of actors with points.
function QuestieData.GetTrainers(faction)
    local result = {}
    for _, npcID in ipairs(state.trainers) do
        if friendlyTo(npcID, faction) then
            result[#result + 1] = {
                kind = "npc", id = npcID,
                name = get("Npc", npcID, "name") or "Trainer",
                points = spawnsOf("Npc", npcID),
            }
        end
    end
    return result
end

--- The zone a quest belongs to: its zoneOrSort when that's a real area,
--- otherwise where its first quest giver stands.
questArea = function(questID)
    local zoneOrSort = get("Quest", questID, "zoneOrSort")
    if type(zoneOrSort) == "number" and zoneOrSort > 0 then
        return zoneOrSort
    end
    local startedBy = get("Quest", questID, "startedBy")
    if type(startedBy) ~= "table" then return nil end
    for index, entity in ipairs({ "Npc", "Object" }) do
        for _, id in ipairs(startedBy[index] or {}) do
            local spawns = get(entity, id, "spawns")
            if type(spawns) == "table" then
                local areaID = next(spawns)
                if areaID then return areaID end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Dungeons
---------------------------------------------------------------------------

local function normaliseName(name)
    return (name or ""):lower():gsub("^the%s+", ""):gsub("[^%a]", "")
end

local dungeonByArea = {} -- areaID -> Data.Dungeons entry, or false

--- The dungeon (from Data/Dungeons.lua) an area ID belongs to, matched by
--- the area's name ("The Deadmines" and "Deadmines" both match).
function QuestieData.DungeonForArea(areaID)
    if not areaID then return nil end
    local cached = dungeonByArea[areaID]
    if cached ~= nil then return cached or nil end
    local wanted = normaliseName(ns.GameApi.GetAreaName(areaID))
    local found = false
    if wanted ~= "" then
        for _, d in ipairs(ns.Data.Dungeons) do
            if normaliseName(d.name) == wanted then found = d; break end
        end
    end
    dungeonByArea[areaID] = found
    return found or nil
end

--- The dungeon a quest takes place in, or nil.
function QuestieData.DungeonOf(questID)
    local zoneOrSort = get("Quest", questID, "zoneOrSort")
    if type(zoneOrSort) == "number" and zoneOrSort > 0 then
        return QuestieData.DungeonForArea(zoneOrSort)
    end
    return nil
end

--- Every indexed quest for this character that takes place in `dungeonName`.
function QuestieData.GetQuestsForDungeon(dungeonName)
    local result = {}
    for _, q in ipairs(state.candidates) do
        local d = QuestieData.DungeonForArea(q.areaID)
        if d and d.name == dungeonName then
            result[#result + 1] = q
        end
    end
    return result
end

--- Every indexed quest for this character whose zone is `mapID`,
--- regardless of level. Used by the guide browser's quest overview.
function QuestieData.GetQuestsForMap(mapID)
    local result = {}
    for _, q in ipairs(state.candidates) do
        if q.areaID and ns.ZoneMap.ToUiMap(q.areaID) == mapID then
            result[#result + 1] = q
        end
    end
    return result
end

local function allIds(entity)
    local l = lib()
    local e = l and l[entity]
    if not e or type(e.GetAllIds) ~= "function" then return {} end
    local ok, ids = pcall(e.GetAllIds)
    return (ok and type(ids) == "table") and ids or {}
end

--- Build the candidate and trainer index in small batches so the game
--- doesn't stall. Calls onDone() when finished.
-- @param profile from Character.Detect plus raceID
-- @param schedule fn(callback) that runs callback on a later frame
function QuestieData.BuildIndex(profile, schedule, onDone)
    if QuestieData.Detect() ~= "unknown" then
        if onDone then onDone(state.status) end
        return
    end
    state.status = "indexing"
    state.candidates, state.trainers = {}, {}

    local trainerTitle = profile.class and (profile.class.name .. " Trainer") or nil
    local work = coroutine.create(function()
        local count = 0
        for _, id in ipairs(allIds("Quest")) do
            if suitsCharacter(id, profile) then
                local reqLevel = get("Quest", id, "requiredLevel")
                if (reqLevel or 1) <= ns.Util.MAX_LEVEL then
                    state.candidates[#state.candidates + 1] = {
                        id = id,
                        requiredLevel = reqLevel,
                        questLevel = get("Quest", id, "questLevel"),
                        areaID = questArea(id),
                    }
                end
            end
            count = count + 1
            if count % SCAN_BATCH == 0 then coroutine.yield() end
        end
        if trainerTitle then
            for _, id in ipairs(allIds("Npc")) do
                if get("Npc", id, "subName") == trainerTitle then
                    state.trainers[#state.trainers + 1] = id
                end
                count = count + 1
                if count % SCAN_BATCH == 0 then coroutine.yield() end
            end
        end
    end)

    local function step()
        local ok, err = coroutine.resume(work)
        if not ok then
            state.status = "incompatible"
            ns.Util.Print("QuestieDB scan failed: " .. tostring(err))
            if onDone then onDone(state.status) end
        elseif coroutine.status(work) == "dead" then
            state.status = "ready"
            if onDone then onDone(state.status) end
        else
            schedule(step)
        end
    end
    step()
end

--- Forget everything (tests, or after a level-up changes the race/class view).
function QuestieData.Reset()
    state.status = "unknown"
    state.candidates, state.trainers = {}, {}
    spawnCache = {}
    dungeonByArea = {}
end
