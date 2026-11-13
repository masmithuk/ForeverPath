local function profileFor(ns, mock, race, class, faction, level)
    mock.player.race = race
    mock.player.class = class
    mock.player.faction = faction
    mock.player.level = level
    return ns.Character.Detect()
end

return {
    { "route choice: explicit, then class default, then global default", function(T)
        local ns = T.fresh()
        local warrior = { class = ns.Data.Classes.WARRIOR }
        T.eq(ns.Advisor.ResolveRouteId(warrior, "classic"), "classic")
        T.eq(ns.Advisor.ResolveRouteId(warrior, nil), "dungeon")
        T.eq(ns.Advisor.ResolveRouteId(warrior, "bogus"), "dungeon")
        T.eq(ns.Advisor.ResolveRouteId({}, nil), "frontier")
    end },

    { "band lookup is clamped at both ends", function(T)
        local ns = T.fresh()
        local route = ns.Data.Routes.classic
        T.eq(ns.Advisor.FindBandIndex(route, 0), 1)
        T.eq(ns.Advisor.FindBandIndex(route, 1), 1)
        T.eq(ns.Advisor.FindBandIndex(route, 15), 2)
        T.eq(ns.Advisor.FindBandIndex(route, 60), #route.bands)
        T.eq(ns.Advisor.FindBandIndex(route, 99), #route.bands)
    end },

    { "starting zone replaces the START token", function(T)
        local ns, mock = T.fresh()
        local p = profileFor(ns, mock, { "Night Elf", "NightElf", 4 }, { "Druid", "DRUID", 11 }, "Alliance", 3)
        local plan = ns.Advisor.BuildPlan(p, "classic")
        T.eq(plan.current.zones[1], "Teldrassil")
    end },

    { "Undead are pointed at Silverpine first at 11-20", function(T)
        local ns, mock = T.fresh()
        local p = profileFor(ns, mock, { "Undead", "Scourge", 5 }, { "Mage", "MAGE", 8 }, "Horde", 14)
        local plan = ns.Advisor.BuildPlan(p, "classic")
        T.eq(plan.current.zones[1], "Silverpine Forest")
        T.contains(plan.current.zones, "The Barrens")
    end },

    { "Skyborne stay on Zephras Isle until 12", function(T)
        local ns, mock = T.fresh()
        local p = profileFor(ns, mock, { "Skyborne", "Skyborne", 90 }, { "Rogue", "ROGUE", 4 }, "Alliance", 11)
        local plan = ns.Advisor.BuildPlan(p, "frontier")
        T.eq(plan.current.zones[1], "Zephras Isle")
        p.level = 13
        plan = ns.Advisor.BuildPlan(p, "frontier")
        T.truthy(plan.current.zones[1] ~= "Zephras Isle", "moved on at 13")
    end },

    { "neutral characters see both factions' zones", function(T)
        local ns, mock = T.fresh()
        local p = profileFor(ns, mock, { "Skyborne", "Skyborne", 90 }, { "Rogue", "ROGUE", 4 }, nil, 15)
        local plan = ns.Advisor.BuildPlan(p, "classic")
        T.contains(plan.current.zones, "Westfall")
        T.contains(plan.current.zones, "The Barrens")
    end },

    { "frontier route sends mid-30s players to Riverglades", function(T)
        local ns, mock = T.fresh()
        local p = profileFor(ns, mock, { "Human", "Human", 1 }, { "Hunter", "HUNTER", 3 }, "Alliance", 38)
        local plan = ns.Advisor.BuildPlan(p, "frontier")
        T.contains(plan.current.zones, "Riverglades")
    end },

    { "dungeons are filtered by level and enemy territory sorts last", function(T)
        local ns = T.fresh()
        local list = ns.Advisor.GetDungeons(16, "Horde", { below = 0, above = 2 })
        local names = {}
        for i, d in ipairs(list) do names[i] = d.name end
        T.contains(names, "Ruins of Lordaeron")
        T.contains(names, "Hall of Thanes")
        T.truthy(not ({ Gnomeregan = true })[names[1]], "no out-of-range dungeons")
        -- Alliance-territory dungeons come after the rest for a Horde player.
        local lastNeutralIndex, firstEnemyIndex = 0, math.huge
        for i, d in ipairs(list) do
            if d.territory == "Alliance" then
                firstEnemyIndex = math.min(firstEnemyIndex, i)
            else
                lastNeutralIndex = i
            end
        end
        T.truthy(lastNeutralIndex < firstEnemyIndex, "enemy territory last")
    end },

    { "milestones respect class restrictions", function(T)
        local ns = T.fresh()
        local function texts(list)
            local out = {}
            for i, m in ipairs(list) do out[i] = m.text end
            return table.concat(out, "|")
        end
        T.contains(texts(ns.Advisor.GetMilestonesAt(10, "HUNTER")), "Tame Beast")
        T.truthy(not texts(ns.Advisor.GetMilestonesAt(10, "MAGE")):find("Tame Beast"), "mage has no pet")
        T.eq(#ns.Advisor.GetUpcomingMilestones(60, "MAGE"), 0, "nothing after 60")
    end },

    { "rested XP percentage and XP to level", function(T)
        local ns = T.fresh()
        local xp = ns.Advisor.GetXpInfo(12)
        T.eq(xp.rested, 2000)
        T.eq(xp.restedPct, 50)
        T.eq(xp.toLevel, 3000)
        T.eq(xp.atCap, false)
    end },

    { "rested XP handles nil and the level cap", function(T)
        local ns, mock = T.fresh()
        mock.player.rested = nil
        T.eq(ns.Advisor.GetXpInfo(20).rested, 0)
        T.eq(ns.Advisor.GetXpInfo(60).atCap, true)
    end },
}
