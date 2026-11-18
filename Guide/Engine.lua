--[[
    Questwalker - Guide/Engine.lua

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
local questieStarted = nil -- was Questie ready when the last plan was made?
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

--- Maps where the guide may suggest new quests: your guide's zones for
--- your level, plus where you stand.
local function allowedMaps(plan, playerMapID)
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
        playerMapID = mapID,
        allowedMaps = allowedMaps(route, mapID),
        skipped = char.skipped,
        notOffered = char.notOffered,
        includeGroupQuests = guideSettings().groupQuests ~= false,
        char = char,
        focusQuest = char.focus,
        -- Last planning pass's available quests (the Steps list uses them
        -- to tell where guide steps come up). Replan refreshes them.
        doable = doableCache and doableCache.list,
        doableFromList = doableCache and doableCache.fromList,
    }
end

--- Recompute the step list now.
function Engine.Replan()
    replanPending = false
    if not guideSettings().enabled then return end

    questieStarted = ns.QuestieData.QuestieStarted()
    local ctx = Engine.BuildContext()
    local origin = ctx.origin
    local char = charGuide()

    -- A quest chosen in the Steps list stays the focus until it's handed in.
    if char.focus and isCompleted(char.focus) then
        char.focus = nil
        ctx.focusQuest = nil
    end

    local questsChanged = false
    if not doableCache and ns.QuestieData.IsReady() then
        local list, fromList = ns.Sources.DoableQuests(ctx)
        doableCache = { list = list, fromList = fromList, rates = ctx.rates, rateMedian = ctx.rateMedian }
        questsChanged = true
    end
    ctx.doable = doableCache and doableCache.list
    ctx.rates = doableCache and doableCache.rates
    ctx.rateMedian = doableCache and doableCache.rateMedian
    ctx.doableFromList = doableCache and doableCache.fromList

    -- So is a step chosen there, until it's ticked off.
    if char.focusStep and char.done[char.focusStep] then char.focusStep = nil end

    local candidates = ns.Sources.Collect(ctx)
    local state = Engine.state
    local merged = ns.Planner.GroupObjectives(ns.Planner.Merge(candidates), nil, origin)
    local pinned = state.currentKey
    -- Keep following the same quests when a group grows or shrinks (its
    -- key changes as quests join or finish).
    local previous = state.steps[1]
    local pinnedFound = false
    for _, step in ipairs(merged) do if step.key == pinned then pinnedFound = true end end
    if pinned and not pinnedFound and previous and previous.kind == "COMPLETE" then
        local wanted = {}
        for _, id in ipairs(previous.questIDs or {}) do wanted[id] = true end
        for _, step in ipairs(merged) do
            if step.kind == "COMPLETE" and not pinnedFound then
                for _, id in ipairs(step.questIDs or {}) do
                    if wanted[id] then pinned, pinnedFound = step.key, true; break end
                end
            end
        end
    end
    for _, step in ipairs(merged) do
        if char.focusStep and step.key == char.focusStep then pinned = step.key end
    end
    if ctx.focusQuest then
        for _, step in ipairs(merged) do
            for _, id in ipairs(step.questIDs or {}) do
                if id == ctx.focusQuest then pinned = step.key end
            end
        end
    end
    state.steps = ns.Planner.Order(origin, merged, pinned, guideSettings().maxSteps)
    state.origin = origin
    state.log = ctx.log
    state.onHold = ctx.onHold or {}
    state.tooLow = ctx.tooLow or {}
    state.groupHidden = ctx.groupHidden or {}
    state.dungeons = ctx.route and ctx.route.dungeons or {}
    state.dataStatus = ns.QuestieData.Status()

    local first = state.steps[1]
    -- Already standing on a "go to" spot: tick it off (which plans again).
    if Engine.Arrived(first, origin) and Engine.MarkDone(first.key) then return end
    Engine.AnnotateZoneChange(ctx, first)
    state.currentKey = first and first.key or nil
    ns.Waypoints.Set(state.steps, guideSettings().waypoints)

    if ns.GuideFrame then ns.GuideFrame.Update(state) end
    if ns.TargetButton then ns.TargetButton.Update(state, origin) end
    -- Quest statuses in the Zones and Steps tabs only change with quest state.
    if questsChanged and ns.MainFrame then
        ns.MainFrame.RefreshIf("zones")
        ns.MainFrame.RefreshIf("steps")
    end
end

