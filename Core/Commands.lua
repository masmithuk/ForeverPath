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
    return Util.Join(ns.Data.RouteOrder, ", ")
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
        ns.MainFrame.ResetPosition()
        Util.Print(L.POSITION_RESET)
    end,
    route = function(arg)
        local id = arg and arg:lower()
        if not id or not ns.Data.Routes[id] then
            Util.Print(L.ROUTE_UNKNOWN:format(routeIds()))
            return
        end
        ns.MainFrame.SetRoute(id)
        Util.Print(L.ROUTE_SET_FMT:format(ns.Data.Routes[id].name))
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

