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

-- How many nearby quest givers to consider per planning pass.
local MAX_ACCEPT_CANDIDATES = 15

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
-- Quest log
---------------------------------------------------------------------------

local function questLogSteps(ctx, out)
    local data = ns.QuestieData
    for questID, quest in pairs(ctx.log) do
        if not ctx.skipped[questID] then
            if quest.complete then
                local actor, point = nearestActor(ctx.origin, data.GetFinishers(questID, ctx.profile.faction))
                out[#out + 1] = {
                    key = "turnin:" .. questID,
                    kind = "TURNIN",
                    title = actor and ("Turn in to " .. actor.name) or "Turn in",
                    lines = { quest.title },
                    questIDs = { questID },
                    actor = actor and (actor.kind .. ":" .. actor.id) or nil,
                    target = target(point, actor and actor.name),
                }
            else
                local point = withWorld(ns.GameApi.GetQuestWaypoint(questID))
                local label
                if not point then
                    local actor
                    actor, point = nearestActor(ctx.origin, data.GetObjectiveTargets(questID))
                    label = actor and actor.name
                end
                local lines = { quest.title }
                for _, objective in ipairs(ns.GameApi.GetOpenObjectives(questID)) do
                    lines[#lines + 1] = "  " .. objective
                end
                out[#out + 1] = {
                    key = "complete:" .. questID,
                    kind = "COMPLETE",
                    title = "Complete: " .. quest.title,
                    lines = lines,
                    questIDs = { questID },
                    target = target(point, label or quest.title),
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Available quests
---------------------------------------------------------------------------

--- Quest IDs the character can pick up right now. This is the expensive
--- part of planning, so the Engine caches it between quest-state changes.
function Sources.DoableQuests(ctx)
    local data = ns.QuestieData
    local doable = {}
    if not data.IsReady() then return doable end
    for _, questID in ipairs(data.GetCandidates(ctx.profile.level)) do
        if data.IsDoable(questID, ctx) then
            doable[#doable + 1] = questID
        end
    end
    return doable
end

local function availableSteps(ctx, out)
    local data = ns.QuestieData
    local found = {}
    for _, questID in ipairs(ctx.doable or Sources.DoableQuests(ctx)) do
        if not ctx.skipped[questID] and not ctx.log[questID] then
            local actor, point, dist = nearestActor(ctx.origin,
                data.GetStarters(questID, ctx.profile.faction), ctx.allowedMaps)
            if actor then
                found[#found + 1] = { questID = questID, actor = actor, point = point, dist = dist }
            end
        end
    end

    table.sort(found, function(a, b) return a.dist < b.dist end)
    for i = 1, math.min(#found, MAX_ACCEPT_CANDIDATES) do
        local f = found[i]
        out[#out + 1] = {
            key = "accept:" .. f.questID,
            kind = "ACCEPT",
            title = "Talk to " .. f.actor.name,
            lines = { "Accept: " .. (data.GetQuestName(f.questID) or ("quest " .. f.questID)) },
            questIDs = { f.questID },
            actor = f.actor.kind .. ":" .. f.actor.id,
            target = target(f.point, f.actor.name),
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

local function suggestionSteps(ctx, out, reminders)
    local profile, char = ctx.profile, ctx.char

    for _, s in ipairs(ns.Data.Suggestions) do
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
--     char = { done = {}, trainedLevel = n } }
-- @return steps (route candidates), reminders (no route position)
function Sources.Collect(ctx)
    local steps, reminders = {}, {}
    questLogSteps(ctx, steps)
    availableSteps(ctx, steps)
    suggestionSteps(ctx, steps, reminders)
    return steps, reminders
end
