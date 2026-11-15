--[[
    ForeverPath - Core/ZoneMap.lua

    QuestieDB stores locations per *area ID* with 0-100 coordinates, while
    waypoints and the player position use *uiMapIDs* with 0-1 coordinates.
    This module converts between them.

    Lookup order for an area ID:
      1. Questie's own ZoneDB, once the full Questie addon has started
         (its tables are empty before that).
      2. Matching the area's name against the client's zone map names.
      3. The same for the area's parent zone, for sub-zones such as
         Valley of Trials (Questie's parent table, or a short built-in
         list of starting areas).

    A lookup that fails while Questie is still starting isn't remembered,
    so it's tried again once Questie is ready.
]]

local _, ns = ...

local ZoneMap = {}
ns.ZoneMap = ZoneMap

local cache = {}        -- areaID -> uiMapID (false = unknown)

-- Starting areas that are sub-zones in newer area IDs -> their zone.
-- Questie's ZoneDB knows all of these once it's running; this covers the
-- first moments after login and setups without the full Questie addon.
local PARENT_ZONE = {
    [363] = 14, [6451] = 14, [6453] = 14, -- Valley of Trials, Echo Isles -> Durotar
    [6452] = 215,                          -- Camp Narache -> Mulgore
    [6454] = 85,                           -- Deathknell -> Tirisfal Glades
    [6170] = 12,                           -- Northshire -> Elwynn Forest
    [6176] = 1,                            -- Coldridge Valley -> Dun Morogh
    [6450] = 141,                          -- Shadowglen -> Teldrassil
}
local nameToMap         -- lowercase zone name -> uiMapID, built on demand

local function buildNameIndex()
    nameToMap = {}
    for mapID, name in pairs(ns.GameApi.GetZoneMaps()) do
        nameToMap[name:lower()] = mapID
    end
end

local function questieZoneDB()
    if not ns.QuestieData.QuestieStarted() then return nil end
    local loader = _G.QuestieLoader
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then
        return nil
    end
    local ok, zoneDB = pcall(loader.ImportModule, loader, "ZoneDB")
    if ok and type(zoneDB) == "table" and type(zoneDB.GetUiMapIdByAreaId) == "function" then
        return zoneDB
    end
    return nil
end

--- uiMapID for a zone name such as "The Barrens", or nil.
function ZoneMap.MapIdByName(name)
    if not nameToMap then buildNameIndex() end
    return name and nameToMap[name:lower()] or nil
end

--- uiMapID for a QuestieDB area ID, or nil.
function ZoneMap.ToUiMap(areaID)
    local cached = cache[areaID]
    if cached ~= nil then return cached or nil end

    local zoneDB = questieZoneDB()
    local function lookup(id)
        local found
        if zoneDB then
            local ok, result = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, id)
            if ok and type(result) == "number" then found = result end
        end
        return found or ZoneMap.MapIdByName(ns.GameApi.GetAreaName(id))
    end

    local mapID = lookup(areaID)
    if not mapID then
        local parent
        if zoneDB and type(zoneDB.GetParentZoneId) == "function" then
            local ok, result = pcall(zoneDB.GetParentZoneId, zoneDB, areaID)
            if ok and type(result) == "number" then parent = result end
        end
        parent = parent or PARENT_ZONE[areaID]
        if parent and parent ~= areaID then mapID = lookup(parent) end
    end

    -- Don't remember a failure while Questie is still starting up.
    local questieLoading = _G.Questie ~= nil and not ns.QuestieData.QuestieStarted()
    if mapID or not questieLoading then cache[areaID] = mapID or false end
    return mapID
end

--- Convert a QuestieDB spawn (area ID, 0-100 coords) to a map point.
function ZoneMap.ToMapPoint(areaID, x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or y < 0 then
        return nil -- QuestieDB uses -1,-1 for "somewhere in an instance"
    end
    local mapID = ZoneMap.ToUiMap(areaID)
    if not mapID then return nil end
    return { mapID = mapID, x = x / 100, y = y / 100 }
end

--- Forget cached lookups (tests, or after a map data change).
function ZoneMap.Reset()
    cache = {}
    nameToMap = nil
end
