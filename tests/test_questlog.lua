-- Reading the quest log carefully, and hand-ins without quest data.

local fixtures = require("fixtures")

local function stepFor(state, kind, id)
    for _, s in ipairs(state.steps) do
        if s.kind == kind then
            for _, q in ipairs(s.questIDs or {}) do if q == id then return s end end
        end
    end
    return nil
end

return {
    { "a 0 from the game doesn't count as ready to hand in", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 101, "Boar Hunt", false, { "Boar killed: 0/8" })
        _G.C_QuestLog.ReadyForTurnIn = function() return 0 end
        T.eq(ns.GameApi.GetQuestLog()[101].complete, false)
        _G.C_QuestLog.ReadyForTurnIn = function() return 1 end
        T.eq(ns.GameApi.GetQuestLog()[101].complete, false, "an objective is still open")
    end },

    { "an open objective means it isn't ready, whatever the game says", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 101, "Boar Hunt", true, { { text = "Boar killed: 3/8", finished = false } })
        local state = fixtures.login(ns)
        T.eq(stepFor(state, "TURNIN", 101), nil)
        T.truthy(stepFor(state, "OBJECTIVE", 101) or stepFor(state, "KILL", 101) or #state.steps > 0)
    end },

    { "without Questie, a hand-in uses the game's quest marker and says what to do", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        _G.LibQuestieDB = nil
        fixtures.addToLog(mock, 101, "Elmore's Task", true)
        mock.questWaypoints[101] = { mapID = 1411, x = 0.42, y = 0.66 }
        local state = fixtures.login(ns)
        local step = stepFor(state, "TURNIN", 101)
        T.truthy(step, "turn-in step")
        T.eq(step.title, "Turn in Elmore's Task")
        T.truthy(step.target and step.target.x == 0.42, "the game's marker")
        T.eq(step.lines[1], ns.L.STEP_TURNIN_UNKNOWN)
    end },
}
