-- Auto accept and auto turn-in.

local fixtures = require("fixtures")

local function setup(T, mode, level)
    local ns, mock = T.fresh()
    fixtures.durotar(mock, { level = level or 8, mode = mode })
    fixtures.login(ns)
    mock.calls = {}
    return ns, mock
end

local function calls(mock) return table.concat(mock.calls, ",") end

--- Simulate the conversation ending (all quest windows closed).
local function endConversation(ns)
    ns:FireEvent("GOSSIP_CLOSED")
end

return {
    ---------------------------------------------------------------------
    -- Picking from the NPC's list
    ---------------------------------------------------------------------
    { "hands in a finished quest before accepting new ones", function(T)
        local ns, mock = setup(T)
        mock.dialog.gossipActive = { { questID = 101, isComplete = true } }
        mock.dialog.gossipAvailable = { { questID = 103 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectActiveQuest:101")
    end },

    { "ignores quests that aren't finished yet", function(T)
        local ns, mock = setup(T)
        mock.dialog.gossipActive = { { questID = 101, isComplete = false } }
        mock.dialog.gossipAvailable = { { questID = 102 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:102")
    end },

    { "skips grey, repeatable and skipped-in-the-guide quests", function(T)
        local ns, mock = setup(T)
        ForeverPathCharDB.guide.skipped[103] = true
        mock.dialog.gossipAvailable = {
            { questID = 108, isTrivial = true },
            { questID = 107, repeatable = true },
            { questID = 103 },
            { questID = 102 },
        }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:102")
    end },

    { "Efficient mode won't accept quests it would skip", function(T)
        local ns, mock = setup(T, "efficient", 6)
        -- 108 is level 1: outside Efficient's 2-levels-below window, even if
        -- the client doesn't flag it grey.
        mock.dialog.gossipAvailable = { { questID = 108 }, { questID = 101 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:101")
    end },

    { "quests QuestieDB doesn't know yet are accepted", function(T)
        local ns, mock = setup(T, "efficient", 6)
        mock.dialog.gossipAvailable = { { questID = 99999 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:99999")
    end },

    { "each quest is tried once per conversation (full quest log)", function(T)
        local ns, mock = setup(T)
        mock.dialog.gossipAvailable = { { questID = 102 } }
        ns:FireEvent("GOSSIP_SHOW")
        ns:FireEvent("GOSSIP_SHOW") -- accept failed, list shown again
        T.eq(calls(mock), "SelectAvailableQuest:102")
        endConversation(ns)
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(#mock.calls, 2, "tried again in a new conversation")
    end },

    { "the older greeting window works too", function(T)
        local ns, mock = setup(T)
        mock.dialog.greetingActive = { { title = "Vile Familiars", questID = 101, isComplete = true } }
        ns:FireEvent("QUEST_GREETING")
        T.eq(calls(mock), "SelectActiveQuest#:1")
        mock.calls = {}
        mock.dialog.greetingActive = {}
        mock.dialog.greetingAvailable = { { questID = 108, isTrivial = true }, { questID = 102 } }
        ns:FireEvent("QUEST_GREETING")
        T.eq(calls(mock), "SelectAvailableQuest#:2")
    end },

    ---------------------------------------------------------------------
    -- The quest dialog
    ---------------------------------------------------------------------
    { "accepts the quest text", function(T)
        local ns, mock = setup(T)
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "AcceptQuest")
    end },

    { "an NPC with one quest opening its text directly is still filtered", function(T)
        local ns, mock = setup(T)
        ForeverPathCharDB.guide.skipped[102] = true
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "", "skipped in the guide")
    end },

    { "quests shared by players are left alone", function(T)
        local ns, mock = setup(T)
        mock.dialog.questID = 102
        mock.dialog.sharedByPlayer = true
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "")
    end },

    { "server auto-accepted quests are just acknowledged", function(T)
        local ns, mock = setup(T)
        mock.dialog.questID = 102
        mock.dialog.autoAccepted = true
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "AcknowledgeAutoAcceptQuest")
    end },

    { "continues when you have everything, waits when you don't", function(T)
        local ns, mock = setup(T)
        ns:FireEvent("QUEST_PROGRESS")
        T.eq(calls(mock), "CompleteQuest")
        mock.calls = {}
        mock.dialog.completable = false
        ns:FireEvent("QUEST_PROGRESS")
        T.eq(calls(mock), "")
    end },

    { "takes the reward when there's nothing to choose", function(T)
        local ns, mock = setup(T)
        mock.dialog.choices = 0
        ns:FireEvent("QUEST_COMPLETE")
        mock.dialog.choices = 1
        ns:FireEvent("QUEST_COMPLETE")
        T.eq(calls(mock), "GetQuestReward:0,GetQuestReward:1")
    end },

    { "never chooses between rewards or pays gold", function(T)
        local ns, mock = setup(T)
        mock.dialog.choices = 3
        ns:FireEvent("QUEST_COMPLETE")
        T.eq(calls(mock), "")
        T.contains(mock.printed[#mock.printed], "Pick your reward")
        mock.dialog.choices = 1
        mock.dialog.cost = 5000
        ns:FireEvent("QUEST_COMPLETE")
        T.eq(calls(mock), "")
        T.contains(mock.printed[#mock.printed], "costs gold")
    end },

    ---------------------------------------------------------------------
    -- Pausing and switching off
    ---------------------------------------------------------------------
    { "holding Shift pauses for the whole conversation", function(T)
        local ns, mock = setup(T)
        mock.keys.shift = true
        mock.dialog.gossipAvailable = { { questID = 102 } }
        ns:FireEvent("GOSSIP_SHOW")
        mock.keys.shift = false
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "", "still paused after letting go")
        endConversation(ns)
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "AcceptQuest", "next conversation is automatic again")
    end },

    { "the pause key can be changed", function(T)
        local ns, mock = setup(T)
        ns.MainFrame.ShowTab("settings")
        ForeverPathDB.auto.pauseKey = "CTRL"
        mock.keys.shift = true
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "AcceptQuest", "Shift no longer pauses")
    end },

    { "a conversation that's still open isn't reset", function(T)
        local ns, mock = setup(T)
        mock.keys.shift = true
        ns:FireEvent("GOSSIP_SHOW")
        mock.keys.shift = false
        _G.QuestFrame:Show() -- moved on to the quest text
        endConversation(ns)
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "", "still the same conversation")
    end },

    { "Settings checkboxes switch accepting and turning in off", function(T)
        local ns, mock = setup(T)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_AUTO_ACCEPT", false)
        ns.SettingsTab.Click("SETTING_AUTO_TURNIN", false)
        T.eq(ForeverPathDB.auto.accept, false)
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        ns:FireEvent("QUEST_PROGRESS")
        ns:FireEvent("QUEST_COMPLETE")
        T.eq(calls(mock), "")
    end },

    { "stands aside when Questie's own automation is on", function(T)
        local ns, mock = setup(T)
        _G.Questie = { db = { profile = { autoAccept = { enabled = true }, autocomplete = false } } }
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "")
        T.eq(ns.AutoQuest.QuestieAutomationOn(), true)
        _G.Questie.db.profile.autoAccept.enabled = false
        T.eq(ns.AutoQuest.QuestieAutomationOn(), false)
    end },
}
