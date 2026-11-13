--[[
    ForeverPath - Integrations/Waypoints.lua

    Points an arrow at the current guide step.

    Providers
      tomtom   TomTom's crazy arrow. Path addons that follow TomTom's
               waypoints (Well Trodden, Map Shortcuts, ...) pick this up too.
      builtin  The game's own map pin (C_Map.SetUserWaypoint).
      off      No waypoints.

    "auto" (the default) uses TomTom when it's loaded and the built-in pin
    otherwise. Only one waypoint from ForeverPath exists at a time; the
    previous one is removed before the next is set, and nothing is saved
    into TomTom's persistent waypoint list.
]]

local _, ns = ...

local Waypoints = {}
ns.Waypoints = Waypoints

Waypoints.PROVIDERS = { "auto", "tomtom", "builtin", "off" }

local current = {
    provider = nil,  -- provider that owns the active waypoint
    uid = nil,       -- TomTom waypoint handle
    signature = nil, -- "mapID:x:y" so identical targets aren't re-set
}

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
    if setting == "tomtom" then return hasTomTom() and "tomtom" or "off" end
    if setting == "builtin" then return hasBuiltin() and "builtin" or "off" end
    if hasTomTom() then return "tomtom" end
    if hasBuiltin() then return "builtin" end
    return "off"
end

local providers = {}

providers.tomtom = {
    set = function(t, title)
        current.uid = _G.TomTom:AddWaypoint(t.mapID, t.x, t.y, {
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
    set = function(t)
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(t.mapID) then
            return
        end
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.mapID, t.x, t.y))
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

--- Point at `target` ({ mapID, x, y }) with the given title.
-- @return the provider used ("tomtom" | "builtin" | "off")
function Waypoints.Set(target, title, setting)
    local provider = Waypoints.Resolve(setting)
    if not target or provider == "off" then
        Waypoints.Clear()
        return "off"
    end

    local signature = ("%s:%d:%.4f:%.4f"):format(provider, target.mapID, target.x, target.y)
    if signature == current.signature then return provider end

    Waypoints.Clear()
    local ok, err = pcall(providers[provider].set, target, title)
    if ok then
        current.provider, current.signature = provider, signature
    else
        ns.Util.Print("Couldn't set waypoint: " .. tostring(err))
    end
    return provider
end
