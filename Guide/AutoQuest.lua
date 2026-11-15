--[[
    ForeverPath - Guide/AutoQuest.lua

    Accepts and hands in quests for you when you talk to quest givers.

    The dialog flow
      GOSSIP_SHOW / QUEST_GREETING  the NPC lists quests: pick a completed
                                    one to hand in first, else one to accept
      QUEST_DETAIL                  quest text shown: accept it
      QUEST_PROGRESS                "Do you have the items?": continue
      QUEST_COMPLETE                rewards shown: take the reward

    Safety rules
      * Hold the pause key (Shift by default) while opening the NPC and
        nothing is automated until every quest window has closed.
      * A choice between several rewards is always left to you.
      * Quests that cost gold to complete are left to you.
      * Quests shared by other players, and escort-quest confirmations,
        are left to you.
      * Each quest is tried at most once per conversation, so a full quest
        log can't cause a loop.
      * If Questie's own auto-accept or auto-complete is on, ForeverPath
        stands aside so the two don't fight over the same dialog.

    What gets accepted (all optional, Settings tab):
      * not quests you skipped in the guide
      * not grey (trivial) quests
      * not repeatable quests
      * only quests your current mode would pick (level window, Efficient's
        detour limit, Dungeon mode's dungeon quests)
]]

local _, ns = ...

local AutoQuest = {}
ns.AutoQuest = AutoQuest

local L = ns.L

local RESET_DELAY = 0.5 -- windows briefly all close between dialog steps

local paused = false
local tried = {}        -- [questID] = true, this conversation

---------------------------------------------------------------------------
-- Settings and conflicts
---------------------------------------------------------------------------

local function settings() return ns.Settings.account.auto end

--- Is Questie's own quest automation switched on?
function AutoQuest.QuestieAutomationOn()
    local q = _G.Questie
    local ok, on = pcall(function()
        local profile = q.db.profile
        return (profile.autoAccept and profile.autoAccept.enabled) or profile.autocomplete
    end)
    return ok and on and true or false
end

local MODIFIERS = {
    SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
    CTRL  = function() return IsControlKeyDown and IsControlKeyDown() end,
    ALT   = function() return IsAltKeyDown and IsAltKeyDown() end,
    NONE  = function() return false end,
}
AutoQuest.MODIFIERS = { "SHIFT", "CTRL", "ALT", "NONE" }

local function pauseKeyHeld()
    local check = MODIFIERS[settings().pauseKey] or MODIFIERS.SHIFT
    return check() and true or false
end

--- Should anything be automated right now?
local function active(kind)
    local s = settings()
    if not s[kind] then return false end
    if AutoQuest.QuestieAutomationOn() then return false end
    if paused then return false end
    if pauseKeyHeld() then
        paused = true -- stay paused for the rest of this conversation
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Decisions (pure; tested)
---------------------------------------------------------------------------

--- Should this offered quest be accepted?
-- @param q { questID, isTrivial, repeatable }
-- @param wants function(questID) -> bool from the guide (mode filter)
function AutoQuest.ShouldAccept(q, opts, wants)
    if not q.questID or tried[q.questID] then return false end
    if opts.skipTrivial and q.isTrivial then return false end
    if opts.skipRepeatable and q.repeatable then return false end
    if ns.Settings.char.guide.skipped[q.questID] then return false end
    if opts.followMode and wants and not wants(q.questID) then return false end
    return true
end

--- Pick what to do with an NPC's quest list.
-- @param activeList    { { questID, isComplete } }
-- @param availableList { { questID, isTrivial, repeatable } }
-- @return "turnin", index | "accept", index | nil
function AutoQuest.Choose(activeList, availableList, opts, wants)
    if opts.turnIn then
        for i, q in ipairs(activeList) do
            if q.isComplete and not tried[q.questID or ("active" .. i)] then
                return "turnin", i
            end
        end
    end
    if opts.accept then
        for i, q in ipairs(availableList) do
            if AutoQuest.ShouldAccept(q, opts, wants) then
                return "accept", i
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Reading the NPC's quest list (modern C_GossipInfo, or the greeting API)
---------------------------------------------------------------------------

local function gossipLists()
    local G = C_GossipInfo
    local activeList, availableList = {}, {}
    for _, q in ipairs(G.GetActiveQuests and G.GetActiveQuests() or {}) do
        activeList[#activeList + 1] = { questID = q.questID, isComplete = q.isComplete }
    end
    for _, q in ipairs(G.GetAvailableQuests and G.GetAvailableQuests() or {}) do
        availableList[#availableList + 1] = {
            questID = q.questID, isTrivial = q.isTrivial, repeatable = q.repeatable,
        }
    end
    return activeList, availableList
end

local function greetingLists()
    local activeList, availableList = {}, {}
    for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
        local _, isComplete = GetActiveTitle(i)
        activeList[i] = { questID = GetActiveQuestID and GetActiveQuestID(i), isComplete = isComplete }
    end
    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        local isTrivial, _, isRepeatable, _, questID = GetAvailableQuestInfo(i)
        availableList[i] = { questID = questID, isTrivial = isTrivial, repeatable = isRepeatable }
    end
    return activeList, availableList
end

local function decisionOptions()
    local s = settings()
    return {
        accept = active("accept"),
        turnIn = active("turnIn"),
        skipTrivial = s.skipTrivial,
        skipRepeatable = s.skipRepeatable,
        followMode = s.followMode,
    }
end

local function handleList(activeList, availableList, selectActive, selectAvailable)
    local opts = decisionOptions()
    if not opts.accept and not opts.turnIn then return end
    local action, index = AutoQuest.Choose(activeList, availableList, opts, ns.Engine.WantsQuest)
    if action == "turnin" then
        local q = activeList[index]
        tried[q.questID or ("active" .. index)] = true
        selectActive(index, q.questID)
    elseif action == "accept" then
        local q = availableList[index]
        tried[q.questID] = true
        selectAvailable(index, q.questID)
    end
end

function AutoQuest.OnGossipShow()
    if not C_GossipInfo then return end
    local activeList, availableList = gossipLists()
    handleList(activeList, availableList,
        function(_, questID) C_GossipInfo.SelectActiveQuest(questID) end,
        function(_, questID) C_GossipInfo.SelectAvailableQuest(questID) end)
end

function AutoQuest.OnQuestGreeting()
    local activeList, availableList = greetingLists()
    handleList(activeList, availableList,
        function(index) SelectActiveQuest(index) end,
        function(index) SelectAvailableQuest(index) end)
end

---------------------------------------------------------------------------
-- The quest dialog
---------------------------------------------------------------------------

local function sharedByPlayer()
    return UnitIsPlayer and UnitIsPlayer("questnpc") and true or false
end

function AutoQuest.OnQuestDetail()
    if not active("accept") or sharedByPlayer() then return end
    local questID = GetQuestID and GetQuestID() or 0
    if questID == 0 then return end

    -- Some quests are accepted by the server the moment you see them.
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
        return
    end

    -- Quests picked from the NPC's list already passed the filters (and
    -- were marked as tried). An NPC with a single quest opens its text
    -- directly, so run the filters here for those.
    if not tried[questID] then
        if ns.Settings.char.guide.skipped[questID] then return end
        if settings().followMode and not ns.Engine.WantsQuest(questID) then return end
        tried[questID] = true
    end
    AcceptQuest()
end

function AutoQuest.OnQuestProgress()
    if not active("turnIn") then return end
    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

function AutoQuest.OnQuestComplete()
    if not active("turnIn") then return end
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices > 1 then
        ns.Util.Print(L.AUTO_CHOOSE_REWARD)
        return
    end
    local cost = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
    if cost > 0 then
        ns.Util.Print(L.AUTO_COSTS_GOLD)
        return
    end
    GetQuestReward(choices)
end

---------------------------------------------------------------------------
-- Conversation lifetime
---------------------------------------------------------------------------

local function windowsOpen()
    local gossip = _G.GossipFrame
    local quest = _G.QuestFrame
    return (gossip and gossip:IsShown()) or (quest and quest:IsShown())
end

--- The conversation is over once every window has stayed closed briefly.
local function onWindowClosed()
    C_Timer.After(RESET_DELAY, function()
        if not windowsOpen() then
            paused = false
            tried = {}
        end
    end)
end

function AutoQuest.Start()
    ns:RegisterEvent("GOSSIP_SHOW", AutoQuest.OnGossipShow)
    ns:RegisterEvent("QUEST_GREETING", AutoQuest.OnQuestGreeting)
    ns:RegisterEvent("QUEST_DETAIL", AutoQuest.OnQuestDetail)
    ns:RegisterEvent("QUEST_PROGRESS", AutoQuest.OnQuestProgress)
    ns:RegisterEvent("QUEST_COMPLETE", AutoQuest.OnQuestComplete)
    ns:RegisterEvent("GOSSIP_CLOSED", onWindowClosed)
    ns:RegisterEvent("QUEST_FINISHED", onWindowClosed)
end

-- Exposed for tests.
AutoQuest._reset = function()
    paused = false
    tried = {}
end
