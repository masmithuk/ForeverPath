--[[
    Questwalker - Guide/Sources.lua

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

-- A guide's quest list: the next few available quests, in list order, are
-- treated as this many yards closer (1st, 2nd, 3rd...), so the route
-- follows the list while hand-ins and objectives still fit in by distance.
local LIST_BONUSES = { 1500, 1200, 900 }

--- Quests the chosen guide never picks up (its "skip quests" list), or
--- that you skipped in the step guide.
local function isSkipped(ctx, questID)
    if ctx.skipped[questID] then return true end
    if ctx.notOffered and ctx.notOffered[questID] then return true end
    return ctx.guide ~= nil and ctx.guide.skipSet ~= nil and ctx.guide.skipSet[questID] == true
end

--- Position of a quest in the guide's own quest list, or nil.
local function listRank(ctx, questID)
    return ctx.guide ~= nil and ctx.guide.questRank ~= nil and ctx.guide.questRank[questID] or nil
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
    -- Elites: how to solo them (pull to nearby guards) or to group up.
    if ns.QuestieData.IsReady() then
        for _, elite in ipairs(ns.QuestValue.Elites(questID)) do
            lines[#lines + 1] = "  " .. ns.QuestValue.EliteTip(elite, ctx.profile.faction, ctx.origin)
        end
    end
    return {
        key = "complete:" .. questID,
        kind = "COMPLETE",
        title = "Complete: " .. quest.title,
        questTitle = quest.title,
        lines = lines,
        questIDs = { questID },
        target = target(point, label or quest.title),
    }
end

--- A quest in your log that's still too hard waits until you're close
--- enough in level (the quest picked in the Steps list is never held).
-- @return the level to come back at, or nil
function Sources.OnHoldUntil(ctx, questID)
    if ctx.focusQuest == questID or not ns.QuestieData.IsReady() then return nil end
    local tooHard, level = ns.QuestieData.TooHard(questID, ctx.profile.level, rulesOf(ctx))
    return tooHard and level or nil
end

--- A quest in your log that's too far below you to bother with: not
--- finished, or finished but handed in somewhere off your route. (The
--- quest picked in the Steps list always counts.)
-- @param turnIn the hand-in step, for finished quests
-- @return the quest's level, or nil
function Sources.TooLowLevel(ctx, questID, quest, turnIn)
    if ctx.focusQuest == questID or not ns.QuestieData.IsReady() then return nil end
    local tooLow, qLevel = ns.QuestieData.TooLow(questID, ctx.profile.level, rulesOf(ctx))
    if not tooLow then return nil end
    if quest.complete then
        local mapID = turnIn and turnIn.target and turnIn.target.mapID
        if mapID and (not ctx.allowedMaps or ctx.allowedMaps[mapID]) then return nil end -- on the way
    end
    return qLevel
end

--- Group quests are left out when the "group quests" setting is off
--- (the quest picked in the Steps list always counts).
function Sources.HideGroupQuest(ctx, questID)
    if ctx.includeGroupQuests ~= false or ctx.focusQuest == questID then return false end
    return ns.QuestieData.IsReady() and ns.QuestieData.IsGroupQuest(questID)
end

local function questLogSteps(ctx, out)
    ctx.onHold, ctx.tooLow, ctx.groupHidden = {}, {}, {}
    for questID, quest in pairs(ctx.log) do
        -- Left out, in this order: group quests (setting off), too hard
        -- for now, too low to bother. Otherwise it's a step.
        local hideGroup = not quest.complete and Sources.HideGroupQuest(ctx, questID)
        local holdUntil = not hideGroup and not quest.complete and Sources.OnHoldUntil(ctx, questID)
        local turnIn = quest.complete and not ctx.skipped[questID] and turnInStep(ctx, questID, quest)
        local lowLevel = not hideGroup and not holdUntil and Sources.TooLowLevel(ctx, questID, quest, turnIn)
        if hideGroup then
            ctx.groupHidden[#ctx.groupHidden + 1] = { id = questID, title = quest.title }
        elseif holdUntil then
            ctx.onHold[#ctx.onHold + 1] = { id = questID, title = quest.title, level = holdUntil }
        elseif lowLevel then
            ctx.tooLow[#ctx.tooLow + 1] = { id = questID, title = quest.title, level = lowLevel }
        elseif not ctx.skipped[questID] then -- quests already taken are always shown
            if quest.complete then
                out[#out + 1] = turnIn
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
-- Guides with a quest list: listed quests that can be picked up now, in
-- list order. The author chose them, so the mode's level window doesn't
-- apply - only the quest's own required level and prerequisites.
local function doableListed(ctx)
    local data = ns.QuestieData
    local listed = {}
    for _, q in ipairs(ctx.guide and ctx.guide.quests or {}) do
        local id = q.id
        if id and not ctx.log[id] and not ctx.isCompleted(id) and not ctx.skipped[id]
            and not (ctx.notOffered and ctx.notOffered[id])
            and data.MeetsLevel(id, ctx.profile.level) and data.IsDoable(id, ctx) then
            listed[#listed + 1] = id
        end
    end
    return listed
end

--- Quest IDs the character can pick up right now. For a guide with a
--- quest list, the listed ones (in order) while any are available;
--- otherwise every quest in the guide's level window. This is the
--- expensive part of planning, so the Engine caches it between
--- quest-state changes.
-- @return list of quest IDs, and whether they came from the quest list
function Sources.DoableQuests(ctx)
    local data = ns.QuestieData
    if not data.IsReady() then return {}, false end

    local listed = doableListed(ctx)
    if #listed > 0 then return listed, true end

    local doable = {}
    local level, rules = ctx.profile.level, rulesOf(ctx)
    for _, questID in ipairs(data.GetCandidates(level, rules)) do
        -- Its own level is in range; its creatures must be too.
        if not data.TooHard(questID, level, rules) and not Sources.HideGroupQuest(ctx, questID)
            and data.IsDoable(questID, ctx) then
            doable[#doable + 1] = questID
        end
    end
    return Sources.FilterByRate(doable, ctx), false
end

--- Speedrun: XP per minute for each quest (QuestValue), and drop quests
--- paying less than `minRate` percent of the typical (median) rate on
--- offer. Fills ctx.rates / ctx.rateMedian for the ordering bonus.
-- @return the quests kept
function Sources.FilterByRate(doable, ctx)
    local rules = rulesOf(ctx)
    ctx.rates, ctx.rateMedian = {}, nil
    if (rules.minRate or 0) <= 0 and (rules.rateBonus or 0) <= 0 then return doable end
    local values = {}
    for _, id in ipairs(doable) do
        local rate = ns.QuestValue.Rate(id, ctx.profile.level, ctx.profile.faction)
        if rate then
            ctx.rates[id] = rate
            values[#values + 1] = rate
        end
    end
    ctx.rateMedian = ns.QuestValue.Median(values)
    if not ctx.rateMedian or (rules.minRate or 0) <= 0 or #values < 3 then return doable end
    local floor = ctx.rateMedian * rules.minRate / 100
    local kept = {}
    for _, id in ipairs(doable) do
        local rate = ctx.rates[id]
        if not rate or rate >= floor then kept[#kept + 1] = id end
    end
    return kept
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
    if listRank(ctx, questID) then return true end
    local data = ns.QuestieData
    if not data.IsReady() then return true end

    local rules = rulesOf(ctx)
    local inWindow = data.InLevelWindow(questID, ctx.profile.level, rules)
    if inWindow == nil then return true end -- unknown to QuestieDB: allow
    if not inWindow or data.TooHard(questID, ctx.profile.level, rules) then return false end

    local limit = detourLimit(rules)
    if limit then
        local _, point = nearestActor(ctx.origin, data.GetStarters(questID, ctx.profile.faction))
        if isDetour(questID, point, limit) then return false end
    end
    return true
end

local function acceptBonus(ctx, questID, listPosition)
    local rules = rulesOf(ctx)
    local bonus = listPosition and LIST_BONUSES[listPosition] or 0
    if (rules.chainBonus or 0) > 0 and ns.QuestieData.IsFollowUp(questID) then
        bonus = bonus + rules.chainBonus
    end
    -- Speedrun: quests that pay well for their time come first.
    local rate = ctx.rates and ctx.rates[questID]
    if (rules.rateBonus or 0) > 0 and rate and ctx.rateMedian and ctx.rateMedian > 0 then
        local edge = (rate / ctx.rateMedian - 1) * rules.rateBonus
        bonus = bonus + math.max(-rules.rateBonus, math.min(rules.rateBonus, edge))
    end
    -- Story: stand-alone side quests only when they're on the way.
    if (rules.sidePenalty or 0) > 0 and not listPosition and not ns.QuestieData.IsChainQuest(questID) then
        bonus = bonus - rules.sidePenalty
    end
    return bonus
end

local function availableSteps(ctx, out)
    local data = ns.QuestieData
    local rules = rulesOf(ctx)
    local found = {}

    local doable, fromList = ctx.doable, ctx.doableFromList
    if not doable then doable, fromList = Sources.DoableQuests(ctx) end

    for _, questID in ipairs(doable) do
        if not isSkipped(ctx, questID) and not ctx.log[questID] then
            -- Listed quests are fetched wherever their giver stands and in
            -- the list's order; zone quests stay inside the guide's zones.
            local maps = (not fromList) and ctx.allowedMaps or nil
            local actor, point, dist = nearestActor(ctx.origin,
                data.GetStarters(questID, ctx.profile.faction), maps)
            if actor and (fromList or not isDetour(questID, point, detourLimit(rules))) then
                found[#found + 1] = { questID = questID, actor = actor, point = point, dist = dist }
            end
        end
    end

    -- The list keeps its order; zone quests are taken nearest first.
    if not fromList then
        table.sort(found, function(a, b) return a.dist < b.dist end)
    end

    -- A quest chosen with "Go to this step" is offered wherever its giver
    -- stands, ahead of everything else.
    local focus = ctx.focusQuest
    if focus and not ctx.log[focus] and not ctx.isCompleted(focus) then
        for i = #found, 1, -1 do
            if found[i].questID == focus then table.remove(found, i) end
        end
        if data.MeetsLevel(focus, ctx.profile.level) and data.IsDoable(focus, ctx) then
            local actor, point, dist = nearestActor(ctx.origin, data.GetStarters(focus, ctx.profile.faction))
            if actor then
                table.insert(found, 1, { questID = focus, actor = actor, point = point, dist = dist })
            end
        end
    end
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
            bonus = acceptBonus(ctx, f.questID, fromList and i or nil),
        }
    end
end

---------------------------------------------------------------------------
-- Service steps: trainers and innkeepers, only when due and nearby
---------------------------------------------------------------------------

--- The class training level currently owed, or nil if you're up to date.
function Sources.DueTrainingLevel(level, trainedLevel)
    local t = ns.Data.Services.training
    if level < t.from then return nil end
    local due = t.from + math.floor((level - t.from) / t.every) * t.every
    if (trainedLevel or 0) >= due then return nil end
    return due
end

--- Is a profession ready for its next rank at this level?
function Sources.ProfessionNeedsTraining(p, level)
    local services = ns.Data.Services
    if p.max >= services.skillCap then return false end
    if p.skill < p.max - services.rankGap then return false end
    return level >= (services.nextRankLevel[p.max] or 0)
end

--- The nearest NPC with this title, if it's within reach: within
--- `distance` yards (default nearDistance), or - with `sameMap` - anywhere
--- on the map you're on.
local function nearby(ctx, title, distance, sameMap)
    if not title or not ctx.origin then return nil end
    local actor, point, dist = nearestActor(ctx.origin, ns.QuestieData.GetNpcsByTitle(title, ctx.profile.faction))
    if not (actor and point and point.world) then return nil end
    if dist <= (distance or ns.Data.Services.nearDistance) then return actor, point end
    if sameMap and ctx.playerMapID and point.mapID == ctx.playerMapID then return actor, point end
    return nil
end

local function serviceStep(key, kind, title, line, actor, point)
    return {
        key = key, kind = kind, title = title, lines = { line }, questIDs = {},
        serviceKey = key, target = target(point, actor.name),
    }
end

--- Class training. A guide's own "train" steps can make it due earlier.
local function trainingStep(ctx, out)
    local profile, char = ctx.profile, ctx.char
    local due = Sources.DueTrainingLevel(profile.level, char.trainedLevel)
    for _, s in ipairs(ctx.guide and ctx.guide.steps or {}) do
        if s.kind == "TRAIN" and s.level <= profile.level and s.level > (char.trainedLevel or 0) then
            due = math.max(due or 0, s.level)
        end
    end
    if not due then return end
    local actor, point = nearby(ctx, ns.QuestieData.ClassTrainerTitle(), ns.Data.Services.trainerDistance, true)
    if not actor then return end
    local step = serviceStep("train:" .. due, "TRAIN", "Train at " .. actor.name,
        "New class abilities are waiting (level " .. due .. ").", actor, point)
    step.serviceKey = nil -- class training is tracked by level instead
    step.trainingLevel = due
    out[#out + 1] = step
end

--- Set your hearthstone when you're at an inn and it's bound elsewhere.
--- The middle of where you're questing: the average position of the quest
--- steps (pick-ups, objectives, hand-ins) on your continent, or nil.
function Sources.QuestingCentre(steps, continent)
    local x, y, n = 0, 0, 0
    for _, step in ipairs(steps) do
        local w = step.target and step.target.world
        if w and w.continent == continent
            and (step.kind == "ACCEPT" or step.kind == "COMPLETE" or step.kind == "TURNIN") then
            x, y, n = x + w.x, y + w.y, n + 1
        end
    end
    if n == 0 then return nil end
    return { continent = continent, x = x / n, y = y / n }
end

--- Set your hearthstone at the inn nearest to where you're questing -
--- only while you're at that inn and it's bound somewhere else. (Another
--- inn you pass on the way isn't suggested.)
local function hearthStep(ctx, out)
    if not ctx.origin then return end
    local centre = Sources.QuestingCentre(out, ctx.origin.continent)
    if not centre then return end
    local inns = ns.QuestieData.GetNpcsByTitle(ns.Data.Services.innkeeperTitle, ctx.profile.faction)
    local actor, point = nearestActor(centre, inns)
    if not actor or not point or not point.world then return end
    if ns.Util.Distance(ctx.origin, point.world) > ns.Data.Services.nearDistance then return end
    local bind = ns.GameApi.GetBindLocation()
    local zone, subzone = ns.GameApi.GetZoneNames()
    if bind and (bind == subzone or bind == zone) then return end
    local key = "hearth:npc:" .. actor.id
    if ctx.char.skippedSteps[key] then return end
    out[#out + 1] = serviceStep(key, "HEARTH", "Set your hearthstone at " .. actor.name,
        bind and ("It's bound to " .. bind .. ".") or "Your hearthstone isn't bound nearby.", actor, point)
end

--- Profession training for professions you know, when a trainer is near.
local function professionSteps(ctx, out)
    local known = {}
    for _, name in ipairs(ns.Data.Services.professions) do known[name] = true end
    for _, p in ipairs(ns.GameApi.GetProfessions()) do
        if known[p.name] and Sources.ProfessionNeedsTraining(p, ctx.profile.level) then
            local key = ("profession:%s:%d"):format(p.name, p.max)
            local actor, point = nearby(ctx, p.name .. " Trainer")
            if actor and not ctx.char.skippedSteps[key] then
                out[#out + 1] = serviceStep(key, "TRAIN", ("Train %s at %s"):format(p.name, actor.name),
                    ("%s %d/%d - ready for the next rank."):format(p.name, p.skill, p.max), actor, point)
            end
        end
    end
end

--- A guide's own "note" and "buy" steps (no map location; click Done).
local function guideNoteSteps(ctx, out)
    local guide = ctx.guide
    for _, s in ipairs(guide and guide.steps or {}) do
        if (s.kind == "NOTE" or s.kind == "BUY" or s.kind == "HEARTH") and ctx.profile.level >= s.level then
            local id = ("guide:%s:%d:%s:%s"):format(guide.id or "?", s.level, s.kind, s.text)
            if not ctx.char.done[id] then
                out[#out + 1] = {
                    key = id, kind = s.kind == "HEARTH" and "NOTE" or s.kind, title = s.text,
                    lines = {}, questIDs = {}, suggestionID = id, manual = true,
                }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Steps in a guide's quest list (not quests: notes, buy, train, ...)
---------------------------------------------------------------------------

Sources.LIST_STEP_BONUS = 2e6 -- a step the guide has reached goes first, wherever it is
Sources.ARRIVE_RADIUS = 20       -- yards: a "go to" step is done on arrival

--- A stable key for a list step, built from its content (so reordering
--- other entries keeps what you've ticked off). Duplicates get "#n".
function Sources.ListStepKey(guideId, entry, occurrence)
    local key = ("list:%s:%s:%s:%s:%s:%s"):format(guideId or "?", entry.step, entry.text or "",
        entry.zone or "", entry.x or "", entry.y or "")
    if occurrence and occurrence > 1 then key = key .. "#" .. occurrence end
    return key
end

--- Every step in the guide's quest list, with whether it's done and
--- whether the guide has reached it. A step is reached once everything
--- before it is dealt with: earlier steps done, and no earlier listed
--- quest still waiting to be picked up. Quests you can't do yet don't
--- hold it back. A step chosen in the Steps list counts as reached.
-- @return list of { index, entry, key, done, reached }
function Sources.ListSteps(ctx)
    local guide = ctx.guide
    local out = {}
    if not guide or not guide.quests then return out end
    local waiting = {}
    if ctx.doableFromList then
        for _, id in ipairs(ctx.doable or {}) do waiting[id] = true end
    end
    local seen, blocked = {}, false
    for i, entry in ipairs(guide.quests) do
        if entry.step then
            local base = Sources.ListStepKey(guide.id, entry)
            seen[base] = (seen[base] or 0) + 1
            local key = Sources.ListStepKey(guide.id, entry, seen[base])
            local done = ctx.char.done[key] == true
            local focused = ctx.char.focusStep == key
            out[#out + 1] = { index = i, entry = entry, key = key, done = done,
                              reached = not done and (focused or not blocked) }
            if not done then blocked = true end
        elseif waiting[entry.id] then
            blocked = true
        end
    end
    return out
end

local LIST_TITLES = { NOTE = "Note", BUY = "Buy", TRAIN = "Train", HEARTH = "Hearthstone", GOTO = "Go to" }

--- "Durotar 52.0, 41.5"
function Sources.LocationText(entry)
    if not entry.zone then return nil end
    return ("%s %.1f, %.1f"):format(entry.zone, entry.x, entry.y)
end

local function listStepTarget(ctx, entry)
    if entry.zone then
        local mapID = ns.ZoneMap.MapIdByName(entry.zone)
        if not mapID then return nil end
        local point = withWorld({ mapID = mapID, x = entry.x / 100, y = entry.y / 100 })
        return target(point, entry.text or LIST_TITLES[entry.step])
    end
    -- No location: train and hearth point to the nearest trainer / inn.
    local title
    if entry.step == "TRAIN" then title = ns.QuestieData.ClassTrainerTitle() end
    if entry.step == "HEARTH" then title = ns.Data.Services.innkeeperTitle end
    if not title then return nil end
    local actor, point = nearestActor(ctx.origin, ns.QuestieData.GetNpcsByTitle(title, ctx.profile.faction))
    if not actor then return nil end
    return target(point, actor.name), actor.name
end

--- The route step for one list step.
function Sources.ListStepToStep(ctx, item)
    local entry = item.entry
    local tgt, npc = listStepTarget(ctx, entry)
    local title = entry.text
    if not title then
        if entry.step == "TRAIN" then
            title = npc and ("Train at " .. npc) or "Visit your class trainer"
        elseif entry.step == "HEARTH" then
            title = npc and ("Set your hearthstone at " .. npc) or "Set your hearthstone"
        else
            title = "Go to " .. (Sources.LocationText(entry) or "?")
        end
    end
    local lines = {}
    local where = Sources.LocationText(entry)
    if where and entry.text then lines[1] = where end
    return {
        key = item.key, kind = entry.step, title = title, lines = lines, questIDs = {},
        target = tgt, bonus = Sources.LIST_STEP_BONUS, manual = true,
        suggestionID = item.key, listKind = entry.step, listIndex = item.index,
        arriveRadius = entry.step == "GOTO" and Sources.ARRIVE_RADIUS or nil,
    }
end

local function listSteps(ctx, out)
    for _, item in ipairs(Sources.ListSteps(ctx)) do
        if item.reached then out[#out + 1] = Sources.ListStepToStep(ctx, item) end
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
--     rules = the guide's rules, guide = the guide (quest list, skips, steps),
--     focusQuest = quest chosen in the Steps list, or nil,
--     char = { done = {}, trainedLevel = n, skippedSteps = {} } }
-- @return list of candidate steps
function Sources.Collect(ctx)
    local steps = {}
    questLogSteps(ctx, steps)
    availableSteps(ctx, steps)
    trainingStep(ctx, steps)
    hearthStep(ctx, steps)
    professionSteps(ctx, steps)
    guideNoteSteps(ctx, steps)
    listSteps(ctx, steps)
    return steps
end
