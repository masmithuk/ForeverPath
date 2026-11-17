--[[
    Questwalker - Integrations/QuestieData.lua

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
    byTitle = {},         -- NPC title ("Mage Trainer", "Innkeeper"...) -> list of NpcIds
    classTitle = nil,     -- "<Class> Trainer" for this character
    leadsOn = {},         -- [questID] = true when another quest follows it
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
--- Has the full Questie addon finished starting up? Questie fills its
--- availability and zone tables during startup, which can finish a few
--- seconds after login - after Questwalker's first plan. Until then its
--- answers aren't reliable, so they're not used.
--- How many quests suit this character (for /qw debug).
function QuestieData.CandidateCount() return #state.candidates end

function QuestieData.QuestieStarted()
    local questie = _G.Questie
    return type(questie) == "table" and questie.started == true
end

local function questieIsDoable(questID)
    if not QuestieData.QuestieStarted() then return nil end
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
--- How tough a quest's fights are: for each objective, the lowest
--- minimum level among the creatures that give it, and then the highest
--- of those. nil when no creature levels are known (e.g. only objects).
function QuestieData.ObjectiveLevel(questID)
    local objectives = get("Quest", questID, "objectives")
    if type(objectives) ~= "table" then return nil end
    local hardest
    local function consider(npcIDs)
        local easiest
        for _, npcID in ipairs(npcIDs) do
            local lvl = get("Npc", npcID, "minLevel")
            if type(lvl) == "number" and lvl > 0 and (not easiest or lvl < easiest) then easiest = lvl end
        end
        if easiest and (not hardest or easiest > hardest) then hardest = easiest end
    end
    for _, creature in ipairs(objectives[1] or {}) do consider({ creature[1] }) end
    for _, item in ipairs(objectives[3] or {}) do consider(get("Item", item[1], "npcDrops") or {}) end
    return hardest
end

--- Is a quest too hard for you yet? Its level is more than `levelsAbove`
--- over yours, or the creatures it needs are more than one level beyond
--- that. Returns true and the level to come back at, or false.
--- Is a quest too far below you to be worth doing (more than the guide's
--- greyGap levels under you)? Returns true and the quest's level, or false.
function QuestieData.TooLow(questID, level, rules)
    local gap = rules and rules.greyGap or GREY_LEVEL_GAP
    local qLevel = get("Quest", questID, "questLevel")
    if type(qLevel) == "number" and qLevel > 0 and qLevel < level - gap then return true, qLevel end
    return false
end

function QuestieData.TooHard(questID, level, rules)
    local above = rules and rules.levelsAbove or LEVELS_ABOVE
    local qLevel = get("Quest", questID, "questLevel")
    local mobLevel = QuestieData.ObjectiveLevel(questID)
    local needed = 0
    if type(qLevel) == "number" and qLevel > level + above then needed = qLevel - above end
    if mobLevel and mobLevel > level + above + 1 then needed = math.max(needed, mobLevel - above - 1) end
    if needed > 0 then return true, needed end
    return false
end

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

--- True when the quest continues a chain (it has prerequisite quests).
function QuestieData.IsFollowUp(questID)
    for _, field in ipairs({ "preQuestSingle", "preQuestGroup" }) do
        local list = get("Quest", questID, field)
        if type(list) == "table" and #list > 0 then return true end
    end
    return false
end

--- The uiMapID of the zone a quest belongs to (its zone, or where its
--- quest giver stands), or nil.
function QuestieData.QuestMapID(questID)
    local areaID = questArea(questID)
    return areaID and ns.ZoneMap.ToUiMap(areaID) or nil
end

--- Read one field of a QuestieDB entity ("Quest", "Npc", "Item", "Object").
function QuestieData.Field(entity, id, field)
    return get(entity, id, field)
end

-- Guards are indexed under this pseudo-title (see BuildIndex).
QuestieData.GUARD_TITLE = "@guard"
local GUARD_WORDS = { "Guard", "Sentinel", "Grunt", "Deathguard", "Bluffwatcher", "Protector", "Footman" }

--- Does an NPC name look like a town guard ("Stormwind City Guard",
--- "Orgrimmar Grunt", "Darnassus Sentinel", "Deathguard Burgess")?
function QuestieData.IsGuardName(name)
    for _, word in ipairs(GUARD_WORDS) do
        if name:find("%f[%a]" .. word .. "%f[%A]") then return true end
    end
    return false
end

--- XP this quest gives you now, from Questie's XP table (once Questie has
--- started), or nil when it isn't known.
function QuestieData.QuestXP(questID)
    if not QuestieData.QuestieStarted() then return nil end
    local loader = _G.QuestieLoader
    local ok, xpModule = pcall(loader.ImportModule, loader, "QuestXP")
    if not ok or type(xpModule) ~= "table" or type(xpModule.GetQuestLogRewardXP) ~= "function" then return nil end
    local ok2, xp = pcall(xpModule.GetQuestLogRewardXP, xpModule, questID)
    if ok2 and type(xp) == "number" and xp > 0 then return xp end
    return nil
end

--- Is it a class quest (only some classes can take it)?
function QuestieData.IsClassQuest(questID)
    local classes = get("Quest", questID, "requiredClasses")
    return type(classes) == "number" and classes > 0
end

--- Is the quest part of a chain - a follow-up, or one that leads on to
--- another quest? Stand-alone side quests aren't. (Story mode uses this.)
function QuestieData.IsChainQuest(questID)
    if QuestieData.IsFollowUp(questID) or state.leadsOn[questID] then return true end
    local nextInChain = get("Quest", questID, "nextQuestInChain")
    return type(nextInChain) == "number" and nextInChain > 0
end

---------------------------------------------------------------------------
-- Candidate index
---------------------------------------------------------------------------

--- Is the character high enough to pick the quest up? (true if unknown)
function QuestieData.MeetsLevel(questID, level)
    local required = get("Quest", questID, "requiredLevel")
    return not required or required <= level
end

--- Is a quest inside a mode's level window? nil when QuestieDB doesn't know it.
function QuestieData.InLevelWindow(questID, level, rules)
    local qLevel = get("Quest", questID, "questLevel") or get("Quest", questID, "requiredLevel")
    if not qLevel or qLevel <= 0 then return nil end
    local greyGap = rules and rules.greyGap or GREY_LEVEL_GAP
    local above = rules and rules.levelsAbove or LEVELS_ABOVE
    return qLevel >= level - greyGap and qLevel <= level + above
end

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

--- NPCs with a given title (QuestieDB "subName"), friendly to `faction`,
--- as actors with spawn points. Titles are indexed at login: your class
--- trainer, innkeepers and every profession trainer.
function QuestieData.GetNpcsByTitle(title, faction)
    local result = {}
    for _, npcID in ipairs(state.byTitle[title] or {}) do
        if friendlyTo(npcID, faction) then
            result[#result + 1] = {
                kind = "npc", id = npcID,
                name = get("Npc", npcID, "name") or title,
                points = spawnsOf("Npc", npcID),
            }
        end
    end
    return result
end

--- "<Class> Trainer" for this character (set when the index is built).
function QuestieData.ClassTrainerTitle()
    return state.classTitle
end

--- Class trainers for the player's class.
function QuestieData.GetTrainers(faction)
    return state.classTitle and QuestieData.GetNpcsByTitle(state.classTitle, faction) or {}
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
    state.candidates, state.byTitle, state.leadsOn = {}, {}, {}

    -- NPC titles worth indexing: class trainer, innkeepers, profession trainers.
    local services = ns.Data.Services
    local titles = { [services.innkeeperTitle] = true }
    state.classTitle = profile.class and (profile.class.name .. " Trainer") or nil
    if state.classTitle then titles[state.classTitle] = true end
    for _, p in ipairs(services.professions) do titles[p .. " Trainer"] = true end
    local work = coroutine.create(function()
        local count = 0
        for _, id in ipairs(allIds("Quest")) do
            if suitsCharacter(id, profile) then
                local reqLevel = get("Quest", id, "requiredLevel")
                -- Remember which quests lead on to this one.
                for _, field in ipairs({ "preQuestSingle", "preQuestGroup" }) do
                    local pre = get("Quest", id, field)
                    if type(pre) == "table" then
                        for _, preID in ipairs(pre) do state.leadsOn[preID] = true end
                    end
                end
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
        for _, id in ipairs(allIds("Npc")) do
            local title = get("Npc", id, "subName")
            if title and titles[title] then
                state.byTitle[title] = state.byTitle[title] or {}
                table.insert(state.byTitle[title], id)
            end
            -- Town guards (for "pull the elite to the guards" tips).
            local name = get("Npc", id, "name")
            if type(name) == "string" and QuestieData.IsGuardName(name) then
                state.byTitle[QuestieData.GUARD_TITLE] = state.byTitle[QuestieData.GUARD_TITLE] or {}
                table.insert(state.byTitle[QuestieData.GUARD_TITLE], id)
            end
            count = count + 1
            if count % SCAN_BATCH == 0 then coroutine.yield() end
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

---------------------------------------------------------------------------
-- Search (guide editor)
---------------------------------------------------------------------------

local searchIndex -- list of { id, name, lower } for every quest in QuestieDB

local function buildSearchIndex()
    searchIndex = {}
    for _, id in ipairs(allIds("Quest")) do
        local name = get("Quest", id, "name")
        if type(name) == "string" and name ~= "" then
            searchIndex[#searchIndex + 1] = { id = id, name = name, lower = name:lower() }
        end
    end
end

--- What QuestieDB knows about a quest: { id, name, level, requiredLevel,
--- zone }. Works for unknown quests too (name "Quest <id>", level 0).
function QuestieData.Describe(id, name)
    local zoneOrSort = get("Quest", id, "zoneOrSort")
    local zone = type(zoneOrSort) == "number" and zoneOrSort > 0
        and ns.GameApi.GetAreaName(zoneOrSort) or nil
    return {
        id = id,
        name = name or get("Quest", id, "name") or ("Quest " .. id),
        level = get("Quest", id, "questLevel") or 0,
        requiredLevel = get("Quest", id, "requiredLevel") or 0,
        zone = zone,
    }
end

--- Find quests by part of their name, or by quest ID. Searches every quest
--- in QuestieDB (any race, class or faction) so guides can be written for
--- other characters too.
-- @return list of { id, name, level, requiredLevel, zone } (at most `limit`)
function QuestieData.Search(query, limit)
    limit = limit or 50
    local results = {}
    if not lib() then return results end
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return results end
    if not searchIndex then buildSearchIndex() end

    local describe = QuestieData.Describe

    -- An exact quest ID comes first.
    local asNumber = tonumber(query)
    if asNumber then
        local name = get("Quest", asNumber, "name")
        if name then results[1] = describe(asNumber, name) end
    end

    -- Names starting with the text, then names containing it.
    local starts, contains = {}, {}
    for _, q in ipairs(searchIndex) do
        if q.id ~= asNumber then
            local at = q.lower:find(query, 1, true)
            if at == 1 then starts[#starts + 1] = q
            elseif at then contains[#contains + 1] = q end
        end
    end
    local byName = function(a, b)
        if a.lower ~= b.lower then return a.lower < b.lower end
        return a.id < b.id
    end
    table.sort(starts, byName)
    table.sort(contains, byName)
    for _, list in ipairs({ starts, contains }) do
        for _, q in ipairs(list) do
            if #results >= limit then return results end
            results[#results + 1] = describe(q.id, q.name)
        end
    end
    return results
end

--- Forget everything (tests, or after a level-up changes the race/class view).
--- Forget converted spawn points (after map lookups get better, e.g. when
--- Questie finishes starting up).
function QuestieData.ResetSpawns()
    spawnCache = {}
end

function QuestieData.Reset()
    if ns.StepList then ns.StepList.ResetCache() end
    state.status = "unknown"
    state.candidates, state.byTitle, state.classTitle, state.leadsOn = {}, {}, nil, {}
    spawnCache = {}
    dungeonByArea = {}
    searchIndex = nil
end
