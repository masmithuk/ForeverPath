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
    local info = ns.QuestieData.Describe(q.id, q.name)
    local row = {
        index = i, id = q.id, name = info.name, level = info.level,
        requiredLevel = info.requiredLevel, zone = info.zone,
        isCurrent = inCurrent[q.id] == true, isFocus = ctx.focusQuest == q.id,
    }
    local givers = ns.QuestieData.GetStarters(q.id, ctx.profile.faction)
    row.giver = givers[1] and givers[1].name or nil

    local logEntry = ctx.log[q.id]
    if ctx.isCompleted(q.id) then
        row.status = "done"
    elseif logEntry then
        row.status = logEntry.complete and "ready" or "active"
    elseif ctx.skipped[q.id] or (ctx.guide.skipSet and ctx.guide.skipSet[q.id]) then
        row.status = "skipped"
    elseif ctx.notOffered and ctx.notOffered[q.id] then
        row.status = "notoffered"
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
--- The quests to list: the guide's own list, or - for guides that go by
--- zones (the built-in ones) - the quests of the zones for your level and
--- the next band, so the list stays short and quick to build.
function StepList.Quests(ctx)
    local guide = ctx.guide
    if #guide.quests > 0 then return guide.quests, false end
    local list, seen = {}, {}
    for _, entry in ipairs({ ctx.route and ctx.route.current, ctx.route and ctx.route.next }) do
        for _, zone in ipairs(entry and entry.zones or {}) do
            for _, q in ipairs(ns.Catalog.Overview(zone, ctx).quests) do
                if not seen[q.id] and not guide.skipSet[q.id] then
                    seen[q.id] = true
                    list[#list + 1] = { id = q.id, name = q.name }
                end
            end
        end
    end
    return list, true
end

function StepList.Build(ctx, currentStep)
    local quests, byZone = StepList.Quests(ctx)
    local inCurrent = {}
    for _, id in ipairs(currentStep and currentStep.questIDs or {}) do inCurrent[id] = true end
    local listSteps = {}
    for _, item in ipairs(ns.Sources.ListSteps(ctx)) do listSteps[item.index] = item end

    local result = { rows = {}, done = 0, skipped = 0, missed = 0, total = #quests, position = 0,
                     byZone = byZone }
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
