--[[
    ForeverPath - Locales/enUS.lua

    User-interface strings. Data strings (zone, dungeon and spec names) live
    with their data files. Missing keys fall back to the key itself, so a
    forgotten translation shows up as readable English rather than an error.
]]

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L

-- Frame
L.TITLE                 = "ForeverPath"
L.TAB_GUIDES            = "Guides"
L.TAB_PLAN              = "Plan"
L.TAB_SETTINGS          = "Settings"
L.ROUTE_LABEL           = "Mode:"

-- Guide browser
L.GUIDES_FOLLOW         = "Follow this guide"
L.GUIDES_AUTO           = "Automatic"
L.GUIDES_FOLLOWING_FMT  = "Following: %s"
L.GUIDES_FOLLOWING_AUTO = "Following: Automatic (your route's zones for your level)"
L.GUIDES_PROGRESS_FMT   = "%d of %d quests done"
L.GUIDES_NO_QUESTS      = "QuestieDB has no quests for you here yet."
L.GUIDES_ENTRANCE_FMT   = "Entrance: %s"
L.GUIDES_NEED_QUESTIE   = "Install Questie (with QuestieDB) to see the quests in each guide."
L.QUEST_DONE            = "Done"
L.QUEST_READY           = "Ready to turn in"
L.QUEST_ACTIVE          = "In your log"
L.QUEST_AVAILABLE       = "Available"
L.QUEST_LEVEL_FMT       = "Level %d"
L.QUEST_LOCKED          = "Requirements not met yet"

-- Settings tab
L.SETTINGS_GUIDE        = "Step guide"
L.SETTINGS_WAYPOINTS    = "Waypoint arrow"
L.SETTINGS_TOOLS        = "Tools"
L.SETTING_GUIDE_ENABLED = "Guide me step by step (steps and waypoints)"
L.SETTING_GUIDE_SHOWN   = "Show the guide window"
L.SETTING_MINIMAP       = "Show the minimap button"
L.SETTING_ANNOUNCE      = "Announce level-ups and milestones in chat"
L.SETTING_UNSKIP        = "Bring back skipped quests"
L.SETTING_RESET         = "Reset window positions"
L.WAYPOINTS_AUTO        = "Automatic"
L.WAYPOINTS_SHORTESTPATH = "Shortest Path"
L.WAYPOINTS_TOMTOM      = "TomTom"
L.WAYPOINTS_BUILTIN     = "Map pin"
L.WAYPOINTS_OFF         = "Off"
L.WAYPOINTS_IN_USE_FMT  = "In use: %s"

-- Target button
L.TARGET_FMT            = "Target: %s"
L.TARGET_TOOLTIP_TITLE  = "Target nearest quest mob"
L.TARGET_TOOLTIP_BODY   = "Targets the closest creature you still need for a quest. "
    .. "It can't change during combat - it updates as soon as combat ends. "
    .. "Bind a key under Key Bindings > AddOns > ForeverPath. Shift-drag to move."
L.SETTING_TARGET        = "Show the Target button (nearest quest mob)"

-- Key bindings menu (globals the game reads)
_G.BINDING_HEADER_FOREVERPATH = "ForeverPath"
_G["BINDING_NAME_CLICK ForeverPathTargetButton:LeftButton"] = "Target nearest quest mob"

-- Minimap button
L.MINIMAP_LEFT          = "Left-click: show/hide the step guide"
L.MINIMAP_RIGHT         = "Right-click: guides, plan and settings"
L.MINIMAP_DRAG          = "Drag to move"
L.SHOW_ALL_BANDS        = "Show all bands"
L.SHOW_CURRENT_BANDS    = "Show current only"

-- Header
L.HEADER_FMT            = "%s %s - Level %d (%s)"   -- race, class, level, faction
L.NEUTRAL               = "No faction yet"
L.NEW_COMBO             = "New in Forever: this race/class combination did not exist in Classic."
L.UNKNOWN_RACE          = "ForeverPath doesn't recognise your race (%s). Showing faction-wide routes."

