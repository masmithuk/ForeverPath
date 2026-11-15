--[[
    ForeverPath - UI/MainFrame.lua

    The main window: a movable frame with four tabs and a line showing the
    guide you're following.

      Guides    every guide (built-in and your own): use, edit, copy,
                create, delete, export and import
      Zones     the zones of your guide and their quests; follow one
      Plan      class advice, level bands, dungeons and rested XP
      Settings  everything that used to need a slash command

    Each tab lives in its own file (UI/LibraryTab.lua, UI/ZonesTab.lua,
    UI/PlanTab.lua, UI/SettingsTab.lua) and exposes Create(parent) and
    Refresh(). This file only owns the frame, the tab buttons and the
    current-guide line.

    The frame is created lazily on first show. It is not a protected
    frame, so it can be opened and closed in combat.
]]

local _, ns = ...

local MainFrame = {}
ns.MainFrame = MainFrame

local L = ns.L

local FRAME_NAME = "ForeverPathMainFrame" -- needed for UISpecialFrames (Esc)
MainFrame.WIDTH, MainFrame.HEIGHT = 720, 540
MainFrame.PADDING = 12
MainFrame.BUTTON_HEIGHT = 22
-- Where tab content starts, below the tab and route button rows.
MainFrame.CONTENT_TOP = -32 - 2 * (22 + 6)

local TABS = {
    { id = "steps",    label = "TAB_STEPS",    module = "StepsTab" },
    { id = "library",  label = "TAB_LIBRARY",  module = "LibraryTab" },
    { id = "zones",    label = "TAB_ZONES",    module = "ZonesTab" },
    { id = "plan",     label = "TAB_PLAN",     module = "PlanTab" },
    { id = "settings", label = "TAB_SETTINGS", module = "SettingsTab" },
}

local frame -- created on demand

---------------------------------------------------------------------------
-- Position persistence
---------------------------------------------------------------------------

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    local saved = ns.Settings.account.frame
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function restorePosition(f)
    local saved = ns.Settings.account.frame
    f:ClearAllPoints()
    f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function newButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, MainFrame.BUTTON_HEIGHT)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end
MainFrame.NewButton = newButton

local function createTabButtons(f)
    f.tabButtons = {}
    for i, tab in ipairs(TABS) do
        local b = newButton(f, L[tab.label], 110, function() MainFrame.ShowTab(tab.id) end)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", MainFrame.PADDING + (i - 1) * 114, -30)
        b.tabId = tab.id
        f.tabButtons[i] = b
    end
end

--- "Guide: Efficient (Speedrun)   [Change guide]"
local function createGuideLine(f)
    f.guideLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.guideLabel:SetPoint("TOPLEFT", f, "TOPLEFT", MainFrame.PADDING, -30 - 28 - 4)

    f.changeGuide = newButton(f, L.CHANGE_GUIDE, 130, function() MainFrame.ShowTab("library") end)
    f.changeGuide:SetPoint("TOPRIGHT", f, "TOPRIGHT", -MainFrame.PADDING - 4, -30 - 28)
end

local function create()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(MainFrame.WIDTH, MainFrame.HEIGHT)
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
    f:SetScript("OnShow", function() ns.Settings.account.frame.shown = true end)
    f:SetScript("OnHide", function() ns.Settings.account.frame.shown = false end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)
    f.title:SetText(L.TITLE)

    createTabButtons(f)
    createGuideLine(f)

    f.panels = {}
    for _, tab in ipairs(TABS) do
        local panel = ns[tab.module].Create(f)
        panel:Hide()
        f.panels[tab.id] = panel
    end

    -- Close with Escape.
    table.insert(UISpecialFrames, FRAME_NAME)

    restorePosition(f)
    f:Hide()
    return f
end

local function getFrame()
    if not frame then frame = create() end
    return frame
end

--- A content panel filling the area below the button rows.
function MainFrame.NewPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", MainFrame.PADDING, MainFrame.CONTENT_TOP)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -MainFrame.PADDING, MainFrame.PADDING)
    return panel
end

--- A vertical scroll area with a single text block inside.
function MainFrame.NewScrollText(parent, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)

    scroll.child, scroll.text = child, text
    function scroll.SetContent(_, content)
        text:SetText(content)
        child:SetHeight(text:GetStringHeight() + 8)
    end
    return scroll
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

local function highlight(buttons, field, value)
    for _, b in ipairs(buttons) do
        if b[field] == value then b:LockHighlight() else b:UnlockHighlight() end
    end
end

--- Redraw the visible tab. Cheap; safe to call on every event.
function MainFrame.Refresh()
    if not frame or not frame:IsShown() then return end
    local tabId = ns.Settings.account.tab
    local profile = ns.Character.Detect()
    local routeId = ns.Advisor.ResolveRouteId(profile, ns.Settings.char.routeId)

    highlight(frame.tabButtons, "tabId", tabId)
    frame.guideLabel:SetText(L.CURRENT_GUIDE_FMT:format(ns.Library.Get(routeId).name))
    if tabId == "library" then frame.changeGuide:Hide() else frame.changeGuide:Show() end

    for _, tab in ipairs(TABS) do
        if tab.id == tabId then
            frame.panels[tab.id]:Show()
            ns[tab.module].Refresh()
        else
            frame.panels[tab.id]:Hide()
        end
    end
end

--- Redraw only if `tabId` is the visible tab (avoids rebuilding the guide
--- browser on every XP tick).
function MainFrame.RefreshIf(tabId)
    if frame and frame:IsShown() and ns.Settings.account.tab == tabId then
        MainFrame.Refresh()
    end
end

function MainFrame.ShowTab(tabId)
    ns.Settings.account.tab = tabId
    getFrame():Show()
    MainFrame.Refresh()
end

function MainFrame.Show()
    getFrame():Show()
    MainFrame.Refresh()
end

function MainFrame.Hide()
    if frame then frame:Hide() end
end

function MainFrame.Toggle()
    if frame and frame:IsShown() then MainFrame.Hide() else MainFrame.Show() end
end

function MainFrame.IsShown()
    return frame ~= nil and frame:IsShown()
end

--- Follow a guide on this character and redraw everything.
function MainFrame.SetRoute(routeId)
    if ns.Settings.char.routeId ~= routeId then
        ns.Settings.char.routeId = routeId
        if ns.Engine then ns.Engine.OnModeChanged() end
    end
    MainFrame.Refresh()
end

function MainFrame.ResetPosition()
    if frame then restorePosition(frame) end
end
