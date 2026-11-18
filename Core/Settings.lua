--[[
    Questwalker - Core/Settings.lua

    SavedVariables handling.

      QuestwalkerDB         account-wide: window position, UI preferences
      QuestwalkerCharDB     per character: chosen route

    SavedVariables are only available after ADDON_LOADED for this addon, so
    Settings.Init() is called from Core/Bootstrap.lua at that point - never
    at file scope.
]]

local _, ns = ...

local Settings = {}
ns.Settings = Settings

-- Bump when the shape of saved data changes, and add a migration below.
Settings.SCHEMA_VERSION = 6

local ACCOUNT_DEFAULTS = {
    schema = Settings.SCHEMA_VERSION,
    frame = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        shown = false,
        width = 720,
        height = 540,
    },
    announceLevelUp = true,
    tab = "home",                      -- main window tab last shown
    guides = {},                          -- player-made guides: [id] = guide text
    minimap = { angle = 225, hide = false },
    targetButton = true,                  -- show the Target button
    auto = {
        accept = true,          -- accept quests when talking to quest givers
        turnIn = true,          -- hand in finished quests and take the reward
        followMode = false,     -- only accept quests the guide would pick
        skipTrivial = true,     -- never auto-accept grey quests
        skipTooHard = true,     -- never auto-accept quests too hard for your level
        skipRepeatable = true,  -- never auto-accept repeatable quests
    },
    target = { point = "RIGHT", relativePoint = "RIGHT", x = -80, y = 40 },
    editor = {},                          -- guide editor size (width, height) once resized
    guide = {
        enabled = true,
        waypoints = "auto",   -- "auto" | "tomtom" | "builtin" | "off"
        maxSteps = 6,
        shown = true,
        frame = { point = "RIGHT", relativePoint = "RIGHT", x = -80, y = 120 },
        width = 320,          -- guide window width (it grows to fit its text)
        groupQuests = true,   -- include group (elite) quests in the steps
        suggestDungeons = true, -- list dungeons for your level in the guide window
    },
}

local CHAR_DEFAULTS = {
    schema = Settings.SCHEMA_VERSION,
    routeId = nil, -- nil = use the class's default route
    guide = {
        skipped = {},      -- [questID] = true, hidden until /qw unskip
        done = {},         -- [guide note step id] = true
        skippedSteps = {}, -- [service step key] = true (an inn or profession trainer you skipped)
        notOffered = {},   -- [questID] = level: its giver didn't offer it (cleared on level up)
        trainedLevel = 0,  -- last level you visited your class trainer at
        history = {},      -- recent skips / ticked steps, for Back
        focus = nil,       -- quest chosen with "Go to this step", until handed in
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
        if db.tab == "guides" then db.tab = "home" end
    end
    -- Schema 5 (0.8.0): the Zones and Plan tabs and following a single zone
    -- were removed; "efficient" / "story" now mean your race's Speedrun /
    -- Story guide (resolved when the guide is looked up).
    if from < 5 then
        db.guideId = nil
        db.showAllBands = nil
        if db.tab == "zones" or db.tab == "plan" then db.tab = "home" end
        -- The "guide me step by step" switch is gone: the guide window's
        -- show/hide is the one control now, so turn the guide back on.
        if type(db.guide) == "table" and db.guide.waypoints then db.guide.enabled = true end
    end
    -- Schema 6 (0.8.0): "hold to pause" is gone, and auto accept takes every
    -- quest again (only-guide-quests turned too many down without a word).
    if from < 6 and type(db.auto) == "table" then
        db.auto.pauseKey = nil
        db.auto.followMode = false
    end
    db.schema = Settings.SCHEMA_VERSION
end

--- Create or upgrade the saved tables. Safe to call more than once.
function Settings.Init()
    QuestwalkerDB = QuestwalkerDB or {}
    QuestwalkerCharDB = QuestwalkerCharDB or {}

    ns.Util.ApplyDefaults(QuestwalkerDB, ACCOUNT_DEFAULTS)
    ns.Util.ApplyDefaults(QuestwalkerCharDB, CHAR_DEFAULTS)
    migrate(QuestwalkerDB)
    migrate(QuestwalkerCharDB)

    Settings.account = QuestwalkerDB
    Settings.char = QuestwalkerCharDB
end

local function resetPosition(saved, defaults)
    saved.point, saved.relativePoint = defaults.point, defaults.relativePoint
    saved.x, saved.y = defaults.x, defaults.y
end

--- Restore the default window positions (plan window and guide window).
function Settings.ResetFramePosition()
    resetPosition(Settings.account.frame, ACCOUNT_DEFAULTS.frame)
    Settings.account.frame.width, Settings.account.frame.height =
        ACCOUNT_DEFAULTS.frame.width, ACCOUNT_DEFAULTS.frame.height
    resetPosition(Settings.account.guide.frame, ACCOUNT_DEFAULTS.guide.frame)
    Settings.account.guide.width = ACCOUNT_DEFAULTS.guide.width
    resetPosition(Settings.account.target, ACCOUNT_DEFAULTS.target)
end