-- Rested XP
L.RESTED_HEADER         = "Rested XP"
L.RESTED_FMT            = "%s rested XP (%d%% of this level)"
L.RESTED_NONE           = "No rested XP. Log out in an inn or a capital city to build some up."
L.RESTED_RESTING        = "You are resting right now."
L.RESTED_MAX_LEVEL      = "You're at the level cap - rested XP no longer matters."
L.XP_TO_LEVEL_FMT       = "%s XP to level %d"

-- Class section
L.CLASS_HEADER          = "Your class: %s"
L.LEVEL_SPEC            = "Leveling spec: %s"
L.ALT_SPEC              = "Alternative: %s"
L.LEVEL_TIER            = "Leveling tier: %s"

-- Route section
L.ROUTE_HEADER          = "Mode: %s"
L.NOW                   = "Now"
L.NEXT                  = "Next"
L.LEVELS                = "Levels"
L.BAND_FMT              = "%s (%d-%d)"
L.QUEST_IN              = "Quest in: %s"

-- Dungeons
L.DUNGEON_HEADER        = "Dungeons for your level"
L.DUNGEON_NONE          = "Nothing in range yet - keep questing."
L.DUNGEON_FMT           = "%s (%d-%d) - %s"
L.NEW_TAG               = "new"
L.FACTION_TERRITORY     = "%s territory"

-- Milestones
L.MILESTONE_HEADER      = "Coming up"

-- General
L.GENERAL_HEADER        = "Good to know"

-- Chat
L.LOADED                = "loaded. Click the map button on your minimap to pick a guide."
L.DING_FMT              = "Level %d! Your route now suggests: %s"
L.DING_MILESTONE_FMT    = "Level %d unlocks: %s"
L.ROUTE_SET_FMT         = "Mode set to %s."
L.ROUTE_UNKNOWN         = "Unknown mode. Choose one of: %s"
L.POSITION_RESET        = "Window position reset."
L.HELP = {
    "/fp - toggle the leveling plan window",
    "/fp guide - toggle the step-by-step guide window",
    "/fp guide on|off - turn the step guide (and its waypoints) on or off",
    "/fp skip - skip the current step (its quests stay hidden until /fp unskip)",
    "/fp done - mark the current step done",
    "/fp unskip - bring back every skipped quest",
    "/fp waypoints auto|shortestpath|tomtom|builtin|off - choose the arrow",
    "/fp route <story|efficient|dungeon> - pick a leveling mode",
    "/fp next - print your current and next zones to chat",
    "/fp reset - reset window positions",
    "/fp help - show this help",
}

-- Step guide
L.GUIDE_TITLE                = "ForeverPath Guide"
L.GUIDE_AUTOMATIC            = "Automatic"
L.GUIDE_BROWSE               = "Guides"
L.GUIDE_SKIP                 = "Skip"
L.GUIDE_DONE                 = "Done"
L.GUIDE_NOTHING              = "No steps right now. Check the leveling plan (/fp) for where to head next."
L.GUIDE_NO_LOCATION          = "No map location known for this step."
L.GUIDE_REMINDERS            = "Reminders (click when done)"
L.GUIDE_REMINDER_TOOLTIP     = "Click to mark this reminder as done."
L.GUIDE_NEEDS_QUESTIE        = "Install Questie (with QuestieDB) to be guided to new quest givers. Showing your quest log only."
L.GUIDE_QUESTIE_INCOMPATIBLE = "This QuestieDB version isn't supported - update ForeverPath or Questie. Showing your quest log only."
L.GUIDE_INDEXING             = "Reading QuestieDB..."
L.GUIDE_NO_WAYPOINTS         = "No waypoint addon available - install Shortest Path Forever or TomTom."
L.GUIDE_SKIPPED_FMT          = "Skipped: %s (/fp unskip to undo)"
L.GUIDE_UNSKIPPED            = "All skipped quests are back in the guide."
L.GUIDE_ON                   = "Step guide on."
L.GUIDE_OFF                  = "Step guide off."
L.GUIDE_NOTHING_TO_SKIP      = "Nothing to skip."
L.GUIDE_NOTHING_TO_MARK      = "Nothing to mark done - quest steps complete on their own."
L.WAYPOINTS_SET_FMT          = "Waypoints: %s (using %s)."
L.WAYPOINTS_UNKNOWN          = "Choose one of: auto, shortestpath, tomtom, builtin, off"
