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
    QuestwalkerCharDB.guide.trainedLevel = 60
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
        T.eq(QuestwalkerDB.tab, "steps")
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
        QuestwalkerGuideFrame.list:GetScript("OnClick")()
        T.eq(QuestwalkerDB.tab, "steps")
    end },

    { "Undo still works when every step has been skipped", function(T)
        local ns = setup(T)
        local guard = 0
        while ns.Engine.state.steps[1] and guard < 50 do ns.Engine.SkipCurrent(); guard = guard + 1 end
        ns.MainFrame.ShowTab("steps")
        T.eq(ns.StepsTab.GetPanel().undo:IsEnabled(), true)
    end },

    ---------------------------------------------------------------------
    -- Best step ("I'm lost")
    ---------------------------------------------------------------------
    { "Best step drops a chosen step and picks the nearest from here", function(T)
        local ns, mock = setup(T)
        local best = ns.Engine.state.steps[1].key
        ns.StepsTab.Select(101)
        ns.StepsTab.GoTo()
        T.truthy(ns.Engine.state.steps[1].key ~= best, "a different step was chosen")
        ns.StepsTab.GetPanel().best:GetScript("OnClick")()
        T.eq(ns.Engine.FocusedQuest(), nil)
        T.eq(ns.Engine.state.steps[1].key, best, "back to the best step")
        T.contains(mock.printed[#mock.printed], "Best step from here")
    end },

    { "Best step keeps skipped quests skipped", function(T)
        local ns = setup(T)
        ns.Engine.SkipCurrent()
        local skipped = QuestwalkerCharDB.guide.skipped
        local n = 0
        for _ in pairs(skipped) do n = n + 1 end
        ns.Engine.BestStep()
        local m = 0
        for _ in pairs(skipped) do m = m + 1 end
        T.eq(m, n)
    end },

    { "Best step is on the Steps tab and as /qw best", function(T)
        local ns, mock = setup(T)
        ns.StepsTab.Select(101)
        ns.StepsTab.GoTo()
        ns.StepsTab.GetPanel().best:GetScript("OnClick")()
        T.eq(ns.Engine.FocusedQuest(), nil)
        ns.StepsTab.Select(101)
        ns.StepsTab.GoTo()
        SlashCmdList.QUESTWALKER("lost")
        T.eq(ns.Engine.FocusedQuest(), nil)
        T.contains(mock.printed[#mock.printed], "Best step from here")
    end },

    { "built-in guides list every zone from 1 to 60", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        local db = fixtures.durotar(mock, { mode = "efficient" })
        mock.maps[1424] = { name = "Hillsbrad Foothills", areaID = 267, continent = 0, offset = 7000 }
        db.Npc[1007] = { name = "Hillsbrad Giver", friendlyToFaction = "H", spawns = { [267] = { { 50, 50 } } } }
        db.Quest[121] = { name = "Hillsbrad Job", startedBy = { { 1007 } }, requiredLevel = 20, questLevel = 25 }
        fixtures.login(ns)
        ns.MainFrame.ShowTab("steps")
        local ids = {}
        for _, r in ipairs(ns.StepsTab.GetList().rows) do ids[r.id] = true end
        T.truthy(ids[101], "Durotar (now)")
        T.truthy(ids[104], "The Barrens (next)")
        T.truthy(ids[121], "Hillsbrad Foothills, levels 21-30")
        T.truthy(not ns.StepsTab.GetPanel().header:GetText():find("this level and the next"))
    end },

    { "a long list only draws the rows in view, and scrolling refills them", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        local db = fixtures.durotar(mock, { mode = "efficient" })
        for id = 5000, 5599 do -- 600 extra Durotar quests
            db.Quest[id] = { name = "Filler " .. id, startedBy = { { 1002 } }, requiredLevel = 1, questLevel = 8 }
        end
        fixtures.login(ns)
        ns.MainFrame.ShowTab("steps")
        local p = ns.StepsTab.GetPanel()
        T.truthy(#ns.StepsTab.GetList().rows > 600)
        T.truthy(#p.rows < 40, "a small pool of row frames, not one per quest")
        p.scroll:SetVerticalScroll(300 * 18)
        local first = ns.StepsTab.GetVisibleRows()[1]
        T.contains(first.text:GetText(), "301. ", "row 301 is at the top after scrolling")
    end },

    { "opening the tab scrolls to where you are", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        local db = fixtures.durotar(mock, { mode = "efficient" })
        for id = 5000, 5199 do
            db.Quest[id] = { name = "Done " .. id, startedBy = { { 1002 } }, requiredLevel = 1, questLevel = 1 }
            mock.completed[id] = true
        end
        fixtures.login(ns)
        ns.MainFrame.ShowTab("steps")
        local p = ns.StepsTab.GetPanel()
        T.truthy(p.scroll:GetVerticalScroll() > 0, "scrolled down past the finished quests")
        local texts = {}
        for _, w in ipairs(ns.StepsTab.GetVisibleRows()) do texts[#texts + 1] = w.text:GetText() end
        T.truthy(not table.concat(texts, "\n"):find("Done 5000", 1, true), "the finished ones are scrolled past")
    end },

}
