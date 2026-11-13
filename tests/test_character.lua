return {
    { "detects an Undead Mage on the Horde", function(T)
        local ns = T.fresh()
        local p = ns.Character.Detect()
        T.eq(p.raceKey, "Scourge")
        T.eq(p.raceName, "Undead")
        T.eq(p.classFile, "MAGE")
        T.eq(p.faction, "Horde")
        T.eq(p.level, 12)
        T.eq(p.isNewCombo, false)
    end },

    { "flags new Forever combinations", function(T)
        local ns, mock = T.fresh()
        mock.player.class = { "Paladin", "PALADIN", 2 }
        T.eq(ns.Character.Detect().isNewCombo, true, "Undead Paladin")
    end },

    { "matches Skyborne by name even with an unknown token", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Skyborne", "SkyborneWindshaper", 99 }
        mock.player.class = { "Shaman", "SHAMAN", 7 }
        local p = ns.Character.Detect()
        T.eq(p.raceKey, "Skyborne")
        T.eq(p.isNewCombo, true)
    end },

    { "Skyborne classes depend on faction", function(T)
        local ns = T.fresh()
        local race = ns.Data.Races.Skyborne
        T.truthy(ns.Character.GetRaceClasses(race, "Alliance").MAGE, "Alliance mage")
        T.truthy(not ns.Character.GetRaceClasses(race, "Alliance").SHAMAN, "no Alliance shaman")
        T.truthy(ns.Character.GetRaceClasses(race, "Horde").SHAMAN, "Horde shaman")
    end },

    { "unknown faction becomes Neutral", function(T)
        local ns, mock = T.fresh()
        mock.player.faction = nil
        T.eq(ns.Character.Detect().faction, "Neutral")
    end },

    { "unknown race does not crash", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Murloc", "Murloc", 200 }
        local p = ns.Character.Detect()
        T.eq(p.raceKey, nil)
        T.eq(p.raceName, "Murloc")
    end },

    { "secret level values fall back safely", function(T)
        local ns, mock = T.fresh()
        local secret = {}
        _G.issecretvalue = function(v) return v == secret end
        mock.player.level = secret
        T.eq(ns.Character.Detect().level, 1)
        _G.issecretvalue = nil
    end },
}
