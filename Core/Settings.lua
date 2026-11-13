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
Settings.SCHEMA_VERSION = 1

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
}

local CHAR_DEFAULTS = {
    schema = Settings.SCHEMA_VERSION,
    routeId = nil, -- nil = use the class's default route
}

local function migrate(db)
    -- No migrations yet. Example for the future:
    -- if db.schema < 2 then db.newField = db.oldField; db.oldField = nil end
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

--- Restore the default window position.
function Settings.ResetFramePosition()
    local f = Settings.account.frame
    local d = ACCOUNT_DEFAULTS.frame
    f.point, f.relativePoint, f.x, f.y = d.point, d.relativePoint, d.x, d.y
end
