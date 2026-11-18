-- Class quests are never skipped or offered for abandoning, and come first.
-- The fixture player is a Mage (class 8, mask 128).

local fixtures = require("fixtures")

local function hasQuest(step, id)
    for _, q in ipairs(step and step.questIDs or {}) do if q == id then return true end end
    return false
end

local function acceptFor(state, id)
    for _, s in ipairs(state.steps) do
        if s.kind == "ACCEPT" and hasQuest(s, id) then return s end
    end
    return nil
end

return {
    { "a grey class quest is still offered, and isn't too low", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 20, mode = "efficient" })
        db.Quest[106].requiredClasses = 128
        local state = fixtures.login(ns)
        T.truthy(acceptFor(state, 106), "level 5 class quest at level 20")
        T.truthy(not acceptFor(state, 102), "an ordinary grey quest isn't")
        T.eq(ns.QuestieData.TooLow(106, 20, { greyGap = 2 }), false)
        T.eq(ns.QuestieData.TooLow(102, 20, { greyGap = 2 }), true)
    end },

    { "class quests in your log are never 'too low' or abandoned", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 20, mode = "efficient" })
        db.Quest[106].requiredClasses = 128
        fixtures.addToLog(mock, 106, "Mage Only", false)
        fixtures.addToLog(mock, 102, "Lazy Peons", false)
        local state = fixtures.login(ns)
        for _, q in ipairs(state.tooLow or {}) do T.truthy(q.id ~= 106, "class quest listed as too low") end
        for _, q in ipairs(ns.Engine.UnrelatedQuests()) do
            T.truthy((q.id or q.questID) ~= 106, "class quest offered for abandoning")
        end
    end },

    { "class quests come first, even further away", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        QuestwalkerCharDB.guide.trainedLevel = 60
        db.Quest[106].requiredClasses = 128
        db.Quest[106].startedBy = { { 1003 } } -- giver in The Barrens
        db.Quest[106].requiredLevel = 8
        local state = fixtures.login(ns)
        T.truthy(hasQuest(state.steps[1], 106), "first step: " .. tostring(state.steps[1] and state.steps[1].title))
    end },

    { "a guide's quest list doesn't hide class quests", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Quest[106].requiredClasses = 128
        QuestwalkerDB.guides["custom-list"] = {
            format = "Questwalker guide", version = 2, name = "Just Peons", basedOn = "efficient",
            quests = { { id = 102 } }, skipQuests = { 106 },
        }
        ns.Library.Init()
        QuestwalkerCharDB.routeId = "custom-list"
        local state = fixtures.login(ns)
        T.truthy(acceptFor(state, 106), "not in the list, and in skipQuests")
    end },

    { "auto accept takes grey class quests", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Quest[106].requiredClasses = 128
        fixtures.login(ns)
        mock.calls = {}
        mock.dialog.gossipAvailable = { { questID = 108, isTrivial = true }, { questID = 106, isTrivial = true } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(table.concat(mock.calls, ","), "SelectAvailableQuest:106")
    end },
}
