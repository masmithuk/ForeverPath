--[[
    ForeverPath - Data/Routes.lua

    The built-in guides: Story (Completionist) and Efficient (Speedrun).
    They are read-only in the game; players copy one to make their own
    version (see Guide/Library.lua and Guide/GuideFormat.lua).

    Each guide has:
      base   "story" or "efficient": the rule defaults in GuideFormat.BASES
      bands  contiguous level bands covering 1-60. A band lists zones per
             faction (`Alliance`, `Horde`) and optional notes. The zone
             token START becomes the character's racial starting zone
             (Zephras Isle for Skyborne). The zone browser builds one
             guide per zone from these bands.

    The rules (GuideFormat.BASES) decide how the step guide picks quests:
      greyGap      skip quests more than this many levels below you
      levelsAbove  allow quests up to this many levels above you
      maxAccept    quest givers considered per planning pass
      turninBonus  yards a hand-in is treated as closer than it is
      chainBonus   yards a follow-up quest is treated as closer, so story
                   chains are done in one go
      maxDetour    skip quests whose objectives are further than this many
                   yards from their quest giver (0 = no limit)

    Zone/level data comes from the RankedBoost WoW Forever leveling guide and
    Warcraft Wiki (Nov 2026). Shen'dralas had no confirmed level range at
    launch. tests/test_data.lua checks every built-in guide is valid.
]]

local _, ns = ...

local START = "START"
ns.Data.START_ZONE_TOKEN = START

local function band(min, max, alliance, horde, notes)
    return { min = min, max = max, Alliance = alliance, Horde = horde, notes = notes or {} }
end

local BOTH_51_59 = { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands",
                     "Winterspring", "Burning Steppes", "Azshara", "Blasted Lands", "Silithus" }

ns.Data.BuiltinGuides = {
    ------------------------------------------------------------------------
    -- Story: every quest in every zone, chains kept together.
    ------------------------------------------------------------------------
    {
        id = "story",
        name = "Story (Completionist)",
        author = "ForeverPath",
        description = "Every quest in each zone, following quest chains through in order.",
        base = "story",
        bands = {
            band(1, 10, { START }, { START },
                { "Talents open at level 10." }),
            band(11, 20,
                { "Westfall", "Loch Modan", "Darkshore", "Redridge Mountains" },
                { "The Barrens", "Silverpine Forest", "Stonetalon Mountains" }),
            band(21, 30,
                { "Duskwood", "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Alterac Mountains", "Stonetalon Mountains" },
                { "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains", "Thousand Needles", "Alterac Mountains" }),
            band(31, 40,
                { "Stranglethorn Vale", "Arathi Highlands", "Thousand Needles", "Desolace", "Dustwallow Marsh", "Riverglades" },
                { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Badlands", "Dustwallow Marsh", "Riverglades" }),
            band(41, 50,
                { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Riverglades", "Shen'dralas" },
                { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Riverglades", "Shen'dralas" },
                { "Shen'dralas is reached from Desolace through the Valley of Bones (level range unconfirmed)." }),
            band(51, 59, BOTH_51_59, BOTH_51_59),
            band(60, 60, { "Mount Hyjal" }, { "Mount Hyjal" },
                { "Enter Mount Hyjal from Winterspring through Darkwhisper Gorge." }),
        },
    },

    ------------------------------------------------------------------------
    -- Efficient: the quickest path through the densest zones.
    ------------------------------------------------------------------------
    {
        id = "efficient",
        name = "Efficient (Speedrun)",
        author = "ForeverPath",
        description = "The quickest path: dense zones, worthwhile quests only, no long detours.",
        base = "efficient",
        bands = {
            band(1, 10, { START }, { START },
                { "Talents open at level 10." }),
            band(11, 20,
                { "Westfall", "Loch Modan", "Darkshore" },
                { "The Barrens", "Silverpine Forest" }),
            band(21, 30,
                { "Wetlands", "Duskwood", "Alterac Mountains" },
                { "Hillsbrad Foothills", "Ashenvale", "Alterac Mountains" }),
            band(31, 34,
                { "Stranglethorn Vale", "Arathi Highlands" },
                { "Stranglethorn Vale", "Arathi Highlands" }),
            band(35, 45,
                { "Riverglades", "Stranglethorn Vale" },
                { "Riverglades", "Stranglethorn Vale" },
                { "Reach Riverglades by walking in from northern Redridge, or take the Gadgetzan boat to Powderfuse Port.",
                  "Riverglades has more than 150 quests - it can carry most of this band." }),
            band(46, 50,
                { "Tanaris", "Feralas", "The Hinterlands" },
                { "Tanaris", "Feralas", "The Hinterlands" }),
            band(51, 59,
                { "Un'Goro Crater", "Felwood", "Winterspring" },
                { "Un'Goro Crater", "Felwood", "Winterspring" }),
            band(60, 60, { "Mount Hyjal" }, { "Mount Hyjal" },
                { "Enter Mount Hyjal from Winterspring through Darkwhisper Gorge." }),
        },
    },
}

--- Guide ids from older versions, mapped to the guide that replaced them
--- (0.1-0.3 routes, and 0.4's Dungeon mode, which was removed in 0.6).
ns.Data.LegacyRouteIds = { classic = "story", frontier = "efficient", dungeon = "efficient" }
