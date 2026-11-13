--[[
    ForeverPath - Core/Bootstrap.lua

    Wires game events to the modules. Loaded last so every module exists.
]]

local addonName, ns = ...

local L = ns.L
local Util = ns.Util

--- Announce route changes and milestones when the player levels up.
-- PLAYER_LEVEL_UP passes the new level; UnitLevel may not be updated yet,
-- so the profile is patched with the event's value.
local function onLevelUp(_, newLevel)
    if not ns.Settings.account.announceLevelUp then return end
    newLevel = Util.SafeNumber(newLevel)
    if not newLevel then return end

    local profile = ns.Character.Detect()
    profile.level = newLevel
    local plan = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)

    -- Only mention zones when the player has crossed into a new band.
    local previous = ns.Advisor.FindBandIndex(plan.route, newLevel - 1)
    if previous ~= plan.bandIndex then
        Util.Print(L.DING_FMT:format(newLevel, ns.Text.Summary(plan)))
    end

    for _, milestone in ipairs(ns.Advisor.GetMilestonesAt(newLevel, profile.classFile)) do
        Util.Print(L.DING_MILESTONE_FMT:format(newLevel, milestone.text))
    end

    ns.MainFrame.Refresh()
end

ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName then return end
    ns.Settings.Init()
    ns.Commands.Register()
    ns:UnregisterEvent("ADDON_LOADED")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    Util.Print(L.LOADED)
    if ns.Settings.account.frame.shown then
        ns.MainFrame.Show()
    end
    ns.Engine.Start()
end)

ns:RegisterEvent("PLAYER_LEVEL_UP", onLevelUp)

-- Keep the rested/XP numbers live while the window is open.
local function refresh() ns.MainFrame.Refresh() end
ns:RegisterEvent("PLAYER_XP_UPDATE", refresh)
ns:RegisterEvent("UPDATE_EXHAUSTION", refresh)
ns:RegisterEvent("PLAYER_UPDATE_RESTING", refresh)
