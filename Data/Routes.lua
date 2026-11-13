--[[
    ForeverPath - Data/Routes.lua

    Leveling routes. Each route is a list of contiguous level bands covering
    1-60. A band lists zones per faction (`Alliance`, `Horde`) and optional
    notes. The special zone token START is replaced by the character's racial
    starting zone at runtime (Zephras Isle for Skyborne).

    Zone/level data comes from the RankedBoost WoW Forever leveling guide and
    Warcraft Wiki (Nov 2026). Shen'dralas had no confirmed level range at
    launch; it is suggested as optional exploration in the 45-50 band.

    tests/test_data.lua verifies every route covers 1-60 with no gaps.
]]

local _, ns = ...

local START = "START"
ns.Data.START_ZONE_TOKEN = START

local function band(min, max, alliance, horde, notes)
    return { min = min, max = max, Alliance = alliance, Horde = horde, notes = notes or {} }
end

ns.Data.Routes = {
    ------------------------------------------------------------------------
    classic = {
        id = "classic",
        name = "Classic Questing",
        description = "The familiar vanilla path through the original zones.",
        dungeonWindow = { below = 0, above = 2 },
        bands = {
            band(1, 10, { START }, { START },
                { "Talents open at level 10." }),
            band(11, 20,
                { "Westfall", "Loch Modan", "Darkshore", "Redridge Mountains" },
                { "The Barrens", "Silverpine Forest", "Stonetalon Mountains" },
                { "New boats run from Stormwind Harbor to Auberdine." }),
            band(21, 30,
                { "Duskwood", "Wetlands", "Ashenvale", "Hillsbrad Foothills" },
                { "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains", "Thousand Needles" }),
            band(31, 40,
                { "Stranglethorn Vale", "Arathi Highlands", "Thousand Needles", "Desolace", "Dustwallow Marsh" },
                { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Badlands", "Dustwallow Marsh" }),
            band(41, 50,
                { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge" },
                { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge" }),
            band(51, 59,
                { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands", "Winterspring" },
                { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands", "Winterspring" }),
            band(60, 60, { "Mount Hyjal" }, { "Mount Hyjal" },
                { "Level 60 is the cap - forever. Mount Hyjal is the endgame zone." }),
        },
    },

    ------------------------------------------------------------------------
    frontier = {
        id = "frontier",
        name = "Forever Frontier",
        description = "Prioritises Forever's new zones and dungeons for fresh content.",
        dungeonWindow = { below = 0, above = 3 },
        bands = {
            band(1, 10, { START }, { START },
                { "Talents open at level 10." }),
            band(11, 20,
                { "Westfall", "Loch Modan", "Darkshore" },
                { "The Barrens", "Silverpine Forest" },
                { "Try the new Hall of Thanes (Alliance) or Ruins of Lordaeron (Horde)." }),
            band(21, 30,
                { "Wetlands", "Duskwood", "Alterac Mountains" },
                { "Hillsbrad Foothills", "Ashenvale", "Alterac Mountains" },
                { "Visit Dalaran in Alterac Mountains - its new dungeon opens at 28." }),
            band(31, 34,
                { "Stranglethorn Vale", "Arathi Highlands" },
                { "Stranglethorn Vale", "Arathi Highlands" }),
            band(35, 45,
                { "Riverglades", "Stranglethorn Vale" },
                { "Riverglades", "Stranglethorn Vale" },
                { "Reach Riverglades by walking in from northern Redridge, or take the Gadgetzan boat to Powderfuse Port.",
                  "Riverglades has more than 150 quests - it can carry most of this band." }),
            band(46, 50,
                { "Tanaris", "Feralas", "The Hinterlands", "Shen'dralas" },
                { "Tanaris", "Feralas", "The Hinterlands", "Shen'dralas" },
                { "Shen'dralas is reached from Desolace through the Valley of Bones (level range unconfirmed)." }),
            band(51, 59,
                { "Un'Goro Crater", "Azshara", "Felwood", "Winterspring" },
                { "Un'Goro Crater", "Azshara", "Felwood", "Winterspring" }),
            band(60, 60, { "Mount Hyjal" }, { "Mount Hyjal" },
                { "Enter Mount Hyjal from Winterspring through Darkwhisper Gorge." }),
        },
    },

    ------------------------------------------------------------------------
    dungeon = {
        id = "dungeon",
        name = "Dungeon Runner",
        description = "Quest near dungeon entrances and run every dungeon in range.",
        dungeonWindow = { below = 2, above = 4 },
        dungeonFirst = true,
        bands = {
            band(1, 12, { START }, { START },
                { "Quest to 13, then queue for your first dungeon." }),
            band(13, 22,
                { "Westfall", "Loch Modan", "Dun Morogh" },
                { "The Barrens", "Silverpine Forest", "Tirisfal Glades" },
                { "Grab dungeon quests in town before you go in - they are a big part of the XP." }),
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

--- Display order for the route picker.
ns.Data.RouteOrder = { "frontier", "classic", "dungeon" }
