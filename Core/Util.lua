--[[
    ForeverPath - Core/Util.lua

    Small, dependency-free helpers shared by the logic and UI layers.
]]

local _, ns = ...

local Util = {}
ns.Util = Util

Util.MAX_LEVEL = 60

Util.COLORS = {
    accent = "ffd100", -- Blizzard gold
    muted  = "9d9d9d",
    good   = "40c040",
    new    = "33ccff",
    warn   = "ff7f3f",
}

--- Wrap `text` in a WoW colour escape.
function Util.Color(colorName, text)
    local hex = Util.COLORS[colorName] or colorName
    return "|cff" .. hex .. tostring(text) .. "|r"
end

--- Forever (like Midnight) can return "secret" values that error when
--- compared or printed. Returns nil for secret or non-numeric values.
function Util.SafeNumber(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    if type(value) ~= "number" then
        return nil
    end
    return value
end

--- Same as SafeNumber but for strings.
function Util.SafeString(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    if type(value) ~= "string" then
        return nil
    end
    return value
end

--- 12345 -> "12,345". Uses Blizzard's helper when present.
function Util.FormatNumber(n)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(n)
    end
    local s = tostring(math.floor(n))
    local formatted, count
    repeat
        formatted, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        s = formatted
    until count == 0
    return s
end

--- Join a list of strings, skipping nils.
function Util.Join(list, sep)
    local out = {}
    for i = 1, #list do
        if list[i] ~= nil then
            out[#out + 1] = tostring(list[i])
        end
    end
    return table.concat(out, sep or ", ")
end

--- Return a new list with duplicates removed, preserving order.
function Util.Unique(list)
    local seen, out = {}, {}
    for i = 1, #list do
        local v = list[i]
        if not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

--- Recursively fill missing keys in `target` from `defaults`.
function Util.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            Util.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

--- Print a prefixed message to the default chat frame.
function Util.Print(...)
    local prefix = Util.Color("accent", ns.name or "ForeverPath") .. ":"
    print(prefix, ...)
end
