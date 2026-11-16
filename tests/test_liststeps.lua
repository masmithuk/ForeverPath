-- Steps that aren't quests in a guide's quest list: note, buy, train,
-- set hearth and go to, placed between quests.

local fixtures = require("fixtures")

-- 102 Lazy Peons (Foreman, close by), then "buy bags", then a "go to",
-- then 101 Vile Familiars.
local GUIDE = [[
{
  "name": "Steps Between Quests",
  "basedOn": "story",
  "quests": [
    { "id": 102 },
    { "step": "buy", "text": "Buy bags from the vendor." },
    { "step": "goto", "text": "Walk to the cave mouth.", "zone": "Durotar", "x": 60, "y": 60 },
    { "id": 101 }
  ],
  "bands": [ { "levels": [1, 60], "horde": ["Durotar"], "alliance": ["Elwynn Forest"] } ]
}
]]

local function setup(T, json, before)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    QuestwalkerCharDB.guide.trainedLevel = 60
    if before then before(mock) end
    fixtures.login(ns)
    local guide = assert(ns.GuideFormat.FromJson(json or GUIDE))
    local id = ns.Library.Save(guide)
    ns.MainFrame.SetRoute(id)
    return ns, mock, id
end

local function current(ns) return ns.Engine.state.steps[1] end

local function hasStep(ns, kind)
    for _, s in ipairs(ns.Engine.state.steps) do
        if s.listKind == kind then return s end
    end
end

