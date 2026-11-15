-- Guide library, quest lists in the step guide, and the guide editor.

local fixtures = require("fixtures")

-- A Horde guide for the Durotar fixture with its own quest list.
local MINE = [[
{
  "name": "My Durotar Run",
  "author": "Mike",
  "basedOn": "story",
  "quests": [ { "id": 101, "name": "Vile Familiars" }, { "id": 102 } ],
  "bands": [ { "levels": [1, 60], "alliance": ["Elwynn Forest"], "horde": ["Durotar"] } ],
  "steps": [ { "level": 8, "kind": "buy", "text": "Buy a Small Brown Pouch." } ]
}
]]

local function setup(T)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    ForeverPathCharDB.guide.trainedLevel = 60
    fixtures.login(ns)
    ns.MainFrame.ShowTab("library")
    return ns, mock
end

local function save(ns, json)
    local guide = assert(ns.GuideFormat.FromJson(json or MINE))
    return ns.Library.Save(guide)
end

local function ids(list)
    local out = {}
    for i, q in ipairs(list) do out[i] = q.id end
    return table.concat(out, ",")
end

return {
    ---------------------------------------------------------------------
    -- Library
    ---------------------------------------------------------------------
    { "lists the built-in guides first, then yours", function(T)
        local ns = setup(T)
        save(ns)
        local list = ns.Library.List()
        T.eq(list[1].id, "story")
        T.eq(list[2].id, "efficient")
        T.eq(list[3].name, "My Durotar Run")
    end },

    { "saved guides are stored as data and survive a reload", function(T)
        local ns = setup(T)
        local id = save(ns)
        T.eq(ForeverPathDB.guides[id].name, "My Durotar Run")
        T.eq(ForeverPathDB.guides[id].quests[1].id, 101)
        local reloaded = T.reload()
        T.eq(ids(reloaded.Library.Get(id).quests), "101,102")
    end },

    { "0.6 text guides in saved data are converted on load", function(T)
        T.fresh()
        ForeverPathDB = { schema = 4, guides = {
            ["custom-old"] = "guide: Old\n[1-60]\nboth: Durotar\npriority quests: 101\n",
        } }
        local ns = T.reload()
        T.eq(ns.Library.Get("custom-old").quests[1].id, 101)
        T.eq(type(ForeverPathDB.guides["custom-old"]), "table", "saved back as data")
    end },

    { "built-in guides can't be overwritten", function(T)
        local ns = setup(T)
        local draft = ns.Library.Draft("story")
        draft.name = "Hacked"
        local id = ns.Library.Save(draft, "story")
        T.truthy(id ~= "story")
        T.eq(ns.Library.Get("story").name, "Story (Completionist)")
    end },

    { "names are kept unique", function(T)
        local ns = setup(T)
        local a = save(ns)
        local b, _, warnings = save(ns)
        T.truthy(a ~= b)
        T.eq(ns.Library.Get(b).name, "My Durotar Run (2)")
        T.contains(warnings[1].message, "already exists")
    end },

    { "export then import gives the same guide", function(T)
        local ns = setup(T)
        local id = save(ns)
        local json = ns.Library.Export(id)
        ns.Library.Delete(id)
        local imported = ns.Library.Import(json)
        T.eq(ns.Library.Export(imported), json)
    end },

    { "a built-in guide's quest list is generated from its zones", function(T)
        local ns = setup(T)
        -- The fixture's Undead would start in Tirisfal (no fixture quests),
        -- so use an Orc for a Durotar start.
        _G.UnitRace = function() return "Orc", "Orc", 2 end
        local ctx = ns.Engine.BuildContext()
        local list = ns.Library.QuestList(ns.Library.Get("story"), ctx)
        T.truthy(#list >= 5, "Durotar quests listed")
        T.eq(list[1].name, "Grey Quest", "lowest level first")
    end },

    { "copying a built-in guide fills in an editable quest list", function(T)
        local ns = setup(T)
        _G.UnitRace = function() return "Orc", "Orc", 2 end
        local draft = ns.Library.CopyDraft("story", ns.Engine.BuildContext())
        T.eq(draft.name, "Story (Completionist) (copy)")
        T.truthy(#draft.quests >= 5)
    end },

    ---------------------------------------------------------------------
    -- Following a guide's quest list
    ---------------------------------------------------------------------
    { "the step guide follows the quest list in order", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.MainFrame.SetRoute(id)
        -- 101 (Zureetha, 50 yd) is first in the list, so it beats the
        -- nearer Foreman (20 yd, quest 102, second in the list).
        T.eq(ns.Engine.state.steps[1].title, "Talk to Zureetha Fargaze")
    end },

    { "reordering the list changes what comes first", function(T)
        local ns = setup(T)
        local guide = assert(ns.GuideFormat.FromJson(MINE))
        guide.quests = { { id = 102 }, { id = 101 } }
        local id = ns.Library.Save(guide)
        ns.MainFrame.SetRoute(id)
        T.eq(ns.Engine.state.steps[1].title, "Talk to Foreman Thazz'ril")
    end },

    { "only listed quests are offered while any are available", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.MainFrame.SetRoute(id)
        for _, s in ipairs(ns.Engine.state.steps) do
            if s.kind == "ACCEPT" then
                for _, q in ipairs(s.questIDs) do
                    T.truthy(q == 101 or q == 102, "unlisted quest " .. q .. " offered")
                end
            end
        end
    end },

    { "when the list is used up, the guide's zones take over", function(T)
        local ns, mock = setup(T)
        mock.completed[101], mock.completed[102] = true, true
        local id = save(ns)
        ns.MainFrame.SetRoute(id)
        T.truthy(fixtures.findStep(ns.Engine.state, "accept:npc:1001"), "Zureetha's follow-up from the zone")
    end },

    { "listed quests ignore the guide's level window", function(T)
        local ns = setup(T)
        local id = save(ns, MINE:gsub('{ "id": 102 }', '{ "id": 108 }'))   -- Grey Quest (level 1)
        ns.MainFrame.SetRoute(id)
        T.eq(ns.Engine.WantsQuest(108), true, "auto-accept takes listed quests")
        T.truthy(fixtures.findStep(ns.Engine.state, "accept:npc:1002"), "grey but listed, so offered")
    end },

    { "a guide's own steps and skip list still apply", function(T)
        local ns = setup(T)
        local id = save(ns, MINE:gsub('"steps"', '"skipQuests": [103], "steps"'))
        ns.MainFrame.SetRoute(id)
        T.truthy(fixtures.findStep(ns.Engine.state, "suggest:guide:" .. id .. ":8:BUY:Buy a Small Brown Pouch."))
        T.eq(ns.Engine.WantsQuest(103), false)
    end },

    ---------------------------------------------------------------------
    -- Guides tab
    ---------------------------------------------------------------------
    { "the Guides tab shows guides and which one is in use", function(T)
        local ns = setup(T)
        local rows = {}
        for _, r in ipairs(ns.LibraryTab.GetRows()) do
            if r:IsShown() then rows[#rows + 1] = r.text:GetText() end
        end
        local text = table.concat(rows, "\n")
        T.contains(text, "> Story (Completionist)")
        T.contains(text, "built-in")
        T.eq(ns.LibraryTab.GetButton("delete"):IsEnabled(), false, "built-ins can't be deleted")
    end },

    { "deleting the guide you follow falls back to your class default", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.MainFrame.SetRoute(id)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("delete")
        T.truthy(ns.Library.Get(id), "first click only asks")
        ns.LibraryTab.Press("delete")
        T.eq(ns.Library.Get(id), nil, "second click deletes")
        T.eq(ns.Engine.CurrentGuide().id, "efficient", "Mage default")
    end },

    ---------------------------------------------------------------------
    -- Editor: quests tab
    ---------------------------------------------------------------------
    { "editor list operations: move, remove, add", function(T)
        local ns = setup(T)
        local Ops = ns.GuideEditor.Ops
        local list = { { id = 1 }, { id = 2 }, { id = 3 } }
        T.eq(Ops.Move(list, 3, 1), 1)
        T.eq(ids(list), "3,1,2")
        T.eq(Ops.Move(list, 1, 99), 3, "clamped to the end")
        T.eq(ids(list), "1,2,3")
        T.eq(Ops.Remove(list, 3), 2)
        T.eq(ids(list), "1,2")
        local at, added = Ops.Add(list, { id = 9 }, 1)
        T.eq(at, 2)
        T.eq(added, true)
        T.eq(ids(list), "1,9,2")
        local _, again = Ops.Add(list, { id = 9 })
        T.eq(again, false, "no duplicates")
    end },

    { "search finds quests by part of the name or by ID", function(T)
        local ns = setup(T)
        local results = ns.QuestieData.Search("famil")
        T.eq(results[1].name, "Vile Familiars")
        T.eq(results[1].level, 5)
        results = ns.QuestieData.Search("Q")
        T.eq(results[1].name, "Grey Quest", "names starting with the text come first")
        results = ns.QuestieData.Search("103")
        T.eq(results[1].name, "Burning Blade Medallion")
        T.eq(#ns.QuestieData.Search("zzzz"), 0)
    end },

    { "build a guide in the editor: search, add, reorder, save", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        local E = ns.GuideEditor
        T.eq(E.GetMode(), "new")
        E.SetField("name", "Built By Hand")

        E.Search("peon")
        T.contains(E.ResultRows()[1], "Lazy Peons")
        E.AddSelectedResult()
        E.Search("familiar")
        E.AddSelectedResult()
        T.eq(ids(E.GetState().draft.quests), "102,101", "added after the selected quest")
        T.contains(E.QuestRows()[2], "2. [5] Vile Familiars")

        E.SelectQuest(2)
        E.PressMove(1) -- Top
        T.eq(ids(E.GetState().draft.quests), "101,102")
        T.contains(E.ResultRows()[1], "(in guide)")

        local id = E.Save()
        T.truthy(id)
        T.eq(ids(ns.Library.Get(id).quests), "101,102")
        T.eq(ns.Library.Get(id).name, "Built By Hand")
        T.contains(E.GetStatus(), "Saved.")
    end },

    { "removing quests and moving down", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("edit")
        local E = ns.GuideEditor
        E.SelectQuest(1)
        E.PressMove(3) -- Down
        T.eq(ids(E.GetState().draft.quests), "102,101")
        E.PressMove(5) -- Remove
        T.eq(ids(E.GetState().draft.quests), "102")
        E.Save()
        T.eq(ids(ns.Library.Get(id).quests), "102")
    end },

    { "quest IDs can be added without QuestieDB", function(T)
        local ns = setup(T)
        _G.LibQuestieDB = nil
        ns.LibraryTab.Press("new")
        ns.GuideEditor.Search("4242")
        ns.GuideEditor.AddSelectedResult()
        T.eq(ns.GuideEditor.GetState().draft.quests[1].id, 4242)
    end },

    { "built-in guides open read-only with their generated quest list", function(T)
        local ns = setup(T)
        _G.UnitRace = function() return "Orc", "Orc", 2 end
        ns.LibraryTab.Select("story")
        ns.LibraryTab.Press("edit")
        local E = ns.GuideEditor
        T.eq(E.GetMode(), "view")
        T.truthy(#E.QuestRows() >= 5, "shows the quests it would pick")
        E.SelectQuest(1)
        E.PressMove(5) -- Remove does nothing in a view
        T.truthy(#E.QuestRows() >= 5)
        T.eq(E.Save(), nil, "can't save a view")
    end },

    ---------------------------------------------------------------------
    -- Editor: JSON, export and import
    ---------------------------------------------------------------------
    { "edits in the JSON tab carry over to the quest list", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("edit")
        local E = ns.GuideEditor
        E.ShowTab("json")
        T.contains(E.GetJson(), '"id": 101')
        E.SetJson(E.GetJson():gsub('"id": 101', '"id": 103'))
        E.ShowTab("quests")
        T.eq(ids(E.GetState().draft.quests), "103,102")
    end },

    { "broken JSON keeps you on the JSON tab with the problem shown", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        local E = ns.GuideEditor
        E.ShowTab("json")
        E.SetJson('{ "name": "X", ')
        E.ShowTab("quests")
        T.eq(E.GetState().tab, "json")
        T.contains(E.GetStatus(), "Line 1")
    end },

    { "saving an invalid guide shows errors and stores nothing", function(T)
        local ns = setup(T)
        ns.LibraryTab.Press("new")
        ns.GuideEditor.SetField("name", "")
        T.eq(ns.GuideEditor.Save(), nil)
        T.contains(ns.GuideEditor.GetStatus(), "name is required")
        T.eq(#ns.Library.List(), 2)
    end },

    { "Export shows the JSON, Import adds a pasted guide", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("export")
        local E = ns.GuideEditor
        T.eq(E.GetMode(), "export")
        T.eq(E.GetJson(), ns.Library.Export(id))
        T.contains(E.GetStatus(), "Ctrl+C")

        ns.LibraryTab.Press("import")
        T.eq(E.GetJson(), "")
        E.SetJson((MINE:gsub("My Durotar Run", "Shared Route")))
        local imported = E.Save()
        T.eq(ns.Library.Get(imported).name, "Shared Route")
        T.contains(E.GetStatus(), 'Imported "Shared Route"')
    end },

    { "editing the guide you follow re-plans with the new version", function(T)
        local ns = setup(T)
        local id = save(ns)
        ns.MainFrame.SetRoute(id)
        T.eq(ns.Engine.state.steps[1].title, "Talk to Zureetha Fargaze")
        ns.LibraryTab.Select(id)
        ns.LibraryTab.Press("edit")
        ns.GuideEditor.SelectQuest(2)
        ns.GuideEditor.PressMove(1) -- 102 to the top
        ns.GuideEditor.Save()
        T.eq(ns.Engine.state.steps[1].title, "Talk to Foreman Thazz'ril")
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
