--[[
    ForeverPath - Guide/Library.lua

    Every guide a player can choose: the built-in ones (Data/Routes.lua,
    read-only) and their own, which are saved account-wide as guide text in
    ForeverPathDB.guides[id] so every character can use them.

    Guide text (Guide/GuideFormat.lua) is the single source of truth:
    the editor edits it, Export shows it, Import accepts it. Parsed copies
    are cached and rebuilt whenever a guide is saved or deleted.

    A guide table, as returned by Get(), has:
      id, name, author, description, base, rules, bands,
      skipQuests, priorityQuests, steps, builtin (bool),
      skipSet / prioritySet (lookup tables), dungeonWindow (Plan tab)
]]

local _, ns = ...

local Library = {}
ns.Library = Library

local Format -- ns.GuideFormat, resolved lazily (load order)

local BUILTIN_ORDER = { "story", "efficient" }
local DUNGEON_WINDOW = { below = 0, above = 3 }

local builtins = {}  -- id -> guide
local custom = {}    -- id -> guide (parsed from saved text)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function toSet(list)
    local set = {}
    for _, v in ipairs(list or {}) do set[v] = true end
    return set
end

--- Fill in the derived fields every guide carries.
local function finish(guide, id, builtin)
    guide.id = id
    guide.builtin = builtin
    guide.skipQuests = guide.skipQuests or {}
    guide.priorityQuests = guide.priorityQuests or {}
    guide.steps = guide.steps or {}
    guide.skipSet = toSet(guide.skipQuests)
    guide.prioritySet = toSet(guide.priorityQuests)
    guide.dungeonWindow = DUNGEON_WINDOW
    return guide
end

local function storage()
    ForeverPathDB.guides = ForeverPathDB.guides or {}
    return ForeverPathDB.guides
end

local function slug(name)
    local s = name:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if s == "" then s = "guide" end
    return s:sub(1, 30)
end

local function nameTaken(name, exceptID)
    for id, g in pairs(builtins) do
        if g.name:lower() == name:lower() and id ~= exceptID then return true end
    end
    for id, g in pairs(custom) do
        if g.name:lower() == name:lower() and id ~= exceptID then return true end
    end
    return false
end

--- "Name", or "Name (2)", "Name (3)"... if that name is in use.
local function uniqueName(name, exceptID)
    if not nameTaken(name, exceptID) then return name end
    local n = 2
    while nameTaken(("%s (%d)"):format(name, n), exceptID) do n = n + 1 end
    return ("%s (%d)"):format(name, n)
end

local function newID(name)
    local base = "custom-" .. slug(name)
    local id, n = base, 2
    while builtins[id] or storage()[id] do
        id = base .. "-" .. n
        n = n + 1
    end
    return id
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

--- Build the built-ins and parse every saved guide. Call after
--- SavedVariables load; safe to call again.
function Library.Init()
    Format = ns.GuideFormat
    builtins, custom = {}, {}
    for _, def in ipairs(ns.Data.BuiltinGuides) do
        local guide = {}
        for k, v in pairs(def) do guide[k] = v end
        guide.rules = {}
        for k, v in pairs(Format.BASES[def.base]) do guide.rules[k] = v end
        builtins[def.id] = finish(guide, def.id, true)
    end
    for id, text in pairs(storage()) do
        local guide = Format.Parse(text)
        if guide then
            custom[id] = finish(guide, id, false)
        else
            ns.Util.Print(("Saved guide %q couldn't be read and was skipped."):format(id))
        end
    end
end

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------

function Library.Get(id)
    if not Format then Library.Init() end
    return builtins[id] or custom[id]
end

--- All guides: built-ins first, then the player's own by name.
function Library.List()
    if not Format then Library.Init() end
    local list = {}
    for _, id in ipairs(BUILTIN_ORDER) do list[#list + 1] = builtins[id] end
    local mine = {}
    for _, g in pairs(custom) do mine[#mine + 1] = g end
    table.sort(mine, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, g in ipairs(mine) do list[#list + 1] = g end
    return list
end

--- A guide as text (for the editor and for Export).
function Library.Text(id)
    if not Format then Library.Init() end
    if custom[id] then return storage()[id] end
    if builtins[id] then return Format.Write(builtins[id]) end
    return nil
end

--- Text for an editable copy of any guide, named "<name> (copy)".
function Library.CopyText(id)
    local guide = Library.Get(id)
    if not guide then return nil end
    local copy = Format.Parse(Library.Text(id))
    copy.name = uniqueName(guide.name .. " (copy)")
    copy.author = nil
    return Format.Write(copy)
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

--- Save guide text, as a new guide or over one of the player's guides.
-- Built-in guides can't be overwritten; saving one creates a new guide.
-- @param text guide text
-- @param id   existing custom guide id, or nil for a new guide
-- @return id or nil, errors, warnings
function Library.Save(text, id)
    if not Format then Library.Init() end
    local guide, errors, warnings = Format.Parse(text)
    if not guide then return nil, errors, warnings end

    if not (id and custom[id]) then id = nil end
    local wanted = uniqueName(guide.name, id)
    if wanted ~= guide.name then
        warnings[#warnings + 1] = { message = ("A guide called %q already exists, so this one is called %q.")
            :format(guide.name, wanted) }
        guide.name = wanted
        text = Format.Write(guide)
    end
    id = id or newID(guide.name)

    storage()[id] = text
    custom[id] = finish(guide, id, false)
    return id, errors, warnings
end

--- Import shared guide text as a new guide.
function Library.Import(text)
    return Library.Save(text, nil)
end

--- Delete one of the player's guides. Characters using it fall back to
--- their class's default guide.
function Library.Delete(id)
    if not custom[id] then return false end
    storage()[id] = nil
    custom[id] = nil
    return true
end
