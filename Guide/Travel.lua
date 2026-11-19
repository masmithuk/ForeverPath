--[[
    Questwalker - Guide/Travel.lua

    Plans how to get from where you are to a step, like a sat-nav picking
    a route: walk straight there, or

      fly      walk to a flight master you know, fly to the one you know
               nearest the step, walk the rest
      hearth   your Hearthstone is ready and you're bound near the step
      ride     the step is on another continent: walk (or fly) to a boat
               or zeppelin, ride it, then carry on from the other dock

    The quickest wins, with every option timed in seconds. Only flight
    masters you've used are counted (Questwalker remembers them when you
    open a flight map), because you can only fly between paths you've
    discovered.

    Pure: positions in, legs out. The Navigator calls this about once a
    second and shows the first leg.

    A plan is { seconds, legs = { leg, ... } } where a leg is one of
      { kind = "walk", to = place, seconds }
      { kind = "fly", from = place, to = place, seconds }
      { kind = "hearth", to = place, seconds }
      { kind = "ride", ride = "boat"|"zeppelin", from = place, to = place, seconds }
    and a place is { world = {continent, x, y}, name, mapID?, x?, y? }.
]]

local _, ns = ...

local Travel = {}
ns.Travel = Travel

Travel.RUN_SPEED = 7          -- yards a second on foot
Travel.MOUNT_SPEED = 11       -- 60% mount
Travel.FLY_SPEED = 30         -- flight paths
Travel.FLY_DETOUR = 1.3       -- flight paths aren't straight lines
Travel.FLY_OVERHEAD = 25      -- talking to the flight master, take-off, landing
Travel.HEARTH_OVERHEAD = 12   -- the cast and the loading screen
Travel.RIDE_SECONDS = 150     -- average wait plus the crossing
Travel.WORTH_IT = 30          -- an option must save this many seconds to beat walking
Travel.NEAREST = 3            -- flight masters tried at each end

local function dist(a, b)
    if not (a and b) or a.continent ~= b.continent then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
Travel.Distance = dist

local function walkLeg(from, place, speed)
    local d = dist(from, place.world)
    if not d then return nil end
    return { kind = "walk", to = place, seconds = d / speed, distance = d }
end

--- The `count` places nearest `point` on its continent.
local function nearest(places, point, count)
    local list = {}
    for _, p in ipairs(places or {}) do
        local d = dist(point, p.world)
        if d then list[#list + 1] = { place = p, d = d } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(count, #list) do out[i] = list[i].place end
    return out
end

local function total(legs)
    local s = 0
    for _, leg in ipairs(legs) do s = s + leg.seconds end
    return s
end

--- Best way across one continent (walk, or fly between known paths).
local function sameContinent(from, target, opts, speed)
    local walk = walkLeg(from, target, speed)
    if not walk then return nil end
    local best = { legs = { walk }, seconds = walk.seconds }
    for _, a in ipairs(nearest(opts.flights, from, Travel.NEAREST)) do
        for _, b in ipairs(nearest(opts.flights, target.world, Travel.NEAREST)) do
            if a ~= b then
                local toA = walkLeg(from, a, speed)
                local hop = dist(a.world, b.world)
                local fromB = walkLeg(b.world, target, speed)
                if toA and hop and fromB then
                    local fly = { kind = "fly", from = a, to = b,
                        seconds = Travel.FLY_OVERHEAD + hop * Travel.FLY_DETOUR / Travel.FLY_SPEED }
                    local legs = { toA, fly, fromB }
                    local s = total(legs)
                    if s + Travel.WORTH_IT < best.seconds then best = { legs = legs, seconds = s } end
                end
            end
        end
    end
    return best
end

--- Plan a journey.
-- @param from world position {continent, x, y}
-- @param target place
-- @param opts { flights = {place}, hearth = place|nil (only when ready),
--               transports = { {ride, a = place, b = place} }, mounted = bool }
-- @return plan or nil when there's no way there
function Travel.Plan(from, target, opts)
    opts = opts or {}
    if not (from and target and target.world) then return nil end
    local speed = opts.speed or (opts.mounted and Travel.MOUNT_SPEED or Travel.RUN_SPEED)
    local candidates = {}

    if from.continent == target.world.continent then
        candidates[#candidates + 1] = sameContinent(from, target, opts, speed)
    else
        -- Boats and zeppelins, both ways round.
        for _, t in ipairs(opts.transports or {}) do
            for _, ends in ipairs({ { t.a, t.b }, { t.b, t.a } }) do
                local dock, other = ends[1], ends[2]
                if dock.world.continent == from.continent and other.world.continent == target.world.continent then
                    local before = sameContinent(from, dock, opts, speed)
                    local after = sameContinent(other.world, target, opts, speed)
                    if before and after then
                        local legs = {}
                        for _, l in ipairs(before.legs) do legs[#legs + 1] = l end
                        legs[#legs + 1] = { kind = "ride", ride = t.ride, from = dock, to = other,
                            seconds = Travel.RIDE_SECONDS }
                        for _, l in ipairs(after.legs) do legs[#legs + 1] = l end
                        candidates[#candidates + 1] = { legs = legs, seconds = total(legs) }
                    end
                end
            end
        end
    end

    -- Hearthstone: from anywhere, if you're bound on the step's continent.
    local hearth = opts.hearth
    if hearth and hearth.world and hearth.world.continent == target.world.continent then
        local after = sameContinent(hearth.world, target, opts, speed)
        if after then
            local legs = { { kind = "hearth", to = hearth, seconds = Travel.HEARTH_OVERHEAD } }
            for _, l in ipairs(after.legs) do legs[#legs + 1] = l end
            local s = total(legs)
            candidates[#candidates + 1] = { legs = legs, seconds = s + Travel.WORTH_IT, real = s }
        end
    end

    local best
    for _, c in ipairs(candidates) do
        if not best or c.seconds < best.seconds then best = c end
    end
    if best and best.real then best.seconds, best.real = best.real, nil end
    return best
end