--- Ask for a replan soon; many events arrive in bursts.
function Engine.RequestReplan()
    if replanPending then return end
    replanPending = true
    C_Timer.After(REPLAN_DELAY, Engine.Replan)
end

--- You've out-levelled the zone you're in: the guide's zones for your
--- level don't include it, and the next step is in one of them. Returns
--- { from = zone name, to = zone name } or nil.
function Engine.ZoneChange(ctx, step)
    local target = step and step.target
    local here = ctx.playerMapID
    if not target or not target.mapID or not here or target.mapID == here then return nil end
    local bandMaps = {}
    for _, zone in ipairs(ctx.route.current and ctx.route.current.zones or {}) do
        local mapID = ns.ZoneMap.MapIdByName(zone)
        if mapID then bandMaps[mapID] = zone end
    end
    if bandMaps[here] or not bandMaps[target.mapID] then return nil end
    return { from = ns.GameApi.GetMapName(here) or "?", to = bandMaps[target.mapID] }
end

--- Tell the player on the step (and once in chat) when it takes them to a
--- new zone because they've out-levelled this one.
function Engine.AnnotateZoneChange(ctx, step)
    local change = Engine.ZoneChange(ctx, step)
    if not change then return end
    local line = ns.L.ZONE_CHANGE_FMT:format(change.from, change.to)
    step.lines = step.lines or {}
    if step.lines[1] ~= line then table.insert(step.lines, 1, line) end
    step.zoneChange = change
    local char = charGuide()
    if char.zoneHint ~= change.to then
        char.zoneHint = change.to
        ns.Util.Print(ns.L.ZONE_CHANGE_CHAT_FMT:format(change.from, change.to, step.title))
    end
end

--- Has the player arrived at a "go to" step's spot?
function Engine.Arrived(step, origin)
    local to = step and step.arriveRadius and step.target and step.target.world
    if not to or not origin or origin.continent ~= to.continent then return false end
    return ns.Util.Distance(origin, to) <= step.arriveRadius
end

--- When Questie finishes starting up, its availability and zone data
--- become usable: drop everything worked out without it and plan again.
--- (questieStarted is recorded by each Replan.)
local function checkQuestieStarted()
    local started = ns.QuestieData.QuestieStarted()
    if started and questieStarted == false then
        questieStarted = true
        ns.ZoneMap.Reset()
        ns.QuestieData.ResetSpawns()
        ns.StepList.ResetCache()
        invalidateDoable()
        Engine.state.currentKey = nil
        Engine.Replan()
        return true
    end
    questieStarted = started
    return false
end
Engine._checkQuestieStarted = checkQuestieStarted

local function onTick()
    if not guideSettings().enabled then return end
    if checkQuestieStarted() then return end
    local origin = currentOrigin()
    local current = Engine.state.steps[1]
    if Engine.Arrived(current, origin) then
        Engine.MarkDone(current.key)
        return
    end
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
-- History: every skip and every hand-ticked step is recorded, so Back
-- can undo them one at a time (newest first). Saved per character.
---------------------------------------------------------------------------

local MAX_HISTORY = 50

local function history()
    local char = charGuide()
    char.history = char.history or {}
    return char.history
end

--- Record a step as dealt with (a guide note ticked off, training done,
--- an inn or profession trainer passed) and note what changed in `entry`
--- so Back can undo it.
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
    if step.serviceKey and not char.skippedSteps[step.serviceKey] then
        char.skippedSteps[step.serviceKey] = true
        entry.serviceKey = step.serviceKey
    end
end

local function record(entry)
    local list = history()
    list[#list + 1] = entry
    while #list > MAX_HISTORY do table.remove(list, 1) end
end

--- Tick off the guide's reached list steps of one kind ("TRAIN" when you
--- open your class trainer, "HEARTH" when you set your hearthstone).
function Engine.CompleteListSteps(kind)
    local char = charGuide()
    for _, step in ipairs(Engine.state.steps) do
        if step.listKind == kind and not char.done[step.key] then
            local entry = { action = "done", key = step.key, title = step.title, questIDs = {} }
            markSuggestion(step, entry)
            record(entry)
        end
    end
end

--- Skip one of the guide's list steps (Steps list). Back can undo it.
function Engine.SkipListStep(key, title)
    local char = charGuide()
    if char.done[key] then return false end
    char.done[key] = true
    record({ action = "skip", key = key, title = title or key, questIDs = {}, suggestionID = key })
    if char.focusStep == key then char.focusStep = nil end
    Engine.Replan()
    return true
end

