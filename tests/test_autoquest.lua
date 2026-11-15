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

    { "accepts every quest by default, even ones the guide wouldn't pick", function(T)
        local ns, mock = setup(T, "efficient", 6)
        T.eq(ForeverPathDB.auto.followMode, false, "off by default")
        mock.dialog.gossipAvailable = { { questID = 108 }, { questID = 101 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:108")
    end },

    { "with 'only quests my guide uses', Speedrun won't accept quests it would skip", function(T)
        local ns, mock = setup(T, "efficient", 6)
        ForeverPathDB.auto.followMode = true
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
    { "a quest is tried again in the next conversation, whatever the quest windows say", function(T)
        local ns, mock = setup(T)
        -- A dialog replacement (DialogueUI) can leave Blizzard's frames
        -- "shown"; the conversation still ends when the events stop.
        _G.GossipFrame = _G.GossipFrame or CreateFrame("Frame")
        _G.GossipFrame:Show()
        mock.dialog.gossipAvailable = { { questID = 102 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:102")
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:102", "not retried in the same conversation")
        endConversation(ns)
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(calls(mock), "SelectAvailableQuest:102,SelectAvailableQuest:102", "tried again next time")
    end },

    { "Shift no longer pauses anything", function(T)
        local ns, mock = setup(T)
        mock.keys.shift = true
        mock.dialog.questID = 102
        ns:FireEvent("QUEST_DETAIL")
        T.eq(calls(mock), "AcceptQuest")
        T.eq(ForeverPathDB.auto.pauseKey, nil)
    end },

    { "/fp debug explains auto accept", function(T)
        local _, mock = setup(T)
        SlashCmdList.FOREVERPATH("debug")
        T.contains(table.concat(mock.printed, "\n"), "auto accept on, hand in on, only guide quests off")
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

    ---------------------------------------------------------------------
    -- Quests the guide expected but the NPC doesn't offer
    ---------------------------------------------------------------------
    { "a quest the NPC doesn't offer is noted and the guide moves on", function(T)
        local ns, mock = setup(T)
        ForeverPathDB.auto.accept = false -- just talking
        local state = ns.Engine.state
        T.eq(state.steps[1].title, "Talk to Foreman Thazz'ril")
        T.contains(state.steps[1].questIDs, 102)
        -- The Foreman only offers 107 (108 and 102 need something else).
        mock.dialog.npcID = 1002
        mock.dialog.gossipAvailable = { { questID = 107 } }
        ns:FireEvent("GOSSIP_SHOW")
        T.contains(mock.printed[#mock.printed], "Not offered to you yet: ")
        T.contains(mock.printed[#mock.printed], "Lazy Peons")
        T.eq(ForeverPathCharDB.guide.notOffered[102], 8)
        for _, step in ipairs(ns.Engine.state.steps) do
            T.truthy(not (step.kind == "ACCEPT" and step.questIDs[1] == 102), "102 no longer suggested")
        end
        ns.MainFrame.ShowTab("steps")
        T.eq(ns.Engine.FocusQuest(102), true, "picking it in the Steps list tries again")
        T.eq(ForeverPathCharDB.guide.notOffered[102], nil)
    end },

    { "another NPC's quests aren't affected, and levelling up checks again", function(T)
        local ns, mock = setup(T)
        mock.dialog.npcID = 9999 -- some other NPC with nothing to offer
        ns:FireEvent("GOSSIP_SHOW")
        T.eq(next(ForeverPathCharDB.guide.notOffered), nil)
        mock.dialog.npcID = 1002
        mock.dialog.gossipAvailable = {}
        ns:FireEvent("GOSSIP_SHOW")
        T.truthy(next(ForeverPathCharDB.guide.notOffered), "Foreman's quests noted")
        ns:FireEvent("PLAYER_LEVEL_UP", 9)
        T.eq(next(ForeverPathCharDB.guide.notOffered), nil, "cleared on level up")
    end },
}
