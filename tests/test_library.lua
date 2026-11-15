-- Guide library and the Guides tab / editor workflow.

local fixtures = require("fixtures")

local MINE = [[
guide: My Durotar Run
author: Mike
based on: story
[1-60]
horde: Durotar
alliance: Elwynn Forest
skip quests: 102
priority quests: 103
step 8 buy: Buy a Small Brown Pouch.
]]

local function setup(T)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    ForeverPathCharDB.guide.trainedLevel = 60
    fixtures.login(ns)
    ns.MainFrame.ShowTab("library")
    return ns, mock
end

local function rowsText(ns)
    local out = {}
    for _, r in ipairs(ns.LibraryTab.GetRows()) do
        if r:IsShown() then out[#out + 1] = r.text:GetText() end
    end
    return table.concat(out, "\n")
end

return {
    ---------------------------------------------------------------------
    -- Library
    ---------------------------------------------------------------------
    { "lists the built-in guides first, then yours", function(T)
        local ns = setup(T)
        ns.Library.Save(MINE)
        local list = ns.Library.List()
        T.eq(list[1].id, "story")
        T.eq(list[2].id, "efficient")
        T.eq(list[3].name, "My Durotar Run")
        T.eq(list[3].builtin, false)
    end },

    { "saved guides are stored as text and survive a reload", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        T.truthy(ForeverPathDB.guides[id]:find("My Durotar Run", 1, true))
        T.reload()
        T.truthy(ns.Library.Get(id), "still there")
    end },

    { "built-in guides can't be overwritten", function(T)
        local ns = setup(T)
        local text = ns.Library.Text("story"):gsub("guide: Story %(Completionist%)", "guide: Hacked")
        local id = ns.Library.Save(text, "story")
        T.truthy(id ~= "story", "saved as a new guide")
        T.eq(ns.Library.Get("story").name, "Story (Completionist)")
    end },

    { "names are kept unique", function(T)
        local ns = setup(T)
        local a = ns.Library.Save(MINE)
        local b, _, warnings = ns.Library.Save(MINE)
        T.truthy(a ~= b)
        T.eq(ns.Library.Get(b).name, "My Durotar Run (2)")
        T.contains(warnings[1].message, "already exists")
    end },

    { "copies get their own name and no author", function(T)
        local ns = setup(T)
        local text = ns.Library.CopyText("efficient")
        local g = ns.GuideFormat.Parse(text)
        T.eq(g.name, "Efficient (Speedrun) (copy)")
        T.eq(g.author, nil)
        T.eq(g.rules.maxDetour, 350, "rules copied")
    end },

    { "export then import gives the same guide", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        local exported = ns.Library.Text(id)
        ns.Library.Delete(id)
        local imported = ns.Library.Import(exported)
        T.eq(ns.Library.Text(imported), exported)
    end },

    ---------------------------------------------------------------------
    -- Following a custom guide
    ---------------------------------------------------------------------
    { "a custom guide's zones, skip list, priorities and steps drive the step guide", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        ns.MainFrame.SetRoute(id)
        local state = ns.Engine.state
        local all = {}
        for _, s in ipairs(state.steps) do
            for _, l in ipairs(s.lines) do all[#all + 1] = l end
        end
        local lines = table.concat(all, "|")
        T.truthy(not lines:find("Lazy Peons"), "quest 102 skipped by the guide")
        T.truthy(fixtures.findStep(state, "suggest:guide:" .. id .. ":8:BUY:Buy a Small Brown Pouch."),
            "custom step shown")
        T.eq(ns.Engine.WantsQuest(102), false, "auto-accept respects the skip list")
    end },

    { "priority quests jump the queue", function(T)
        local ns, mock = setup(T)
        mock.completed[101] = true -- unlocks 103 at Zureetha (50 yd away)
        local id = ns.Library.Save(MINE:gsub("skip quests: 102\n", ""))
        ns.MainFrame.SetRoute(id)
        T.eq(ns.Engine.state.steps[1].title, "Talk to Zureetha Fargaze", "priority beats the nearer Foreman")
    end },

    { "deleting the guide you follow falls back to your class default", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        ns.MainFrame.SetRoute(id)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("delete")
        T.truthy(ns.Library.Get(id), "first click only asks")
        ns.LibraryTab.Press("delete")
        T.eq(ns.Library.Get(id), nil, "second click deletes")
        T.eq(ForeverPathCharDB.routeId, nil)
        T.eq(ns.Engine.CurrentGuide().id, "efficient", "Mage default")
    end },

    ---------------------------------------------------------------------
    -- Guides tab and editor
    ---------------------------------------------------------------------
    { "the Guides tab shows guides and which one is in use", function(T)
        local ns = setup(T)
        local rows = rowsText(ns)
        T.contains(rows, "Story (Completionist)")
        T.contains(rows, "built-in")
        T.contains(rows, "> Story (Completionist)", "this test character follows Story")
        T.contains(ns.LibraryTab.GetDetailText(), "Story - every quest")
        T.eq(ns.LibraryTab.GetButton("use"):IsEnabled(), false, "already in use")
        T.eq(ns.LibraryTab.GetButton("delete"):IsEnabled(), false, "built-ins can't be deleted")
    end },

    { "Use this guide switches the character's guide", function(T)
        local ns = setup(T)
        ns.LibraryTab.Select("efficient")
        ns.LibraryTab.Press("use")
        T.eq(ForeverPathCharDB.routeId, "efficient")
        T.contains(ForeverPathMainFrame.guideLabel:GetText(), "Efficient (Speedrun)")
    end },

    { "New guide -> edit -> Save creates and selects it", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        T.eq(ns.GuideEditor.GetMode(), "new")
        ns.GuideEditor.SetText(MINE)
        local id = ns.GuideEditor.Save()
        T.truthy(id)
        T.contains(ns.GuideEditor.GetStatus(), "Saved.")
        T.contains(ns.LibraryTab.GetDetailText(), "My Durotar Run")
        T.eq(ns.GuideEditor.GetMode(), "edit", "later saves update the same guide")
        ns.GuideEditor.SetText(MINE:gsub("author: Mike", "author: Michael"))
        T.eq(ns.GuideEditor.Save(), id)
        T.eq(ns.Library.Get(id).author, "Michael")
    end },

    { "saving a broken guide shows errors and stores nothing", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        ns.GuideEditor.SetText("guide: Broken\n[1-60]\nhordee: Durotar\n")
        T.eq(ns.GuideEditor.Save(), nil)
        T.contains(ns.GuideEditor.GetStatus(), "Line 3")
        T.eq(#ns.Library.List(), 2, "nothing saved")
    end },

    { "Check validates without saving", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        T.eq(ns.GuideEditor.Check(), true)
        T.contains(ns.GuideEditor.GetStatus(), "No problems")
        T.eq(#ns.Library.List(), 2)
    end },

    { "built-in guides open read-only, with Copy & edit", function(T)
        local ns = setup(T)
        ns.LibraryTab.Select("story")
        ns.LibraryTab.Press("edit")
        T.eq(ns.GuideEditor.GetMode(), "view")
        T.eq(ns.GuideEditor.Save(), nil, "can't save a view")
        T.contains(ns.GuideEditor.GetText(), "guide: Story (Completionist)")
    end },

    { "Export shows the guide text, Import adds a pasted guide", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("export")
        T.eq(ns.GuideEditor.GetMode(), "export")
        T.eq(ns.GuideEditor.GetText(), ns.Library.Text(id))
        T.contains(ns.GuideEditor.GetStatus(), "Ctrl+C")

        ns.LibraryTab.Press("import")
        T.eq(ns.GuideEditor.GetText(), "")
        ns.GuideEditor.SetText(MINE:gsub("My Durotar Run", "Shared Route"))
        local imported = ns.GuideEditor.Save()
        T.eq(ns.Library.Get(imported).name, "Shared Route")
        T.contains(ns.GuideEditor.GetStatus(), 'Imported "Shared Route"')
    end },

    { "editing the guide you follow re-plans with the new version", function(T)
        local ns = setup(T)
        local id = ns.Library.Save(MINE)
        ns.MainFrame.SetRoute(id)
        T.truthy(fixtures.findStep(ns.Engine.state, "suggest:guide:" .. id .. ":8:BUY:Buy a Small Brown Pouch."))
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("edit")
        ns.GuideEditor.SetText(MINE:gsub("step 8 buy: Buy a Small Brown Pouch.\n", "step 8 note: Wave hello.\n"))
        ns.GuideEditor.Save()
        T.truthy(fixtures.findStep(ns.Engine.state, "suggest:guide:" .. id .. ":8:NOTE:Wave hello."))
    end },

    { "the editor's message list is capped", function(T)
        local ns = setup(T)
        local errors = {}
        for i = 1, 10 do errors[i] = { line = i, message = "bad" } end
        local text = ns.GuideEditor.FormatMessages(errors, {})
        T.contains(text, "Line 1: bad")
        T.contains(text, "and 4 more")
    end },
}
