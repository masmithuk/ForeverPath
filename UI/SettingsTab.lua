--[[
    ForeverPath - UI/SettingsTab.lua

    "Settings" tab: every option as a checkbox or button, so nothing needs
    a slash command.
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
        label = "SETTING_GUIDE_ENABLED",
        get = function() return ns.Settings.account.guide.enabled end,
        set = function(v) ns.Engine.SetEnabled(v) end,
    },
    {
        label = "SETTING_GUIDE_SHOWN",
        get = function() return ns.Settings.account.guide.shown end,
        set = function(v)
            if v then ns.GuideFrame.Show() else ns.GuideFrame.Hide() end
        end,
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

local function heading(parent, text, anchor, offset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetText(text)
    if anchor then
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset or -18)
    else
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    end
    return fs
end

-- Right column: quest automation.
local AUTO_CHECKBOXES = {}
for _, entry in ipairs({
    { "SETTING_AUTO_ACCEPT", "accept" },
    { "SETTING_AUTO_TURNIN", "turnIn" },
    { "SETTING_AUTO_FOLLOW", "followMode" },
    { "SETTING_AUTO_TRIVIAL", "skipTrivial" },
    { "SETTING_AUTO_REPEAT", "skipRepeatable" },
}) do
    local key = entry[2]
    AUTO_CHECKBOXES[#AUTO_CHECKBOXES + 1] = {
        label = entry[1],
        get = function() return ns.Settings.account.auto[key] end,
        set = function(v) ns.Settings.account.auto[key] = v end,
    }
end

local RIGHT_COLUMN_X = 360

local function createCheckbox(parent, def, anchor)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
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

function SettingsTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)

    -- Step guide options.
    local guideHeading = heading(panel, L.SETTINGS_GUIDE)
    panel.checkboxes = {}
    local anchor = guideHeading
    for _, def in ipairs(CHECKBOXES) do
        local cb = createCheckbox(panel, def, anchor)
        panel.checkboxes[#panel.checkboxes + 1] = cb
        anchor = cb
    end

    -- Waypoint arrow.
    local wpHeading = heading(panel, L.SETTINGS_WAYPOINTS, anchor)
    panel.waypointButtons = {}
    for i, choice in ipairs(WAYPOINT_CHOICES) do
        local b = MF.NewButton(panel, L[choice.label], 120, function()
            ns.Settings.account.guide.waypoints = choice.id
            ns.Waypoints.Clear()
            ns.Engine.Replan()
            SettingsTab.Refresh()
        end)
        b:SetPoint("TOPLEFT", wpHeading, "BOTTOMLEFT", (i - 1) * 124, -8)
        b.choice = choice.id
        panel.waypointButtons[i] = b
    end
    panel.waypointStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.waypointStatus:SetPoint("TOPLEFT", panel.waypointButtons[1], "BOTTOMLEFT", 0, -6)

    -- Maintenance.
    local toolsHeading = heading(panel, L.SETTINGS_TOOLS, panel.waypointStatus)
    panel.unskip = MF.NewButton(panel, L.SETTING_UNSKIP, 200, function()
        ns.Engine.UnskipAll()
        ns.Util.Print(L.GUIDE_UNSKIPPED)
    end)
    panel.unskip:SetPoint("TOPLEFT", toolsHeading, "BOTTOMLEFT", 0, -8)

    panel.reset = MF.NewButton(panel, L.SETTING_RESET, 200, function()
        ns.Settings.ResetFramePosition()
        ns.MainFrame.ResetPosition()
        ns.GuideFrame.ResetPosition()
        ns.TargetButton.ResetPosition()
        ns.MinimapButton.UpdatePosition()
        ns.Util.Print(L.POSITION_RESET)
    end)
    panel.reset:SetPoint("LEFT", panel.unskip, "RIGHT", 6, 0)

    -- Quest automation (right column).
    local autoHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    autoHeading:SetText(L.SETTINGS_AUTO)
    autoHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_COLUMN_X, 0)
    anchor = autoHeading
    for _, def in ipairs(AUTO_CHECKBOXES) do
        local cb = createCheckbox(panel, def, anchor)
        panel.checkboxes[#panel.checkboxes + 1] = cb
        anchor = cb
    end

    local pauseLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pauseLabel:SetText(L.AUTO_PAUSE_LABEL)
    pauseLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    panel.pauseButtons = {}
    for i, key in ipairs(ns.AutoQuest.MODIFIERS) do
        local b = MF.NewButton(panel, L["AUTO_KEY_" .. key], 70, function()
            ns.Settings.account.auto.pauseKey = key
            SettingsTab.Refresh()
        end)
        b:SetPoint("TOPLEFT", pauseLabel, "BOTTOMLEFT", (i - 1) * 74, -6)
        b.key = key
        panel.pauseButtons[i] = b
    end

    panel.autoNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.autoNote:SetPoint("TOPLEFT", panel.pauseButtons[1], "BOTTOMLEFT", 0, -10)
    panel.autoNote:SetWidth(320)
    panel.autoNote:SetJustifyH("LEFT")

    return panel
end

function SettingsTab.Refresh()
    if not panel then return end
    for _, cb in ipairs(panel.checkboxes) do
        cb:SetChecked(cb.def.get() and true or false)
    end
    local setting = ns.Settings.account.guide.waypoints
    for _, b in ipairs(panel.waypointButtons) do
        if b.choice == setting then b:LockHighlight() else b:UnlockHighlight() end
    end
    for _, b in ipairs(panel.pauseButtons) do
        if b.key == ns.Settings.account.auto.pauseKey then b:LockHighlight() else b:UnlockHighlight() end
    end
    if ns.AutoQuest.QuestieAutomationOn() then
        panel.autoNote:SetText(ns.Util.Color("warn", L.AUTO_QUESTIE_ON))
    else
        panel.autoNote:SetText(ns.Util.Color("muted", L.AUTO_NOTES))
    end

    local inUse = ns.Waypoints.Resolve(setting)
    panel.waypointStatus:SetText(L.WAYPOINTS_IN_USE_FMT:format(L["WAYPOINTS_" .. inUse:upper()]))
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

--- For tests: press a waypoint choice.
function SettingsTab.ChooseWaypoints(id)
    for _, b in ipairs(panel.waypointButtons) do
        if b.choice == id then b:GetScript("OnClick")(b) end
    end
end
