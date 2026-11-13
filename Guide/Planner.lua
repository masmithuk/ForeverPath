--[[
    ForeverPath - Guide/Planner.lua

    Pure route planning: takes candidate steps that already know where they
    are, merges steps at the same NPC, and orders them into a walking route.

    No game API calls in here - everything arrives as plain tables, so the
    whole file is covered by tests/test_planner.lua.

    Step shape
      key       stable identity, e.g. "accept:npc:1234" or "train:12"
      kind      "TURNIN" | "ACCEPT" | "COMPLETE" | "TRAIN" | "BUY" | "NOTE" | "HEARTH"
      title     short headline ("Talk to Grull Hawkwind")
      lines     list of detail lines (quest names, objectives)
      questIDs  quests this step covers (for skipping and completion)
      actor     optional "npc:<id>" / "object:<id>" used for merging
      target    optional { mapID, x, y, world = { continent, x, y } }
      manual    true when the player must click Done
]]

local _, ns = ...

local Planner = {}
ns.Planner = Planner

-- Order used to break ties between steps at the same spot:
-- hand quests in before picking up the follow-ups.
local KIND_ORDER = { TURNIN = 1, ACCEPT = 2, TRAIN = 3, HEARTH = 4, BUY = 5, COMPLETE = 6, NOTE = 7 }

-- Turn-ins free up log space and often unlock the next quest, so they are
-- treated as this many yards closer than they really are.
local TURNIN_BONUS = 60

-- Cost of a step on another continent, or with no comparable position.
local FAR_AWAY = 1e6
local UNKNOWN_POSITION = 5e5

--- Merge ACCEPT and TURNIN steps that share an actor (the same NPC) into a
--- single step listing every quest.
function Planner.Merge(steps)
    local merged, byKey = {}, {}
    for _, step in ipairs(steps) do
        local mergeKey = step.actor and (step.kind .. ":" .. step.actor) or nil
        local existing = mergeKey and byKey[mergeKey]
        if existing then
            for _, line in ipairs(step.lines or {}) do
                existing.lines[#existing.lines + 1] = line
            end
            for _, id in ipairs(step.questIDs or {}) do
                existing.questIDs[#existing.questIDs + 1] = id
            end
        else
            local copy = {}
            for k, v in pairs(step) do copy[k] = v end
            copy.lines = { unpack(step.lines or {}) }
            copy.questIDs = { unpack(step.questIDs or {}) }
            if mergeKey then
                copy.key = mergeKey:lower()
                byKey[mergeKey] = copy
            end
            merged[#merged + 1] = copy
        end
    end
    return merged
end

--- Yards between two world positions, with penalties for the unknown.
function Planner.Cost(from, step)
    local to = step.target and step.target.world
    local cost
    if not from or not to then
        cost = UNKNOWN_POSITION
    elseif from.continent ~= to.continent then
        cost = FAR_AWAY
    else
        cost = ns.Util.Distance(from, to)
    end
    if step.kind == "TURNIN" then cost = cost - TURNIN_BONUS end
    return cost
end

local function better(a, costA, b, costB)
    if costA ~= costB then return costA < costB end
    local oa, ob = KIND_ORDER[a.kind] or 99, KIND_ORDER[b.kind] or 99
    if oa ~= ob then return oa < ob end
    return a.key < b.key
end

--- Order steps by repeatedly walking to the nearest remaining one.
-- @param origin   player's world position { continent, x, y } or nil
-- @param steps    candidate steps (merged)
-- @param pinnedKey key of the current step; kept first while it exists
--                 so the route doesn't jump around as you walk
-- @param limit    maximum number of steps to return
function Planner.Order(origin, steps, pinnedKey, limit)
    local remaining = {}
    for i = 1, #steps do remaining[i] = steps[i] end

    local ordered = {}
    local position = origin

    local function take(index)
        local step = table.remove(remaining, index)
        ordered[#ordered + 1] = step
        if step.target and step.target.world then
            position = step.target.world
        end
    end

    if pinnedKey then
        for i, step in ipairs(remaining) do
            if step.key == pinnedKey then take(i); break end
        end
    end

    while #remaining > 0 and #ordered < (limit or math.huge) do
        local bestIndex, bestCost = 1, Planner.Cost(position, remaining[1])
        for i = 2, #remaining do
            local cost = Planner.Cost(position, remaining[i])
            if better(remaining[i], cost, remaining[bestIndex], bestCost) then
                bestIndex, bestCost = i, cost
            end
        end
        take(bestIndex)
    end
    return ordered
end

--- Choose the point closest to `origin` from a list of map points that
--- have already been given world positions.
function Planner.Nearest(origin, points)
    local best, bestDist
    for _, p in ipairs(points) do
        local d
        if origin and p.world and p.world.continent == origin.continent then
            d = ns.Util.Distance(origin, p.world)
        else
            d = UNKNOWN_POSITION
        end
        if not bestDist or d < bestDist then
            best, bestDist = p, d
        end
    end
    return best, bestDist
end

--- Full planning pass: merge, then order.
function Planner.Build(origin, steps, pinnedKey, limit)
    return Planner.Order(origin, Planner.Merge(steps), pinnedKey, limit)
end
