--[[
    ForeverPath - Integrations/Waypoints.lua

    Points an arrow at the current guide step.

    Providers
      shortestpath  Shortest Path Forever: real walking/flight/boat routes.
                    ForeverPath hands it the next few steps as one journey
                    (ShortestPathForever.API.NavigateRoute). The first stop
                    is held until the step is actually done, so arriving
                    doesn't skip ahead; later stops are drawn as numbered
                    pins with quest badges.
      tomtom        TomTom's crazy arrow. Path addons that follow TomTom's
                    waypoints (Well Trodden, Map Shortcuts, ...) pick this up.
      builtin       The game's own map pin (C_Map.SetUserWaypoint).
      off           No waypoints.

    "auto" (the default) uses the first one available in that order. Only
    one ForeverPath waypoint or journey exists at a time, and nothing is
    saved into TomTom's persistent waypoint list.
]]

local _, ns = ...

local Waypoints = {}
ns.Waypoints = Waypoints

Waypoints.PROVIDERS = { "auto", "shortestpath", "tomtom", "builtin", "off" }

local OWNER = "ForeverPath"
local MAX_ROUTE_STOPS = 6

-- Our step kinds -> Shortest Path Forever stop kinds (for map badges).
local STOP_KINDS = {
    ACCEPT = "pickup", TURNIN = "turnin", COMPLETE = "objective",
    TRAIN = "trainer", HEARTH = "innkeeper", DUNGEON = "dungeon", BUY = "vendor",
}

local current = {
    provider = nil,  -- provider that owns the active waypoint
    uid = nil,       -- TomTom waypoint handle
    signature = nil, -- "mapID:x:y" so identical targets aren't re-set
}

--- Shortest Path Forever's API, if a supported version is loaded.
--- Its docs say to accept versions 1 and 2 and reject anything newer.
local function shortestPath()
    local spf = _G.ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if type(api) ~= "table" then return nil end
    if api.version ~= 1 and api.version ~= 2 then return nil end
    if type(api.NavigateRoute) ~= "function" then return nil end
    return api
end

local function hasTomTom()
    return type(_G.TomTom) == "table" and type(_G.TomTom.AddWaypoint) == "function"
end

local function hasBuiltin()
    return C_Map and type(C_Map.SetUserWaypoint) == "function"
        and type(UiMapPoint) == "table" and type(UiMapPoint.CreateFromCoordinates) == "function"
end

--- Which provider will actually be used for a setting.
function Waypoints.Resolve(setting)
    if setting == "off" then return "off" end
    if setting == "shortestpath" then return shortestPath() and "shortestpath" or "off" end
    if setting == "tomtom" then return hasTomTom() and "tomtom" or "off" end
    if setting == "builtin" then return hasBuiltin() and "builtin" or "off" end
    if shortestPath() then return "shortestpath" end
    if hasTomTom() then return "tomtom" end
    if hasBuiltin() then return "builtin" end
    return "off"
end

local providers = {}

--- Journey stops for Shortest Path Forever from the planned steps.
function Waypoints.BuildStops(steps)
    local stops = {}
    for _, step in ipairs(steps) do
        local t = step.target
        if t then
            local stop = {
                map = t.mapID, x = t.x, y = t.y,
                title = step.title,
                kind = STOP_KINDS[step.kind],
            }
            if step.questIDs and #step.questIDs > 0 then
                stop.questIDs = step.questIDs
                if step.kind == "TURNIN" then stop.handins = step.questIDs end
            end
            if #stops == 0 then
                -- Wait at the current step until ForeverPath moves on.
                stop.hold = true
            end
            stops[#stops + 1] = stop
            if #stops >= MAX_ROUTE_STOPS then break end
        end
    end
    return stops
end

providers.shortestpath = {
    -- Returns false when Shortest Path declines (combat, journeys off);
    -- the Engine retries when combat ends.
    set = function(stops)
        return shortestPath().NavigateRoute(OWNER, stops)
    end,
    clear = function()
        local api = shortestPath()
        if api and api.Cancel then api.Cancel(OWNER) end
    end,
}

providers.tomtom = {
    set = function(stops)
        local t, title = stops[1], stops[1].title
        current.uid = _G.TomTom:AddWaypoint(t.map, t.x, t.y, {
            title = title,
            from = "ForeverPath",
            persistent = false,
            minimap = true,
            world = true,
            crazy = true,
        })
    end,
    clear = function()
        if current.uid and _G.TomTom and _G.TomTom.RemoveWaypoint then
            pcall(_G.TomTom.RemoveWaypoint, _G.TomTom, current.uid)
        end
        current.uid = nil
    end,
}

providers.builtin = {
    set = function(stops)
        local t = stops[1]
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(t.map) then
            return
        end
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.map, t.x, t.y))
    end,
    clear = function()
        if C_Map and C_Map.ClearUserWaypoint then
            pcall(C_Map.ClearUserWaypoint)
        end
    end,
}

--- Remove ForeverPath's waypoint, if any.
function Waypoints.Clear()
    local p = current.provider and providers[current.provider]
    if p then pcall(p.clear) end
    current.provider, current.signature = nil, nil
end

--- A string identifying a set of stops, so identical routes aren't re-sent
--- (re-sending would restart a Shortest Path journey).
local function signatureOf(provider, stops)
    local count = provider == "shortestpath" and #stops or 1
    local parts = { provider }
    for i = 1, count do
        local s = stops[i]
        parts[#parts + 1] = ("%d:%.4f:%.4f"):format(s.map, s.x, s.y)
    end
    return table.concat(parts, "|")
end

--- Guide the player through the planned steps (the first one with a
--- location becomes the waypoint; Shortest Path also gets the next few).
-- @return the provider used ("shortestpath" | "tomtom" | "builtin" | "off")
function Waypoints.Set(steps, setting)
    local provider = Waypoints.Resolve(setting)
    local stops = Waypoints.BuildStops(steps or {})
    if #stops == 0 or provider == "off" then
        Waypoints.Clear()
        return "off"
    end

    local signature = signatureOf(provider, stops)
    if signature == current.signature then return provider end

    -- A new Shortest Path route replaces the old journey by itself;
    -- cancelling first would only make the arrow flicker.
    if current.provider ~= "shortestpath" or provider ~= "shortestpath" then
        Waypoints.Clear()
    end
    local ok, accepted = pcall(providers[provider].set, stops)
    if not ok then
        ns.Util.Print("Couldn't set waypoint: " .. tostring(accepted))
    elseif accepted ~= false then
        current.provider, current.signature = provider, signature
    end
    return provider
end
