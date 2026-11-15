--[[
    ForeverPath - Guide/Sources.lua

    Turns the live game state into candidate steps for the Planner:

      * quests in your log that are ready  -> TURNIN at the quest ender
      * quests in your log still in progress -> COMPLETE at the objectives
      * quests you can pick up nearby       -> ACCEPT at the quest giver
      * suggestions and class training       -> TRAIN / BUY / NOTE / HEARTH

    Locations come from Blizzard's own quest waypoints first, then from
    QuestieDB. Available quests are limited to the zones of your current
    route band plus the zone you're standing in, so the guide keeps you on
    the route you picked in the main window.
]]

local _, ns = ...

local Sources = {}
ns.Sources = Sources

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Give a map point world coordinates (cached per point table).
local function withWorld(point)
    if point and point.world == nil then
        point.world = ns.GameApi.GetWorldPosition(point.mapID, point.x, point.y) or false
    end
    return point
end

local function worldOf(point)
    return point and point.world or nil
end

--- Nearest point among a list of actors; returns actor, point.
local function nearestActor(origin, actors, allowedMaps)
    local bestActor, bestPoint, bestDist
    for _, actor in ipairs(actors) do
        local usable = {}
        for _, p in ipairs(actor.points) do
            if not allowedMaps or allowedMaps[p.mapID] then
                usable[#usable + 1] = withWorld(p)
            end
        end
        local point, dist = ns.Planner.Nearest(origin, usable)
        if point and (not bestDist or dist < bestDist) then
            bestActor, bestPoint, bestDist = actor, point, dist
        end
    end
    return bestActor, bestPoint, bestDist
end

local function target(point, label)
    if not point then return nil end
    return { mapID = point.mapID, x = point.x, y = point.y, world = worldOf(point) or nil, label = label }
end

--- Maps the guide may send you to for new quests.
function Sources.AllowedMaps(plan, playerMapID)
    local allowed = {}
    if playerMapID then allowed[playerMapID] = true end
    if plan and plan.current then
        for _, zone in ipairs(plan.current.zones) do
            local mapID = ns.ZoneMap.MapIdByName(zone)
            if mapID then allowed[mapID] = true end
        end
    end
    return allowed
end

---------------------------------------------------------------------------
-- Mode helpers
---------------------------------------------------------------------------

local DEFAULT_MAX_ACCEPT = 15

local function rulesOf(ctx)
    return ctx.rules or {}
end

-- Yards a guide's "priority quests" are treated as closer than they are.
local PRIORITY_BONUS = 1000

--- Quests the chosen guide never picks up (its "skip quests" list), or
--- that you skipped in the step guide.
local function isSkipped(ctx, questID)
    if ctx.skipped[questID] then return true end
    return ctx.guide ~= nil and ctx.guide.skipSet ~= nil and ctx.guide.skipSet[questID] == true
end

local function isPriority(ctx, questID)
    return ctx.guide ~= nil and ctx.guide.prioritySet ~= nil and ctx.guide.prioritySet[questID] == true
end

--- maxDetour of 0 (or unset) means "no limit".
local function detourLimit(rules)
    local limit = rules.maxDetour
    if limit and limit > 0 then return limit end
    return nil
end

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------

local function turnInStep(ctx, questID, quest)
    local actor, point = nearestActor(ctx.origin,
        ns.QuestieData.GetFinishers(questID, ctx.profile.faction))
    return {
        key = "turnin:" .. questID,
        kind = "TURNIN",
        title = actor and ("Turn in to " .. actor.name) or "Turn in",
        lines = { quest.title },
        questIDs = { questID },
        actor = actor and (actor.kind .. ":" .. actor.id) or nil,
        target = target(point, actor and actor.name),
        bonus = rulesOf(ctx).turninBonus,
    }
end

--- One "Run <dungeon>" step per dungeon, collecting its quests. Blizzard's
--- quest waypoint for a dungeon quest usually leads to the entrance.
local function dungeonStep(ctx, questID, quest, dungeon)
    local point = withWorld(ns.GameApi.GetQuestWaypoint(questID))
    local lines = { quest.title }
    if not point then
        lines[#lines + 1] = "  Entrance: " .. dungeon.zone
    end
    return {
        key = "dungeon:" .. questID,
        kind = "DUNGEON",
        title = "Run " .. dungeon.name,
        lines = lines,
        questIDs = { questID },
        actor = "dungeon:" .. dungeon.name,
        target = target(point, dungeon.name),
        bonus = rulesOf(ctx).turninBonus,
    }
end

local function objectiveStep(ctx, questID, quest)
    local point = withWorld(ns.GameApi.GetQuestWaypoint(questID))
    local label
    if not point then
        local actor
        actor, point = nearestActor(ctx.origin, ns.QuestieData.GetObjectiveTargets(questID))
        label = actor and actor.name
    end
    local lines = { quest.title }
    for _, objective in ipairs(ns.GameApi.GetOpenObjectives(questID)) do
        lines[#lines + 1] = "  " .. objective
    end
    return {
        key = "complete:" .. questID,
        kind = "COMPLETE",
        title = "Complete: " .. quest.title,
        lines = lines,
        questIDs = { questID },
        target = target(point, label or quest.title),
    }
end

local function questLogSteps(ctx, out)
    for questID, quest in pairs(ctx.log) do
        if not ctx.skipped[questID] then -- quests already taken are always shown
            if quest.complete then
                out[#out + 1] = turnInStep(ctx, questID, quest)
            else
                local dungeon = ns.QuestieData.DungeonOf(questID)
                if dungeon then
                    out[#out + 1] = dungeonStep(ctx, questID, quest, dungeon)
                else
                    out[#out + 1] = objectiveStep(ctx, questID, quest)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Available quests
---------------------------------------------------------------------------

--- Quest IDs the character can pick up right now, within the mode's level
--- window. This is the expensive part of planning, so the Engine caches it
--- between quest-state changes.
function Sources.DoableQuests(ctx)
    local data = ns.QuestieData
    local doable = {}
    if not data.IsReady() then return doable end
    for _, questID in ipairs(data.GetCandidates(ctx.profile.level, rulesOf(ctx))) do
        if data.IsDoable(questID, ctx) then
            doable[#doable + 1] = questID
        end
    end
    return doable
end

--- Is the quest's nearest objective too far from its giver (Efficient)?
local function isDetour(questID, giverPoint, maxDetour)
    if not maxDetour or not giverPoint or not giverPoint.world then return false end
    local _, _, dist = nearestActor(giverPoint.world, ns.QuestieData.GetObjectiveTargets(questID))
    return dist ~= nil and dist > maxDetour
end

--- Would the current guide pick this quest up? Used by auto-accept.
--- A quest an NPC offers is clearly available, so prerequisites aren't
--- re-checked - only what the guide itself filters on.
function Sources.WantsQuest(ctx, questID)
    if isSkipped(ctx, questID) then return false end
    if isPriority(ctx, questID) then return true end
    local data = ns.QuestieData
    if not data.IsReady() then return true end

    local rules = rulesOf(ctx)
    local inWindow = data.InLevelWindow(questID, ctx.profile.level, rules)
    if inWindow == nil then return true end -- unknown to QuestieDB: allow
    if not inWindow then return false end

    local limit = detourLimit(rules)
    if limit then
        local _, point = nearestActor(ctx.origin, data.GetStarters(questID, ctx.profile.faction))
        if isDetour(questID, point, limit) then return false end
    end
    return true
end

local function acceptBonus(ctx, questID)
    local rules = rulesOf(ctx)
    local bonus = 0
    if isPriority(ctx, questID) then bonus = bonus + PRIORITY_BONUS end
    if (rules.chainBonus or 0) > 0 and ns.QuestieData.IsFollowUp(questID) then
        bonus = bonus + rules.chainBonus
    end
    return bonus
end

local function availableSteps(ctx, out)
    local data = ns.QuestieData
    local rules = rulesOf(ctx)
    local found = {}

    for _, questID in ipairs(ctx.doable or Sources.DoableQuests(ctx)) do
        if not isSkipped(ctx, questID) and not ctx.log[questID] then
            -- Priority quests are fetched wherever their giver stands;
            -- everything else stays inside the guide's zones.
            local priority = isPriority(ctx, questID)
            local maps = (not priority) and ctx.allowedMaps or nil
            local actor, point, dist = nearestActor(ctx.origin,
                data.GetStarters(questID, ctx.profile.faction), maps)
            if actor and (priority or not isDetour(questID, point, detourLimit(rules))) then
                found[#found + 1] = { questID = questID, actor = actor, point = point, dist = dist }
            end
        end
    end

    table.sort(found, function(a, b) return a.dist < b.dist end)
    for i = 1, math.min(#found, rules.maxAccept or DEFAULT_MAX_ACCEPT) do
        local f = found[i]
        local name = data.GetQuestName(f.questID) or ("quest " .. f.questID)
        local line = "Accept: " .. name
        out[#out + 1] = {
            key = "accept:" .. f.questID,
            kind = "ACCEPT",
            title = "Talk to " .. f.actor.name,
            lines = { line },
            questIDs = { f.questID },
            actor = f.actor.kind .. ":" .. f.actor.id,
            target = target(f.point, f.actor.name),
            bonus = acceptBonus(ctx, f.questID),
        }
    end
end

---------------------------------------------------------------------------
-- Suggestions and training
---------------------------------------------------------------------------

--- The training level currently owed, or nil if you're up to date.
function Sources.DueTrainingLevel(level, trainedLevel)
    local t = ns.Data.Training
    if level < t.from then return nil end
    local due = t.from + math.floor((level - t.from) / t.every) * t.every
    if (trainedLevel or 0) >= due then return nil end
    return due
end

local GUIDE_STEP_DETECT = { TRAIN = "trainer", HEARTH = "hearth" }

--- Built-in suggestions plus the chosen guide's own "step" lines, in the
--- same shape. A guide step's id is built from its content, so editing
--- other lines of the guide doesn't reset what you've ticked off.
function Sources.AllSuggestions(guide)
    local list = {}
    for _, s in ipairs(ns.Data.Suggestions) do list[#list + 1] = s end
    for _, s in ipairs(guide and guide.steps or {}) do
        list[#list + 1] = {
            id = ("guide:%s:%d:%s:%s"):format(guide.id or "?", s.level, s.kind, s.text),
            level = s.level,
            kind = s.kind,
            text = s.text,
            detect = GUIDE_STEP_DETECT[s.kind],
        }
    end
    return list
end

local function suggestionSteps(ctx, out, reminders)
    local profile, char = ctx.profile, ctx.char

    for _, s in ipairs(Sources.AllSuggestions(ctx.guide)) do
        local forClass = not s.classes or s.classes[profile.classFile]
        if forClass and profile.level >= s.level and not char.done[s.id] then
            reminders[#reminders + 1] = {
                key = "suggest:" .. s.id,
                kind = s.kind,
                title = s.text,
                lines = {},
                questIDs = {},
                suggestionID = s.id,
                detect = s.detect,
                manual = s.detect == nil,
            }
        end
    end

    local due = Sources.DueTrainingLevel(profile.level, char.trainedLevel)
    if due then
        local step = {
            key = "train:" .. due,
            kind = "TRAIN",
            title = ns.Data.Training.text,
            lines = { "New abilities are waiting (level " .. due .. ")." },
            questIDs = {},
            detect = "trainer",
            trainingLevel = due,
        }
        local actor, point = nearestActor(ctx.origin, ns.QuestieData.GetTrainers(profile.faction))
        if actor and point and point.world then
            step.title = "Train at " .. actor.name
            step.target = target(point, actor.name)
            out[#out + 1] = step          -- part of the walking route
        else
            reminders[#reminders + 1] = step
        end
    end
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------

--- Collect every candidate step.
-- @param ctx {
--     profile, log, isCompleted(id), origin (world pos or nil),
--     allowedMaps, skipped = { [questID] = true },
--     doable = optional cached result of Sources.DoableQuests(ctx),
--     rules = the guide's rules, guide = the guide (skip/priority lists, steps),
--     char = { done = {}, trainedLevel = n } }
-- @return steps (route candidates), reminders (no route position)
function Sources.Collect(ctx)
    local steps, reminders = {}, {}
    questLogSteps(ctx, steps)
    availableSteps(ctx, steps)
    suggestionSteps(ctx, steps, reminders)
    return steps, reminders
end
