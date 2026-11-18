--[[
    Questwalker - UI/SettingsTab.lua

    "Settings" tab: every option as a checkbox, dropdown or button, so
    nothing needs a slash command.

      Step guide         guide window, Target button, minimap button,
                         level-up messages; the waypoint arrow (dropdown);
                         bring back skipped quests, abandon quests the guide
                         doesn't use (two clicks), reset window positions
      Quest automation   auto accept / hand in and what to skip

    The two columns sit side by side when the window is wide enough and
    stack when it's narrow.
]]

local _, ns = ...

local SettingsTab = {}
ns.SettingsTab = SettingsTab

local L = ns.L
local panel

local WAYPOINT_CHOICES = {
    { id = "auto",    label = "WAYPOINTS_AUTO" },
    { id = "shortestpath", label = "WAYPOINTS_SHORTESTPATH" },
    { id = "tomtom",  label = "WAYPOINTS_TOMTOM" },
    { id = "builtin", label = "WAYPOINTS_BUILTIN" },
    { id = "off",     label = "WAYPOINTS_OFF" },
}

-- Each checkbox reads and writes one setting through these functions.
local CHECKBOXES = {
    {
        label = "SETTING_GUIDE_SHOWN",
        get = function() return ns.Settings.account.guide.shown end,
        set = function(v)
            if v then ns.GuideFrame.Show() else ns.GuideFrame.Hide() end
        end,
    },
    {
        label = "SETTING_GROUP_QUESTS",
        get = function() return ns.Settings.account.guide.groupQuests ~= false end,
        set = function(v)
            ns.Settings.account.guide.groupQuests = v
            ns.Engine.OnRulesChanged()
        end,
    },
    {
        label = "SETTING_DUNGEONS",
        get = function() return ns.Settings.account.guide.suggestDungeons ~= false end,
        set = function(v)
            ns.Settings.account.guide.suggestDungeons = v
            ns.GuideFrame.Update(ns.Engine.state)
        end,
    },
    {
        label = "SETTING_COMPASS",
        get = function() return ns.Settings.account.guide.compass ~= false end,
        set = function(v) ns.Compass.SetEnabled(v) end,
    },
    {
        label = "SETTING_MAP_NUMBERS",
        get = function() return ns.Settings.account.guide.mapNumbers ~= false end,
        set = function(v) ns.MapPins.SetEnabled(v) end,
    },
    {
        label = "SETTING_TARGET",
        get = function() return ns.Settings.account.targetButton end,
        set = function(v) ns.TargetButton.SetEnabled(v) end,
    },
    {
        label = "SETTING_MINIMAP",
        get = function() return not ns.Settings.account.minimap.hide end,
        set = function(v) ns.MinimapButton.SetShown(v) end,
    },
    {
        label = "SETTING_ANNOUNCE",
        get = function() return ns.Settings.account.announceLevelUp end,
        set = function(v) ns.Settings.account.announceLevelUp = v end,
    },
}

-- Right column: quest automation.
local AUTO_CHECKBOXES = {}
for _, entry in ipairs({
    { "SETTING_AUTO_ACCEPT", "accept" },
    { "SETTING_AUTO_TURNIN", "turnIn" },
    { "SETTING_AUTO_FOLLOW", "followMode" },
    { "SETTING_AUTO_TRIVIAL", "skipTrivial" },
    { "SETTING_AUTO_TOOHARD", "skipTooHard" },
    { "SETTING_AUTO_REPEAT", "skipRepeatable" },
}) do
    local key = entry[2]
    AUTO_CHECKBOXES[#AUTO_CHECKBOXES + 1] = {
        label = entry[1],
        get = function() return ns.Settings.account.auto[key] end,
        set = function(v) ns.Settings.account.auto[key] = v end,
    }
end

-- Below this content width the two columns are stacked.
local TWO_COLUMN_WIDTH = 620

local function heading(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

local function label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function createCheckbox(parent, def)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetText(L[def.label])
    cb.def = def
    cb:SetScript("OnClick", function(self)
        def.set(self:GetChecked() and true or false)
        SettingsTab.Refresh()
    end)
    return cb
end

--- Stack widgets top to bottom under `anchor`: each entry is
--- { widget, gap } (gap in pixels, negative = down).
local function stack(anchor, items)
    local last = anchor
    for _, item in ipairs(items) do
        local w, gap = item[1], item[2] or -6
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, gap)
        last = w
    end
    return last
end

local abandonArmed = nil -- unrelated quests listed by a first click on Abandon
local function disarm() abandonArmed = nil end

function SettingsTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)
    panel.checkboxes = {}

    -- Left column: the guide, the arrow and tools.
    panel.guideHeading = heading(panel, L.SETTINGS_GUIDE)
    panel.guideHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.left = {}
    for _, def in ipairs(CHECKBOXES) do
        local cb = createCheckbox(panel, def)
        panel.checkboxes[#panel.checkboxes + 1] = cb
        panel.left[#panel.left + 1] = cb
    end

    panel.waypointLabel = label(panel, L.SETTINGS_WAYPOINTS, "GameFontNormal")
    local choices = {}
    for _, c in ipairs(WAYPOINT_CHOICES) do choices[#choices + 1] = { id = c.id, label = L[c.label] } end
    panel.waypoints = MF.NewDropdown(panel, 200, choices,
        function() return ns.Settings.account.guide.waypoints end,
        function(id)
            ns.Settings.account.guide.waypoints = id
            ns.Waypoints.Clear()
            ns.Engine.Replan()
            SettingsTab.Refresh()
        end)
    panel.waypointStatus = label(panel, "", "GameFontHighlightSmall")

    panel.toolsLabel = label(panel, L.SETTINGS_TOOLS, "GameFontNormal")
    panel.unskip = MF.NewButton(panel, L.SETTING_UNSKIP, 200, function()
        ns.Engine.UnskipAll()
        ns.Util.Print(L.GUIDE_UNSKIPPED)
    end)
    panel.abandon = MF.NewButton(panel, L.SETTING_ABANDON, 200, function() SettingsTab.Abandon() end)
    panel.abandon:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.SETTING_ABANDON_TOOLTIP, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    panel.abandon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.reset = MF.NewButton(panel, L.SETTING_RESET, 200, function()
        ns.Settings.ResetFramePosition()
        ns.MainFrame.ResetPosition()
        ns.GuideFrame.ResetPosition()
        ns.TargetButton.ResetPosition()
        ns.MinimapButton.UpdatePosition()
        ns.Util.Print(L.POSITION_RESET)
    end)

    -- Right column (or below, when narrow): quest automation.
    panel.autoHeading = heading(panel, L.SETTINGS_AUTO)
    panel.right = {}
    for _, def in ipairs(AUTO_CHECKBOXES) do
        local cb = createCheckbox(panel, def)
        panel.checkboxes[#panel.checkboxes + 1] = cb
        panel.right[#panel.right + 1] = cb
    end
    panel.autoNote = label(panel, "", "GameFontHighlightSmall")
    panel:SetScript("OnHide", disarm) -- leaving the tab cancels a half-done abandon
    return panel
end

--- Place the columns for the window's current width.
local function layout()
    local width = ns.MainFrame.ContentWidth()
    local twoColumns = width >= TWO_COLUMN_WIDTH
    local columnWidth = twoColumns and (width / 2 - 10) or width

    local leftItems = {}
    for i, cb in ipairs(panel.left) do leftItems[i] = { cb, i == 1 and -6 or -2 } end
    leftItems[#leftItems + 1] = { panel.waypointLabel, -14 }
    leftItems[#leftItems + 1] = { panel.waypoints, -6 }
    leftItems[#leftItems + 1] = { panel.waypointStatus, -4 }
    leftItems[#leftItems + 1] = { panel.toolsLabel, -14 }
    leftItems[#leftItems + 1] = { panel.unskip, -6 }
    leftItems[#leftItems + 1] = { panel.abandon, -4 }
    leftItems[#leftItems + 1] = { panel.reset, -4 }
    local leftLast = stack(panel.guideHeading, leftItems)

    panel.autoHeading:ClearAllPoints()
    if twoColumns then
        panel.autoHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", width / 2 + 10, 0)
    else
        panel.autoHeading:SetPoint("TOPLEFT", leftLast, "BOTTOMLEFT", 0, -18)
    end
    local rightItems = {}
    for i, cb in ipairs(panel.right) do rightItems[i] = { cb, i == 1 and -6 or -2 } end
    rightItems[#rightItems + 1] = { panel.autoNote, -10 }
    stack(panel.autoHeading, rightItems)
    panel.autoNote:SetWidth(columnWidth)
    panel.waypointStatus:SetWidth(columnWidth)
    panel.twoColumns = twoColumns
end

--- "Abandon unrelated quests": the first click lists them and asks for a
--- second click; the second abandons them. Switching tab cancels.
function SettingsTab.Abandon()
    if abandonArmed then
        local n = ns.Engine.AbandonUnrelated()
        abandonArmed = nil
        ns.Util.Print(L.ABANDONED_FMT:format(n))
        SettingsTab.Refresh()
        return n
    end
    local list = ns.Engine.UnrelatedQuests()
    if #list == 0 then
        ns.Util.Print(L.ABANDON_NONE)
        return 0
    end
    local names = {}
    for i, q in ipairs(list) do names[i] = q.title end
    ns.Util.Print(L.ABANDON_LIST_FMT:format(#list, table.concat(names, ", ")))
    abandonArmed = list
    SettingsTab.Refresh()
    return nil
end

function SettingsTab.Refresh()
    if not panel then return end
    layout()
    if abandonArmed then
        panel.abandon:SetText(L.SETTING_ABANDON_CONFIRM_FMT:format(#abandonArmed))
    else
        panel.abandon:SetText(L.SETTING_ABANDON)
    end
    for _, cb in ipairs(panel.checkboxes) do
        cb:SetChecked(cb.def.get() and true or false)
    end
    panel.waypoints.Update()
    if ns.AutoQuest.QuestieAutomationOn() then
        panel.autoNote:SetText(ns.Util.Color("warn", L.AUTO_QUESTIE_ON))
    else
        panel.autoNote:SetText(ns.Util.Color("muted", L.AUTO_NOTES))
    end
    local inUse = ns.Waypoints.Resolve(ns.Settings.account.guide.waypoints)
    local status = L.WAYPOINTS_IN_USE_FMT:format(L["WAYPOINTS_" .. inUse:upper()])
    if ns.Waypoints.NeedsArrowAddon(ns.Settings.account.guide.waypoints) then
        status = status .. "\n" .. ns.Util.Color("warn", L.GUIDE_NEEDS_ARROW)
    end
    panel.waypointStatus:SetText(status)
end

--- For tests: click a checkbox by its label key.
function SettingsTab.Click(labelKey, value)
    for _, cb in ipairs(panel.checkboxes) do
        if cb.def.label == labelKey then
            cb:SetChecked(value)
            cb:GetScript("OnClick")(cb)
            return
        end
    end
end

--- For tests: pick a waypoint choice from the dropdown.
function SettingsTab.ChooseWaypoints(id)
    panel.waypoints:GetScript("OnClick")(panel.waypoints) -- open
    for _, item in ipairs(panel.waypoints.items) do
        if item.choice == id then item:GetScript("OnClick")(item) end
    end
end

function SettingsTab.GetPanel() return panel end
