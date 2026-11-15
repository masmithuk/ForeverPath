-- Smoke tests for the window, slash commands and event wiring.

return {
    { "minimap button opens the main window on Home", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        T.truthy(ForeverPathMinimapButton, "minimap button created")
        ns.MinimapButton.Click("RightButton")
        T.truthy(ForeverPathMainFrame:IsShown(), "shown")
        T.eq(ForeverPathDB.tab, "home")
        T.contains(ns.HomeTab.GetText(), "Undead Speedrun (1-60)")

        ns.MainFrame.SetRoute("story")
        T.eq(ForeverPathCharDB.routeId, "story")
        T.contains(ns.HomeTab.GetText(), "Undead Story (1-60)")

        ns.MinimapButton.Click("RightButton")
        T.truthy(not ForeverPathMainFrame:IsShown(), "hidden")
        T.eq(ForeverPathDB.frame.shown, false)
    end },

    { "left-click on the minimap button toggles the guide window", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        T.eq(ForeverPathDB.guide.shown, true)
        ns.MinimapButton.Click("LeftButton")
        T.eq(ForeverPathDB.guide.shown, false)
        T.truthy(not ForeverPathGuideFrame:IsShown(), "hidden")
        ns.MinimapButton.Click("LeftButton")
        T.truthy(ForeverPathGuideFrame:IsShown(), "shown again")
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
        SlashCmdList.FOREVERPATH("route nowhere")
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
        ForeverPathDB = { schema = 5, announceLevelUp = false }
        T.reload()
        T.eq(ForeverPathDB.announceLevelUp, false, "kept")
        T.eq(ForeverPathDB.frame.point, "CENTER", "defaults filled")
        T.eq(ForeverPathDB.schema, 5, "schema stamped")
    end },

    { "a 0.3 route choice carries over to the new modes", function(T)
        T.fresh()
        ForeverPathCharDB = { schema = 2, routeId = "frontier" }
        T.reload()
        T.eq(ForeverPathCharDB.routeId, "efficient")
    end },

    { "a 0.4 Dungeon mode choice becomes Efficient", function(T)
        T.fresh()
        ForeverPathCharDB = { schema = 3, routeId = "dungeon", guideId = "Wailing Caverns" }
        ForeverPathDB = { schema = 3, tab = "guides" }
        T.reload()
        T.eq(ForeverPathCharDB.routeId, "efficient")
        T.eq(ForeverPathCharDB.guideId, nil, "dungeon guide choice dropped")
        T.eq(ForeverPathDB.tab, "home", "old tabs open Home")
    end },

    { "0.8 upgrade: old tabs, zone choice and the guide switch are cleared", function(T)
        T.fresh()
        ForeverPathCharDB = { schema = 4, routeId = "efficient", guideId = "Durotar" }
        ForeverPathDB = { schema = 4, tab = "plan", showAllBands = true,
                          guide = { enabled = false, waypoints = "auto" } }
        local ns = T.reload()
        T.eq(ForeverPathCharDB.guideId, nil)
        T.eq(ForeverPathDB.tab, "home")
        T.eq(ForeverPathDB.showAllBands, nil)
        T.eq(ForeverPathDB.guide.enabled, true, "guide back on (there's no switch for it now)")
        T.eq(ns.Engine.CurrentGuide().id, "speedrun-undead", "efficient -> your race's Speedrun")
    end },
}