return {
    ---------------------------------------------------------------------
    -- Format
    ---------------------------------------------------------------------
    { "steps in the quest list survive a JSON round trip", function(T)
        local ns = T.fresh()
        local guide = assert(ns.GuideFormat.FromJson(GUIDE))
        T.eq(guide.quests[2].step, "BUY")
        T.eq(guide.quests[3].zone, "Durotar")
        local again = assert(ns.GuideFormat.FromJson(ns.GuideFormat.ToJson(guide)))
        T.eq(#again.quests, 4)
        T.eq(again.quests[2].text, "Buy bags from the vendor.")
        T.eq(again.quests[3].step, "GOTO")
        T.eq(again.quests[3].x, 60)
        T.contains(ns.GuideFormat.ToJson(guide), '"step": "goto"')
    end },

    { "bad steps are explained", function(T)
        local ns = T.fresh()
        local function errorsOf(entry)
            local json = '{ "name": "X", "basedOn": "story", "quests": [ ' .. entry .. ' ], '
                .. '"bands": [ { "levels": [1, 60], "zones": ["START"] } ] }'
            local _, errors = ns.GuideFormat.FromJson(json)
            local out = {}
            for _, e in ipairs(errors or {}) do out[#out + 1] = ns.GuideFormat.Describe(e) end
            return table.concat(out, "\n")
        end
        T.contains(errorsOf('{ "step": "dance" }'), "must be \"note\", \"buy\"")
        T.contains(errorsOf('{ "step": "goto", "text": "x" }'), "needs \"zone\"")
        T.contains(errorsOf('{ "step": "note" }'), "is needed for a note or buy step")
        T.contains(errorsOf('{ "step": "goto", "zone": "Durotar", "x": 140, "y": 2 }'), "0 to 100")
        T.eq(errorsOf('{ "step": "train" }'), "", "train without text or place is fine")
    end },

    ---------------------------------------------------------------------
    -- In the step guide
    ---------------------------------------------------------------------
    { "a step comes up once the quests before it are dealt with", function(T)
        local ns, mock = setup(T)
        T.truthy(not hasStep(ns, "BUY"), "Lazy Peons is still waiting to be picked up")
        fixtures.addToLog(mock, 102, "Lazy Peons", false)
        ns:FireEvent("QUEST_ACCEPTED", 102)
        ns.Engine.BestStep()
        T.eq(current(ns).title, "Buy bags from the vendor.", "goes first once reached")
        T.truthy(current(ns).manual, "ticked off with Done")
        T.truthy(not hasStep(ns, "GOTO"), "steps come one at a time")
    end },

    { "Done ticks a step off and Back brings it back", function(T)
        local ns = setup(T, nil, function(mock) mock.completed[102] = true end)
        T.eq(current(ns).listKind, "BUY")
        QuestwalkerGuideFrame.done:GetScript("OnClick")()
        T.truthy(not hasStep(ns, "BUY"))
        T.eq(current(ns).listKind, "GOTO", "the next step comes up")
        ns.Engine.Back()
        T.eq(current(ns).listKind, "BUY")
    end },

    { "a go-to step points at its spot and finishes when you get there", function(T)
        local ns, mock = setup(T, nil, function(mock) mock.completed[102] = true end)
        ns.Engine.MarkDone(current(ns).key) -- bags bought
        local step = current(ns)
        T.eq(step.listKind, "GOTO")
        T.eq(step.target.mapID, 1411)
        T.eq(step.lines[1], "Durotar 60.0, 60.0")
        mock.player.position = { mapID = 1411, x = 0.601, y = 0.6 }
        ns.Engine.Replan()
        T.truthy(not hasStep(ns, "GOTO"), "arrived")
        T.contains(ns.Engine.state.steps[1].questIDs, 101, "on to Vile Familiars")
    end },

    { "a train step without a place goes to your class trainer and clears there", function(T)
        local json = GUIDE:gsub('{ "step": "buy", "text": "Buy bags from the vendor." },', '{ "step": "train" },')
        local ns, mock = setup(T, json, function(mock) mock.completed[102] = true end)
        T.eq(current(ns).title, "Train at Mai'ah")
        T.truthy(current(ns).target, "points to the trainer")
        ns:FireEvent("TRAINER_SHOW")
        T.truthy(not hasStep(ns, "TRAIN"))
        T.truthy(mock, "mock")
    end },

    { "a hearth step clears when you set your hearthstone", function(T)
        local json = GUIDE:gsub('"buy", "text": "Buy bags from the vendor."', '"hearth", "text": "Set hearth in Razor Hill."')
        local ns = setup(T, json, function(mock) mock.completed[102] = true end)
        T.eq(current(ns).listKind, "HEARTH")
        ns:FireEvent("HEARTHSTONE_BOUND")
        T.truthy(not hasStep(ns, "HEARTH"))
    end },

    { "moving other entries keeps what you've ticked off", function(T)
        local ns, _, id = setup(T, nil, function(mock) mock.completed[102] = true end)
        ns.Engine.MarkDone(current(ns).key)
        local guide = ns.Library.Draft(id)
        guide.quests[1], guide.quests[4] = guide.quests[4], guide.quests[1]
        ns.Library.Save(guide, id)
        ns.Engine.Replan()
        T.truthy(not hasStep(ns, "BUY"), "still done")
    end },

    ---------------------------------------------------------------------
    -- Steps tab
    ---------------------------------------------------------------------
    { "steps are rows in the Steps list and can be gone to or skipped", function(T)
        local ns = setup(T)
        ns.MainFrame.ShowTab("steps")
        local rows = ns.StepsTab.GetList().rows
        T.truthy(rows[2].isStep)
        T.eq(rows[2].status, "later")
        T.contains(ns.StepsTab.RowText(rows[3]), "<Go to>")
        T.contains(ns.StepsTab.RowText(rows[3]), "Durotar 60.0, 60.0")
        ns.StepsTab.Select(rows[3].key)
        T.truthy(ns.StepsTab.GoTo())
        T.eq(current(ns).listKind, "GOTO", "chosen step is current")
        ns.StepsTab.Select(rows[2].key)
        ns.StepsTab.GetPanel().skip:GetScript("OnClick")()
        T.eq(ns.StepsTab.GetList().rows[2].status, "done")
    end },

    ---------------------------------------------------------------------
    -- Editor
    ---------------------------------------------------------------------
    { "the editor adds, edits and saves steps between quests", function(T)
        local ns, mock = setup(T)
        ns.MainFrame.ShowTab("library")
        ns.LibraryTab.Press("new")
        local E = ns.GuideEditor
        E.SetField("name", "Hand Made Steps")
        E.Search("peon")
        E.AddSelectedResult()

        E.SetStepForm("NOTE", "")
        T.eq(E.AddStep(), false, "a note needs text")
        T.contains(E.GetStatus(), "need some text")

        E.SetStepForm("GOTO", "To the cave")
        T.eq(E.AddStep(), false, "go to needs a place")
        mock.player.position = { mapID = 1411, x = 0.523, y = 0.418 }
        T.truthy(E.UseMyLocation())
        T.truthy(E.AddStep())
        T.contains(E.QuestRows()[2], "<Go to>")
        T.contains(E.QuestRows()[2], "To the cave")
        T.contains(E.QuestRows()[2], "Durotar 52.3, 41.8")

        E.SelectQuest(2)
        T.eq(E.GetStepForm().kind, "GOTO", "selecting a step loads it")
        E.SetStepForm("GOTO", "To the big cave")
        T.truthy(E.UpdateStep())
        T.contains(E.QuestRows()[2], "To the big cave")

        local id = E.Save()
        T.truthy(id)
        local saved = ns.Library.Get(id).quests
        T.eq(saved[1].id, 102)
        T.eq(saved[2].step, "GOTO")
        T.eq(saved[2].x, 52.3)
    end },

    { "Ops.AddStep and UpdateStep only touch steps", function(T)
        local ns = T.fresh()
        local Ops = ns.GuideEditor.Ops
        local list = { { id = 1 }, { id = 2 } }
        T.eq(Ops.AddStep(list, { kind = "NOTE", text = "hi" }, 1), 2)
        T.eq(list[2].step, "NOTE")
        T.eq(Ops.UpdateStep(list, 1, { kind = "BUY", text = "x" }), false, "not a step")
        T.eq(Ops.UpdateStep(list, 2, { kind = "BUY", text = "x" }), true)
        T.eq(list[2].step, "BUY")
    end },
}
