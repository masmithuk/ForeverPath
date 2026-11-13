--[[
    ForeverPath - Core/GameApi.lua

    Every quest-log, map and position call the guide makes goes through this
    table. That keeps three concerns in one place:

      * Forever uses the modern API, but functions can still be missing, so
        each call checks the function exists before using it.
      * Values may be "secret" in some contexts (instances, combat); those
        come back as nil instead of raising errors.
      * Tests replace ns.GameApi with a fake (see tests/wow_mock.lua).

    Coordinates returned here are always 0-1 map fractions on a uiMapID.
]]

local _, ns = ...

local GameApi = {}
ns.GameApi = GameApi

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function num(v) return ns.Util.SafeNumber(v) end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

--- Quests currently in the log: { [questID] = { title, complete } }.
function GameApi.GetQuestLog()
    local log = {}
    local QL = C_QuestLog
    if not QL then return log end

    local count = num(safe(QL.GetNumQuestLogEntries)) or 0
    for i = 1, count do
        local info = safe(QL.GetInfo, i)
        if info and not info.isHeader and not info.isHidden and num(info.questID) then
            local id = info.questID
            local complete = safe(QL.ReadyForTurnIn, id)
            if complete == nil then complete = safe(QL.IsComplete, id) end
            log[id] = {
                title = ns.Util.SafeString(info.title) or ("Quest " .. id),
                complete = complete and true or false,
            }
        end
    end
    return log
end

function GameApi.IsQuestCompleted(questID)
    local QL = C_QuestLog
    if QL and QL.IsQuestFlaggedCompleted then
        return safe(QL.IsQuestFlaggedCompleted, questID) and true or false
    end
    return false
end

--- Every objective of a quest in the log: list of { text, finished }.
function GameApi.GetObjectives(questID)
    local list = {}
    local QL = C_QuestLog
    local objectives = QL and safe(QL.GetQuestObjectives, questID)
    if type(objectives) ~= "table" then return list end
    for _, o in ipairs(objectives) do
        local text = ns.Util.SafeString(o.text)
        if text then list[#list + 1] = { text = text, finished = o.finished and true or false } end
    end
    return list
end

--- Unfinished objective lines for a quest in the log, e.g. "Bristleback Quilboar slain: 3/8".
function GameApi.GetOpenObjectives(questID)
    local lines = {}
    local QL = C_QuestLog
    local objectives = QL and safe(QL.GetQuestObjectives, questID)
    if type(objectives) ~= "table" then return lines end
    for _, o in ipairs(objectives) do
        local text = ns.Util.SafeString(o.text)
        if text and text ~= "" and not o.finished then
            lines[#lines + 1] = text
        end
    end
    return lines
end

--- Blizzard's own objective waypoint for a quest in the log, if any.
function GameApi.GetQuestWaypoint(questID)
    local QL = C_QuestLog
    if not (QL and QL.GetNextWaypoint) then return nil end
    local mapID, x, y = safe(QL.GetNextWaypoint, questID)
    mapID, x, y = num(mapID), num(x), num(y)
    if mapID and x and y then
        return { mapID = mapID, x = x, y = y }
    end
    return nil
end

---------------------------------------------------------------------------
-- Player and maps
---------------------------------------------------------------------------

--- Player's position as { mapID, x, y }, or nil (e.g. inside instances).
function GameApi.GetPlayerPosition()
    if not C_Map then return nil end
    local mapID = num(safe(C_Map.GetBestMapForUnit, "player"))
    if not mapID then return nil end
    local vec = safe(C_Map.GetPlayerMapPosition, mapID, "player")
    if not vec then return nil end
    local x, y = safe(vec.GetXY, vec)
    x, y = num(x), num(y)
    if not x or not y then return nil end
    return { mapID = mapID, x = x, y = y }
end

--- Continent and world coordinates (yards) for a map point. Used to
--- measure distances across zone borders.
function GameApi.GetWorldPosition(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local continentID, worldPos = safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not continentID or not worldPos then return nil end
    local wx, wy = safe(worldPos.GetXY, worldPos)
    wx, wy = num(wx), num(wy)
    if not wx then return nil end
    return { continent = continentID, x = wx, y = wy }
end

function GameApi.GetMapName(mapID)
    local info = C_Map and safe(C_Map.GetMapInfo, mapID)
    return info and ns.Util.SafeString(info.name) or nil
end

--- Name of an area (zone) ID, used to match QuestieDB zones to maps.
function GameApi.GetAreaName(areaID)
    return C_Map and ns.Util.SafeString(safe(C_Map.GetAreaInfo, areaID)) or nil
end

--- All zone-level maps below the world map: { [mapID] = name }.
function GameApi.GetZoneMaps()
    local result = {}
    if not (C_Map and C_Map.GetMapChildrenInfo) then return result end
    local root = num(safe(C_Map.GetFallbackWorldMapID)) or 947
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    local children = safe(C_Map.GetMapChildrenInfo, root, zoneType, true) or {}
    for _, info in ipairs(children) do
        if info.mapID and info.name then
            result[info.mapID] = info.name
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Character
---------------------------------------------------------------------------

function GameApi.InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

--- True when the open trainer window is a profession trainer.
function GameApi.IsTradeskillTrainer()
    return safe(IsTradeskillTrainer) and true or false
end
