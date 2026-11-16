--[[
    Questwalker - UI/MainFrame.lua

    The main window: a movable, resizable frame with four tabs.

      Home      your character and guide, and what every part does
      Steps     every quest in your guide: where you are, done, skipped,
                missed; go to any step, or Best step if you're lost
      Guides    Speedrun and Story guides for your race, and your own:
                use, edit, copy, create, delete, export and import
      Settings  arrow, quest automation, buttons and windows

    Each tab lives in its own file (UI/HomeTab.lua, UI/StepsTab.lua,
    UI/LibraryTab.lua, UI/SettingsTab.lua) and exposes Create(parent) and
    Refresh(). Refresh lays the tab out for the window's current size, and
    runs again whenever the window is resized. This file owns the frame,
    the tab buttons and shared widgets (buttons, scrolling text, dropdowns).

    The frame is created lazily on first show. It is not a protected
    frame, so it can be opened and closed in combat.
]]

local _, ns = ...

local MainFrame = {}
ns.MainFrame = MainFrame

local L = ns.L

local FRAME_NAME = "QuestwalkerMainFrame" -- needed for UISpecialFrames (Esc)
MainFrame.WIDTH, MainFrame.HEIGHT = 720, 540 -- default size
MainFrame.MIN_WIDTH, MainFrame.MIN_HEIGHT = 560, 400
MainFrame.MAX_WIDTH, MainFrame.MAX_HEIGHT = 1400, 1000
MainFrame.PADDING = 12
MainFrame.BUTTON_HEIGHT = 22
-- Where tab content starts, below the tab buttons.
MainFrame.CONTENT_TOP = -32 - (22 + 8)

local TABS = {
    { id = "home",     label = "TAB_HOME",     module = "HomeTab" },
    { id = "steps",    label = "TAB_STEPS",    module = "StepsTab" },
    { id = "library",  label = "TAB_LIBRARY",  module = "LibraryTab" },
    { id = "settings", label = "TAB_SETTINGS", module = "SettingsTab" },
}
MainFrame.TABS = TABS

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

--- A grip in the bottom-right corner that resizes `f`.
-- @param onDone called after a resize, to save the size
function MainFrame.AddResizeGrip(f, minW, minH, maxW, maxH, onDone)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, maxW, maxH)
    elseif f.SetMinResize then
        f:SetMinResize(minW, minH)
        f:SetMaxResize(maxW, maxH)
    end
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        if onDone then onDone(f) end
    end)
    f.resizeGrip = grip
    return grip
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function saveSize(f)
    local saved = ns.Settings.account.frame
    saved.width, saved.height = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

local function restoreSize(f)
    local saved = ns.Settings.account.frame
    f:SetSize(clamp(saved.width or MainFrame.WIDTH, MainFrame.MIN_WIDTH, MainFrame.MAX_WIDTH),
              clamp(saved.height or MainFrame.HEIGHT, MainFrame.MIN_HEIGHT, MainFrame.MAX_HEIGHT))
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
    MainFrame.AddResizeGrip(f, MainFrame.MIN_WIDTH, MainFrame.MIN_HEIGHT,
        MainFrame.MAX_WIDTH, MainFrame.MAX_HEIGHT, saveSize)
    restoreSize(f)
    -- Lay the visible tab out again for the new size.
    f:SetScript("OnSizeChanged", function() MainFrame.Refresh() end)

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
    --- Follow the window's width (call from the tab's Refresh).
    function scroll.SetTextWidth(_, w)
        w = math.max(100, w)
        child:SetWidth(w)
        text:SetWidth(w)
    end
    return scroll
end

--- Width available to a tab's content at the window's current size.
function MainFrame.ContentWidth()
    local w = frame and frame:GetWidth()
    if not w or w <= 0 then w = MainFrame.WIDTH end
    return w - MainFrame.PADDING * 2
end

--- Height available to a tab's content.
function MainFrame.ContentHeight()
    local h = frame and frame:GetHeight()
    if not h or h <= 0 then h = MainFrame.HEIGHT end
    return h + MainFrame.CONTENT_TOP - MainFrame.PADDING
end

--- A compact dropdown: a button showing the current choice; clicking it
--- opens a list of choices underneath.
-- @param choices list of { id, label }
-- @param get     function() -> current id
-- @param set     function(id)
function MainFrame.NewDropdown(parent, width, choices, get, set)
    local dd = newButton(parent, "", width, nil)
    local menu = CreateFrame("Frame", nil, dd, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, #choices * 22 + 8)
    if menu.SetBackdrop then
        menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                           edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                           edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        menu:SetBackdropColor(0, 0, 0, 0.95)
    end
    menu:Hide()
    dd.menu, dd.items, dd.choices = menu, {}, choices

    local function labelOf(id)
        for _, c in ipairs(choices) do if c.id == id then return c.label end end
        return tostring(id)
    end
    function dd.Update()
        dd:SetText(labelOf(get()) .. "  v")
    end
    function dd.Choose(_, id)
        menu:Hide()
        set(id)
        dd.Update()
    end
    for i, c in ipairs(choices) do
        local item = newButton(menu, c.label, width - 8, function() dd:Choose(c.id) end)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 22)
        item.choice = c.id
        dd.items[i] = item
    end
    dd:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)
    dd:SetScript("OnHide", function() menu:Hide() end)
    dd.Update()
    return dd
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
    local known = false
    for _, tab in ipairs(TABS) do if tab.id == tabId then known = true end end
    if not known then -- a tab from an older version (Zones, Plan)
        tabId = "home"
        ns.Settings.account.tab = tabId
    end

    highlight(frame.tabButtons, "tabId", tabId)

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
