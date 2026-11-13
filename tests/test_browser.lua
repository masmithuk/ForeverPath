-- Guide browser (Guides tab), following a guide, and the Settings tab.

local fixtures = require("fixtures")

-- An Orc Mage in Durotar on the Classic route: Durotar is the 1-10 guide
-- and The Barrens the 11-20 guide.
local function orc(T, level)
    local ns, mock = T.fresh()
    mock.player.race = { "Orc", "Orc", 2 }
    fixtures.durotar(mock, { level = level or 8 })
    ForeverPathCharDB.routeId = "classic"
    fixtures.login(ns)
    return ns, mock
end

local function guideNames(list)
    local out = {}
    for i, g in ipairs(list) do out[i] = g.name end
    return out
end

local function questStatus(overview, id)
    for _, q in ipairs(overview.quests) do
        if q.id == id then return q.status end
    end
    return nil
end

return {
    { "lists every zone guide on the route in level order", function(T)
        local ns = orc(T)
        local guides = ns.Catalog.List(ns.Character.Detect(), "classic")
        local names = guideNames(guides)
        T.eq(names[1], "Durotar", "racial start zone first")
        T.contains(names, "The Barrens")
        T.contains(names, "Mount Hyjal")
        T.eq(guides[1].recommended, true, "level 8 fits 1-10")
        for i = 2, #guides do
            T.truthy(guides[i].min >= guides[i - 1].min, "sorted by level")
        end
    end },

    { "a zone that appears in several bands is one guide spanning them", function(T)
        local ns = orc(T)
        local stv
        for _, g in ipairs(ns.Catalog.List(ns.Character.Detect(), "frontier")) do
            if g.name == "Stranglethorn Vale" then stv = g end
        end
        T.eq(stv.min, 31)
        T.eq(stv.max, 45)
    end },

    { "quest overview shows each quest's status for you", function(T)
        local ns, mock = orc(T)
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
        local ns, mock = orc(T)
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        fixtures.addToLog(mock, 102, "Lazy Peons", true)
        local overview = ns.Catalog.Overview("Durotar", ns.Engine.BuildContext())
        T.eq(questStatus(overview, 101), "active")
        T.eq(questStatus(overview, 102), "ready")
    end },

    { "the Guides tab lists guides and shows the selected guide's quests", function(T)
        local ns = orc(T)
        ns.MainFrame.ShowTab("guides")
        local rows = ns.GuidesTab.GetRows()
        T.truthy(#rows >= 10, "a row per guide")
        T.contains(rows[1].text:GetText(), "Durotar")
        local detail = ns.GuidesTab.GetDetailText()
        T.contains(detail, "Vile Familiars")
        T.contains(detail, "Requirements not met yet")
        T.contains(detail, "Level 30")
    end },

    { "following a guide limits new quests to that zone", function(T)
        local ns = orc(T, 11)
        ns.MainFrame.ShowTab("guides")
        ns.GuidesTab.Select("The Barrens")
        ns.Engine.SetGuide("The Barrens")
        T.eq(ForeverPathCharDB.guideId, "The Barrens")

        local state = ns.Engine.state
        -- Training (due at 10, trainer next door) still comes first.
        T.eq(state.steps[1].title, "Train at Mai'ah")
        T.truthy(fixtures.findStep(state, "accept:npc:1003"), "Barrens quest giver")
        for _, s in ipairs(state.steps) do
            T.truthy(s.kind ~= "ACCEPT" or s.target.mapID == 1413, "only Barrens givers")
        end
        T.contains(ns.GuideFrame.HeaderText(), "The Barrens")
        T.contains(ns.GuidesTab.FollowingText(), "The Barrens")

        ns.Engine.SetGuide(nil)
        T.contains(ns.GuideFrame.HeaderText(), "Automatic")
    end },

    { "settings checkboxes turn the guide and minimap button on and off", function(T)
        local ns, mock = orc(T)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_GUIDE_ENABLED", false)
        T.eq(ForeverPathDB.guide.enabled, false)
        T.eq(#ns.Engine.state.steps, 0)
        T.eq(mock.userWaypoint, nil, "waypoint cleared")

        ns.SettingsTab.Click("SETTING_MINIMAP", false)
        T.eq(ForeverPathDB.minimap.hide, true)
        T.truthy(not ForeverPathMinimapButton:IsShown(), "button hidden")
    end },

    { "settings waypoint buttons switch the arrow", function(T)
        local ns, mock = orc(T)
        mock.installTomTom()
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.ChooseWaypoints("tomtom")
        T.eq(ForeverPathDB.guide.waypoints, "tomtom")
        T.truthy(#mock.tomtom.waypoints > 0, "TomTom arrow set")
        ns.SettingsTab.ChooseWaypoints("off")
        T.eq(#mock.tomtom.removed, #mock.tomtom.waypoints, "arrow removed")
    end },

    { "browser text helpers", function(T)
        local ns = orc(T)
        local row = ns.GuidesTab.RowText({ name = "Durotar", min = 1, max = 10, active = true },
            { total = 12, done = 3 })
        T.contains(row, "> ")
        T.contains(row, "3/12")
        T.contains(ns.GuidesTab.DetailText({ name = "X", min = 1, max = 2 },
            { dataStatus = "missing", quests = {}, total = 0, done = 0 }), "Install Questie")
    end },
}
