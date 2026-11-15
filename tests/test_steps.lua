-- The Steps tab: where you are in the guide, what's done, skipped and
-- missed, and picking any step to go to.

local fixtures = require("fixtures")

-- Quests in guide order: 102 Lazy Peons, 108 Grey Quest, 101 Vile Familiars,
-- 103 Burning Blade Medallion (needs 101), 104 Barrens Errand (level 10).
local GUIDE = [[
{
  "name": "Durotar Steps",
  "basedOn": "story",
  "quests": [ { "id": 102 }, { "id": 108 }, { "id": 101 }, { "id": 103 }, { "id": 104 } ],
  "bands": [ { "levels": [1, 60], "alliance": ["Elwynn Forest"], "horde": ["Durotar"] } ]
}
]]

local function setup(T, before)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    ForeverPathCharDB.guide.trainedLevel = 60
    if before then before(mock) end
    fixtures.login(ns)
    local id = ns.Library.Save(assert(ns.GuideFormat.FromJson(GUIDE)))
    ns.MainFrame.SetRoute(id)
    ns.MainFrame.ShowTab("steps")
    return ns, mock
end

local function statuses(ns)
    local out = {}
    for _, r in ipairs(ns.StepsTab.GetList().rows) do out[#out + 1] = r.id .. "=" .. r.status end
    return table.concat(out, " ")
end

local function row(ns, id)
    for _, r in ipairs(ns.StepsTab.GetList().rows) do
        if r.id == id then return r end
    end
end

return {
    { "Steps is the first tab", function(T)
        local ns = setup(T)
        T.eq(ForeverPathDB.tab, "steps")
        T.truthy(ns.StepsTab.GetPanel():IsShown())
    end },

    { "every quest is listed in guide order with its status", function(T)
        local ns = setup(T, function(mock)
            mock.completed[102] = true
            fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        end)
        T.eq(statuses(ns), "102=done 108=missed 101=active 103=locked 104=level")
    end },

    { "where you are and the counts are shown at the top", function(T)
        local ns = setup(T, function(mock)
            mock.completed[102] = true
            fixtures.addToLog(mock, 101, "Vile Familiars", false)
        end)
        local list = ns.StepsTab.GetList()
        T.eq(list.position, 3)
        T.eq(list.done, 1)
        T.eq(list.missed, 1)
        local header = ns.StepsTab.GetPanel().header:GetText()
        T.contains(header, "quest 3 of 5")
        T.contains(header, "1 done")
        T.contains(header, "1 missed")
    end },

    { "the current step is marked in the list", function(T)
        local ns = setup(T)
        local current = row(ns, ns.Engine.state.steps[1].questIDs[1])
        T.truthy(current.isCurrent)
        T.contains(ns.StepsTab.RowText(current), "> ")
    end },

    { "Go to this step makes a missed quest the current step", function(T)
        local ns = setup(T, function(mock)
            mock.completed[102] = true
            fixtures.addToLog(mock, 101, "Vile Familiars", false)
        end)
        ns.StepsTab.Select(108)
        T.truthy(ns.StepsTab.GoTo())
        T.contains(ns.Engine.state.steps[1].questIDs, 108)
        T.eq(ns.Engine.FocusedQuest(), 108)
    end },

    { "the chosen step stays current until it's done", function(T)
        local ns, mock = setup(T)
        ns.StepsTab.Select(101)
        ns.StepsTab.GoTo()
        mock.player.position = { mapID = 1411, x = 0.5, y = 0.53 } -- right next to the Foreman
        ns.Engine.Replan()
        T.contains(ns.Engine.state.steps[1].questIDs, 101, "still Vile Familiars")
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        mock.completed[101] = true
        fixtures.removeFromLog(mock, 101)
        ns:FireEvent("QUEST_TURNED_IN", 101)
        T.eq(ns.Engine.FocusedQuest(), nil, "focus cleared once done")
    end },

    { "a quest you can't do yet says why", function(T)
        local ns, mock = setup(T)
        ns.StepsTab.Select(104)
        T.eq(ns.StepsTab.GoTo(), false)
        T.contains(mock.printed[#mock.printed], "level 10")
        ns.StepsTab.Select(103)
        T.eq(ns.StepsTab.GoTo(), false)
        T.contains(mock.printed[#mock.printed], "earlier quest")
    end },

    { "Skip, Unskip and Undo last skip", function(T)
        local ns = setup(T)
        local panel = ns.StepsTab.GetPanel()
        T.eq(panel.undo:IsEnabled(), false, "nothing to undo yet")
        ns.StepsTab.Select(108)
        panel.skip:GetScript("OnClick")()
        T.eq(row(ns, 108).status, "skipped")
        T.eq(panel.skip:GetText(), "Unskip")
        T.eq(panel.undo:IsEnabled(), true)
        panel.skip:GetScript("OnClick")()
        T.truthy(row(ns, 108).status ~= "skipped", "unskipped")
        ns.StepsTab.Select(102)
        panel.skip:GetScript("OnClick")()
        panel.undo:GetScript("OnClick")()
        T.truthy(row(ns, 102).status ~= "skipped", "undone")
    end },

    { "filters: to do, skipped & missed, done", function(T)
        local ns = setup(T, function(mock)
            mock.completed[102] = true
            fixtures.addToLog(mock, 101, "Vile Familiars", false)
        end)
        ns.StepsTab.SetFilter("done")
        T.eq(#ns.StepsTab.GetVisibleRows(), 1)
        ns.StepsTab.SetFilter("missed")
        T.eq(#ns.StepsTab.GetVisibleRows(), 1, "Grey Quest was passed by")
        ns.StepsTab.SetFilter("todo")
        T.eq(#ns.StepsTab.GetVisibleRows(), 4)
        ns.StepsTab.SetFilter("all")
        T.eq(#ns.StepsTab.GetVisibleRows(), 5)
    end },

    { "the guide window's Steps button opens the list", function(T)
        local ns = setup(T)
        ns.MainFrame.ShowTab("library")
        ForeverPathGuideFrame.list:GetScript("OnClick")()
        T.eq(ForeverPathDB.tab, "steps")
    end },

    { "Undo still works when every step has been skipped", function(T)
        local ns = setup(T)
        local guard = 0
        while ns.Engine.state.steps[1] and guard < 50 do ns.Engine.SkipCurrent(); guard = guard + 1 end
        ns.MainFrame.ShowTab("steps")
        T.eq(ns.StepsTab.GetPanel().undo:IsEnabled(), true)
    end },
}
