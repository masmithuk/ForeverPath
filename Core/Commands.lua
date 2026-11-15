--[[
    ForeverPath - Core/Commands.lua

    Slash commands (/fp, /foreverpath) and the Addon Compartment callback.
]]

local _, ns = ...

local Commands = {}
ns.Commands = Commands

local L = ns.L
local Util = ns.Util

local function routeIds()
    local ids = {}
    for _, g in ipairs(ns.Library.List()) do ids[#ids + 1] = g.id end
    return Util.Join(ids, ", ")
end

--- A guide by id or by name (case-insensitive), or nil.
local function findGuide(text)
    if not text then return nil end
    local id = ns.Data.LegacyRouteIds[text:lower()] or text
    local guide = ns.Library.Get(id) or ns.Library.Get(id:lower())
    if guide then return guide end
    for _, g in ipairs(ns.Library.List()) do
        if g.name:lower() == text:lower() then return g end
    end
    return nil
end

local function printHelp()
    for _, line in ipairs(L.HELP) do
        Util.Print(line)
    end
end

local function printNext()
    local profile = ns.Character.Detect()
    local plan = ns.Advisor.BuildPlan(profile, ns.Settings.char.routeId)
    Util.Print(plan.route.name .. " - " .. L.NOW .. ": " .. ns.Text.Summary(plan))
    if plan.next then
        Util.Print(L.NEXT .. " (" .. plan.next.band.min .. "+): " .. Util.Join(plan.next.zones))
    end
end

local subcommands = {
    [""] = function() ns.MainFrame.Toggle() end,
    show = function() ns.MainFrame.Show() end,
    hide = function() ns.MainFrame.Hide() end,
    help = printHelp,
    next = printNext,
    reset = function()
        ns.Settings.ResetFramePosition()
        ns.MainFrame.ResetPosition()
        ns.GuideFrame.ResetPosition()
        Util.Print(L.POSITION_RESET)
    end,
    guide = function(arg)
        if arg == "on" or arg == "off" then
            ns.Engine.SetEnabled(arg == "on")
            Util.Print(arg == "on" and L.GUIDE_ON or L.GUIDE_OFF)
        else
            ns.GuideFrame.Toggle()
        end
    end,
    skip = function()
        local step = ns.Engine.SkipCurrent()
        Util.Print(step and L.GUIDE_SKIPPED_FMT:format(step.title) or L.GUIDE_NOTHING_TO_SKIP)
    end,
    done = function()
        -- Only a guide's note/buy steps are ticked off by hand; everything
        -- else completes itself from game events.
        local current = ns.Engine.state.steps[1]
        local target = current and current.manual and current or nil
        if target then
            ns.Engine.MarkDone(target.key)
        else
            Util.Print(L.GUIDE_NOTHING_TO_MARK)
        end
    end,
    back = function()
        local entry = ns.Engine.Back()
        Util.Print(entry and L.GUIDE_RESTORED_FMT:format(entry.title) or L.GUIDE_BACK_NONE)
    end,
    best = function() ns.GuideFrame.BestStep() end,
    lost = function() ns.GuideFrame.BestStep() end,
    unskip = function()
        ns.Engine.UnskipAll()
        Util.Print(L.GUIDE_UNSKIPPED)
    end,
    waypoints = function(arg)
        local setting = arg and arg:lower()
        local valid = false
        for _, p in ipairs(ns.Waypoints.PROVIDERS) do
            if p == setting then valid = true end
        end
        if not valid then
            Util.Print(L.WAYPOINTS_UNKNOWN)
            return
        end
        ns.Settings.account.guide.waypoints = setting
        ns.Waypoints.Clear()
        ns.Engine.Replan()
        Util.Print(L.WAYPOINTS_SET_FMT:format(setting, ns.Waypoints.Resolve(setting)))
    end,
    route = function(arg)
        local guide = findGuide(arg)
        if not guide then
            Util.Print(L.ROUTE_UNKNOWN:format(routeIds()))
            return
        end
        ns.MainFrame.SetRoute(guide.id)
        Util.Print(L.ROUTE_SET_FMT:format(guide.name))
    end,
}

--- Parse and run a slash command line. Exposed for tests.
function Commands.Handle(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    local handler = subcommands[command]
    if handler then
        handler(rest ~= "" and rest or nil)
    else
        printHelp()
    end
end

function Commands.Register()
    SLASH_FOREVERPATH1 = "/fp"
    SLASH_FOREVERPATH2 = "/foreverpath"
    SlashCmdList.FOREVERPATH = Commands.Handle
end

-- Called by the minimap Addon Compartment (declared in the .toc).
-- Must be a global because the TOC references it by name.
function ForeverPath_OnAddonCompartmentClick()
    ns.MainFrame.Toggle()
end

