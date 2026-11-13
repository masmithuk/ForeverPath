--[[
    ForeverPath - Data/Classes.lua

    Leveling advice per class, keyed by the `classFile` token returned by
    UnitClass("player").

    Fields
      spec          recommended solo leveling spec
      altSpec       a reasonable alternative and when to pick it
      tier          consensus leveling tier at launch (S+ best .. C)
      why           one-line reason the spec levels well
      tips          short, practical tips
      defaultRoute  route id from Data/Routes.lua that suits the class

    Tiers and specs follow the launch consensus of the Timesaver and
    MMOnster leveling tier lists (as compiled by AxeeTech, 6 Nov 2026).
    Balance changes will date these; update them here, nowhere else.
]]

local _, ns = ...

ns.Data.Classes = {
    HUNTER = {
        name = "Hunter",
        spec = "Beast Mastery",
        altSpec = "Marksmanship once your gear can carry ranged damage",
        tier = "S+",
        why = "Your pet tanks while you shoot, and Aimed Shot and Arcane Shot were buffed.",
        tips = {
            "Tame Beast arrives at level 10 - get your pet before leaving the starting area.",
            "Keep your pet fed and its abilities trained; it is your tank.",
        },
        defaultRoute = "frontier",
    },
    MAGE = {
        name = "Mage",
        spec = "Frost",
        altSpec = "Fire for faster single-target kills in dungeons",
        tier = "S+",
        why = "AoE pulls and free food and water - the fastest class in the race to 60.",
        tips = {
            "Blizzard's slow was weakened in Forever, so kite carefully on big pulls.",
            "Conjure food and water before every outing; it removes almost all downtime.",
            "You can teleport to capital cities - use it to train and sell quickly.",
        },
        defaultRoute = "frontier",
    },
    PALADIN = {
        name = "Paladin",
        spec = "Retribution",
        altSpec = "Protection - the strongest tank, great for dungeon-heavy leveling",
        tier = "S",
        why = "Plate armor and self-heals make it forgiving and rarely deadly.",
        tips = {
            "Righteous Fury is available at level 10 if you want to tank dungeons.",
            "Heal yourself between pulls instead of eating to keep moving.",
        },
        defaultRoute = "frontier",
    },
    WARLOCK = {
        name = "Warlock",
        spec = "Affliction",
        altSpec = "Demonology for a sturdier pet",
        tier = "A",
        why = "Instant DoTs plus a tanking pet keep downtime low.",
        tips = {
            "Pet Stamina scaling was cut at launch, so the Voidwalker tanks less than in beta.",
            "Summoning needs two party members to help - handy for dungeon groups.",
        },
        defaultRoute = "frontier",
    },
    DRUID = {
        name = "Druid",
        spec = "Feral",
        altSpec = "Balance if you prefer ranged damage",
        tier = "B",
        why = "Cat Form damage was buffed, and Bear Form is a safety net.",
        tips = {
            "Many of the best tools arrive after level 30, so the class gets stronger as you go.",
            "Swap to Bear Form when a pull goes wrong instead of dying in Cat Form.",
        },
        defaultRoute = "frontier",
    },
    PRIEST = {
        name = "Priest",
        spec = "Discipline",
        altSpec = "Shadow for more solo damage",
        tier = "B",
        why = "Shield, Renew and a wand keep you alive, though kills are slow.",
        tips = {
            "Pick up a wand as early as you can - it does much of your solo damage.",
            "Priests level much faster in groups; healers find dungeon groups quickly.",
        },
        defaultRoute = "dungeon",
    },
    SHAMAN = {
        name = "Shaman",
        spec = "Enhancement",
        altSpec = "Elemental for ranged damage (watch your mana)",
        tier = "B",
        why = "Lightning Bolt and Stormstrike were buffed.",
        tips = {
            "Early mana costs are high; melee more and cast less in the first levels.",
            "Tier lists disagree on Shaman (ratings from A to C), so play what feels good.",
        },
        defaultRoute = "frontier",
    },
    ROGUE = {
        name = "Rogue",
        spec = "Combat",
        altSpec = "Subtlety if you like to pick fights on your terms",
        tier = "B",
        why = "Shank and Poised help with energy.",
        tips = {
            "Still fragile - pull one enemy at a time and keep bandages handy.",
            "Stealth past enemies you don't need to kill for a quest.",
        },
        defaultRoute = "classic",
    },
    WARRIOR = {
        name = "Warrior",
        spec = "Arms",
        altSpec = "Protection to tank dungeons, where Warriors shine",
        tier = "C",
        why = "Slow solo - Warriors need gear, build Rage slowly and have no self-heal.",
        tips = {
            "Lean on dungeons: tanks find groups fast and level well with a healer.",
            "Upgrade your weapon whenever you can - it matters more for Warriors than anyone.",
            "Train First Aid early to cut downtime.",
        },
        defaultRoute = "dungeon",
    },
}

--- Tips that apply to every class.
ns.Data.GeneralTips = {
    "Abilities are not learned automatically - visit your class trainer every couple of levels.",
    "Weapon skills must be learned and levelled before a new weapon type hits reliably.",
    "Budget roughly 206 gold for class training from 1 to 60, plus riding.",
}
