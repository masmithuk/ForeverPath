--[[
    ForeverPath - UI/PlanTab.lua

    "Plan" tab: class advice, the route's level bands, dungeons for your
    level, milestones and rested XP (rendered by UI/Text.lua).
]]

local _, ns = ...

local PlanTab = {}
ns.PlanTab = PlanTab

local L = ns.L
local panel

function PlanTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)

    local width = MF.WIDTH - MF.PADDING * 2 - 30
    panel.scroll = MF.NewScrollText(panel, width)
    panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, MF.BUTTON_HEIGHT + 8)

    panel.bandToggle = MF.NewButton(panel, L.SHOW_ALL_BANDS, 160, function()
        local account = ns.Settings.account
        account.showAllBands = not account.showAllBands
        PlanTab.Refresh()
    end)
    panel.bandToggle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    return panel
end

function PlanTab.Refresh()
    if not panel then return end
    local profile = ns.Character.Detect()
    local plan = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    local xp = ns.Advisor.GetXpInfo(profile.level)
    local showAll = ns.Settings.account.showAllBands

    panel.scroll:SetContent(ns.Text.Render(profile, plan, xp, { showAllBands = showAll }))
    panel.bandToggle:SetText(showAll and L.SHOW_CURRENT_BANDS or L.SHOW_ALL_BANDS)
end

--- Current text, for tests.
function PlanTab.GetText()
    return panel and panel.scroll.text:GetText()
end
