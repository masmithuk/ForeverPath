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
Settings.SCHEMA_VERSION = 4

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
    tab = "library",                      -- main window tab last shown
    guides = {},                          -- player-made guides: [id] = guide text
    minimap = { angle = 225, hide = false },
    targetButton = true,                  -- show the Target button
    auto = {
        accept = true,          -- accept quests when talking to quest givers
        turnIn = true,          -- hand in finished quests and take the reward
        followMode = true,      -- only accept quests the current mode would pick
        skipTrivial = true,     -- never auto-accept grey quests
        skipRepeatable = true,  -- never auto-accept repeatable quests
        pauseKey = "SHIFT",     -- hold while talking to pause: SHIFT | CTRL | ALT | NONE
    },
    target = { point = "RIGHT", relativePoint = "RIGHT", x = -80, y = 40 },
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
    guideId = nil, -- zone name of the guide being followed; nil = Automatic
    guide = {
        skipped = {},      -- [questID] = true, hidden until /fp unskip
        done = {},         -- [suggestionID] = true
        trainedLevel = 0,  -- last level you visited your class trainer at
        history = {},      -- recent skips / ticked reminders, for Back
    },
}

local function migrate(db)
    local from = db.schema or 1
    -- Schema 2 (0.2.0) only added the `guide` tables, which ApplyDefaults fills in.
    -- Schema 3 (0.4.0) replaced the Classic/Frontier routes with the
    -- Story/Efficient modes; carry each character's choice across.
    if from < 3 and db.routeId then
        db.routeId = ns.Data.LegacyRouteIds[db.routeId] or db.routeId
    end
    -- Schema 4 (0.6.0) removed Dungeon mode and added the guide library.
    if from < 4 then
        if db.routeId == "dungeon" then
            db.routeId = ns.Data.LegacyRouteIds.dungeon
            db.guideId = nil -- was a dungeon name, not a zone
        end
        if db.tab == "guides" then db.tab = "zones" end
    end
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
    resetPosition(Settings.account.target, ACCOUNT_DEFAULTS.target)
end
