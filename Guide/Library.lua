--[[
    Questwalker - Guide/Library.lua

    Every guide a player can choose: the built-in ones (Data/Routes.lua,
    read-only) and their own, saved account-wide in QuestwalkerDB.guides[id]
    so every character can use them.

    Saved guides are stored as plain tables in the JSON shape
    (GuideFormat.ToData), which the game writes to disk natively. Guides
    saved by 0.6 as text are converted the first time they're loaded.

    A guide table, as returned by Get(), has the GuideFormat fields plus:
      id, builtin (bool), skipSet (lookup), questRank ([questID] = position
      in the quest list), dungeonWindow (Plan tab)
]]

local _, ns = ...

local Library = {}
ns.Library = Library

local BUILTIN_ORDER = {} -- built-in ids in Data/Routes.lua order
local DUNGEON_WINDOW = { below = 0, above = 3 }

local builtins = {}  -- id -> guide
local custom = {}    -- id -> guide
local loaded = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Fill in the derived fields every guide carries.
local function finish(guide, id, builtin)
    guide.id = id
    guide.builtin = builtin
    guide.quests = guide.quests or {}
    guide.skipQuests = guide.skipQuests or {}
    guide.steps = guide.steps or {}
    guide.skipSet = {}
    for _, q in ipairs(guide.skipQuests) do guide.skipSet[q] = true end
    guide.questRank = {}
    for i, q in ipairs(guide.quests) do
        if q.id then guide.questRank[q.id] = i end
    end
    guide.dungeonWindow = DUNGEON_WINDOW
    return guide
end

local function storage()
    QuestwalkerDB.guides = QuestwalkerDB.guides or {}
    return QuestwalkerDB.guides
end

local function slug(name)
    local s = name:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if s == "" then s = "guide" end
    return s:sub(1, 30)
end

local function nameTaken(name, exceptID)
    for _, set in ipairs({ builtins, custom }) do
        for id, g in pairs(set) do
            if g.name:lower() == name:lower() and id ~= exceptID then return true end
        end
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

local function ensureLoaded()
    if not loaded then Library.Init() end
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

