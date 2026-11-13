--[[
    ForeverPath - Data/Routes.lua

    The three leveling modes. Each mode has:

      bands  contiguous level bands covering 1-60. A band lists zones per
             faction (`Alliance`, `Horde`) and optional notes. The zone
             token START becomes the character's racial starting zone
             (Zephras Isle for Skyborne). The guide browser builds one guide
             per zone from these bands.

      rules  how the step guide picks and orders quests in this mode:
               greyGap      skip quests more than this many levels below you
               levelsAbove  allow quests up to this many levels above you
               maxAccept    quest givers considered per planning pass
               turninBonus  yards a hand-in is treated as closer than it is
               chainBonus   yards a follow-up quest is treated as closer,
                            so story chains are done in one go
               maxDetour    skip quests whose objectives are further than
                            this many yards from their quest giver
               dungeons     dungeon quests (and their pre-quests) are picked
                            up anywhere; other quests only in the band zones
               dungeonBonus yards a dungeon quest pickup is treated as closer

    Zone/level data comes from the RankedBoost WoW Forever leveling guide and
    Warcraft Wiki (Nov 2026). Shen'dralas had no confirmed level range at
    launch. tests/test_data.lua verifies every mode covers 1-60 with no gaps.
]]

local _, ns = ...

local START = "START"
ns.Data.START_ZONE_TOKEN = START

local function band(min, max, alliance, horde, notes)
    return { min = min, max = max, Alliance = alliance, Horde = horde, notes = notes or {} }
end

local BOTH_51_59 = { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands",
                     "Winterspring", "Burning Steppes", "Azshara", "Blasted Lands", "Silithus" }

ns.Data.Routes = {
    ------------------------------------------------------------------------
    -- Story: every quest in every zone, chains kept together.
    ------------------------------------------------------------------------
    story = {
        id = "story",
        name = "Story (Completionist)",
        description = "Every quest in each zone, following quest chains through in order.",
        dungeonWindow = { below = 0, above = 3 },
        rules = {
            greyGap = 10, levelsAbove = 3, maxAccept = 30,
            turninBonus = 60, chainBonus = 150,
        },
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
    efficient = {
        id = "efficient",
        name = "Efficient (Speedrun)",
        description = "The quickest path: dense zones, worthwhile quests only, no long detours.",
        dungeonWindow = { below = 0, above = 3 },
        rules = {
            greyGap = 2, levelsAbove = 2, maxAccept = 10,
            turninBonus = 120, chainBonus = 0, maxDetour = 350,
        },
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

    ------------------------------------------------------------------------
    -- Dungeon: level through dungeons; quest only near their entrances.
    ------------------------------------------------------------------------
    dungeon = {
        id = "dungeon",
        name = "Dungeon",
        description = "Collect every dungeon's quests and pre-quests, run the dungeons, and quest only near their entrances.",
        guidesAreDungeons = true,
        dungeonFirst = true,
        dungeonWindow = { below = 2, above = 4 },
        rules = {
            greyGap = 4, levelsAbove = 3, maxAccept = 12,
            turninBonus = 60, chainBonus = 0,
            dungeons = true, dungeonBonus = 200,
        },
        bands = {
            band(1, 12, { START }, { START },
                { "Quest to 13, then pick up your first dungeon's quests." }),
            band(13, 22,
                { "Westfall", "Loch Modan", "Dun Morogh" },
                { "The Barrens", "Silverpine Forest", "Tirisfal Glades" },
                { "Grab every quest for a dungeon before you go in - they are a big part of the XP." }),
            band(23, 33,
                { "Wetlands", "Ashenvale", "Alterac Mountains" },
                { "The Barrens", "Ashenvale", "Alterac Mountains" }),
            band(34, 45,
                { "Stranglethorn Vale", "Badlands", "Riverglades" },
                { "Stranglethorn Vale", "Badlands", "Riverglades" }),
            band(46, 54,
                { "Tanaris", "Dustwallow Marsh", "Searing Gorge" },
                { "Tanaris", "Dustwallow Marsh", "Searing Gorge" }),
            band(55, 59,
                { "Eastern Plaguelands", "Western Plaguelands", "Burning Steppes", "Azshara" },
                { "Eastern Plaguelands", "Western Plaguelands", "Burning Steppes", "Azshara" }),
            band(60, 60, { "Mount Hyjal" }, { "Mount Hyjal" },
                { "Gear up in the level 60 dungeons; raids open on 9 December." }),
        },
    },
}

--- Display order for the mode picker.
ns.Data.RouteOrder = { "story", "efficient", "dungeon" }

--- Route ids from 0.1-0.3, mapped to the mode that replaced them.
ns.Data.LegacyRouteIds = { classic = "story", frontier = "efficient" }
