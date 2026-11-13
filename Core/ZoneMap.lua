--[[
    ForeverPath - Core/ZoneMap.lua

    QuestieDB stores locations per *area ID* with 0-100 coordinates, while
    waypoints and the player position use *uiMapIDs* with 0-1 coordinates.
    This module converts between them.

    Lookup order for an area ID:
      1. Questie's own ZoneDB, when the full Questie addon is loaded.
      2. Matching the area's name against the client's zone map names.
]]

local _, ns = ...

local ZoneMap = {}
ns.ZoneMap = ZoneMap

local cache = {}        -- areaID -> uiMapID (false = unknown)
local nameToMap         -- lowercase zone name -> uiMapID, built on demand

local function buildNameIndex()
    nameToMap = {}
    for mapID, name in pairs(ns.GameApi.GetZoneMaps()) do
        nameToMap[name:lower()] = mapID
    end
end

local function questieZoneDB()
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

    local mapID
    local zoneDB = questieZoneDB()
    if zoneDB then
        local ok, result = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaID)
        if ok then mapID = result end
    end
    if not mapID then
        mapID = ZoneMap.MapIdByName(ns.GameApi.GetAreaName(areaID))
    end

    cache[areaID] = mapID or false
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
