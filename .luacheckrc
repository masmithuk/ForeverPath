-- luacheck configuration for ForeverPath (run: luacheck .)
std = "lua51"
max_line_length = 140
codes = true

-- Colon-defined methods get an implicit `self` that may go unused.
ignore = { "212/self" }

exclude_files = { ".release/", "libs/" }

-- Globals the addon defines on purpose.
globals = {
    "ForeverPathDB",
    "ForeverPathCharDB",
    "ForeverPath_OnAddonCompartmentClick",
    "SLASH_FOREVERPATH1",
    "SLASH_FOREVERPATH2",
    "SlashCmdList",
    "UISpecialFrames",
}

-- WoW API used by the addon.
read_globals = {
    "BreakUpLargeNumbers",
    "C_Map",
    "C_QuestLog",
    "C_Timer",
    "CreateFrame",
    "CreateVector2D",
    "Enum",
    "GameTooltip",
    "GetCursorPosition",
    "GetTime",
    "IsTradeskillTrainer",
    "Minimap",
    "UiMapPoint",
    "GetXPExhaustion",
    "IsResting",
    "UIParent",
    "UnitClass",
    "UnitFactionGroup",
    "UnitLevel",
    "UnitRace",
    "UnitXP",
    "UnitXPMax",
    "issecretvalue",
    -- Optional addons, always accessed via _G and type checks.
    "LibQuestieDB",
    "QuestieLoader",
    "TomTom",
}

files["tests/"] = {
    std = "+lua51",
    globals = { "_G", "print", "issecretvalue", "ForeverPathMainFrame", "ForeverPathGuideFrame", "ForeverPathMinimapButton" },
}
