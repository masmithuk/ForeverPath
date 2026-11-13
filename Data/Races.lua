--[[
    ForeverPath - Data/Races.lua

    Playable races in World of Warcraft: Forever (client 1.60.1).

    Keys are the `raceFile` token returned by UnitRace("player"). Undead use
    the internal token "Scourge". The Skyborne token was not documented at
    launch, so Core/Character.lua also matches it by name (see `aliases`).

    `classes` maps classFile -> true, or -> "new" for combinations added in
    Forever (Orc Mage, Troll Warlock, Undead Paladin, Human Hunter,
    Gnome Priest, Dwarf Shaman). Skyborne classes depend on faction.

    Sources: Warcraft Wiki "World of Warcraft: Forever", Icy Veins and
    Gfinity race/class combination guides (Sept-Oct 2026).
]]

local _, ns = ...

ns.Data.Races = {
    Human = {
        name = "Human",
        faction = "Alliance",
        startZone = "Elwynn Forest",
        nextZone = "Westfall",
        classes = {
            HUNTER = "new", MAGE = true, PALADIN = true, PRIEST = true,
            ROGUE = true, WARLOCK = true, WARRIOR = true,
        },
    },
    Dwarf = {
        name = "Dwarf",
        faction = "Alliance",
        startZone = "Dun Morogh",
        nextZone = "Loch Modan",
        classes = {
            HUNTER = true, PALADIN = true, PRIEST = true, ROGUE = true,
            SHAMAN = "new", WARRIOR = true,
        },
    },
    Gnome = {
        name = "Gnome",
        faction = "Alliance",
        startZone = "Dun Morogh",
        nextZone = "Loch Modan",
        classes = {
            MAGE = true, PRIEST = "new", ROGUE = true, WARLOCK = true,
            WARRIOR = true,
        },
    },
    NightElf = {
        name = "Night Elf",
        faction = "Alliance",
        startZone = "Teldrassil",
        nextZone = "Darkshore",
        classes = {
            DRUID = true, HUNTER = true, PRIEST = true, ROGUE = true,
            WARRIOR = true,
        },
    },
    Orc = {
        name = "Orc",
        faction = "Horde",
        startZone = "Durotar",
        nextZone = "The Barrens",
        classes = {
            HUNTER = true, MAGE = "new", ROGUE = true, SHAMAN = true,
            WARLOCK = true, WARRIOR = true,
        },
    },
    Troll = {
        name = "Troll",
        faction = "Horde",
        startZone = "Durotar",
        nextZone = "The Barrens",
        classes = {
            HUNTER = true, MAGE = true, PRIEST = true, ROGUE = true,
            SHAMAN = true, WARLOCK = "new", WARRIOR = true,
        },
    },
    Tauren = {
        name = "Tauren",
        faction = "Horde",
        startZone = "Mulgore",
        nextZone = "The Barrens",
        classes = {
            DRUID = true, HUNTER = true, SHAMAN = true, WARRIOR = true,
        },
    },
    Scourge = {
        name = "Undead",
        faction = "Horde",
        startZone = "Tirisfal Glades",
        nextZone = "Silverpine Forest",
        classes = {
            MAGE = true, PALADIN = "new", PRIEST = true, ROGUE = true,
            WARLOCK = true, WARRIOR = true,
        },
    },
    Skyborne = {
        name = "Skyborne",
        faction = "Both",
        startZone = "Zephras Isle",
        -- Zephras Isle runs to roughly level 12 rather than 10.
        startZoneMaxLevel = 12,
        nextZone = nil, -- joins the faction's normal 11-20 zones
        -- Alliance Skyborne (High Order) can be Mages; Horde Skyborne
        -- (Windshaper) can be Shamans. Classes are all new by definition.
        classesByFaction = {
            Alliance = { DRUID = "new", HUNTER = "new", MAGE = "new", ROGUE = "new", WARRIOR = "new" },
            Horde    = { DRUID = "new", HUNTER = "new", SHAMAN = "new", ROGUE = "new", WARRIOR = "new" },
        },
        aliases = { "skyborne", "highorder", "windshaper" },
    },
}
