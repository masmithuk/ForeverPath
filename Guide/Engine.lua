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

--- Maps where the guide may suggest new quests:
---   * a zone chosen in the Zones tab: that zone
---   * Automatic: your guide's zones for your level, plus where you stand
local function allowedMaps(plan, playerMapID)
    local zone = ns.Settings.char.guideId
    local mapID = zone and ns.ZoneMap.MapIdByName(zone)
    if mapID then return { [mapID] = true } end
    return ns.Sources.AllowedMaps(plan, playerMapID)
end

--- The guide this character is following.
function Engine.CurrentGuide()
    local profile = ns.Character.Detect()
    return ns.Library.Get(ns.Advisor.ResolveRouteId(profile, ns.Settings.char.routeId))
end

--- Everything a planning pass (or the guide browser) needs to know about
--- the character right now.
function Engine.BuildContext()
    local profile = ns.Character.Detect()
    local route = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    local origin, mapID = currentOrigin()
    local char = charGuide()
    return {
        profile = profile,
        level = profile.level,
        route = route,
        guide = route.route,
        rules = route.route.rules,
        log = ns.GameApi.GetQuestLog(),
        isCompleted = isCompleted,
        origin = origin,
        allowedMaps = allowedMaps(route, mapID),
        skipped = char.skipped,
        char = char,
    }
end

--- Recompute the step list now.
function Engine.Replan()
    replanPending = false
    if not guideSettings().enabled then return end

    local ctx = Engine.BuildContext()
    local origin = ctx.origin

    local questsChanged = false
    if not doableCache and ns.QuestieData.IsReady() then
        local list, fromList = ns.Sources.DoableQuests(ctx)
        doableCache = { list = list, fromList = fromList }
        questsChanged = true
    end
    ctx.doable = doableCache and doableCache.list
    ctx.doableFromList = doableCache and doableCache.fromList

    local candidates, reminders = ns.Sources.Collect(ctx)
    local state = Engine.state
    state.steps = ns.Planner.Build(origin, candidates, state.currentKey, guideSettings().maxSteps)
    state.reminders = reminders
    state.origin = origin
    state.log = ctx.log
    state.dataStatus = ns.QuestieData.Status()

    local first = state.steps[1]
    state.currentKey = first and first.key or nil
    ns.Waypoints.Set(state.steps, guideSettings().waypoints)

    if ns.GuideFrame then ns.GuideFrame.Update(state) end
    if ns.TargetButton then ns.TargetButton.Update(state, origin) end
    -- Quest statuses in the guide browser only change with quest state.
    if questsChanged and ns.MainFrame then ns.MainFrame.RefreshIf("guides") end
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
    else
        if ns.GuideFrame then ns.GuideFrame.UpdateDistance(origin) end
        -- The nearest objective creature changes as you walk.
        if ns.TargetButton then ns.TargetButton.Update(Engine.state, origin) end
    end
end

---------------------------------------------------------------------------
-- Completing and skipping steps
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- History: every skip and every hand-ticked reminder is recorded, so Back
-- can undo them one at a time (newest first). Saved per character.
---------------------------------------------------------------------------

local MAX_HISTORY = 50

local function history()
    local char = charGuide()
    char.history = char.history or {}
    return char.history
end

--- Mark a step's reminder/training as done and return what was changed,
--- so it can be undone.
local function markSuggestion(step, entry)
    local char = charGuide()
    if step.suggestionID and not char.done[step.suggestionID] then
        char.done[step.suggestionID] = true
        entry.suggestionID = step.suggestionID
    end
    if step.trainingLevel and (char.trainedLevel or 0) < step.trainingLevel then
        entry.trainedLevelBefore = char.trainedLevel or 0
        char.trainedLevel = step.trainingLevel
    end
end

