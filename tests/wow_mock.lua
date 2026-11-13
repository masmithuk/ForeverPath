--[[
    Minimal stand-in for the WoW client so the addon can run under plain
    Lua 5.1. Only what ForeverPath touches is mocked.

    Usage: local mock = dofile("tests/wow_mock.lua"); mock.install()
]]

local mock = {}

-- Mutable "player" state that tests can change between cases.
mock.player = {}

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
    }
    mock.printed = {}
end

---------------------------------------------------------------------------
-- Frames: every method is a no-op that records state where it matters.
---------------------------------------------------------------------------

local Frame = {}
Frame.__index = function(self, key)
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
function Frame:CreateFontString() return mock.newFrame() end

function mock.newFrame()
    return setmetatable({ events = {}, scripts = {}, shown = true }, Frame)
end

mock.frames = {}

---------------------------------------------------------------------------
-- Install globals
---------------------------------------------------------------------------

function mock.install()
    mock.reset()
    _G.ForeverPathDB = nil
    _G.ForeverPathCharDB = nil
    _G.ForeverPathMainFrame = nil

    _G.CreateFrame = function(_, name)
        local f = mock.newFrame()
        mock.frames[#mock.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = mock.newFrame()
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}

    _G.UnitRace = function() return unpack(mock.player.race) end
    _G.UnitClass = function() return unpack(mock.player.class) end
    _G.UnitLevel = function() return mock.player.level end
    _G.UnitFactionGroup = function() return mock.player.faction end
    _G.UnitXP = function() return mock.player.xp end
    _G.UnitXPMax = function() return mock.player.xpMax end
    _G.GetXPExhaustion = function() return mock.player.rested end
    _G.IsResting = function() return mock.player.resting end

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
