-- luacheck configuration for Questwalker (run: luacheck .)
std = "lua51"
max_line_length = 140
codes = true

-- Colon-defined methods get an implicit `self` that may go unused.
ignore = { "212/self" }

exclude_files = { ".release/", "libs/" }

-- Globals the addon defines on purpose.
globals = {
    "QuestwalkerDB",
    "QuestwalkerCharDB",
    "Questwalker_OnAddonCompartmentClick",
    "SLASH_QUESTWALKER1",
    "SLASH_QUESTWALKER2",
    "SlashCmdList",
    "UISpecialFrames",
}

-- WoW API used by the addon.
read_globals = {
    -- Quest dialog (auto accept / turn in)
    "AcceptQuest", "AcknowledgeAutoAcceptQuest", "C_GossipInfo", "CompleteQuest",
    "GetActiveQuestID", "GetActiveTitle", "GetAvailableQuestInfo", "GetNumActiveQuests",
    "GetNumAvailableQuests", "GetNumQuestChoices", "GetQuestID", "GetQuestMoneyToGet",
    "GetQuestReward", "IsAltKeyDown", "IsControlKeyDown", "IsQuestCompletable",
    "QuestGetAutoAccept", "SelectActiveQuest", "SelectAvailableQuest", "UnitIsPlayer", "UnitGUID", "strsplit",
    "BreakUpLargeNumbers", "hooksecurefunc", "GetPlayerFacing", "UnitExists", "UnitClass", "UnitName",
    "RAID_CLASS_COLORS", "GetItemCooldown", "IsMounted", "UnitOnTaxi", "PlaySound", "SOUNDKIT",
    "C_Container", "NumTaxiNodes", "TaxiNodeName", "TaxiNodeGetType", "GetItemCount",
    "C_Map",
    "ChatFontNormal",
    "ScrollingEdit_OnCursorChanged",
    "ScrollingEdit_OnUpdate",
    "C_QuestLog",
    "C_Timer",
    "CreateFrame",
    "CreateVector2D",
    "Enum",
    "GameTooltip",
    "GetCursorPosition",
    "GetCVarBool",
    "SecureHandlerWrapScript",
    "GetTime",
    "InCombatLockdown",
    "IsShiftKeyDown",
    "IsTradeskillTrainer", "SelectQuestLogEntry", "SetAbandonQuest", "AbandonQuest", "GetBindLocation", "GetZoneText", "GetSubZoneText",
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
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
    "ShortestPathForever",
}

files["tests/"] = {
    std = "+lua51",
    globals = { "_G", "print", "issecretvalue", "QuestwalkerMainFrame", "QuestwalkerGuideFrame", "QuestwalkerGuideEditor", "QuestwalkerMinimapButton", "QuestwalkerTargetButton", "ShortestPathForever" },
}
