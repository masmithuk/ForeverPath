--[[
    ForeverPath - UI/HomeTab.lua

    "Home" tab: the first thing you see. Your character, the guide you're
    following and where you are in it, rested XP, class tips, dungeons for
    your level, and a short explanation of every other part of ForeverPath.

      [Guide window]  show or hide the step guide window
      [Steps]         open the Steps tab
      [Choose guide]  open the Guides tab

    The text comes from UI/Text.lua (Text.Home).
]]

local _, ns = ...

local HomeTab = {}
ns.HomeTab = HomeTab

local L = ns.L
local panel

function HomeTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)

    panel.window = MF.NewButton(panel, L.HOME_WINDOW, 150, function()
        ns.GuideFrame.Toggle()
        HomeTab.Refresh()
    end)
    panel.window:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.steps = MF.NewButton(panel, L.HOME_OPEN_STEPS, 150, function() MF.ShowTab("steps") end)
    panel.steps:SetPoint("LEFT", panel.window, "RIGHT", 6, 0)
    panel.guides = MF.NewButton(panel, L.HOME_CHOOSE_GUIDE, 150, function() MF.ShowTab("library") end)
    panel.guides:SetPoint("LEFT", panel.steps, "RIGHT", 6, 0)

    panel.scroll = MF.NewScrollText(panel, MF.ContentWidth() - 30)
    panel.scroll:SetPoint("TOPLEFT", panel.window, "BOTTOMLEFT", 0, -10)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 0)
    return panel
end

function HomeTab.Refresh()
    if not panel then return end
    local profile = ns.Character.Detect()
    local plan = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    local xp = ns.Advisor.GetXpInfo(profile.level)
    panel.scroll:SetTextWidth(ns.MainFrame.ContentWidth() - 30)
    panel.scroll:SetContent(ns.Text.Home(profile, plan, xp, ns.Engine.state.steps[1]))
    panel.window:SetText(ns.Settings.account.guide.shown and L.HOME_HIDE_WINDOW or L.HOME_WINDOW)
end

--- Current text, for tests.
function HomeTab.GetText()
    return panel and panel.scroll.text:GetText()
end

function HomeTab.GetPanel() return panel end
