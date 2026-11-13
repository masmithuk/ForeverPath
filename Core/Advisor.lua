--[[
    ForeverPath - Core/Advisor.lua

    Pure planning logic. Takes a profile from Core/Character.lua and returns
    plain tables describing what the player should do next. No frames, no
    globals beyond ns, so every function here is unit-tested.
]]

local _, ns = ...

local Advisor = {}
ns.Advisor = Advisor

local DEFAULT_ROUTE = "efficient"

---------------------------------------------------------------------------
-- Routes
---------------------------------------------------------------------------

--- Resolve which route to use: explicit choice, then class default, then
--- the global default.
function Advisor.ResolveRouteId(profile, chosenId)
    local routes = ns.Data.Routes
    chosenId = ns.Data.LegacyRouteIds[chosenId] or chosenId
    if chosenId and routes[chosenId] then
        return chosenId
    end
    local class = profile and profile.class
    if class and class.defaultRoute and routes[class.defaultRoute] then
        return class.defaultRoute
    end
    return DEFAULT_ROUTE
end

--- Index of the band containing `level`, clamped to the route's range.
function Advisor.FindBandIndex(route, level)
    local bands = route.bands
    if level < bands[1].min then return 1 end
    for i = 1, #bands do
        if level >= bands[i].min and level <= bands[i].max then
            return i
        end
    end
    return #bands
end

--- Zones for a band, resolved for this character's faction and race.
function Advisor.ResolveZones(band, profile, isCurrentBand)
    local Util = ns.Util
    local token = ns.Data.START_ZONE_TOKEN
    local race = profile.race

    local zones
    if profile.faction == "Alliance" or profile.faction == "Horde" then
        zones = band[profile.faction] or {}
    else
        -- No faction yet (e.g. a fresh Skyborne): show both sides.
        zones = {}
        for _, z in ipairs(band.Alliance or {}) do zones[#zones + 1] = z end
        for _, z in ipairs(band.Horde or {}) do zones[#zones + 1] = z end
    end

    local out = {}
    for _, zone in ipairs(zones) do
        if zone == token then
            out[#out + 1] = (race and race.startZone) or "your racial starting zone"
        else
            out[#out + 1] = zone
        end
    end

    if race and band.min > 1 then
        -- Steer each race toward its natural follow-up zone first.
        if race.nextZone and band.min <= 20 then
            table.insert(out, 1, race.nextZone)
        end
        -- Skyborne stay on Zephras Isle a little past the usual level 10.
        local startMax = race.startZoneMaxLevel or 10
        if isCurrentBand and profile.level and profile.level <= startMax then
            table.insert(out, 1, race.startZone)
        end
    end

    return Util.Unique(out)
end

---------------------------------------------------------------------------
-- Dungeons
---------------------------------------------------------------------------

local function otherFaction(faction)
    if faction == "Alliance" then return "Horde" end
    if faction == "Horde" then return "Alliance" end
    return nil
end

--- Dungeons whose range overlaps [level - below, level + above], with
--- enemy-territory dungeons placed last. Sorted by minimum level.
function Advisor.GetDungeons(level, faction, window)
    window = window or { below = 0, above = 2 }
    local low, high = level - window.below, level + window.above
    local enemy = otherFaction(faction)

    local result = {}
    for _, d in ipairs(ns.Data.Dungeons) do
        if d.min <= high and d.max >= low then
            result[#result + 1] = d
        end
    end

    table.sort(result, function(a, b)
        local aEnemy = (a.territory ~= nil and a.territory == enemy)
        local bEnemy = (b.territory ~= nil and b.territory == enemy)
        if aEnemy ~= bEnemy then return bEnemy end
        if a.min ~= b.min then return a.min < b.min end
        return a.name < b.name
    end)
    return result
end

---------------------------------------------------------------------------
-- Milestones
---------------------------------------------------------------------------

local function appliesTo(milestone, classFile)
    return milestone.classes == nil or milestone.classes[classFile] == true
end

--- Milestones reached exactly at `level`.
function Advisor.GetMilestonesAt(level, classFile)
    local out = {}
    for _, m in ipairs(ns.Data.Milestones) do
        if m.level == level and appliesTo(m, classFile) then
            out[#out + 1] = m
        end
    end
    return out
end

--- The next `count` milestones above `level`.
function Advisor.GetUpcomingMilestones(level, classFile, count)
    count = count or 3
    local out = {}
    for _, m in ipairs(ns.Data.Milestones) do
        if m.level > level and appliesTo(m, classFile) then
            out[#out + 1] = m
            if #out >= count then break end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Rested XP
---------------------------------------------------------------------------

Advisor.defaultXpApi = {
    GetXPExhaustion = function() return GetXPExhaustion() end,
    UnitXP = function() return UnitXP("player") end,
    UnitXPMax = function() return UnitXPMax("player") end,
    IsResting = function() return IsResting() end,
}

--- Rested and XP state. Values the client hides (secret values) come back
--- as nil and the UI simply omits them.
function Advisor.GetXpInfo(level, api)
    api = api or Advisor.defaultXpApi
    local Util = ns.Util

    local info = {
        atCap = level >= Util.MAX_LEVEL,
        resting = api.IsResting() and true or false,
    }
    if info.atCap then return info end

    info.rested = Util.SafeNumber(api.GetXPExhaustion()) or 0
    info.xp = Util.SafeNumber(api.UnitXP())
    info.xpMax = Util.SafeNumber(api.UnitXPMax())

    if info.xpMax and info.xpMax > 0 then
        info.restedPct = math.floor(info.rested / info.xpMax * 100 + 0.5)
        if info.xp then
            info.toLevel = info.xpMax - info.xp
        end
    end
    return info
end

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------

--- Everything the UI needs, in one table.
function Advisor.BuildPlan(profile, chosenRouteId)
    local routeId = Advisor.ResolveRouteId(profile, chosenRouteId)
    local route = ns.Data.Routes[routeId]
    local level = profile.level
    local index = Advisor.FindBandIndex(route, level)

    local function describe(i, isCurrent)
        local b = route.bands[i]
        if not b then return nil end
        return {
            band = b,
            zones = Advisor.ResolveZones(b, profile, isCurrent),
            notes = b.notes,
        }
    end

    local allBands = {}
    for i = 1, #route.bands do
        allBands[i] = describe(i, i == index)
    end

    return {
        route = route,
        routeId = routeId,
        bandIndex = index,
        current = allBands[index],
        next = allBands[index + 1],
        allBands = allBands,
        dungeons = Advisor.GetDungeons(level, profile.faction, route.dungeonWindow),
        milestones = Advisor.GetUpcomingMilestones(level, profile.classFile, 3),
        class = profile.class,
    }
end