--- Make one of the guide's list steps the current step (Steps list).
function Engine.FocusStep(key)
    local char = charGuide()
    char.done[key] = nil
    char.focusStep = key
    char.focus = nil
    Engine.state.currentKey = nil
    Engine.Replan()
    return true
end

--- Mark a step as done by hand (a guide's note/buy steps, which the game
--- can't detect).
function Engine.MarkDone(key)
    for _, step in ipairs(Engine.state.steps) do
        if step.key == key then
            local entry = { action = "done", key = step.key, title = step.title, questIDs = {} }
            markSuggestion(step, entry)
            record(entry)
            Engine.Replan()
            return true
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
    for _, questID in ipairs(step.questIDs or {}) do
        if char.focus == questID then char.focus = nil end
    end
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.Replan()
    return step
end

--- "I'm lost": forget the step you chose in the Steps list and the step
--- the guide was holding on to, and pick the best one from where you're
--- standing right now. Skipped quests stay skipped.
-- @return the new current step, or nil
function Engine.BestStep()
    charGuide().focus = nil
    charGuide().focusStep = nil
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.state.origin = nil -- force a fresh position and a full re-sort
    Engine.Replan()
    return Engine.state.steps[1]
end

---------------------------------------------------------------------------
-- Working with one quest (the Steps list)
---------------------------------------------------------------------------

--- Make the step guide take you through one quest next: pick it up, do
--- it, hand it in. A skipped quest is unskipped.
-- @return true, or false and a reason ("done" | "level" | "locked"), level
function Engine.FocusQuest(questID)
    local ctx = Engine.BuildContext()
    local info = ns.QuestieData.Describe(questID)
    local status = ns.Catalog.QuestStatus({ id = questID, requiredLevel = info.requiredLevel }, ctx)
    if status == "done" or status == "level" or status == "locked" then
        return false, status, info.requiredLevel
    end
    local char = charGuide()
    char.skipped[questID] = nil
    char.notOffered[questID] = nil
    char.focus = questID
    char.focusStep = nil
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.Replan()
    return true
end

--- The quest chosen in the Steps list, if any.
function Engine.FocusedQuest()
    return charGuide().focus
end

--- Skip one quest (from the Steps list). Back can undo it.
function Engine.SkipQuest(questID, title)
    local char = charGuide()
    if char.skipped[questID] then return false end
    char.skipped[questID] = true
    record({ action = "skip", key = "accept:" .. questID, title = title or ("Quest " .. questID),
             questIDs = { questID } })
    if char.focus == questID then char.focus = nil end
    invalidateDoable()
    Engine.Replan()
    return true
end

--- Bring one skipped quest back (from the Steps list).
function Engine.UnskipQuest(questID)
    local char = charGuide()
    if not char.skipped[questID] then return false end
    char.skipped[questID] = nil
    invalidateDoable()
    Engine.Replan()
    return true
end

--- The step Back would bring back, or nil.
function Engine.LastSkipped()
    local list = history()
    return list[#list]
end

--- Undo the most recent skip or hand-ticked step, and make that step
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
    if entry.serviceKey then char.skippedSteps[entry.serviceKey] = nil end
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
function Engine.OnModeChanged()
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

--- Quests in your log that aren't part of your guide. A quest is part of
--- it when it's on the guide's quest list or in one of the guide's zones
--- for your level or the next band - and not too far below your level. Kept anyway: quests ready to hand
--- in, class quests, and quests whose zone QuestieDB doesn't know.
-- @return list of { id, title }, sorted by title
function Engine.UnrelatedQuests()
    local ctx = Engine.BuildContext()
    local data = ns.QuestieData
    local listed = ctx.guide.questRank or {}
    local guideMaps = {}
    for _, entry in ipairs({ ctx.route.current, ctx.route.next }) do
        for _, zone in ipairs(entry and entry.zones or {}) do
            local mapID = ns.ZoneMap.MapIdByName(zone)
            if mapID then guideMaps[mapID] = true end
        end
    end
    local out = {}
    for id, quest in pairs(ctx.log) do
        local known = data.IsReady() and data.Describe(id).level > 0
        local mapID = known and data.QuestMapID(id)
        local tooLow = not quest.complete and data.TooLow(id, ctx.profile.level, ctx.rules)
        local related = not known or not mapID or quest.complete or listed[id]
            or data.IsClassQuest(id) or (guideMaps[mapID] and not tooLow)
        if not related then
            out[#out + 1] = { id = id, title = quest.title }
        end
    end
    table.sort(out, function(a, b) return a.title < b.title end)
    return out
end

--- Abandon every unrelated quest. @return how many were abandoned
function Engine.AbandonUnrelated()
    local n = 0
    for _, q in ipairs(Engine.UnrelatedQuests()) do
        if ns.GameApi.AbandonQuest(q.id) then n = n + 1 end
    end
    invalidateDoable()
    Engine.RequestReplan()
    return n
end

function Engine.UnskipAll()
    local char = charGuide()
    char.skipped = {}
    char.skippedSteps = {}
    char.notOffered = {}
    -- Skips are all undone; keep only hand-ticked steps in the history.
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

--- Visiting your class trainer counts as training for your level.
--- Profession trainers and hearthstone binding change game state the
--- service steps read directly, so a replan is enough for those.
local function onTrainerShow()
    if not ns.GameApi.IsTradeskillTrainer() then
        local char = charGuide()
        char.trainedLevel = math.max(char.trainedLevel or 0, ns.Character.Detect().level)
        Engine.CompleteListSteps("TRAIN")
    end
    Engine.RequestReplan()
end

local function onHearthBound()
    Engine.CompleteListSteps("HEARTH")
    Engine.RequestReplan()
end

local function buildIndex()
    local profile = ns.Character.Detect()
    ns.QuestieData.BuildIndex(profile, function(fn) C_Timer.After(0, fn) end, function()
        invalidateDoable()
        Engine.RequestReplan()
    end)
end

--- A guide setting changed that affects which quests count: plan afresh.
function Engine.OnRulesChanged()
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.Replan()
end

--- Is a quest too hard for you yet (quest or creature level)? For auto accept.
function Engine.TooHard(questID)
    if not ns.QuestieData.IsReady() then return false end
    local ctx = Engine.BuildContext()
    return (ns.QuestieData.TooHard(questID, ctx.profile.level, ctx.rules))
end

--- You're talking to an NPC: if the guide sent you here for quests it
--- doesn't offer (they need an item, reputation or something QuestieDB
--- doesn't know about), note them so the guide moves on. They're checked
--- again after you level up.
-- @param npcID     the NPC's creature ID
-- @param offered   { [questID] = true } for every quest it lists
-- @return list of quest IDs that weren't offered
function Engine.NoteOffered(npcID, offered)
    if not npcID then return {} end
    local char = charGuide()
    local log = Engine.state.log or {}
    local actor = "npc:" .. npcID
    local missing, names = {}, {}
    for _, step in ipairs(Engine.state.steps) do
        if step.actor == actor and step.kind == "ACCEPT" then
            for _, id in ipairs(step.questIDs or {}) do
                if not log[id] and not offered[id] and not char.notOffered[id]
                    and not ns.GameApi.IsQuestCompleted(id) then
                    missing[#missing + 1] = id
                    names[#names + 1] = ns.QuestieData.GetQuestName(id) or ("quest " .. id)
                end
            end
        end
    end
    if #missing == 0 then return missing end
    local level = ns.Character.Detect().level
    for _, id in ipairs(missing) do char.notOffered[id] = level end
    ns.Util.Print(ns.L.NOT_OFFERED_FMT:format(table.concat(names, ", ")))
    invalidateDoable()
    Engine.state.currentKey = nil
    Engine.RequestReplan()
    return missing
end

local function onQuestList(kind)
    return function()
        local activeList, availableList = ns.AutoQuest.ReadOffers(kind)
        local offered = {}
        for _, q in ipairs(activeList) do if q.questID then offered[q.questID] = true end end
        for _, q in ipairs(availableList) do if q.questID then offered[q.questID] = true end end
        Engine.NoteOffered(ns.GameApi.GetDialogNpcID(), offered)
    end
end

function Engine.Start()
    -- What an NPC really offers (its full list; a lone quest's text isn't
    -- enough to tell, as more may follow).
    ns:RegisterEvent("GOSSIP_SHOW", onQuestList("gossip"))
    ns:RegisterEvent("QUEST_GREETING", onQuestList("greeting"))
    -- A new level can make those quests available.
    ns:RegisterEvent("PLAYER_LEVEL_UP", function() charGuide().notOffered = {} end)
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
    ns:RegisterEvent("SKILL_LINES_CHANGED", Engine.RequestReplan)

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
        Engine.state.steps, Engine.state.log = {}, {}
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
    Engine.state = { steps = {}, dataStatus = "unknown" }
end
