--[[
    Questwalker - UI/TargetButton.lua

    "Target" button: each press targets the next quest creature, from the
    nearest to the furthest, then starts again at the nearest.

    Why it's built this way
      * Addons may not call TargetUnit; targeting has to come from a
        hardware click on a secure button. So this is a
        SecureActionButton running the macro "/targetexact <name>".
      * Addon code can't change a secure button during combat, but a
        secure snippet running inside the button can. So, out of combat,
        Questwalker stores the sorted creature list on the button as
        attributes (fp-name1..N, fp-count), and a secure pre-click snippet
        steps to the next name and rewrites the macro on every press -
        which keeps working mid-fight.
      * The button listens to both mouse-down and mouse-up (so key bindings
        work whatever your "cast on key down" setting is); the snippet lets
        exactly one of them through so each press moves one step.
      * Shift is reserved for moving: Shift + left-drag moves the button and
        a Shift-click doesn't target anything.

    It is its own small frame rather than part of the guide window: a
    protected button inside the guide window would stop that window from
    resizing during combat.

    Several creatures (e.g. a group of quests in the same area): the main
    button still cycles through all of them, and one extra button per
    creature appears underneath it (QuestwalkerTargetButton2..6), each
    targeting just that creature. They follow the main button when it's
    moved, and can have their own key bindings.

    The creature list (pure; tested):
      * only the guide's current step, and only when it's a "complete
        objectives" step (pick-ups, hand-ins and trainers hide the button)
      * that step's quests that aren't ready to hand in yet
      * their creature objectives and creatures that drop their quest items
        (objects can't be targeted)
      * skipping creatures whose kill objective is already finished
      * one entry per creature, sorted by its nearest spawn
]]

local _, ns = ...

local TargetButton = {}
ns.TargetButton = TargetButton

local L = ns.L

local FRAME_NAME = "QuestwalkerTargetButton" -- referenced by Bindings.xml
local MAX_TARGETS = 8
local MAX_EXTRA = 5 -- extra per-creature buttons (2nd to 6th creature)

local extras = {} -- per-creature buttons, created on first need

local button, header
local pendingList     -- chosen in combat, applied after
local appliedKey      -- signature of the list on the button

-- Runs in the secure (restricted) environment before every click.
-- `self` is the button; returning false cancels the click.
local PRE_CLICK = [[
    if IsShiftKeyDown() then return false end
    if (down and true or false) ~= (self:GetAttribute("fp-usedown") and true or false) then
        return false
    end
    local count = self:GetAttribute("fp-count") or 0
    if count == 0 then return false end
    local index = (self:GetAttribute("fp-index") or 0) % count + 1
    self:SetAttribute("fp-index", index)
    self:SetAttribute("macrotext", "/targetexact " .. self:GetAttribute("fp-name" .. index))
]]
TargetButton.PRE_CLICK = PRE_CLICK

---------------------------------------------------------------------------
-- Choosing the creatures (pure)
---------------------------------------------------------------------------

--- Is the objective naming this creature already done?
local function killDone(name, objectives)
    local finished, open = false, false
    for _, o in ipairs(objectives) do
        if o.text:find(name, 1, true) then
            if o.finished then finished = true else open = true end
        end
    end
    return finished and not open
end

--- Add each targetable creature for one quest to `found` (name -> distance).
local function collectForQuest(questID, origin, found)
    local objectives = ns.GameApi.GetObjectives(questID)
    for _, t in ipairs(ns.QuestieData.GetObjectiveTargets(questID)) do
        if t.kind == "npc" and t.name ~= "" and not killDone(t.name, objectives) then
            for _, p in ipairs(t.points) do
                if p.world == nil then
                    p.world = ns.GameApi.GetWorldPosition(p.mapID, p.x, p.y) or false
                end
            end
            local _, dist = ns.Planner.Nearest(origin, t.points)
            dist = dist or math.huge
            if not found[t.name] or dist < found[t.name] then
                found[t.name] = dist
            end
        end
    end
end

--- Creature names to cycle through for the current step, nearest first.
--- Only a step that sends you to do objectives has targets; turn-ins,
--- pick-ups and trainer visits leave the button hidden.
-- @param step   the guide's current step (may be nil)
-- @param log    quest log from GameApi.GetQuestLog()
-- @param origin player's world position (may be nil)
function TargetButton.BuildList(step, log, origin)
    if step and step.kind == "GRIND" then
        return step.grindNames or {} -- the mobs to grind on, nearest first
    end
    local found = {}
    if step and step.kind == "COMPLETE" then
        for _, questID in ipairs(step.questIDs or {}) do
            local quest = log[questID]
            if quest and not quest.complete then collectForQuest(questID, origin, found) end
        end
    end
    local list = {}
    for name, dist in pairs(found) do list[#list + 1] = { name = name, dist = dist } end
    table.sort(list, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.name < b.name
    end)
    local names = {}
    for i = 1, math.min(#list, MAX_TARGETS) do names[i] = list[i].name end
    return names
end

---------------------------------------------------------------------------
-- The secure button
---------------------------------------------------------------------------

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    local saved = ns.Settings.account.target
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function restorePosition(f)
    local saved = ns.Settings.account.target
    f:ClearAllPoints()
    f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end

--- "Target: Vile Familiar (2/4)" for the creature the next press targets.
local function updateLabel(b)
    local count = b:GetAttribute("fp-count") or 0
    if count == 0 then return end
    local index = (b:GetAttribute("fp-index") or 0) % count + 1
    local name = b:GetAttribute("fp-name" .. index)
    if count > 1 then
        b:SetText(L.TARGET_CYCLE_FMT:format(name, index, count))
    else
        b:SetText(L.TARGET_FMT:format(name))
    end
end

local function create()
    local b = CreateFrame("Button", FRAME_NAME, UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(220, 24)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetMovable(true)
    b:EnableMouse(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")

    -- Shift + left-drag moves it (secure frames can only move out of combat).
    b:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not ns.GameApi.InCombat() then self:StartMoving() end
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)

    -- Show which creature the *next* press will target.
    b:HookScript("PostClick", updateLabel)

    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TARGET_TOOLTIP_TITLE)
        GameTooltip:AddLine(L.TARGET_TOOLTIP_BODY, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- The secure snippet needs a secure handler "header" to run from.
    header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    SecureHandlerWrapScript(b, "OnClick", header, PRE_CLICK)

    restorePosition(b)
    b:Hide()
    return b
end

--- One extra button for a single creature, stacked under the previous one.
local function createExtra(i)
    local anchor = i == 1 and button or extras[i - 1]
    local b = CreateFrame("Button", FRAME_NAME .. (i + 1), UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(220, 22)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    b:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    b:EnableMouse(true)
    b:RegisterForDrag("LeftButton")
    -- Shift + left-drag on any of them moves the whole stack.
    b:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not ns.GameApi.InCombat() then button:StartMoving() end
    end)
    b:SetScript("OnDragStop", function()
        button:StopMovingOrSizing()
        savePosition(button)
    end)
    b:Hide()
    return b
end

--- Show one extra button for each creature after the first.
local function applyExtras(names, useDown)
    for i = 1, MAX_EXTRA do
        local name = #names > 1 and names[i + 1] or nil
        local b = extras[i]
        if name and not b then
            b = createExtra(i)
            extras[i] = b
        end
        if b then
            if name then
                b:SetAttribute("macrotext", "/targetexact " .. name)
                b:RegisterForClicks(useDown and "AnyDown" or "AnyUp")
                b:SetText(L.TARGET_FMT:format(name))
                b:Show()
            else
                b:SetAttribute("macrotext", "")
                b:Hide()
            end
        end
    end
end

--- Store a creature list on the button (out of combat only).
local function apply(names)
    if ns.GameApi.InCombat() then
        pendingList = names
        return
    end
    pendingList = nil
    if not button then button = create() end
    if not ns.Settings.account.targetButton then names = {} end

    local key = table.concat(names, "\n")
    if key == appliedKey then return end
    appliedKey = key

    local oldCount = button:GetAttribute("fp-count") or 0
    for i = 1, math.max(oldCount, #names) do
        button:SetAttribute("fp-name" .. i, names[i])
    end
    local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false
    button:SetAttribute("fp-count", #names)
    button:SetAttribute("fp-index", 0) -- next press: the nearest again
    button:SetAttribute("fp-usedown", useDown)
    button:SetAttribute("macrotext", names[1] and ("/targetexact " .. names[1]) or "")
    applyExtras(names, useDown)

    if #names > 0 then
        updateLabel(button)
        button:Show()
    else
        button:Hide()
    end
end

--- Rebuild the creature list from the guide's current step.
-- @param state Engine.state (uses .steps[1] and .log)
-- @param origin player's world position
function TargetButton.Update(state, origin)
    apply(TargetButton.BuildList(state.steps and state.steps[1], state.log or {}, origin))
end

--- Why the button is or isn't showing, for /qw debug.
function TargetButton.Describe(state)
    local step = state.steps and state.steps[1]
    local names = TargetButton.BuildList(step, state.log or {}, state.origin)
    local why
    if not ns.Settings.account.targetButton then
        why = "turned off in Settings"
    elseif pendingList then
        why = "waiting for combat to end"
    elseif not step then
        why = "hidden: no current step"
    elseif step.kind ~= "COMPLETE" then
        why = ("hidden: the current step is %s (%s), not a Complete step"):format(step.kind, step.title or "?")
    elseif #names == 0 then
        why = "hidden: the current step's quests have no creatures left to kill in QuestieDB"
    else
        why = "showing"
    end
    return ("target button %s; creatures: %s"):format(why, #names > 0 and table.concat(names, ", ") or "none")
end

--- Apply a list chosen during combat.
function TargetButton.OnCombatEnded()
    if pendingList then apply(pendingList) end
end

function TargetButton.SetEnabled(enabled)
    ns.Settings.account.targetButton = enabled and true or false
    appliedKey = nil -- force the next apply to redraw
    TargetButton.Update(ns.Engine.state, ns.Engine.state.origin)
end

function TargetButton.ResetPosition()
    if button and not ns.GameApi.InCombat() then restorePosition(button) end
end

--- For tests: the creature names stored on the button, in order.
function TargetButton.GetNames()
    local names = {}
    if not button then return names end
    for i = 1, button:GetAttribute("fp-count") or 0 do
        names[i] = button:GetAttribute("fp-name" .. i)
    end
    return names
end

function TargetButton.GetMacro()
    return button and button:GetAttribute("macrotext")
end

--- For tests: the extra per-creature buttons that are showing.
function TargetButton.GetExtraButtons()
    local out = {}
    for _, b in ipairs(extras) do
        if b:IsShown() then out[#out + 1] = b end
    end
    return out
end
