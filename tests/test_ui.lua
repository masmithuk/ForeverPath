-- Smoke tests for the window, slash commands and event wiring.

return {
    { "rendered text contains the key sections", function(T)
        local ns = T.fresh()
        local profile = ns.Character.Detect()
        local plan = ns.Advisor.BuildPlan(profile, nil)
        local text = ns.Text.Render(profile, plan, ns.Advisor.GetXpInfo(profile.level), {})
        T.contains(text, "Undead Mage - Level 12 (Horde)")
        T.contains(text, "Frost")
        T.contains(text, "Rested XP")
        T.contains(text, "Ruins of Lordaeron")
    end },

    { "show-all mode lists every band", function(T)
        local ns = T.fresh()
        local profile = ns.Character.Detect()
        local plan = ns.Advisor.BuildPlan(profile, "story")
        local text = ns.Text.Render(profile, plan, nil, { showAllBands = true })
        T.contains(text, "Mount Hyjal")
    end },

    { "minimap button opens the main window; route buttons save per character", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        T.truthy(ForeverPathMinimapButton, "minimap button created")

        ns.MinimapButton.Click("RightButton")
        T.truthy(ForeverPathMainFrame:IsShown(), "shown")
        ns.MainFrame.ShowTab("plan")
        T.contains(ns.PlanTab.GetText(), "Efficient (Speedrun)")

        ns.MainFrame.SetRoute("story")
        T.eq(ForeverPathCharDB.routeId, "story")
        T.contains(ns.PlanTab.GetText(), "Story (Completionist)")

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
        T.contains(mock.printed[#mock.printed], "story, efficient, dungeon")
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
        ForeverPathDB = { showAllBands = true }
        T.reload()
        T.eq(ForeverPathDB.showAllBands, true, "kept")
        T.eq(ForeverPathDB.frame.point, "CENTER", "defaults filled")
        T.eq(ForeverPathDB.schema, 3, "schema stamped")
    end },

    { "a 0.3 route choice carries over to the new modes", function(T)
        T.fresh()
        ForeverPathCharDB = { schema = 2, routeId = "frontier" }
        T.reload()
        T.eq(ForeverPathCharDB.routeId, "efficient")
    end },
}
