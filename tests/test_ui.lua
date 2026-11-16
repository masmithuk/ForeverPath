-- Smoke tests for the window, slash commands and event wiring.

return {
    { "minimap button opens the main window on Home", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        T.truthy(QuestwalkerMinimapButton, "minimap button created")
        ns.MinimapButton.Click("RightButton")
        T.truthy(QuestwalkerMainFrame:IsShown(), "shown")
        T.eq(QuestwalkerDB.tab, "home")
        T.contains(ns.HomeTab.GetText(), "Undead Speedrun (1-60)")

        ns.MainFrame.SetRoute("story")
        T.eq(QuestwalkerCharDB.routeId, "story")
        T.contains(ns.HomeTab.GetText(), "Undead Story (1-60)")

        ns.MinimapButton.Click("RightButton")
        T.truthy(not QuestwalkerMainFrame:IsShown(), "hidden")
        T.eq(QuestwalkerDB.frame.shown, false)
    end },

    { "left-click on the minimap button toggles the guide window", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        T.eq(QuestwalkerDB.guide.shown, true)
        ns.MinimapButton.Click("LeftButton")
        T.eq(QuestwalkerDB.guide.shown, false)
        T.truthy(not QuestwalkerGuideFrame:IsShown(), "hidden")
        ns.MinimapButton.Click("LeftButton")
        T.truthy(QuestwalkerGuideFrame:IsShown(), "shown again")
    end },

    { "minimap button position follows the saved angle", function(T)
        local ns = T.fresh()
        local x, y = ns.MinimapButton.Offset(0, 80)
        T.eq(math.floor(x + 0.5), 80)
        T.eq(math.floor(y + 0.5), 0)
        x, y = ns.MinimapButton.Offset(90, 80)
        T.eq(math.floor(x + 0.5), 0)
        T.eq(math.floor(y + 0.5), 80)
    end },

    { "unknown route prints the valid choices", function(T)
        local _, mock = T.fresh()
        SlashCmdList.QUESTWALKER("route nowhere")
        T.contains(mock.printed[#mock.printed], "speedrun, story")
    end },

    { "level-up into a new band announces zones and milestones", function(T)
        local ns, mock = T.fresh()
        mock.player.class = { "Hunter", "HUNTER", 3 }
        mock.player.race = { "Orc", "Orc", 2 }
        ns:FireEvent("PLAYER_LEVEL_UP", 10)
        local all = table.concat(mock.printed, "\n")
        T.contains(all, "Tame Beast")

        mock.printed = {}
        ns:FireEvent("PLAYER_LEVEL_UP", 11)
        T.contains(table.concat(mock.printed, "\n"), "The Barrens")

        mock.printed = {}
        ns:FireEvent("PLAYER_LEVEL_UP", 12)
        T.eq(#mock.printed, 0, "no spam inside a band")
    end },

    { "saved variables survive a relog and gain new defaults", function(T)
        T.fresh()
        -- Pretend an older install saved only one field.
        QuestwalkerDB = { schema = 6, announceLevelUp = false }
        T.reload()
        T.eq(QuestwalkerDB.announceLevelUp, false, "kept")
        T.eq(QuestwalkerDB.frame.point, "CENTER", "defaults filled")
        T.eq(QuestwalkerDB.schema, 6, "schema stamped")
    end },

    { "a 0.3 route choice carries over to the new modes", function(T)
        T.fresh()
        QuestwalkerCharDB = { schema = 2, routeId = "frontier" }
        T.reload()
        T.eq(QuestwalkerCharDB.routeId, "efficient")
    end },

    { "a 0.4 Dungeon mode choice becomes Efficient", function(T)
        T.fresh()
        QuestwalkerCharDB = { schema = 3, routeId = "dungeon", guideId = "Wailing Caverns" }
        QuestwalkerDB = { schema = 3, tab = "guides" }
        T.reload()
        T.eq(QuestwalkerCharDB.routeId, "efficient")
        T.eq(QuestwalkerCharDB.guideId, nil, "dungeon guide choice dropped")
        T.eq(QuestwalkerDB.tab, "home", "old tabs open Home")
    end },

    { "0.8 upgrade: old tabs, zone choice and the guide switch are cleared", function(T)
        T.fresh()
        QuestwalkerCharDB = { schema = 4, routeId = "efficient", guideId = "Durotar" }
        QuestwalkerDB = { schema = 4, tab = "plan", showAllBands = true,
                          guide = { enabled = false, waypoints = "auto" } }
        local ns = T.reload()
        T.eq(QuestwalkerCharDB.guideId, nil)
        T.eq(QuestwalkerDB.tab, "home")
        T.eq(QuestwalkerDB.showAllBands, nil)
        T.eq(QuestwalkerDB.guide.enabled, true, "guide back on (there's no switch for it now)")
        T.eq(ns.Engine.CurrentGuide().id, "speedrun-undead", "efficient -> your race's Speedrun")
    end },

    { "0.8 upgrade: hold-to-pause removed, auto accept takes every quest", function(T)
        T.fresh()
        QuestwalkerDB = { schema = 5, auto = { accept = true, followMode = true, pauseKey = "SHIFT" } }
        T.reload()
        T.eq(QuestwalkerDB.auto.pauseKey, nil)
        T.eq(QuestwalkerDB.auto.followMode, false)
        T.eq(QuestwalkerDB.auto.accept, true, "kept")
    end },
}
