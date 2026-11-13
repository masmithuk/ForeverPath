--[[
    ForeverPath - UI/MainFrame.lua

    The leveling plan window: a movable frame with one button per route,
    a "show all bands" toggle and a scrolling text area.

    The frame is created lazily on first show so the addon costs nothing
    until it is used. It is not a protected frame, so it can be shown and
    hidden in combat.
]]

local _, ns = ...

local MainFrame = {}
ns.MainFrame = MainFrame

local L = ns.L

local FRAME_NAME = "ForeverPathMainFrame" -- needed for UISpecialFrames (Esc)
local WIDTH, HEIGHT = 480, 560
local PADDING = 12
local BUTTON_HEIGHT = 22

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

local function createRouteButtons(f)
    f.routeButtons = {}
    local order = ns.Data.RouteOrder
    local available = WIDTH - PADDING * 2
    local width = math.floor(available / #order) - 4

    for i, routeId in ipairs(order) do
        local route = ns.Data.Routes[routeId]
        local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        button:SetSize(width, BUTTON_HEIGHT)
        button:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + (i - 1) * (width + 4), -32)
        button:SetText(route.name)
        button:SetScript("OnClick", function()
            MainFrame.SetRoute(routeId)
        end)
        button.routeId = routeId
        f.routeButtons[#f.routeButtons + 1] = button
    end
end

local function createToggle(f)
    local toggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    toggle:SetSize(140, BUTTON_HEIGHT)
    toggle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    toggle:SetScript("OnClick", function()
        local account = ns.Settings.account
        account.showAllBands = not account.showAllBands
        MainFrame.Refresh()
    end)
    f.bandToggle = toggle
end

local function createScrollArea(f)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -32 - BUTTON_HEIGHT - 8)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING - 22, PADDING + BUTTON_HEIGHT + 8)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - PADDING * 2 - 26, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    text:SetWidth(WIDTH - PADDING * 2 - 26)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)

    f.scroll, f.scrollChild, f.text = scroll, child, text
end

local function create()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", f, "TOP", 0, -6)
    title:SetText(L.TITLE)
    f.title = title

    createRouteButtons(f)
    createToggle(f)
    createScrollArea(f)

    -- Close with Escape.
    table.insert(UISpecialFrames, FRAME_NAME)

    restorePosition(f)
    f:Hide()
    return f
end

local function getFrame()
    if not frame then
        frame = create()
    end
    return frame
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Re-read the character and redraw. Cheap; safe to call on every event.
function MainFrame.Refresh()
    if not frame or not frame:IsShown() then return end

    local profile = ns.Character.Detect()
    local plan = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    local xp = ns.Advisor.GetXpInfo(profile.level)
    local showAll = ns.Settings.account.showAllBands

    frame.text:SetText(ns.Text.Render(profile, plan, xp, { showAllBands = showAll }))
    frame.scrollChild:SetHeight(frame.text:GetStringHeight() + 8)
    frame.bandToggle:SetText(showAll and L.SHOW_CURRENT_BANDS or L.SHOW_ALL_BANDS)

    for _, button in ipairs(frame.routeButtons) do
        if button.routeId == plan.routeId then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

function MainFrame.Show()
    getFrame():Show()
    MainFrame.Refresh()
end

function MainFrame.Hide()
    if frame then frame:Hide() end
end

function MainFrame.Toggle()
    if frame and frame:IsShown() then
        MainFrame.Hide()
    else
        MainFrame.Show()
    end
end

--- Save a route choice for this character and redraw.
function MainFrame.SetRoute(routeId)
    ns.Settings.char.routeId = routeId
    MainFrame.Refresh()
end

function MainFrame.ResetPosition()
    ns.Settings.ResetFramePosition()
    if frame then restorePosition(frame) end
end
