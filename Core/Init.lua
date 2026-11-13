--[[
    ForeverPath - Core/Init.lua

    Creates the shared addon namespace (`ns`) and a tiny event dispatcher.
    Every other file receives the same `ns` table via `...`, so nothing is
    written to the global environment except what WoW requires (the saved
    variables, the slash command globals and the compartment callback).
]]

local addonName, ns = ...

ns.name = addonName
ns.Data = ns.Data or {}

---------------------------------------------------------------------------
-- Event dispatcher
--
-- Modules register handlers with ns:RegisterEvent("EVENT", fn). A single
-- hidden frame owns the WoW event registrations and fans events out to all
-- handlers, avoiding long if/elseif chains in an OnEvent script.
---------------------------------------------------------------------------

local handlers = {}
local eventFrame

local function getEventFrame()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            local list = handlers[event]
            if not list then return end
            for i = 1, #list do
                list[i](event, ...)
            end
        end)
    end
    return eventFrame
end

--- Register `fn(event, ...)` to run whenever `event` fires.
function ns:RegisterEvent(event, fn)
    assert(type(event) == "string", "event must be a string")
    assert(type(fn) == "function", "handler must be a function")

    if not handlers[event] then
        handlers[event] = {}
        getEventFrame():RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

--- Remove every handler for `event`.
function ns:UnregisterEvent(event)
    if handlers[event] then
        handlers[event] = nil
        getEventFrame():UnregisterEvent(event)
    end
end

--- Exposed for tests so they can fire events without a game client.
function ns:FireEvent(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end