--- Build the built-ins and load every saved guide. Call after
--- SavedVariables load; safe to call again.
function Library.Init()
    loaded = true
    builtins, custom, BUILTIN_ORDER = {}, {}, {}
    for _, def in ipairs(ns.Data.BuiltinGuides) do
        local guide = ns.GuideFormat.Copy(def)
        for k, v in pairs(ns.GuideFormat.BASES[def.base]) do guide.rules[k] = v end
        guide.races, guide.group = def.races, def.group
        builtins[def.id] = finish(guide, def.id, true)
        BUILTIN_ORDER[#BUILTIN_ORDER + 1] = def.id
    end

    local store = storage()
    for id, saved in pairs(store) do
        local guide
        if type(saved) == "string" then
            -- A 0.6 text guide: convert it and save it in the new shape.
            guide = ns.LegacyText.Parse(saved)
            if guide then store[id] = ns.GuideFormat.ToData(guide) end
        else
            guide = ns.GuideFormat.FromData(saved)
        end
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

--- The built-in guide id for a generic choice ("efficient" / "story")
--- and a starting-area group ("orc-troll"): "speedrun-orc-troll".
function Library.GroupGuideId(genericId, groupKey)
    local kind = ns.Data.GenericRouteIds[genericId]
    if not kind or not groupKey then return nil end
    return kind .. "-" .. groupKey
end

function Library.Get(id)
    ensureLoaded()
    local guide = builtins[id] or custom[id]
    if guide or not ns.Data.GenericRouteIds[id] then return guide end
    -- "efficient" / "story": the version for this character's race.
    return builtins[Library.GroupGuideId(id, ns.Advisor.RaceGroup(ns.Character.Detect()))]
end

--- Guides for this character: the built-ins for its starting area (all of
--- them if the race isn't known), then the player's own.
function Library.ListFor(profile)
    local group = ns.Advisor.RaceGroup(profile)
    local list = {}
    for _, g in ipairs(Library.List()) do
        if not g.builtin or not group or g.group == group then list[#list + 1] = g end
    end
    return list
end

--- All guides: built-ins first, then the player's own by name.
function Library.List()
    ensureLoaded()
    local list = {}
    for _, id in ipairs(BUILTIN_ORDER) do list[#list + 1] = builtins[id] end
    local mine = {}
    for _, g in pairs(custom) do mine[#mine + 1] = g end
    table.sort(mine, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, g in ipairs(mine) do list[#list + 1] = g end
    return list
end

--- A guide as JSON, for Export.
function Library.Export(id)
    local guide = Library.Get(id)
    return guide and ns.GuideFormat.ToJson(guide) or nil
end

--- The quests a guide covers for this character, in order: its own quest
--- list, or (for guides without one, like the built-ins) every quest in
--- its zones, band by band and by level, as the Zones tab shows them.
-- @param ctx from Engine.BuildContext()
function Library.QuestList(guide, ctx)
    if #guide.quests > 0 then return guide.quests end
    local list, seen = {}, {}
    for _, band in ipairs(guide.bands) do
        for _, zone in ipairs(ns.Advisor.ResolveZones(band, ctx.profile, false)) do
            for _, q in ipairs(ns.Catalog.Overview(zone, ctx).quests) do
                if not seen[q.id] and not guide.skipSet[q.id] then
                    seen[q.id] = true
                    list[#list + 1] = { id = q.id, name = q.name }
                end
            end
        end
    end
    return list
end

--- An editable draft of a guide (a deep copy).
function Library.Draft(id)
    local guide = Library.Get(id)
    return guide and ns.GuideFormat.Copy(guide) or nil
end

--- A draft copy named "<name> (copy)". Copying a guide without its own
--- quest list fills the list in from its zones for this character, so the
--- copy can be reordered and trimmed quest by quest.
function Library.CopyDraft(id, ctx)
    local guide = Library.Get(id)
    if not guide then return nil end
    local draft = ns.GuideFormat.Copy(guide)
    draft.name = uniqueName(guide.name .. " (copy)")
    draft.author = nil
    if #draft.quests == 0 and ctx then
        for i, q in ipairs(Library.QuestList(guide, ctx)) do
            draft.quests[i] = { id = q.id, name = q.name }
        end
    end
    return draft
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

--- Save a guide, as a new guide or over one of the player's guides.
-- Built-in guides can't be overwritten; saving one creates a new guide.
-- @param guide guide table (e.g. an editor draft)
-- @param id    existing custom guide id, or nil for a new guide
-- @return id or nil, errors, warnings
function Library.Save(guide, id)
    ensureLoaded()
    local checked, errors, warnings = ns.GuideFormat.Check(guide)
    if not checked then return nil, errors, warnings end

    if not (id and custom[id]) then id = nil end
    local wanted = uniqueName(checked.name, id)
    if wanted ~= checked.name then
        warnings[#warnings + 1] = { message = ("A guide called %q already exists, so this one is called %q.")
            :format(checked.name, wanted) }
        checked.name = wanted
    end
    id = id or newID(checked.name)

    storage()[id] = ns.GuideFormat.ToData(checked)
    custom[id] = finish(checked, id, false)
    return id, errors, warnings
end

--- Import a shared guide (JSON, or 0.6 text) as a new guide.
-- @return id or nil, errors, warnings
function Library.Import(text)
    local guide, errors, warnings = ns.GuideFormat.FromJson(text)
    if not guide then return nil, errors, warnings end
    local id, saveErrors, saveWarnings = Library.Save(guide, nil)
    for _, w in ipairs(saveWarnings or {}) do warnings[#warnings + 1] = w end
    return id, saveErrors or errors, warnings
end

--- Delete one of the player's guides. Characters using it fall back to
--- their class's default guide.
function Library.Delete(id)
    if not custom[id] then return false end
    storage()[id] = nil
    custom[id] = nil
    return true
end
