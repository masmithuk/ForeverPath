--[[
    Questwalker - Data/Services.lua

    Settings for the "service" steps the guide adds to your route when they
    matter and you're close by - no reminders, just steps:

      Train at <class trainer>        your class training is due
      Set your hearthstone at <inn>   your hearthstone is bound elsewhere
      Train <profession> at <trainer> a profession you know is ready for
                                      its next rank

    Each one clears itself when the game state changes (you train, bind
    your hearthstone, or learn the next rank), or you can Skip it.
]]

local _, ns = ...

ns.Data.Services = {
    -- Service steps only appear when the NPC is within this many yards.
    nearDistance = 400,
    -- Class trainers: suggested when one is this close, or in the zone
    -- you're in (they're usually in towns, so 400 yards was rarely met).
    trainerDistance = 1200,

    -- Class training every `every` levels from `from` (Classic cadence;
    -- Forever's schedule isn't published).
    training = { from = 4, every = 2 },

    -- QuestieDB titles ("subName") used to find NPCs.
    innkeeperTitle = "Innkeeper",
    professions = {
        "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking",
        "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing",
    },

    -- A profession is ready for its next rank once its skill is within
    -- `rankGap` points of its cap, and you meet the level for that rank:
    -- cap 75 -> Journeyman (10), 150 -> Expert (20), 225 -> Artisan (35).
    rankGap = 25,
    nextRankLevel = { [75] = 10, [150] = 20, [225] = 35 },
    skillCap = 300,
}