local function record(entry)
    local list = history()
    list[#list + 1] = entry
    while #list > MAX_HISTORY do table.remove(list, 1) end
end

--- Mark a step as done by hand (reminders, or anything the game can't detect).
function Engine.MarkDone(key)
    for _, list in ipairs({ Engine.state.reminders, Engine.state.steps }) do
        for _, step in ipairs(list) do
            if step.key == key then
                local entry = { action = "done", key = step.key, title = step.title, questIDs = {} }
                markSuggestion(step, entry)
                record(entry)
                Engine.Replan()
                return true
            end
        end
    end
    return false
end

--- Skip the current step. Quests it covers stay hidden until Back (or
--- "Bring back skipped quests").
function Engine.SkipCurrent()
    local step = Engine.state.steps[1]
    if not step then return nil end
    local char = charGuide()
    local entry = { action = "skip", key = step.key, title = step.title, questIDs = {} }
    for _, questID in ipairs(step.questIDs or {}) do
        if not char.skipped[questID] then
            char.skipped[questID] = true
            entry.questIDs[#entry.questIDs + 1] = questID
        end
    end
    markSuggestion(step, entry)
    record(entry)
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.Replan()
    return step
end

--- The step Back would bring back, or nil.
function Engine.LastSkipped()
    local list = history()
    return list[#list]
end

--- Undo the most recent skip or hand-ticked reminder, and make that step
--- the current one again. Can be pressed repeatedly.
-- @return the history entry that was undone, or nil
function Engine.Back()
    local list = history()
    local entry = table.remove(list)
    if not entry then return nil end
    local char = charGuide()
    for _, questID in ipairs(entry.questIDs or {}) do
        char.skipped[questID] = nil
    end
    if entry.suggestionID then char.done[entry.suggestionID] = nil end
    if entry.trainedLevelBefore then char.trainedLevel = entry.trainedLevelBefore end
    invalidateDoable()
    -- Pin it so it comes back as the current step (if it still applies).
    Engine.state.currentKey = entry.key
    Engine.Replan()
    return entry
end

--- Would the current mode pick this quest up? (for auto-accept)
function Engine.WantsQuest(questID)
    return ns.Sources.WantsQuest(Engine.BuildContext(), questID)
end

--- The guide changed: different zones and rules, so rebuild everything.
--- A zone chosen under the old guide no longer applies.
function Engine.OnModeChanged()
    ns.Settings.char.guideId = nil
    Engine.state.currentKey = nil
    invalidateDoable()
    Engine.RequestReplan()
end

--- The guide being followed was edited: same guide, new zones/rules.
function Engine.OnGuideEdited()
    Engine.state.currentKey = nil
    invalidateDoable()
    Engine.RequestReplan()
end

--- Follow one zone (by name), or nil for Automatic.
function Engine.SetGuide(guideId)
    ns.Settings.char.guideId = guideId
    Engine.state.currentKey = nil
    invalidateDoable()
    Engine.Replan()
end

function Engine.UnskipAll()
    local char = charGuide()
    char.skipped = {}
    -- Skips are all undone; keep only hand-ticked reminders in the history.
    local kept = {}
    for _, e in ipairs(history()) do
        if e.action == "done" then
            e.questIDs = {}
            kept[#kept + 1] = e
        end
    end
    char.history = kept
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
    for _, s in ipairs(ns.Sources.AllSuggestions(Engine.CurrentGuide())) do
        if s.detect == "trainer" and level >= s.level then char.done[s.id] = true end
    end
    Engine.RequestReplan()
end

local function onHearthBound()
    for _, s in ipairs(ns.Sources.AllSuggestions(Engine.CurrentGuide())) do
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
    -- Waypoint addons refuse new routes in combat; try again after it.
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if ns.TargetButton then ns.TargetButton.OnCombatEnded() end
        Engine.RequestReplan()
    end)
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
        Engine.state.steps, Engine.state.reminders, Engine.state.log = {}, {}, {}
        if ns.GuideFrame then ns.GuideFrame.Update(Engine.state) end
        if ns.TargetButton then ns.TargetButton.Update(Engine.state, nil) end
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
