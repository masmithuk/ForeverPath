--[[
    Minimal stand-in for the WoW client (plus QuestieDB and TomTom) so the
    addon can run under plain Lua 5.1. Only what ForeverPath touches is
    mocked.

    Usage (see tests/run.lua):
        local mock = require("wow_mock"); mock.install()

    Tests change `mock.player`, `mock.questLog`, `mock.completed`,
    `mock.db` etc. between cases.
]]

local mock = {}

---------------------------------------------------------------------------
-- A tiny fake world: two Kalimdor zones side by side and Tirisfal on
-- another continent. World position = (offset + x * 1000, y * 1000) yards.
---------------------------------------------------------------------------

mock.maps = {
    [1411] = { name = "Durotar",         areaID = 14, continent = 1, offset = 0 },
    [1413] = { name = "The Barrens",     areaID = 17, continent = 1, offset = 2000 },
    [1420] = { name = "Tirisfal Glades", areaID = 85, continent = 0, offset = 0 },
}

local function areaName(areaID)
    for _, m in pairs(mock.maps) do
        if m.areaID == areaID then return m.name end
    end
    return nil
end

function mock.reset()
    mock.player = {
        race = { "Undead", "Scourge", 5 },
        class = { "Mage", "MAGE", 8 },
        faction = "Horde",
        level = 12,
        xp = 1000,
        xpMax = 4000,
        rested = 2000,
        resting = false,
        position = { mapID = 1411, x = 0.5, y = 0.5 },
    }
    mock.printed = {}
    mock.questLog = {}        -- list of { id, title, complete, objectives = { "text" } }
    mock.completed = {}       -- [questID] = true
    mock.questWaypoints = {}  -- [questID] = { mapID, x, y }
    mock.tradeskillTrainer = false
    mock.tickers = {}
    mock.tomtom = nil         -- set by mock.installTomTom()
    mock.userWaypoint = nil
    mock.db = nil             -- set by mock.installQuestieDB()
end

---------------------------------------------------------------------------
-- Frames: every method is a no-op that records state where it matters.
---------------------------------------------------------------------------

local Frame = {}
Frame.__index = function(_, key)
    local method = rawget(Frame, key)
    if method then return method end
    -- Unknown methods are harmless no-ops (SetPoint, SetSize, ...).
    return function() end
end

function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown end
function Frame:SetText(t) self.textValue = t end
function Frame:GetText() return self.textValue end
function Frame:GetStringHeight() return 100 end
function Frame:GetPoint() return "CENTER", nil, "CENTER", 10, 20 end
function Frame:GetTop() return 500 end
function Frame:GetBottom() return 400 end
function Frame:CreateFontString() return mock.newFrame() end
function Frame:CreateTexture() return mock.newFrame() end
function Frame:SetTexture(t) self.texture = t end

function mock.newFrame()
    return setmetatable({ events = {}, scripts = {}, shown = true }, Frame)
end

mock.frames = {}

---------------------------------------------------------------------------
-- Optional addons
---------------------------------------------------------------------------

