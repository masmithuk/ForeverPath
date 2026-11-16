-- Going back after skipping steps (or ticking off a step) by mistake.

local fixtures = require("fixtures")

local function setup(T)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    QuestwalkerCharDB.guide.trainedLevel = 60 -- keep training out of the way
    fixtures.login(ns)
    return ns, mock
end

local function first(ns) return ns.Engine.state.steps[1] and ns.Engine.state.steps[1].title end

return {
    { "Back undoes a skip and makes that step current again", function(T)
        local ns = setup(T)
        T.eq(first(ns), "Talk to Foreman Thazz'ril")
        ns.Engine.SkipCurrent()
        T.eq(first(ns), "Talk to Zureetha Fargaze")
        local entry = ns.Engine.Back()
        T.eq(entry.title, "Talk to Foreman Thazz'ril")
        T.eq(first(ns), "Talk to Foreman Thazz'ril", "restored as the current step")
        T.eq(QuestwalkerCharDB.guide.skipped[102], nil)
    end },

    { "pressing Back repeatedly walks back through several skips", function(T)
        local ns = setup(T)
        ns.Engine.SkipCurrent() -- Foreman
        ns.Engine.SkipCurrent() -- Zureetha
        T.eq(ns.Engine.Back().title, "Talk to Zureetha Fargaze")
        T.eq(first(ns), "Talk to Zureetha Fargaze", "current step is the one brought back")
        T.eq(ns.Engine.Back().title, "Talk to Foreman Thazz'ril")
        T.eq(first(ns), "Talk to Foreman Thazz'ril")
        T.eq(ns.Engine.Back(), nil, "nothing left to undo")
    end },

    { "undoing a skipped training step restores the training level", function(T)
        local ns = setup(T)
        QuestwalkerCharDB.guide.trainedLevel = 6
        ns.Engine.Replan()
        T.truthy(fixtures.findStep(ns.Engine.state, "train:8"), "training due")
        -- Skip until the training step is current, then skip it.
        while first(ns) ~= "Train at Mai'ah" do ns.Engine.SkipCurrent() end
        ns.Engine.SkipCurrent()
        T.eq(QuestwalkerCharDB.guide.trainedLevel, 8)
        ns.Engine.Back()
        T.eq(QuestwalkerCharDB.guide.trainedLevel, 6)
        T.eq(first(ns), "Train at Mai'ah")
    end },

    { "a quest that was already skipped isn't un-skipped by an unrelated Back", function(T)
        local ns = setup(T)
        QuestwalkerCharDB.guide.skipped[107] = true -- skipped long ago
        ns.Engine.SkipCurrent()                     -- the Foreman (102)
        ns.Engine.Back()
        T.eq(QuestwalkerCharDB.guide.skipped[107], true)
    end },

    { "history survives a reload and is capped", function(T)
        local ns = setup(T)
        ns.Engine.SkipCurrent()
        local reloaded = T.reload()
        T.eq(reloaded.Engine.LastSkipped().title, "Talk to Foreman Thazz'ril")
        for i = 1, 60 do
            QuestwalkerCharDB.guide.history[#QuestwalkerCharDB.guide.history + 1] =
                { action = "skip", key = "x" .. i, title = "x", questIDs = {} }
        end
        fixtures.login(reloaded)
        reloaded.Engine.SkipCurrent()
        T.eq(#QuestwalkerCharDB.guide.history, 50)
    end },

    { "/qw back works too", function(T)
        local ns, mock = setup(T)
        ns.Engine.SkipCurrent()
        SlashCmdList.QUESTWALKER("back")
        T.contains(mock.printed[#mock.printed], "Back to: Talk to Foreman Thazz'ril")
    end },
}
