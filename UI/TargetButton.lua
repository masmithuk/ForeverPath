--[[
    ForeverPath - UI/TargetButton.lua

    "Target" button: each press targets the next quest creature, from the
    nearest to the furthest, then starts again at the nearest.

    Why it's built this way
      * Addons may not call TargetUnit; targeting has to come from a
        hardware click on a secure button. So this is a
        SecureActionButton running the macro "/targetexact <name>".
      * Addon code can't change a secure button during combat, but a
        secure snippet running inside the button can. So, out of combat,
        ForeverPath stores the sorted creature list on the button as
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

    The creature list (pure; tested):
      * quests in your log that aren't ready to hand in
      * their creature objectives and creatures that drop their quest items
        (objects can't be targeted)
      * skipping creatures whose kill objective is already finished
      * one entry per creature, sorted by its nearest spawn
]]

local _, ns = ...

local TargetButton = {}
ns.TargetButton = TargetButton

local L = ns.L

local FRAME_NAME = "ForeverPathTargetButton" -- referenced by Bindings.xml
local MAX_TARGETS = 8

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

--- Creature names to cycle through, nearest first.
-- @param log    quest log from GameApi.GetQuestLog()
-- @param origin player's world position (may be nil)
function TargetButton.BuildList(log, origin)
    local found = {}
    for questID, quest in pairs(log) do
        if not quest.complete then collectForQuest(questID, origin, found) end
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
    button:SetAttribute("fp-count", #names)
    button:SetAttribute("fp-index", 0) -- next press: the nearest again
    button:SetAttribute("fp-usedown", GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false)
    button:SetAttribute("macrotext", names[1] and ("/targetexact " .. names[1]) or "")

    if #names > 0 then
        updateLabel(button)
        button:Show()
    else
        button:Hide()
    end
end

--- Rebuild the creature list from the guide's current state.
-- @param state Engine.state (uses .log)
-- @param origin player's world position
function TargetButton.Update(state, origin)
    apply(TargetButton.BuildList(state.log or {}, origin))
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
