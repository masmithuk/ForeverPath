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
L.ROUTE_HEADER          = "Route: %s"
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
L.LOADED                = "loaded. Type /fp to open your leveling plan."
L.DING_FMT              = "Level %d! Your route now suggests: %s"
L.DING_MILESTONE_FMT    = "Level %d unlocks: %s"
L.ROUTE_SET_FMT         = "Route set to %s."
L.ROUTE_UNKNOWN         = "Unknown route. Choose one of: %s"
L.POSITION_RESET        = "Window position reset."
L.HELP = {
    "/fp - toggle the leveling plan window",
    "/fp guide - toggle the step-by-step guide window",
    "/fp guide on|off - turn the step guide (and its waypoints) on or off",
    "/fp skip - skip the current step (its quests stay hidden until /fp unskip)",
    "/fp done - mark the current step done",
    "/fp unskip - bring back every skipped quest",
    "/fp waypoints auto|tomtom|builtin|off - choose the arrow",
    "/fp route <classic|frontier|dungeon> - pick a route",
    "/fp next - print your current and next zones to chat",
    "/fp reset - reset window positions",
    "/fp help - show this help",
}

-- Step guide
L.GUIDE_TITLE                = "ForeverPath Guide"
L.GUIDE_SKIP                 = "Skip"
L.GUIDE_DONE                 = "Done"
L.GUIDE_NOTHING              = "No steps right now. Check the leveling plan (/fp) for where to head next."
L.GUIDE_NO_LOCATION          = "No map location known for this step."
L.GUIDE_REMINDERS            = "Reminders (click when done)"
L.GUIDE_REMINDER_TOOLTIP     = "Click to mark this reminder as done."
L.GUIDE_NEEDS_QUESTIE        = "Install Questie (with QuestieDB) to be guided to new quest givers. Showing your quest log only."
L.GUIDE_QUESTIE_INCOMPATIBLE = "This QuestieDB version isn't supported - update ForeverPath or Questie. Showing your quest log only."
L.GUIDE_INDEXING             = "Reading QuestieDB..."
L.GUIDE_NO_WAYPOINTS         = "No waypoint provider available - install TomTom for an arrow."
L.GUIDE_SKIPPED_FMT          = "Skipped: %s (/fp unskip to undo)"
L.GUIDE_UNSKIPPED            = "All skipped quests are back in the guide."
L.GUIDE_ON                   = "Step guide on."
L.GUIDE_OFF                  = "Step guide off."
L.GUIDE_NOTHING_TO_SKIP      = "Nothing to skip."
L.GUIDE_NOTHING_TO_MARK      = "Nothing to mark done - quest steps complete on their own."
L.WAYPOINTS_SET_FMT          = "Waypoints: %s (using %s)."
L.WAYPOINTS_UNKNOWN          = "Choose one of: auto, tomtom, builtin, off"
