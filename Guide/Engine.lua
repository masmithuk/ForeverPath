--[[
    ForeverPath - Guide/Engine.lua

    Keeps the step list current. It replans when something relevant
    happens (a quest is accepted, progressed, turned in or abandoned, you
    level, change zone, visit a trainer or bind your hearthstone) and when
    you have walked far enough that a different step may now be closer.

    The current step is "sticky": once shown it stays first until it is
    finished or skipped, even if you walk past something else, so the
    arrow doesn't flick between targets.
]]

local _, ns = ...

local Engine = {}
ns.Engine = Engine

local REPLAN_DELAY = 0.3          -- seconds; coalesces bursts of quest events
local TICK_INTERVAL = 3           -- seconds between position checks
local REPLAN_DISTANCE = 150       -- yards walked before re-ordering steps

Engine.state = {
    steps = {},
    reminders = {},
    currentKey = nil,
    origin = nil,       -- world position the plan was made from
    dataStatus = "unknown",
}

local turnedInThisSession = {}
local replanPending = false
local ticker

-- Which quests you can pick up only changes when quests are accepted,
-- turned in or abandoned, or you level or change zone - not on every
-- QUEST_LOG_UPDATE (which fires for each kill and loot). Cache it.
local doableCache = nil
local function invalidateDoable() doableCache = nil end

---------------------------------------------------------------------------
-- Settings shortcuts
---------------------------------------------------------------------------

local function guideSettings() return ns.Settings.account.guide end
local function charGuide() return ns.Settings.char.guide end

local function isCompleted(questID)
    return turnedInThisSession[questID] or ns.GameApi.IsQuestCompleted(questID)
end

---------------------------------------------------------------------------
-- Planning
---------------------------------------------------------------------------

local function currentOrigin()
    local pos = ns.GameApi.GetPlayerPosition()
    if not pos then return nil, nil end
    return ns.GameApi.GetWorldPosition(pos.mapID, pos.x, pos.y), pos.mapID
end

--- Recompute the step list now.
function Engine.Replan()
    replanPending = false
    if not guideSettings().enabled then return end

    local profile = ns.Character.Detect()
    local route = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    local origin, mapID = currentOrigin()
    local char = charGuide()

    local ctx = {
        profile = profile,
        level = profile.level,
        log = ns.GameApi.GetQuestLog(),
        isCompleted = isCompleted,
        origin = origin,
        allowedMaps = ns.Sources.AllowedMaps(route, mapID),
        skipped = char.skipped,
        char = char,
    }

    if not doableCache and ns.QuestieData.IsReady() then
        doableCache = ns.Sources.DoableQuests(ctx)
    end
    ctx.doable = doableCache

    local candidates, reminders = ns.Sources.Collect(ctx)
    local state = Engine.state
    state.steps = ns.Planner.Build(origin, candidates, state.currentKey, guideSettings().maxSteps)
    state.reminders = reminders
    state.origin = origin
    state.dataStatus = ns.QuestieData.Status()

    local first = state.steps[1]
    state.currentKey = first and first.key or nil
    ns.Waypoints.Set(first and first.target, first and first.title, guideSettings().waypoints)

    if ns.GuideFrame then ns.GuideFrame.Update(state) end
end

--- Ask for a replan soon; many events arrive in bursts.
function Engine.RequestReplan()
    if replanPending then return end
    replanPending = true
    C_Timer.After(REPLAN_DELAY, Engine.Replan)
end

local function onTick()
    if not guideSettings().enabled then return end
    local origin = currentOrigin()
    local last = Engine.state.origin
    if origin and (not last or origin.continent ~= last.continent
        or ns.Util.Distance(origin, last) > REPLAN_DISTANCE) then
        Engine.RequestReplan()
    elseif ns.GuideFrame then
        ns.GuideFrame.UpdateDistance(origin)
    end
end

---------------------------------------------------------------------------
-- Completing and skipping steps
---------------------------------------------------------------------------

local function markSuggestion(step)
    local char = charGuide()
    if step.suggestionID then char.done[step.suggestionID] = true end
    if step.trainingLevel then
        char.trainedLevel = math.max(char.trainedLevel or 0, step.trainingLevel)
    end
end

--- Mark a step as done by hand (reminders, or anything the game can't detect).
function Engine.MarkDone(key)
    for _, list in ipairs({ Engine.state.reminders, Engine.state.steps }) do
        for _, step in ipairs(list) do
            if step.key == key then
                markSuggestion(step)
                Engine.Replan()
                return true
            end
        end
    end
    return false
end

--- Skip the current step. Quests it covers stay hidden until /fp unskip.
function Engine.SkipCurrent()
    local step = Engine.state.steps[1]
    if not step then return nil end
    local char = charGuide()
    for _, questID in ipairs(step.questIDs or {}) do
        char.skipped[questID] = true
    end
    markSuggestion(step)
    Engine.state.currentKey = nil
    Engine.Replan()
    return step
end

function Engine.UnskipAll()
    charGuide().skipped = {}
    invalidateDoable()
    Engine.Replan()
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------

local function onTrainerShow()
    if ns.GameApi.IsTradeskillTrainer() then return end
    local level = ns.Character.Detect().level
    local char = charGuide()
    char.trainedLevel = math.max(char.trainedLevel or 0, level)
    for _, s in ipairs(ns.Data.Suggestions) do
        if s.detect == "trainer" and level >= s.level then char.done[s.id] = true end
    end
    Engine.RequestReplan()
end

local function onHearthBound()
    for _, s in ipairs(ns.Data.Suggestions) do
        if s.detect == "hearth" then charGuide().done[s.id] = true end
    end
    Engine.RequestReplan()
end

local function buildIndex()
    local profile = ns.Character.Detect()
    ns.QuestieData.BuildIndex(profile, function(fn) C_Timer.After(0, fn) end, function()
        invalidateDoable()
        Engine.RequestReplan()
    end)
end

function Engine.Start()
    ns:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
        if ns.Util.SafeNumber(questID) then turnedInThisSession[questID] = true end
        invalidateDoable()
        Engine.RequestReplan()
    end)
    -- Events that change which quests are available.
    for _, event in ipairs({
        "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    }) do
        ns:RegisterEvent(event, function()
            invalidateDoable()
            Engine.RequestReplan()
        end)
    end
    -- Objective progress: only the log steps change.
    ns:RegisterEvent("QUEST_LOG_UPDATE", Engine.RequestReplan)
    ns:RegisterEvent("TRAINER_SHOW", onTrainerShow)
    ns:RegisterEvent("HEARTHSTONE_BOUND", onHearthBound)

    invalidateDoable()
    buildIndex()
    if not ticker and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(TICK_INTERVAL, onTick)
    end
    Engine.RequestReplan()
end

--- Turn the guide on or off (clears the waypoint when off).
function Engine.SetEnabled(enabled)
    guideSettings().enabled = enabled and true or false
    if enabled then
        Engine.Replan()
    else
        ns.Waypoints.Clear()
        Engine.state.steps, Engine.state.reminders = {}, {}
        if ns.GuideFrame then ns.GuideFrame.Update(Engine.state) end
    end
end

-- Exposed for tests.
Engine._onTick = onTick
Engine._reset = function()
    turnedInThisSession = {}
    doableCache = nil
    replanPending = false
    ticker = nil
    Engine.state = { steps = {}, reminders = {}, dataStatus = "unknown" }
end
