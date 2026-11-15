-- Going back after skipping steps (or ticking off reminders) by mistake.

local fixtures = require("fixtures")

local function setup(T)
    local ns, mock = T.fresh()
    fixtures.durotar(mock)
    ForeverPathCharDB.guide.trainedLevel = 60 -- keep training out of the way
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
        T.eq(ForeverPathCharDB.guide.skipped[102], nil)
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

    { "Back also undoes a reminder ticked off by mistake", function(T)
        local ns = setup(T)
        local function hasBags()
            return fixtures.findStep(ns.Engine.state, "suggest:bags-1") ~= nil
        end
        T.truthy(hasBags())
        ns.Engine.MarkDone("suggest:bags-1")
        T.truthy(not hasBags(), "ticked off")
        ns.Engine.Back()
        T.truthy(hasBags(), "back again")
    end },

    { "undoing a skipped training step restores the training level", function(T)
        local ns = setup(T)
        ForeverPathCharDB.guide.trainedLevel = 6
        ns.Engine.Replan()
        T.truthy(fixtures.findStep(ns.Engine.state, "train:8"), "training due")
        -- Skip until the training step is current, then skip it.
        while first(ns) ~= "Train at Mai'ah" do ns.Engine.SkipCurrent() end
        ns.Engine.SkipCurrent()
        T.eq(ForeverPathCharDB.guide.trainedLevel, 8)
        ns.Engine.Back()
        T.eq(ForeverPathCharDB.guide.trainedLevel, 6)
        T.eq(first(ns), "Train at Mai'ah")
    end },

    { "a quest that was already skipped isn't un-skipped by an unrelated Back", function(T)
        local ns = setup(T)
        ForeverPathCharDB.guide.skipped[107] = true -- skipped long ago
        ns.Engine.SkipCurrent()                     -- the Foreman (102)
        ns.Engine.Back()
        T.eq(ForeverPathCharDB.guide.skipped[107], true)
    end },

    { "history survives a reload and is capped", function(T)
        local ns = setup(T)
        ns.Engine.SkipCurrent()
        local reloaded = T.reload()
        T.eq(reloaded.Engine.LastSkipped().title, "Talk to Foreman Thazz'ril")
        for i = 1, 60 do
            ForeverPathCharDB.guide.history[#ForeverPathCharDB.guide.history + 1] =
                { action = "skip", key = "x" .. i, title = "x", questIDs = {} }
        end
        fixtures.login(reloaded)
        reloaded.Engine.SkipCurrent()
        T.eq(#ForeverPathCharDB.guide.history, 50)
    end },

    { "the Back button is enabled only when there's something to undo", function(T)
        local ns = setup(T)
        local back = ForeverPathGuideFrame.back
        T.eq(back:IsEnabled(), false)
        ForeverPathGuideFrame.skip:GetScript("OnClick")()
        T.eq(back:IsEnabled(), true)
        back:GetScript("OnClick")()
        T.eq(first(ns), "Talk to Foreman Thazz'ril")
        T.eq(back:IsEnabled(), false)
    end },

    { "Back still shows when every step has been skipped", function(T)
        local ns = setup(T)
        while first(ns) do ns.Engine.SkipCurrent() end
        T.truthy(ForeverPathGuideFrame.back:IsShown())
        T.eq(ForeverPathGuideFrame.back:IsEnabled(), true)
    end },

    { "/fp back works too", function(T)
        local ns, mock = setup(T)
        ns.Engine.SkipCurrent()
        SlashCmdList.FOREVERPATH("back")
        T.contains(mock.printed[#mock.printed], "Back to: Talk to Foreman Thazz'ril")
    end },
}
