--[[
    ForeverPath - UI/MainFrame.lua

    The main window: a movable frame with three tabs and a route picker.

      Guides    browse every zone guide on your route and pick one
      Plan      class advice, route bands, dungeons and rested XP
      Settings  everything that used to need a slash command

    Each tab lives in its own file (UI/GuidesTab.lua, UI/PlanTab.lua,
    UI/SettingsTab.lua) and exposes Create(parent) and Refresh(). This file
    only owns the frame, the tab buttons and the route buttons.

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
    { id = "guides",   label = "TAB_GUIDES",   module = "GuidesTab" },
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

local function createRouteButtons(f)
    f.routeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.routeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", MainFrame.PADDING, -30 - 28 - 4)
    f.routeLabel:SetText(L.ROUTE_LABEL)

    f.routeButtons = {}
    for i, routeId in ipairs(ns.Data.RouteOrder) do
        local route = ns.Data.Routes[routeId]
        local b = newButton(f, route.name, 150, function() MainFrame.SetRoute(routeId) end)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", MainFrame.PADDING + 60 + (i - 1) * 154, -30 - 28)
        b.routeId = routeId
        f.routeButtons[i] = b
    end
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
    createRouteButtons(f)

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
    highlight(frame.routeButtons, "routeId", routeId)

    -- The route picker matters on Guides and Plan, not on Settings.
    local showRoutes = tabId ~= "settings"
    for _, b in ipairs(frame.routeButtons) do
        if showRoutes then b:Show() else b:Hide() end
    end
    if showRoutes then frame.routeLabel:Show() else frame.routeLabel:Hide() end

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

--- Save a route choice for this character and redraw everything.
function MainFrame.SetRoute(routeId)
    ns.Settings.char.routeId = routeId
    MainFrame.Refresh()
    if ns.Engine then ns.Engine.RequestReplan() end
end

function MainFrame.ResetPosition()
    if frame then restorePosition(frame) end
end
