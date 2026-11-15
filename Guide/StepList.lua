--[[
    ForeverPath - Guide/StepList.lua

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

--- Build the list.
-- @param ctx         from Engine.BuildContext()
-- @param currentStep the step the guide is showing (Engine.state.steps[1])
-- @return { rows = {...}, done, skipped, missed, total, position }
--   each row: { index, id, name, level, requiredLevel, zone, giver,
--               status, isCurrent, isFocus }
function StepList.Build(ctx, currentStep)
    local guide = ctx.guide
    local quests = ns.Library.QuestList(guide, ctx)
    local inCurrent = {}
    for _, id in ipairs(currentStep and currentStep.questIDs or {}) do inCurrent[id] = true end
    local focus = ctx.focusQuest

    local result = { rows = {}, done = 0, skipped = 0, missed = 0, total = #quests, position = 0 }

    for i, q in ipairs(quests) do
        local info = ns.QuestieData.Describe(q.id, q.name)
        local row = {
            index = i, id = q.id, name = info.name, level = info.level,
            requiredLevel = info.requiredLevel, zone = info.zone,
            isCurrent = inCurrent[q.id] == true, isFocus = focus == q.id,
        }
        local givers = ns.QuestieData.GetStarters(q.id, ctx.profile.faction)
        row.giver = givers[1] and givers[1].name or nil

        local logEntry = ctx.log[q.id]
        if ctx.isCompleted(q.id) then
            row.status = "done"
        elseif logEntry then
            row.status = logEntry.complete and "ready" or "active"
        elseif ctx.skipped[q.id] or (guide.skipSet and guide.skipSet[q.id]) then
            row.status = "skipped"
        else
            local status = ns.Catalog.QuestStatus(
                { id = q.id, requiredLevel = info.requiredLevel }, ctx)
            row.status = status == "available" and "upcoming" or status
        end

        if row.status == "done" or row.status == "ready" or row.status == "active" then
            result.position = i
        end
        result.rows[i] = row
    end

    -- Available quests behind where you are were passed by: missed.
    for i = 1, result.position - 1 do
        local row = result.rows[i]
        if row.status == "upcoming" then row.status = "missed" end
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
