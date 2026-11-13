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
        local plan = ns.Advisor.BuildPlan(profile, "classic")
        local text = ns.Text.Render(profile, plan, nil, { showAllBands = true })
        T.contains(text, "Mount Hyjal")
    end },

    { "/fp toggles the window and /fp route saves per character", function(T)
        local ns = T.fresh()
        ns:FireEvent("PLAYER_LOGIN")
        SlashCmdList.FOREVERPATH("")
        T.truthy(ForeverPathMainFrame:IsShown(), "shown")
        T.contains(ForeverPathMainFrame.text:GetText(), "Forever Frontier")

        SlashCmdList.FOREVERPATH("route Classic")
        T.eq(ForeverPathCharDB.routeId, "classic")
        T.contains(ForeverPathMainFrame.text:GetText(), "Classic Questing")

        SlashCmdList.FOREVERPATH("")
        T.truthy(not ForeverPathMainFrame:IsShown(), "hidden")
        T.eq(ForeverPathDB.frame.shown, false)
    end },

    { "unknown route prints the valid choices", function(T)
        local _, mock = T.fresh()
        SlashCmdList.FOREVERPATH("route nowhere")
        T.contains(mock.printed[#mock.printed], "frontier, classic, dungeon")
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
        T.eq(ForeverPathDB.schema, 1, "schema stamped")
    end },
}
