--[[
    ForeverPath - UI/GuideFrame.lua

    The compact step-by-step window:

      [icon] Turn in to Grull Hawkwind        84 yd
             Rite of Strength
             [Skip]
      Then:  Talk to Brave Windfeather - Accept: ...
             Complete: Break the Quilboar ...
      Reminders (click when done):
             Buy bags from a general goods vendor ...

    It only displays Engine state; all decisions live in Guide/Engine.lua.
]]

local _, ns = ...

local GuideFrame = {}
ns.GuideFrame = GuideFrame

local L = ns.L
local Util = ns.Util

local WIDTH = 320
local PADDING = 10
local MAX_REMINDERS = 3

local ICONS = {
    ACCEPT   = "Interface\\GossipFrame\\AvailableQuestIcon",
    TURNIN   = "Interface\\GossipFrame\\ActiveQuestIcon",
    COMPLETE = "Interface\\Icons\\INV_Misc_Note_01",
    TRAIN    = "Interface\\GossipFrame\\TrainerGossipIcon",
    BUY      = "Interface\\GossipFrame\\VendorGossipIcon",
    HEARTH   = "Interface\\Icons\\INV_Misc_Rune_01",
    NOTE     = "Interface\\GossipFrame\\GossipGossipIcon",
}

local frame

---------------------------------------------------------------------------
-- Text helpers (pure; tested)
---------------------------------------------------------------------------

--- Human-friendly distance, or nil when unknown.
function GuideFrame.FormatDistance(origin, step)
    local to = step and step.target and step.target.world
    if not origin or not to or origin.continent ~= to.continent then return nil end
    local yards = Util.Distance(origin, to)
    if yards >= 1000 then
        return ("%.1fk yd"):format(yards / 1000)
    end
    return ("%d yd"):format(math.floor(yards + 0.5))
end

