--[[
    Questwalker - Core/GameApi.lua

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
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g
end

local function num(v) return ns.Util.SafeNumber(v) end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

--- Is a quest in the log ready to hand in? Only a clear "yes" counts
--- (some clients answer 1/0 rather than true/false), and a quest that still
--- has an unfinished objective is never ready.
local function readyForTurnIn(QL, id, info)
    local ready = safe(QL.ReadyForTurnIn, id)
    if ready == nil then ready = safe(QL.IsComplete, id) end
    if ready == nil then ready = info.isComplete end
    if not (ready == true or ready == 1) then return false end
    local objectives = safe(QL.GetQuestObjectives, id)
    if type(objectives) == "table" then
        for _, o in ipairs(objectives) do
            if type(o) == "table" and o.finished == false then return false end
        end
    end
    return true
end

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
            log[id] = {
                title = ns.Util.SafeString(info.title) or ("Quest " .. id),
                complete = readyForTurnIn(QL, id, info),
            }
        end
    end
    return log
end

--- The creature ID of the NPC you're talking to ("npc" unit), or nil.
--- GUIDs look like "Creature-0-1465-0-2105-211022-0000ABCDEF".
function GameApi.GetDialogNpcID()
    local guid = ns.Util.SafeString(safe(UnitGUID, "npc"))
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

--- Abandon a quest in the log (as the quest log's Abandon button does).
-- @return true if the game was asked to abandon it
function GameApi.AbandonQuest(questID)
    local QL = C_QuestLog
    if QL and QL.SetSelectedQuest and QL.SetAbandonQuest and QL.AbandonQuest then
        safe(QL.SetSelectedQuest, questID)
        safe(QL.SetAbandonQuest)
        safe(QL.AbandonQuest)
        return true
    end
    -- Classic-style API: select by log index.
    local index = QL and QL.GetLogIndexForQuestID and num(safe(QL.GetLogIndexForQuestID, questID))
    if index and SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
        safe(SelectQuestLogEntry, index)
        safe(SetAbandonQuest)
        safe(AbandonQuest)
        return true
    end
    return false
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

--- Where your hearthstone is bound (a town or subzone name), or nil.
function GameApi.GetBindLocation()
    return ns.Util.SafeString(safe(GetBindLocation))
end

--- The zone and subzone you're standing in.
function GameApi.GetZoneNames()
    return ns.Util.SafeString(safe(GetZoneText)), ns.Util.SafeString(safe(GetSubZoneText))
end

--- Professions you've learned: list of { name, skill, max }.
--- Uses the modern profession API, or the Classic skill list.
function GameApi.GetProfessions()
    local list = {}
    if GetProfessions and GetProfessionInfo then
        local indices = { safe(GetProfessions) }
        for i = 1, 6 do
            local index = indices[i]
            if index then
                local name, _, skill, max = safe(GetProfessionInfo, index)
                if ns.Util.SafeString(name) and num(skill) and num(max) then
                    list[#list + 1] = { name = name, skill = skill, max = max }
                end
            end
        end
        return list
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, num(safe(GetNumSkillLines)) or 0 do
            local name, isHeader, _, skill, _, _, max = safe(GetSkillLineInfo, i)
            if not isHeader and ns.Util.SafeString(name) and num(skill) and num(max) then
                list[#list + 1] = { name = name, skill = skill, max = max }
            end
        end
    end
    return list
end

function GameApi.InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

--- True when the open trainer window is a profession trainer.
function GameApi.IsTradeskillTrainer()
    return safe(IsTradeskillTrainer) and true or false
end
