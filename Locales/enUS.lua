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
L.TAB_LIBRARY           = "Guides"
L.TAB_ZONES             = "Zones"
L.TAB_PLAN              = "Plan"
L.TAB_SETTINGS          = "Settings"
L.CURRENT_GUIDE_FMT     = "Guide: %s"
L.CHANGE_GUIDE          = "Change guide"

-- Guide browser
L.GUIDES_FOLLOW         = "Follow this zone"
L.GUIDES_AUTO           = "Automatic"
L.GUIDES_FOLLOWING_FMT  = "Following: %s"
L.GUIDES_FOLLOWING_AUTO = "Following: Automatic (your guide's zones for your level)"
L.GUIDES_PROGRESS_FMT   = "%d of %d quests done"
L.GUIDES_NO_QUESTS      = "QuestieDB has no quests for you here yet."
L.GUIDES_NEED_QUESTIE   = "Install Questie (with QuestieDB) to see the quests in each zone."

-- Guide library (Guides tab)
L.LIB_BUILTIN           = "built-in"
L.LIB_IN_USE            = "in use"
L.LIB_BY_FMT            = "by %s"
L.LIB_BASED_ON_FMT      = "Based on: %s"
L.LIB_BASE_STORY        = "Story - every quest, chains in order"
L.LIB_BASE_EFFICIENT    = "Efficient - speedrun"
L.LIB_RULES_FMT         = "Quests from %d levels below to %d above you; detour limit: %s"
L.LIB_NO_LIMIT          = "none"
L.LIB_YARDS_FMT         = "%d yd"
L.LIB_ZONES_FMT         = "%d zones across levels 1-60"
L.LIB_EXTRAS_FMT        = "%d skipped quests, %d priority quests, %d custom steps"
L.LIB_BUILTIN_NOTE      = "Built-in guides can't be changed - use Copy to make your own version."
L.LIB_USE               = "Use this guide"
L.LIB_USING             = "In use"
L.LIB_EDIT              = "Edit"
L.LIB_VIEW              = "View"
L.LIB_COPY              = "Copy"
L.LIB_NEW               = "New guide"
L.LIB_DELETE            = "Delete"
L.LIB_DELETE_CONFIRM    = "Click again to delete"
L.LIB_EXPORT            = "Export"
L.LIB_IMPORT            = "Import"
L.LIB_DELETED_FMT       = "Deleted the guide %q."
L.LIB_USING_FMT         = "Now following the guide %q."

-- Guide editor
L.EDITOR_TITLE_EDIT     = "Edit guide"
L.EDITOR_TITLE_NEW      = "New guide"
L.EDITOR_TITLE_IMPORT   = "Import a guide"
L.EDITOR_TITLE_EXPORT   = "Export guide"
L.EDITOR_TITLE_VIEW     = "View guide"
L.EDITOR_CHECK          = "Check"
L.EDITOR_SAVE           = "Save"
L.EDITOR_IMPORT         = "Import"
L.EDITOR_CLOSE          = "Close"
L.EDITOR_SELECT_ALL     = "Select all"
L.EDITOR_COPY_EDIT      = "Copy & edit"
L.EDITOR_OK             = "No problems found."
L.EDITOR_SAVED          = "Saved."
L.EDITOR_IMPORTED_FMT   = "Imported %q."
L.EDITOR_LINE_FMT       = "Line %d: %s"
L.EDITOR_MORE_FMT       = "...and %d more."
L.EDITOR_EXPORT_HINT    = "The whole guide is selected - press Ctrl+C to copy it, then paste it anywhere to share."
L.EDITOR_IMPORT_HINT    = "Paste a guide here with Ctrl+V, then click Import."
L.EDITOR_VIEW_HINT      = "Built-in guides are read-only. Click Copy & edit to make your own version."
L.EDITOR_HELP           = "See the comments at the top of a new guide, or the README, for the format."
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

-- Quest automation
L.SETTINGS_AUTO          = "Quest automation"
L.SETTING_AUTO_ACCEPT    = "Accept quests automatically"
L.SETTING_AUTO_TURNIN    = "Turn in quests automatically"
L.SETTING_AUTO_FOLLOW    = "Only accept quests my mode would pick"
L.SETTING_AUTO_TRIVIAL   = "Skip grey (low-level) quests"
L.SETTING_AUTO_REPEAT    = "Skip repeatable quests"
L.AUTO_PAUSE_LABEL       = "Hold to pause while talking:"
L.AUTO_KEY_SHIFT         = "Shift"
L.AUTO_KEY_CTRL          = "Ctrl"
L.AUTO_KEY_ALT           = "Alt"
L.AUTO_KEY_NONE          = "None"
L.AUTO_NOTES             = "Reward choices and quests that cost gold are always left to you."
L.AUTO_QUESTIE_ON        = "Questie's own auto-accept/turn-in is on, so ForeverPath stays out of the way. "
    .. "Turn it off in Questie (/questie) to use these settings."
L.AUTO_CHOOSE_REWARD     = "Pick your reward - ForeverPath never chooses between rewards for you."
L.AUTO_COSTS_GOLD        = "This quest costs gold to complete, so ForeverPath left it to you."

-- Target button
L.TARGET_FMT            = "Target: %s"
L.TARGET_CYCLE_FMT      = "Target: %s (%d/%d)"
L.TARGET_TOOLTIP_TITLE  = "Target nearest quest mob"
L.TARGET_TOOLTIP_BODY   = "Each press targets the next creature you still need for a quest, "
    .. "nearest first, then starts again. Works in combat; the list refreshes when combat ends. "
    .. "Bind a key under Key Bindings > AddOns > ForeverPath (without Shift). "
    .. "Shift + left-drag to move."
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
L.ROUTE_HEADER          = "Guide: %s"
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
L.ROUTE_SET_FMT         = "Now following the guide %s."
L.ROUTE_UNKNOWN         = "Unknown guide. Choose one of: %s"
L.POSITION_RESET        = "Window position reset."
L.HELP = {
    "/fp - toggle the leveling plan window",
    "/fp guide - toggle the step-by-step guide window",
    "/fp guide on|off - turn the step guide (and its waypoints) on or off",
    "/fp skip - skip the current step (its quests stay hidden until /fp unskip)",
    "/fp done - mark the current step done",
    "/fp unskip - bring back every skipped quest",
    "/fp waypoints auto|shortestpath|tomtom|builtin|off - choose the arrow",
    "/fp route <guide id or name> - follow a guide (story, efficient or your own)",
    "/fp next - print your current and next zones to chat",
    "/fp reset - reset window positions",
    "/fp help - show this help",
}

-- Step guide
L.GUIDE_TITLE                = "ForeverPath Guide"
L.GUIDE_AUTOMATIC            = "Automatic"
L.GUIDE_BROWSE               = "Zones"
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