--- Body text for the current step.
function GuideFrame.CurrentText(step)
    local lines = { Util.Color("accent", step.title) }
    for _, line in ipairs(step.lines or {}) do
        lines[#lines + 1] = line
    end
    if not step.target then
        lines[#lines + 1] = Util.Color("muted", L.GUIDE_NO_LOCATION)
    end
    return table.concat(lines, "\n")
end

--- One-line summaries of the steps after the current one.
function GuideFrame.UpcomingText(steps)
    local lines = {}
    for i = 2, #steps do
        local s = steps[i]
        local summary = s.title
        if s.kind == "ACCEPT" or s.kind == "TURNIN" then
            summary = summary .. " (" .. #s.questIDs .. ")"
        end
        lines[#lines + 1] = Util.Color("muted", ("%d. %s"):format(i, summary))
    end
    return table.concat(lines, "\n")
end

--- "ForeverPath Guide - The Barrens" or "... - Automatic".
function GuideFrame.HeaderText()
    local guideId = ns.Settings.char.guideId
    return L.GUIDE_TITLE .. " - " .. (guideId or L.GUIDE_AUTOMATIC)
end

--- Status line explaining missing data, or nil when all is well.
function GuideFrame.StatusText(dataStatus, providerSetting)
    local parts = {}
    if dataStatus == "missing" then
        parts[#parts + 1] = L.GUIDE_NEEDS_QUESTIE
    elseif dataStatus == "incompatible" then
        parts[#parts + 1] = L.GUIDE_QUESTIE_INCOMPATIBLE
    elseif dataStatus == "indexing" then
        parts[#parts + 1] = L.GUIDE_INDEXING
    end
    if ns.Waypoints.Resolve(providerSetting) == "off" and providerSetting ~= "off" then
        parts[#parts + 1] = L.GUIDE_NO_WAYPOINTS
    end
    if #parts == 0 then return nil end
    return Util.Color("warn", table.concat(parts, "\n"))
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    local saved = ns.Settings.account.guide.frame
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function restorePosition(f)
    local saved = ns.Settings.account.guide.frame
    f:ClearAllPoints()
    f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end

local function newText(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWidth(WIDTH - PADDING * 2 - 26)
    return fs
end

local function newButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(70, 20)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function createReminderRows(f)
    f.reminderRows = {}
    for i = 1, MAX_REMINDERS do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(WIDTH - PADDING * 2, 16)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetAllPoints()
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            if self.stepKey then ns.Engine.MarkDone(self.stepKey) end
        end)
        row:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(L.GUIDE_REMINDER_TOOLTIP)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        f.reminderRows[i] = row
    end
end

local function create()
    local f = CreateFrame("Frame", "ForeverPathGuideFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, 120)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.75)
    end

    f.header = newText(f, "GameFontNormalSmall")
    f.header:SetPoint("TOPLEFT", PADDING, -PADDING)
    f.header:SetText(L.GUIDE_TITLE)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f.close:SetScript("OnClick", function() GuideFrame.Hide() end)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)

    f.distance = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.distance:SetPoint("TOPRIGHT", -PADDING, -PADDING - 2)

    f.current = newText(f, "GameFontHighlight")
    f.current:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, 0)

    f.skip = newButton(f, L.GUIDE_SKIP, function()
        local skipped = ns.Engine.SkipCurrent()
        if skipped then Util.Print(L.GUIDE_SKIPPED_FMT:format(skipped.title)) end
    end)
    f.skip:SetPoint("TOPLEFT", f.current, "BOTTOMLEFT", 0, -6)

    f.done = newButton(f, L.GUIDE_DONE, function()
        local step = ns.Engine.state.steps[1]
        if step then ns.Engine.MarkDone(step.key) end
    end)
    f.done:SetPoint("LEFT", f.skip, "RIGHT", 4, 0)

    f.guides = newButton(f, L.GUIDE_BROWSE, function() ns.MainFrame.ShowTab("guides") end)
    -- Sits after Done's slot so it doesn't move when Done is hidden.
    f.guides:SetPoint("LEFT", f.skip, "RIGHT", 78, 0)

    f.upcoming = newText(f, "GameFontHighlightSmall")
    f.upcoming:SetPoint("TOPLEFT", f.skip, "BOTTOMLEFT", 0, -8)

    f.remindersHeader = newText(f, "GameFontNormalSmall")
    f.remindersHeader:SetText(L.GUIDE_REMINDERS)
    createReminderRows(f)

    f.status = newText(f, "GameFontHighlightSmall")

    restorePosition(f)
    return f
end

local function getFrame()
    if not frame then frame = create() end
    return frame
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function layoutBelow(anchor, widgets)
    local last = anchor
    for _, w in ipairs(widgets) do
        if w:IsShown() then
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
            last = w
        end
    end
    return last
end

local function setShown(widget, shown)
    if shown then widget:Show() else widget:Hide() end
end

--- Redraw from Engine state.
function GuideFrame.Update(state)
    if not ns.Settings.account.guide.shown then return end
    local f = getFrame()
    local step = state.steps[1]
    f.header:SetText(GuideFrame.HeaderText())

    if step then
        f.icon:SetTexture(ICONS[step.kind] or ICONS.NOTE)
        f.icon:Show()
        f.current:SetText(GuideFrame.CurrentText(step))
        f.skip:Show()
        setShown(f.done, step.manual)
    else
        f.icon:Hide()
        f.current:SetText(L.GUIDE_NOTHING)
        f.skip:Hide()
        f.done:Hide()
    end

    f.upcoming:SetText(GuideFrame.UpcomingText(state.steps))
    setShown(f.upcoming, #state.steps > 1)

    local reminders = state.reminders or {}
    setShown(f.remindersHeader, #reminders > 0)
    local rowWidgets = {}
    for i, row in ipairs(f.reminderRows) do
        local r = reminders[i]
        if r then
            row.stepKey = r.key
            row.text:SetText("- " .. r.title)
            row:Show()
        else
            row.stepKey = nil
            row:Hide()
        end
        rowWidgets[i] = row
    end

    local status = GuideFrame.StatusText(state.dataStatus, ns.Settings.account.guide.waypoints)
    f.status:SetText(status or "")
    setShown(f.status, status ~= nil)

    local widgets = { f.upcoming, f.remindersHeader }
    for _, row in ipairs(rowWidgets) do widgets[#widgets + 1] = row end
    widgets[#widgets + 1] = f.status
    local last = layoutBelow(step and f.skip or f.current, widgets)

    local top = f:GetTop()
    local bottom = last:GetBottom()
    if top and bottom then
        f:SetHeight(math.max(80, top - bottom + PADDING))
    end

    GuideFrame.UpdateDistance(state.origin)
    f:Show()
end

--- Refresh just the distance readout (called every few seconds).
function GuideFrame.UpdateDistance(origin)
    if not frame then return end
    local step = ns.Engine.state.steps[1]
    frame.distance:SetText(GuideFrame.FormatDistance(origin, step) or "")
end

function GuideFrame.Show()
    ns.Settings.account.guide.shown = true
    GuideFrame.Update(ns.Engine.state)
end

function GuideFrame.Hide()
    ns.Settings.account.guide.shown = false
    if frame then frame:Hide() end
end

function GuideFrame.Toggle()
    if frame and frame:IsShown() then GuideFrame.Hide() else GuideFrame.Show() end
end

function GuideFrame.ResetPosition()
    if frame then restorePosition(frame) end
end
