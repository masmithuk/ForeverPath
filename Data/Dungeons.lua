--[[
    ForeverPath - Data/Dungeons.lua

    Five-player dungeons available while leveling.

    `min`/`max` is the recommended level range. New Forever dungeons use the
    ranges listed on the Warcraft Wiki; Classic dungeons use the minimum
    levels from the RankedBoost Forever leveling guide with an approximate
    upper bound. Where guides disagree (e.g. Excavation Site: Wetlands is
    listed as 24-29 and 26-31) the wiki range is used.

    `territory` marks dungeons inside a faction's capital or heartland,
    which are awkward for the other faction to reach.
]]

local _, ns = ...

ns.Data.Dungeons = {
    -- Classic dungeons
    { name = "Ragefire Chasm",       zone = "Orgrimmar",            min = 13, max = 18, territory = "Horde" },
    { name = "The Deadmines",        zone = "Westfall",             min = 16, max = 22, territory = "Alliance" },
    { name = "Wailing Caverns",      zone = "The Barrens",          min = 17, max = 24 },
    { name = "Shadowfang Keep",      zone = "Silverpine Forest",    min = 18, max = 25 },
    { name = "Blackfathom Deeps",    zone = "Ashenvale",            min = 22, max = 28 },
    { name = "The Stockade",         zone = "Stormwind",            min = 23, max = 28, territory = "Alliance" },
    { name = "Razorfen Kraul",       zone = "The Barrens",          min = 24, max = 30 },
    { name = "Gnomeregan",           zone = "Dun Morogh",           min = 25, max = 32 },
    { name = "Scarlet Monastery",    zone = "Tirisfal Glades",      min = 30, max = 40 },
    { name = "Razorfen Downs",       zone = "The Barrens",          min = 34, max = 40 },
    { name = "Uldaman",              zone = "Badlands",             min = 35, max = 44 },
    { name = "Maraudon",             zone = "Desolace",             min = 42, max = 50 },
    { name = "Zul'Farrak",           zone = "Tanaris",              min = 42, max = 48 },
    { name = "Sunken Temple",        zone = "Swamp of Sorrows",     min = 45, max = 54 },
    { name = "Blackrock Depths",     zone = "Searing Gorge",        min = 48, max = 58 },
    { name = "Blackrock Spire",      zone = "Burning Steppes",      min = 53, max = 60 },
    { name = "Dire Maul",            zone = "Feralas",              min = 54, max = 60 },
    { name = "Stratholme",           zone = "Eastern Plaguelands",  min = 55, max = 60 },
    { name = "Scholomance",          zone = "Western Plaguelands",  min = 57, max = 60 },

    -- New in Forever
    { name = "Hall of Thanes",            zone = "Ironforge",           min = 13, max = 18, isNew = true, territory = "Alliance" },
    { name = "Ruins of Lordaeron",        zone = "Undercity",           min = 15, max = 22, isNew = true, territory = "Horde" },
    { name = "Excavation Site: Wetlands", zone = "Wetlands",            min = 24, max = 29, isNew = true },
    { name = "City of Dalaran",           zone = "Alterac Mountains",   min = 28, max = 33, isNew = true },
    { name = "The Drowned City",          zone = "Stranglethorn Vale",  min = 35, max = 40, isNew = true },
    { name = "Krol'dok Stronghold",       zone = "Riverglades",         min = 40, max = 45, isNew = true },
    { name = "Alcaz Prison",              zone = "Dustwallow Marsh",    min = 48, max = 53, isNew = true },
    { name = "Blackmaw Hold",             zone = "Azshara",             min = 55, max = 60, isNew = true },
    { name = "Shaper's Terrace",          zone = "Un'Goro Crater",      min = 58, max = 60, isNew = true },
}
