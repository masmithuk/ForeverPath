--[[
    ForeverPath - UI/TargetButton.lua

    "Target" button: one click (or one key) targets the nearest creature
    you still need for a quest in your log.

    Addons may not call TargetUnit themselves; targeting has to come from a
    hardware click on a secure button. So this is a SecureActionButton that
    runs the macro "/targetexact <name>", and ForeverPath only decides the
    name. The game also forbids changing a secure button's macro in combat,
    so a new name chosen mid-fight is applied as soon as combat ends.

    It is its own small frame rather than part of the guide window: a
    protected button inside the guide window would stop that window from
    resizing during combat.

    Picking the creature (pure; tested):
      * quests in your log that aren't ready to hand in
      * their creature objectives and creatures that drop their quest items
        (objects can't be targeted)
      * skipping creatures whose kill objective is already finished
      * the current guide step's quest first, then the nearest spawn
]]

local _, ns = ...

local TargetButton = {}
ns.TargetButton = TargetButton

local L = ns.L

local FRAME_NAME = "ForeverPathTargetButton" -- referenced by Bindings.xml
local button
local pendingName -- chosen in combat, applied after
local appliedName

---------------------------------------------------------------------------
-- Choosing the creature (pure)
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

--- Nearest targetable creature for one quest: name, distance.
local function nearestForQuest(questID, origin)
    local objectives = ns.GameApi.GetObjectives(questID)
    local bestName, bestDist
    for _, t in ipairs(ns.QuestieData.GetObjectiveTargets(questID)) do
        if t.kind == "npc" and t.name ~= "" and not killDone(t.name, objectives) then
            local points = {}
            for _, p in ipairs(t.points) do
                if p.world == nil then
                    p.world = ns.GameApi.GetWorldPosition(p.mapID, p.x, p.y) or false
                end
                points[#points + 1] = p
            end
            local _, dist = ns.Planner.Nearest(origin, points)
            if dist and (not bestDist or dist < bestDist) then
                bestName, bestDist = t.name, dist
            end
        end
    end
    return bestName, bestDist
end

--- Name of the creature to target, or nil.
-- @param log      quest log from GameApi.GetQuestLog()
-- @param origin   player's world position (may be nil)
-- @param preferID quest ID of the current guide step, tried first
function TargetButton.Pick(log, origin, preferID)
    if preferID and log[preferID] and not log[preferID].complete then
        local name = nearestForQuest(preferID, origin)
        if name then return name end
    end
    local bestName, bestDist
    for questID, quest in pairs(log) do
        if not quest.complete then
            local name, dist = nearestForQuest(questID, origin)
            if name and (not bestDist or dist < bestDist) then
                bestName, bestDist = name, dist
            end
        end
    end
    return bestName
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

local function create()
    local b = CreateFrame("Button", FRAME_NAME, UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(190, 24)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    -- Both, so it works whether the "cast on key down" option is on or off.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")
    -- Moving a secure frame is only allowed out of combat.
    b:SetScript("OnDragStart", function(self)
        if not ns.GameApi.InCombat() and IsShiftKeyDown and IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.TARGET_TOOLTIP_TITLE)
        GameTooltip:AddLine(L.TARGET_TOOLTIP_BODY, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    restorePosition(b)
    b:Hide()
    return b
end

--- Point the button at `name` (nil hides it). Deferred while in combat.
local function apply(name)
    if ns.GameApi.InCombat() then
        pendingName = name or false
        return
    end
    pendingName = nil
    if not button then button = create() end
    local wanted = ns.Settings.account.targetButton and name or nil
    if wanted == appliedName then return end
    appliedName = wanted

    if wanted then
        button:SetAttribute("macrotext", "/targetexact " .. wanted)
        button:SetText(L.TARGET_FMT:format(wanted))
        button:Show()
    else
        button:SetAttribute("macrotext", "")
        button:Hide()
    end
end

--- Re-pick the creature from the guide's current state.
-- @param state Engine.state (uses .log, .steps)
-- @param origin player's world position
function TargetButton.Update(state, origin)
    local first = state.steps and state.steps[1]
    local preferID = first and first.kind == "COMPLETE" and first.questIDs[1] or nil
    apply(TargetButton.Pick(state.log or {}, origin, preferID))
end

--- Apply a name chosen during combat.
function TargetButton.OnCombatEnded()
    if pendingName ~= nil then apply(pendingName or nil) end
end

function TargetButton.SetEnabled(enabled)
    ns.Settings.account.targetButton = enabled and true or false
    appliedName = "\0" -- force the next apply to redraw
    TargetButton.Update(ns.Engine.state, ns.Engine.state.origin)
end

function TargetButton.ResetPosition()
    if button and not ns.GameApi.InCombat() then restorePosition(button) end
end

--- For tests.
function TargetButton.GetMacro()
    return button and button:GetAttribute("macrotext")
end
