--[[
    ForeverPath - Data/Routes.lua

    The built-in guides: a Speedrun and a Story guide, levels 1-60, for
    each starting area (Orc & Troll, Tauren, Undead, Human, Dwarf & Gnome,
    Night Elf, Skyborne). They are read-only in the game; players copy one
    to make their own version (see Guide/Library.lua, Guide/GuideFormat.lua).

      Speedrun  the quickest quest path to 60 for that race: its own
                starting zones, then the faction's densest zones, worthwhile
                quests only and no long detours (base "efficient").
      Story     the important quests of each zone - quest chains first,
                side quests only when they're on the way - enough to reach
                the next zone's levels (base "story").

    Each guide has:
      base   "story" or "efficient": the rule defaults in GuideFormat.BASES
      races  the race keys (Data/Races.lua) the guide is written for
      bands  contiguous level bands covering 1-60, with zones per faction
             (`Alliance`, `Horde`) and optional notes.

    The rules (GuideFormat.BASES) decide how the step guide picks quests:
      greyGap      skip quests more than this many levels below you
      levelsAbove  allow quests up to this many levels above you
      maxAccept    quest givers considered per planning pass
      turninBonus  yards a hand-in is treated as closer than it is
      chainBonus   yards a follow-up quest is treated as closer, so story
                   chains are done in one go
      sidePenalty  yards a stand-alone side quest is treated as further
                   away, so it's only picked up when it's on the way
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

local TALENTS = { "Talents open at level 10." }
local HYJAL = { "Enter Mount Hyjal from Winterspring through Darkwhisper Gorge." }
local RIVERGLADES = { "Reach Riverglades by walking in from northern Redridge, or take the Gadgetzan boat to Powderfuse Port.",
                      "Riverglades has more than 150 quests - it can carry most of this band." }

---------------------------------------------------------------------------
-- Faction paths after the starting zones (level 21+). { min, max, zones, notes }
---------------------------------------------------------------------------

local SPEEDRUN_TAIL = {
    Horde = {
        { 21, 30, { "Hillsbrad Foothills", "Ashenvale", "Stonetalon Mountains" } },
        { 31, 34, { "Thousand Needles", "Stranglethorn Vale", "Arathi Highlands" } },
        { 35, 45, { "Riverglades", "Stranglethorn Vale" }, RIVERGLADES },
        { 46, 50, { "Tanaris", "Feralas", "The Hinterlands" } },
        { 51, 59, { "Un'Goro Crater", "Felwood", "Winterspring" } },
        { 60, 60, { "Mount Hyjal" }, HYJAL },
    },
    Alliance = {
        { 21, 30, { "Wetlands", "Duskwood", "Redridge Mountains" } },
        { 31, 34, { "Stranglethorn Vale", "Arathi Highlands" } },
        { 35, 45, { "Riverglades", "Stranglethorn Vale" }, RIVERGLADES },
        { 46, 50, { "Tanaris", "Feralas", "The Hinterlands" } },
        { 51, 59, { "Un'Goro Crater", "Felwood", "Winterspring" } },
        { 60, 60, { "Mount Hyjal" }, HYJAL },
    },
}

local STORY_TAIL = {
    Horde = {
        { 21, 30, { "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains", "Thousand Needles" } },
        { 31, 40, { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Badlands", "Dustwallow Marsh", "Riverglades" } },
        { 41, 50, { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Riverglades", "Shen'dralas" },
          { "Shen'dralas is reached from Desolace through the Valley of Bones (level range unconfirmed)." } },
        { 51, 59, { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands", "Winterspring",
                    "Burning Steppes", "Azshara", "Silithus" } },
        { 60, 60, { "Mount Hyjal" }, HYJAL },
    },
    Alliance = {
        { 21, 30, { "Duskwood", "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Redridge Mountains" } },
        { 31, 40, { "Stranglethorn Vale", "Arathi Highlands", "Thousand Needles", "Desolace", "Dustwallow Marsh", "Riverglades" } },
        { 41, 50, { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Riverglades", "Shen'dralas" },
          { "Shen'dralas is reached from Desolace through the Valley of Bones (level range unconfirmed)." } },
        { 51, 59, { "Un'Goro Crater", "Felwood", "Western Plaguelands", "Eastern Plaguelands", "Winterspring",
                    "Burning Steppes", "Azshara", "Silithus" } },
        { 60, 60, { "Mount Hyjal" }, HYJAL },
    },
}

---------------------------------------------------------------------------
-- Starting areas: who starts there and the opening zones.
-- { min, max, zones, notes } for one faction, or Alliance/Horde lists for
-- Skyborne, who choose a side around level 12.
---------------------------------------------------------------------------

local GROUPS = {
    { key = "orc-troll", label = "Orc & Troll", races = { "Orc", "Troll" }, faction = "Horde",
      speedrun = { { 1, 10, { "Durotar" }, TALENTS }, { 11, 20, { "The Barrens" } } },
      story = { { 1, 10, { "Durotar" }, TALENTS }, { 11, 20, { "The Barrens", "Stonetalon Mountains" } } } },
    { key = "tauren", label = "Tauren", races = { "Tauren" }, faction = "Horde",
      speedrun = { { 1, 10, { "Mulgore" }, TALENTS }, { 11, 20, { "The Barrens" } } },
      story = { { 1, 10, { "Mulgore" }, TALENTS }, { 11, 20, { "The Barrens", "Stonetalon Mountains" } } } },
    { key = "undead", label = "Undead", races = { "Scourge" }, faction = "Horde",
      speedrun = { { 1, 10, { "Tirisfal Glades" }, TALENTS }, { 11, 20, { "Silverpine Forest", "The Barrens" } } },
      story = { { 1, 10, { "Tirisfal Glades" }, TALENTS }, { 11, 20, { "Silverpine Forest", "The Barrens" } } } },
    { key = "human", label = "Human", races = { "Human" }, faction = "Alliance",
      speedrun = { { 1, 10, { "Elwynn Forest" }, TALENTS }, { 11, 20, { "Westfall", "Loch Modan" } } },
      story = { { 1, 10, { "Elwynn Forest" }, TALENTS }, { 11, 20, { "Westfall", "Redridge Mountains", "Loch Modan" } } } },
    { key = "dwarf-gnome", label = "Dwarf & Gnome", races = { "Dwarf", "Gnome" }, faction = "Alliance",
      speedrun = { { 1, 10, { "Dun Morogh" }, TALENTS }, { 11, 20, { "Loch Modan", "Westfall" } } },
      story = { { 1, 10, { "Dun Morogh" }, TALENTS }, { 11, 20, { "Loch Modan", "Westfall", "Redridge Mountains" } } } },
    { key = "night-elf", label = "Night Elf", races = { "NightElf" }, faction = "Alliance",
      speedrun = { { 1, 10, { "Teldrassil" }, TALENTS }, { 11, 20, { "Darkshore" } } },
      story = { { 1, 10, { "Teldrassil" }, TALENTS }, { 11, 20, { "Darkshore", "Ashenvale" } } } },
    { key = "skyborne", label = "Skyborne", races = { "Skyborne" },
      speedrun = {
          { 1, 12, { Alliance = { "Zephras Isle" }, Horde = { "Zephras Isle" } },
            { "You choose Alliance or Horde on Zephras Isle around level 12.", "Talents open at level 10." } },
          { 13, 20, { Alliance = { "Westfall", "Darkshore" }, Horde = { "The Barrens", "Silverpine Forest" } } },
      },
      story = {
          { 1, 12, { Alliance = { "Zephras Isle" }, Horde = { "Zephras Isle" } },
            { "You choose Alliance or Horde on Zephras Isle around level 12.", "Talents open at level 10." } },
          { 13, 20, { Alliance = { "Westfall", "Darkshore", "Loch Modan" },
                      Horde = { "The Barrens", "Silverpine Forest", "Stonetalon Mountains" } } },
      } },
}
ns.Data.RaceGroups = GROUPS

local function copy(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

--- One band from a { min, max, zones, notes } entry. `zones` is a list for
--- the group's faction (used for both, so a faction-less character still
--- sees it), or { Alliance = {...}, Horde = {...} }.
local function toBand(entry)
    local zones = entry[3]
    if zones.Alliance or zones.Horde then
        return band(entry[1], entry[2], copy(zones.Alliance), copy(zones.Horde), copy(entry[4]))
    end
    return band(entry[1], entry[2], copy(zones), copy(zones), copy(entry[4]))
end

local function buildBands(group, kind)
    local bands = {}
    for _, entry in ipairs(group[kind]) do bands[#bands + 1] = toBand(entry) end
    local tails = kind == "speedrun" and SPEEDRUN_TAIL or STORY_TAIL
    for i, horde in ipairs(tails.Horde) do
        local alliance = tails.Alliance[i]
        local notes = horde[4] or alliance[4]
        local b
        if group.faction then
            b = toBand({ horde[1], horde[2], tails[group.faction][i][3], notes })
        else
            b = band(horde[1], horde[2], copy(alliance[3]), copy(horde[3]), copy(notes))
        end
        bands[#bands + 1] = b
    end
    return bands
end

local DESCRIPTIONS = {
    speedrun = "The quickest quest path to 60 for %s: their starting zones, then the densest zones, "
        .. "worthwhile quests only and no long detours.",
    story = "The important quests of each zone for %s - quest chains first, side quests only when "
        .. "they're on the way - enough to level into the next zone.",
}

ns.Data.BuiltinGuides = {}
for _, group in ipairs(GROUPS) do
    for _, kind in ipairs({ "speedrun", "story" }) do
        ns.Data.BuiltinGuides[#ns.Data.BuiltinGuides + 1] = {
            id = kind .. "-" .. group.key,
            name = ("%s %s (1-60)"):format(group.label, kind == "speedrun" and "Speedrun" or "Story"),
            author = "ForeverPath",
            description = DESCRIPTIONS[kind]:format(group.label),
            base = kind == "speedrun" and "efficient" or "story",
            races = copy(group.races),
            group = group.key,
            bands = buildBands(group, kind),
        }
    end
end

--- The starting-area group key for a race key ("Troll" -> "orc-troll").
function ns.Data.RaceGroupOf(raceKey)
    for _, group in ipairs(GROUPS) do
        for _, r in ipairs(group.races) do
            if r == raceKey then return group.key end
        end
    end
    return nil
end

--- Guide ids from older versions, mapped to the guide that replaced them
--- (0.1-0.3 routes, and 0.4's Dungeon mode, which was removed in 0.6).
ns.Data.LegacyRouteIds = { classic = "story", frontier = "efficient", dungeon = "efficient" }

--- "efficient" and "story" (the 0.7 guides, saved choices and class
--- defaults) mean the Speedrun / Story guide for the character's race.
ns.Data.GenericRouteIds = { efficient = "speedrun", speedrun = "speedrun", story = "story" }
