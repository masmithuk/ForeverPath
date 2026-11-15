-- Main window: Home, tabs, resizing, Settings layout and dropdowns, the
-- guide window's buttons, and quest overviews.

local fixtures = require("fixtures")

local function login(T, opts)
    local ns, mock = T.fresh()
    if opts and opts.orc then mock.player.race = { "Orc", "Orc", 2 } end
    fixtures.durotar(mock, opts)
    ForeverPathCharDB.guide.trainedLevel = 60
    fixtures.login(ns)
    return ns, mock
end

local function questStatus(overview, id)
    for _, q in ipairs(overview.quests) do
        if q.id == id then return q.status end
    end
    return nil
end

local function tabIds(ns)
    local out = {}
    for i, tab in ipairs(ns.MainFrame.TABS) do out[i] = tab.id end
    return table.concat(out, ",")
end

return {
    ---------------------------------------------------------------------
    -- Home and tabs
    ---------------------------------------------------------------------
    { "the main window has Home, Steps, Guides and Settings", function(T)
        local ns = login(T)
        T.eq(tabIds(ns), "home,steps,library,settings")
        ns.MainFrame.Show()
        T.eq(ForeverPathDB.tab, "home", "opens on Home")
        T.truthy(ns.HomeTab.GetPanel():IsShown())
    end },

    { "Home explains the guide, the current step and every part", function(T)
        local ns = login(T)
        ns.MainFrame.ShowTab("home")
        local text = ns.HomeTab.GetText()
        T.contains(text, "Undead Mage - Level 8 (Horde)")
        T.contains(text, "Following: ")
        T.contains(text, "Test Everything")
        T.contains(text, "Current step: Talk to Foreman Thazz'ril")
        T.contains(text, "Rested XP")
        T.contains(text, "Frost")
        T.contains(text, "What's where")
        for _, part in ipairs({ "Guide window", "Steps", "Guides", "Settings", "Target button", "Minimap button" }) do
            T.contains(text, part .. " - ", part .. " explained")
        end
    end },

    { "Home buttons open the guide window, Steps and Guides", function(T)
        local ns = login(T)
        ns.MainFrame.ShowTab("home")
        local p = ns.HomeTab.GetPanel()
        p.window:GetScript("OnClick")()
        T.eq(ForeverPathDB.guide.shown, false, "guide window toggled off")
        T.eq(p.window:GetText(), "Show guide window")
        p.steps:GetScript("OnClick")()
        T.eq(ForeverPathDB.tab, "steps")
        ns.MainFrame.ShowTab("home")
        p.guides:GetScript("OnClick")()
        T.eq(ForeverPathDB.tab, "library")
    end },

    { "a saved tab from an older version opens Home", function(T)
        local ns = login(T)
        ForeverPathDB.tab = "zones"
        ns.MainFrame.Show()
        T.eq(ForeverPathDB.tab, "home")
    end },

    ---------------------------------------------------------------------
    -- Resizing
    ---------------------------------------------------------------------
    { "the main window is resizable and remembers its size", function(T)
        local ns = login(T)
        ns.MainFrame.Show()
        local f = ForeverPathMainFrame
        T.truthy(f.resizeGrip, "has a resize grip")
        f:SetSize(900, 600)
        f.resizeGrip:GetScript("OnMouseUp")()
        T.eq(ForeverPathDB.frame.width, 900)
        T.eq(ForeverPathDB.frame.height, 600)
        T.eq(ns.MainFrame.ContentWidth(), 900 - 24)
    end },

    { "tabs follow the window width", function(T)
        local ns = login(T, { orc = true })
        ns.MainFrame.ShowTab("steps")
        ForeverPathMainFrame:SetSize(1000, 600)
        local rows = ns.StepsTab.GetVisibleRows()
        T.eq(rows[1]:GetWidth(), 1000 - 24 - 28, "Steps rows are as wide as the window")
        ForeverPathMainFrame:SetSize(600, 600)
        T.eq(rows[1]:GetWidth(), 600 - 24 - 28)
        T.truthy(not ns.StepsTab.GetPanel().hint:IsShown(), "hint hidden when narrow")

        ns.MainFrame.ShowTab("settings")
        ForeverPathMainFrame:SetSize(1000, 600)
        T.eq(ns.SettingsTab.GetPanel().twoColumns, true, "two columns when wide")
        ForeverPathMainFrame:SetSize(600, 600)
        T.eq(ns.SettingsTab.GetPanel().twoColumns, false, "stacked when narrow")
    end },

    { "a saved size outside the limits is clamped", function(T)
        local ns = login(T)
        ForeverPathDB.frame.width, ForeverPathDB.frame.height = 100, 5000
        ns.MainFrame.Show()
        T.eq(ForeverPathMainFrame:GetWidth(), ns.MainFrame.MIN_WIDTH)
        T.eq(ForeverPathMainFrame:GetHeight(), ns.MainFrame.MAX_HEIGHT)
    end },

    { "the guide window's width can be changed and is remembered", function(T)
        login(T)
        local f = ForeverPathGuideFrame
        f:SetSize(480, 200)
        f.resizeGrip:GetScript("OnMouseUp")()
        T.eq(ForeverPathDB.guide.width, 480)
        T.eq(f.current:GetWidth(), 480 - 20 - 26, "text wraps to the new width")
    end },

    ---------------------------------------------------------------------
    -- Guide window
    ---------------------------------------------------------------------
    { "the guide window has Steps, Skip and Done only", function(T)
        login(T)
        local f = ForeverPathGuideFrame
        T.truthy(f.list and f.skip and f.done)
        T.eq(rawget(f, "guides"), nil, "no Zones button")
        T.eq(rawget(f, "best"), nil, "Best step lives on the Steps tab")
        T.contains(f.header:GetText(), "Test Everything", "header names the guide")
    end },

    ---------------------------------------------------------------------
    -- Settings
    ---------------------------------------------------------------------
    { "the waypoint arrow is a dropdown", function(T)
        local ns, mock = login(T)
        mock.installTomTom()
        ns.MainFrame.ShowTab("settings")
        local dd = ns.SettingsTab.GetPanel().waypoints
        T.contains(dd:GetText(), "Automatic")
        dd:GetScript("OnClick")(dd)
        T.truthy(dd.menu:IsShown(), "opens")
        ns.SettingsTab.ChooseWaypoints("tomtom")
        T.truthy(not dd.menu:IsShown(), "closes after a choice")
        T.eq(ForeverPathDB.guide.waypoints, "tomtom")
        T.contains(dd:GetText(), "TomTom")
        T.truthy(#mock.tomtom.waypoints > 0, "TomTom arrow set")
        ns.SettingsTab.ChooseWaypoints("off")
        T.eq(#mock.tomtom.removed, #mock.tomtom.waypoints, "arrow removed")
    end },

    { "the pause key is a dropdown too", function(T)
        local ns = login(T)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.ChoosePauseKey("CTRL")
        T.eq(ForeverPathDB.auto.pauseKey, "CTRL")
        T.contains(ns.SettingsTab.GetPanel().pauseKey:GetText(), "Ctrl")
    end },

    { "settings checkboxes: guide window and minimap button", function(T)
        local ns = login(T)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_GUIDE_SHOWN", false)
        T.truthy(not ForeverPathGuideFrame:IsShown())
        ns.SettingsTab.Click("SETTING_MINIMAP", false)
        T.eq(ForeverPathDB.minimap.hide, true)
        T.truthy(not ForeverPathMinimapButton:IsShown(), "button hidden")
        for _, cb in ipairs(ns.SettingsTab.GetPanel().checkboxes) do
            T.truthy(cb.def.label ~= "SETTING_GUIDE_ENABLED", "no separate on/off switch")
        end
    end },

    ---------------------------------------------------------------------
    -- Quest overviews (used for guides without a quest list)
    ---------------------------------------------------------------------
    { "quest overview shows each quest's status for you", function(T)
        local ns, mock = login(T)
        mock.completed[102] = true
        local overview = ns.Catalog.Overview("Durotar", ns.Engine.BuildContext())
        T.eq(questStatus(overview, 101), "available")
        T.eq(questStatus(overview, 102), "done")
        T.eq(questStatus(overview, 103), "locked", "needs 101")
        T.eq(questStatus(overview, 109), "level")
        T.eq(questStatus(overview, 110), nil, "other faction's quest left out")
        T.eq(questStatus(overview, 105), nil, "other race's quest left out")
        T.eq(overview.done, 1)
    end },

    { "quests in your log show as active or ready", function(T)
        local ns, mock = login(T)
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        fixtures.addToLog(mock, 102, "Lazy Peons", true)
        local overview = ns.Catalog.Overview("Durotar", ns.Engine.BuildContext())
        T.eq(questStatus(overview, 101), "active")
        T.eq(questStatus(overview, 102), "ready")
    end },

    { "the guide editor is resizable and its columns follow", function(T)
        local ns = login(T)
        ns.MainFrame.ShowTab("library")
        ns.LibraryTab.Press("new")
        local f = ForeverPathGuideEditor
        f:SetSize(1100, 700)
        f.resizeGrip:GetScript("OnMouseUp")()
        T.eq(ForeverPathDB.editor.width, 1100)
        T.eq(f.columnWidth, math.floor((1100 - 24 - 20) / 2))
        T.eq(f.questsTab.search:GetWidth(), f.columnWidth - 10)
    end },

    { "without TomTom or Shortest Path the player is told to install one", function(T)
        local ns, mock = login(T)
        T.contains(table.concat(mock.printed, "\n"), "install Shortest Path Forever or TomTom")
        T.contains(ns.GuideFrame.StatusText("ready", "auto"), "install Shortest Path Forever or TomTom")
        ns.MainFrame.ShowTab("home")
        T.contains(ns.HomeTab.GetText(), "No arrow addon found")
        T.eq(mock.userWaypoint ~= nil, true, "a map pin is used meanwhile")
    end },

    { "with TomTom there's no nagging", function(T)
        local ns, mock = T.fresh()
        mock.installTomTom()
        fixtures.durotar(mock)
        fixtures.login(ns)
        T.truthy(not table.concat(mock.printed, "\n"):find("install Shortest Path"))
        T.eq(ns.GuideFrame.StatusText("ready", "auto"), nil)
        T.eq(ns.Waypoints.NeedsArrowAddon("off"), false, "not when arrows are turned off")
    end },

    { "Abandon unrelated quests lists them first, then abandons on a second click", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        local db = fixtures.durotar(mock, { level = 8, mode = "efficient" })
        db.Quest[106].requiredClasses = 128 -- a class quest
        mock.maps[1416] = { name = "Alterac Mountains", areaID = 36, continent = 0, offset = 5000 }
        db.Npc[1006] = { name = "Far Away Giver", friendlyToFaction = "H", spawns = { [36] = { { 50, 50 } } } }
        db.Quest[130] = { name = "Far Errand", startedBy = { { 1006 } }, requiredLevel = 8, questLevel = 9 }
        db.Quest[131] = { name = "Far Chore", startedBy = { { 1006 } }, requiredLevel = 8, questLevel = 10 }
        fixtures.addToLog(mock, 101, "Vile Familiars", false)  -- Durotar: the guide's zone
        fixtures.addToLog(mock, 104, "Barrens Errand", false)  -- The Barrens: the guide's next zone
        fixtures.addToLog(mock, 130, "Far Errand", false)      -- a zone the guide doesn't use
        fixtures.addToLog(mock, 131, "Far Chore", false)
        fixtures.addToLog(mock, 109, "Too High", true)         -- ready to hand in: kept
        fixtures.addToLog(mock, 106, "Paladin Only", false)    -- class quest: kept
        fixtures.addToLog(mock, 999, "Unknown Quest", false)   -- QuestieDB doesn't know it: kept
        fixtures.login(ns)
        ns.MainFrame.ShowTab("settings")
        local button = ns.SettingsTab.GetPanel().abandon

        button:GetScript("OnClick")()
        T.eq(mock.abandoned, nil, "first click only lists")
        T.contains(mock.printed[#mock.printed], "Far Chore, Far Errand")
        for _, kept in ipairs({ "Vile Familiars", "Barrens Errand", "Too High", "Paladin Only", "Unknown" }) do
            T.truthy(not mock.printed[#mock.printed]:find(kept), kept .. " kept")
        end
        T.eq(button:GetText(), "Abandon 2 quests? Click again")

        button:GetScript("OnClick")()
        T.eq(#mock.abandoned, 2)
        T.contains(mock.printed[#mock.printed], "Abandoned 2 quests")
        local left = {}
        for _, q in ipairs(mock.questLog) do left[#left + 1] = q.id end
        T.eq(table.concat(left, ","), "101,104,109,106,999")
        T.eq(button:GetText(), "Abandon unrelated quests")
    end },

    { "leaving Settings cancels a half-done abandon", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 8, mode = "efficient" })
        mock.maps[1416] = { name = "Alterac Mountains", areaID = 36, continent = 0, offset = 5000 }
        db.Npc[1006] = { name = "Far Away Giver", friendlyToFaction = "H", spawns = { [36] = { { 50, 50 } } } }
        db.Quest[130] = { name = "Far Errand", startedBy = { { 1006 } }, requiredLevel = 8, questLevel = 9 }
        fixtures.addToLog(mock, 130, "Far Errand", false)
        fixtures.login(ns)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Abandon()
        ns.MainFrame.ShowTab("home")
        ns.MainFrame.ShowTab("settings")
        T.eq(ns.SettingsTab.GetPanel().abandon:GetText(), "Abandon unrelated quests")
        ns.SettingsTab.Abandon()
        T.eq(mock.abandoned, nil, "starts over with a list, not an abandon")
    end },

    { "nothing to abandon says so", function(T)
        local ns, mock = login(T)
        ns.MainFrame.ShowTab("settings")
        T.eq(ns.SettingsTab.Abandon(), 0)
        T.contains(mock.printed[#mock.printed], "nothing to abandon")
    end },
}