--- Fake TomTom recording waypoints.
function mock.installTomTom()
    local tt = { waypoints = {}, removed = {} }
    function tt:AddWaypoint(m, x, y, opts)
        local uid = { m, x, y, title = opts and opts.title }
        self.waypoints[#self.waypoints + 1] = uid
        return uid
    end
    function tt:RemoveWaypoint(uid)
        self.removed[#self.removed + 1] = uid
    end
    mock.tomtom = tt
    _G.TomTom = tt
    return tt
end

--- Fake LibQuestieDB backed by plain tables:
---   db.Quest[id] = { name=..., startedBy={{npcIds}}, ... }
---   db.Npc[id]   = { name=..., spawns={[areaID]={{x,y}}}, ... }
function mock.installQuestieDB(db, contractOk)
    db.Quest = db.Quest or {}
    db.Npc = db.Npc or {}
    db.Object = db.Object or {}
    db.Item = db.Item or {}
    mock.db = db

    local function entity(rows)
        return {
            Get = function(id, field)
                local row = rows[id]
                return row and row[field]
            end,
            GetAllIds = function()
                local ids = {}
                for id in pairs(rows) do ids[#ids + 1] = id end
                table.sort(ids)
                return ids
            end,
        }
    end

    _G.LibQuestieDB = {
        Quest = entity(db.Quest),
        Npc = entity(db.Npc),
        Object = entity(db.Object),
        Item = entity(db.Item),
        Enum = {
            -- Mirrors QuestieDB: race ID -> single-bit mask.
            raceMaskById = { [1] = 1, [2] = 2, [5] = 16, [8] = 128, [6] = 32 },
        },
        RequireContract = function(n) return contractOk ~= false and n <= 4 end,
    }
    return db
end

---------------------------------------------------------------------------
-- Install globals
---------------------------------------------------------------------------

function mock.install()
    mock.reset()
    _G.ForeverPathDB = nil
    _G.ForeverPathCharDB = nil
    _G.ForeverPathMainFrame = nil
    _G.ForeverPathGuideFrame = nil
    _G.ForeverPathMinimapButton = nil
    _G.TomTom = nil
    _G.LibQuestieDB = nil
    _G.QuestieLoader = nil

    _G.CreateFrame = function(_, name)
        local f = mock.newFrame()
        mock.frames[#mock.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = mock.newFrame()
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.GameTooltip = mock.newFrame()
    _G.Minimap = mock.newFrame()
    _G.GetCursorPosition = function() return 0, 0 end

    _G.UnitRace = function() return unpack(mock.player.race) end
    _G.UnitClass = function() return unpack(mock.player.class) end
    _G.UnitLevel = function() return mock.player.level end
    _G.UnitFactionGroup = function() return mock.player.faction end
    _G.UnitXP = function() return mock.player.xp end
    _G.UnitXPMax = function() return mock.player.xpMax end
    _G.GetXPExhaustion = function() return mock.player.rested end
    _G.IsResting = function() return mock.player.resting end
    _G.IsTradeskillTrainer = function() return mock.tradeskillTrainer end
    _G.GetMoney = function() return 0 end
    _G.GetTime = function() return 0 end

    -- Timers run immediately; tickers are collected so tests can fire them.
    _G.C_Timer = {
        After = function(_, fn) fn() end,
        NewTicker = function(interval, fn)
            local t = { interval = interval, fn = fn }
            mock.tickers[#mock.tickers + 1] = t
            return t
        end,
    }

    _G.C_QuestLog = {
        GetNumQuestLogEntries = function() return #mock.questLog end,
        GetInfo = function(i)
            local q = mock.questLog[i]
            return q and { questID = q.id, title = q.title, isHeader = false }
        end,
        ReadyForTurnIn = function(id)
            for _, q in ipairs(mock.questLog) do
                if q.id == id then return q.complete end
            end
            return false
        end,
        IsQuestFlaggedCompleted = function(id) return mock.completed[id] or false end,
        GetQuestObjectives = function(id)
            for _, q in ipairs(mock.questLog) do
                if q.id == id then
                    local out = {}
                    for _, text in ipairs(q.objectives or {}) do
                        out[#out + 1] = { text = text, finished = false }
                    end
                    return out
                end
            end
            return {}
        end,
        GetNextWaypoint = function(id)
            local w = mock.questWaypoints[id]
            if w then return w.mapID, w.x, w.y end
            return nil
        end,
    }

    local function vector(x, y)
        return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
    end
    _G.CreateVector2D = vector
    _G.Enum = { UIMapType = { Zone = 3 } }
    _G.UiMapPoint = {
        CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, x = x, y = y } end,
    }

    _G.C_Map = {
        GetBestMapForUnit = function()
            return mock.player.position and mock.player.position.mapID
        end,
        GetPlayerMapPosition = function()
            local p = mock.player.position
            return p and vector(p.x, p.y)
        end,
        GetWorldPosFromMapPos = function(mapID, v)
            local m = mock.maps[mapID]
            if not m then return nil end
            return m.continent, vector(m.offset + v.x * 1000, v.y * 1000)
        end,
        GetMapInfo = function(mapID)
            local m = mock.maps[mapID]
            return m and { mapID = mapID, name = m.name }
        end,
        GetAreaInfo = function(areaID) return areaName(areaID) end,
        GetFallbackWorldMapID = function() return 947 end,
        GetMapChildrenInfo = function()
            local out = {}
            for id, m in pairs(mock.maps) do out[#out + 1] = { mapID = id, name = m.name } end
            return out
        end,
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point) mock.userWaypoint = point end,
        ClearUserWaypoint = function() mock.userWaypoint = nil end,
    }

    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
        mock.printed[#mock.printed + 1] = table.concat(parts, " ")
    end
end

---------------------------------------------------------------------------
-- Load the addon in .toc order with a shared namespace.
---------------------------------------------------------------------------

function mock.loadAddon(root, addonName)
    local ns = {}
    local tocPath = root .. "/" .. addonName .. ".toc"
    for line in io.lines(tocPath) do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            local path = root .. "/" .. line:gsub("\\", "/")
            local chunk = assert(loadfile(path))
            chunk(addonName, ns)
        end
    end
    return ns
end

return mock
