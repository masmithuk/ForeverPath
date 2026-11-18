--[[
    Questwalker - Guide/StepList.lua

    The Steps tab's data: every quest in the guide you follow, in order,
    with where you are and how each quest stands.

    Statuses (the step the guide is showing right now is flagged separately
    with isCurrent, so it keeps its real status too)
      done      handed in
      ready     in your log and complete - hand it in
      active    in your log
      skipped   you skipped it (or the guide's skip list does)
      missed    available, but you've already moved past it in the guide
      upcoming  available, still ahead of you
      level     you're not high enough yet
      locked    needs an earlier quest (or other requirement) first
      later     a guide step (note, buy, train...) you haven't reached yet
      notoffered  its quest giver didn't offer it to you (needs an item,
                reputation, ...); checked again when you level up

    Guide steps that aren't quests are rows too (isStep = true, with key
    and kind); they can be done, upcoming (reached), missed or later.

    "Where you are" is the furthest quest in the list you've taken or
    finished; available quests before it that you haven't done or skipped
    count as missed.
]]

local _, ns = ...

local StepList = {}
ns.StepList = StepList

StepList.FILTERS = {
    all = function() return true end,
    todo = function(r)
        return r.status ~= "done" and r.status ~= "skipped"
    end,
    missed = function(r) return r.status == "skipped" or r.status == "missed" end,
    done = function(r) return r.status == "done" end,
}

-- Guides that go by zones (the built-in ones) cover 1-60, which can be a
-- couple of thousand quests. Working that list out walks every zone, so it
-- is done once per guide and character and kept; so are each quest's
-- fixed details (name, level, quest giver). Only statuses are fresh on
-- every Build.
local listCache = { key = nil, list = nil }
local infoCache = {}

--- Forget cached lists and quest details (QuestieDB was re-indexed).
function StepList.ResetCache()
    listCache.key, listCache.list = nil, nil
    infoCache = {}
end

local function questInfo(ctx, q)
    local info = infoCache[q.id]
    if not info then
        local d = ns.QuestieData.Describe(q.id, q.name)
        local givers = ns.QuestieData.GetStarters(q.id, ctx.profile.faction)
        info = { name = d.name, level = d.level, requiredLevel = d.requiredLevel, zone = d.zone,
                 giver = givers[1] and givers[1].name or nil }
        infoCache[q.id] = info
    end
    return info
end

--- The quests to list: the guide's own list, or every quest in the
--- guide's zones from level 1 to 60, in level-band order.
function StepList.Quests(ctx)
    local guide = ctx.guide
    if #guide.quests > 0 then return guide.quests end
    local p = ctx.profile
    local key = table.concat({ tostring(guide.id), tostring(p.faction), tostring(p.raceKey), tostring(p.classFile),
                               tostring(ns.QuestieData.CandidateCount()) }, ":")
    if listCache.key ~= key then
        listCache.key, listCache.list = key, ns.Library.QuestList(guide, ctx)
    end
    return listCache.list
end

local function stepRow(ctx, i, entry, item, currentStep)
    local step = item and ns.Sources.ListStepToStep(ctx, item)
    local row = {
        index = i, isStep = true, kind = entry.step, key = item and item.key,
        name = step and step.title or entry.text or entry.step, level = 0,
        where = ns.Sources.LocationText(entry),
        isCurrent = currentStep ~= nil and item ~= nil and currentStep.key == item.key,
    }
    if item and item.done then row.status = "done"
    elseif item and item.reached then row.status = "upcoming"
    else row.status = "later" end
    return row
end

local function questRow(ctx, i, q, inCurrent)
    local info = questInfo(ctx, q)
    local row = {
        index = i, id = q.id, name = info.name, level = info.level,
        requiredLevel = info.requiredLevel, zone = info.zone, giver = info.giver,
        isCurrent = inCurrent[q.id] == true, isFocus = ctx.focusQuest == q.id,
    }

    local logEntry = ctx.log[q.id]
    if ctx.isCompleted(q.id) then
        row.status = "done"
    elseif logEntry then
        row.status = logEntry.complete and "ready" or "active"
        local holdUntil = not logEntry.complete and ns.Sources.OnHoldUntil(ctx, q.id)
        if holdUntil then row.status, row.requiredLevel = "onhold", holdUntil end
        if not holdUntil and not logEntry.complete and ns.QuestieData.TooLow(q.id, ctx.profile.level, ctx.rules)
            and ctx.focusQuest ~= q.id then
            row.status = "toolow"
        end
    elseif ctx.skipped[q.id] or (ctx.guide.skipSet and ctx.guide.skipSet[q.id]
            and not (ns.QuestieData.IsReady() and ns.QuestieData.IsClassQuest(q.id))) then
        row.status = "skipped"
    elseif ctx.notOffered and ctx.notOffered[q.id] then
        row.status = "notoffered"
    elseif ns.Sources.HideGroupQuest(ctx, q.id) then
        row.status = "group"
    else
        local status = ns.Catalog.QuestStatus({ id = q.id, requiredLevel = info.requiredLevel }, ctx)
        row.status = status == "available" and "upcoming" or status
    end
    return row
end

local REACHED = { done = true, ready = true, active = true }

--- Build the list.
-- @param ctx         from Engine.BuildContext()
-- @param currentStep the step the guide is showing (Engine.state.steps[1])
-- @return { rows = {...}, done, skipped, missed, total, position }
--   quest rows: { index, id, name, level, requiredLevel, zone, giver,
--                 status, isCurrent, isFocus }
--   step rows:  { index, isStep, key, kind, name, where, status, isCurrent }

function StepList.Build(ctx, currentStep)
    local quests = StepList.Quests(ctx)
    local inCurrent = {}
    for _, id in ipairs(currentStep and currentStep.questIDs or {}) do inCurrent[id] = true end
    local listSteps = {}
    for _, item in ipairs(ns.Sources.ListSteps(ctx)) do listSteps[item.index] = item end

    local result = { rows = {}, done = 0, skipped = 0, missed = 0, total = #quests, position = 0 }
    for i, q in ipairs(quests) do
        local row
        if q.step then
            row = stepRow(ctx, i, q, listSteps[i], currentStep)
        else
            row = questRow(ctx, i, q, inCurrent)
        end
        if REACHED[row.status] then result.position = i end
        result.rows[i] = row
    end

    -- Anything still open behind where you are was passed by: missed.
    for i = 1, result.position - 1 do
        local row = result.rows[i]
        if row.status == "upcoming" or (row.isStep and row.status == "later") then row.status = "missed" end
    end

    for _, row in ipairs(result.rows) do
        if row.status == "done" then result.done = result.done + 1 end
        if row.status == "skipped" then result.skipped = result.skipped + 1 end
        if row.status == "missed" then result.missed = result.missed + 1 end
    end
    return result
end

--- Rows passing a filter ("all" | "todo" | "missed" | "done").
function StepList.Filter(rows, filter)
    local keep = StepList.FILTERS[filter] or StepList.FILTERS.all
    local out = {}
    for _, r in ipairs(rows) do
        if keep(r) then out[#out + 1] = r end
    end
    return out
end
