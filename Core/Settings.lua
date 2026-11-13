--[[
    ForeverPath - Core/Settings.lua

    SavedVariables handling.

      ForeverPathDB         account-wide: window position, UI preferences
      ForeverPathCharDB     per character: chosen route

    SavedVariables are only available after ADDON_LOADED for this addon, so
    Settings.Init() is called from Core/Bootstrap.lua at that point - never
    at file scope.
]]

local _, ns = ...

local Settings = {}
ns.Settings = Settings

-- Bump when the shape of saved data changes, and add a migration below.
Settings.SCHEMA_VERSION = 2

local ACCOUNT_DEFAULTS = {
    schema = Settings.SCHEMA_VERSION,
    frame = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        shown = false,
    },
    showAllBands = false,
    announceLevelUp = true,
    guide = {
        enabled = true,
        waypoints = "auto",   -- "auto" | "tomtom" | "builtin" | "off"
        maxSteps = 6,
        shown = true,
        frame = { point = "RIGHT", relativePoint = "RIGHT", x = -80, y = 120 },
    },
}

local CHAR_DEFAULTS = {
    schema = Settings.SCHEMA_VERSION,
    routeId = nil, -- nil = use the class's default route
    guide = {
        skipped = {},      -- [questID] = true, hidden until /fp unskip
        done = {},         -- [suggestionID] = true
        trainedLevel = 0,  -- last level you visited your class trainer at
    },
}

local function migrate(db)
    -- Schema 2 (0.2.0) only added the `guide` tables, which ApplyDefaults
    -- fills in. Future renames or removals go here, e.g.:
    -- if db.schema < 3 then db.newField = db.oldField; db.oldField = nil end
    db.schema = Settings.SCHEMA_VERSION
end

--- Create or upgrade the saved tables. Safe to call more than once.
function Settings.Init()
    ForeverPathDB = ForeverPathDB or {}
    ForeverPathCharDB = ForeverPathCharDB or {}

    ns.Util.ApplyDefaults(ForeverPathDB, ACCOUNT_DEFAULTS)
    ns.Util.ApplyDefaults(ForeverPathCharDB, CHAR_DEFAULTS)
    migrate(ForeverPathDB)
    migrate(ForeverPathCharDB)

    Settings.account = ForeverPathDB
    Settings.char = ForeverPathCharDB
end

local function resetPosition(saved, defaults)
    saved.point, saved.relativePoint = defaults.point, defaults.relativePoint
    saved.x, saved.y = defaults.x, defaults.y
end

--- Restore the default window positions (plan window and guide window).
function Settings.ResetFramePosition()
    resetPosition(Settings.account.frame, ACCOUNT_DEFAULTS.frame)
    resetPosition(Settings.account.guide.frame, ACCOUNT_DEFAULTS.guide.frame)
end
