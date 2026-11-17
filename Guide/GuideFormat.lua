--[[
    Questwalker - Guide/GuideFormat.lua

    The guide schema: what a guide contains, how it's checked, and how it
    becomes JSON for export/import.

    JSON (version 2), as exported:

        {
          "format": "Questwalker guide",
          "version": 2,
          "name": "Hillsbrad Rush",
          "author": "Mike",
          "description": "My fastest Horde route.",
          "basedOn": "efficient",
          "rules": { "greyGap": 2, "maxDetour": 350, ... },
          "quests": [
            { "id": 788, "name": "Your Place In The World" },
            { "step": "buy", "text": "Buy 6-slot bags.", "zone": "Durotar", "x": 52.0, "y": 41.5 },
            { "id": 789, "name": "Cutting Teeth" }
          ],
          "bands": [
            { "levels": [1, 10], "zones": ["START"], "notes": ["Talents open at 10."] },
            { "levels": [11, 20], "alliance": ["Westfall"], "horde": ["The Barrens"] }
          ],
          "skipQuests": [123, 456],
          "steps": [ { "level": 12, "kind": "buy", "text": "Buy bags." } ]
        }

    quests      the guide's own quests, in the order to do them. The step
                guide picks these up first, in order. Names are only for
                people reading the JSON; the id is what counts.
                The list can also hold steps that aren't quests, written
                { "step": kind, "text": ..., "zone": ..., "x": ..., "y": ... }.
                kind is note, buy, train, hearth or goto; zone/x/y (map
                coordinates 0-100) are optional except for goto. A step comes
                up once every quest before it is done, taken or unavailable.
    bands       zones per level range. "zones" means both factions;
                "alliance"/"horde" set one side. Used when the quest list
                has nothing available, and for the Zones and Plan tabs.
    skipQuests  quests the guide never picks up.
    steps       extra steps from a level: train, buy, note or hearth.

    Inside the addon a guide is a plain table:
      name, author, description, base, rules,
      quests = { {id, name} or {step ("NOTE"...), text, zone, x, y} },
      bands = { {min, max, Alliance, Horde, notes} }, skipQuests, steps =
      { {level, kind ("TRAIN"...), text} }

    Every value is type-checked and size-capped, strings are stripped of
    "|" (the game's colour/link escape), and nothing is ever run as code.
    tests/test_guideformat.lua covers it.
]]

local _, ns = ...

local GuideFormat = {}
ns.GuideFormat = GuideFormat

GuideFormat.FORMAT_NAME = "Questwalker guide"
GuideFormat.VERSION = 2
GuideFormat.MAX_BANDS = 60
GuideFormat.MAX_ZONES = 20
GuideFormat.MAX_QUESTS = 1000
GuideFormat.MAX_SKIP = 500
GuideFormat.MAX_STEPS = 100

local START = "START"

--- Defaults for each "basedOn" value. Rules in the guide override these.
GuideFormat.BASES = {
    story = { greyGap = 3, levelsAbove = 3, maxAccept = 30, turninBonus = 60, chainBonus = 250,
              sidePenalty = 350, maxDetour = 0, minRate = 0, rateBonus = 0 },
    efficient = { greyGap = 2, levelsAbove = 2, maxAccept = 10, turninBonus = 120, chainBonus = 0,
                  sidePenalty = 0, maxDetour = 350, minRate = 50, rateBonus = 250 },
}

-- Rules players may set, with allowed ranges, in the order they're written.
GuideFormat.RULES = {
    { key = "greyGap",     min = 0, max = 60 },
    { key = "levelsAbove", min = 0, max = 10 },
    { key = "maxAccept",   min = 1, max = 50 },
    { key = "turninBonus", min = 0, max = 2000 },
    { key = "chainBonus",  min = 0, max = 2000 },
    { key = "sidePenalty", min = 0, max = 2000 },
    { key = "minRate",     min = 0, max = 100 },
    { key = "rateBonus",   min = 0, max = 2000 },
    { key = "maxDetour",   min = 0, max = 10000 }, -- 0 = no detour limit
}

GuideFormat.STEP_KINDS = { train = "TRAIN", buy = "BUY", note = "NOTE", hearth = "HEARTH" }
-- Kinds a step in the quest list may have (goto needs a location).
GuideFormat.LIST_STEP_KINDS = { note = "NOTE", buy = "BUY", train = "TRAIN", hearth = "HEARTH", ["goto"] = "GOTO" }
GuideFormat.LIST_STEP_ORDER = { "NOTE", "BUY", "TRAIN", "HEARTH", "GOTO" }

--- The JSON word for an internal step kind ("TRAIN" -> "train").
function GuideFormat.KindWord(kind)
    for word, k in pairs(GuideFormat.LIST_STEP_KINDS) do if k == kind then return word end end
    return nil
end

--- Is this quest-list entry a step rather than a quest?
function GuideFormat.IsStep(entry) return entry.step ~= nil end

-- Key order for exported JSON, so files read top-down and diff cleanly.
local KEY_ORDER = {
    "format", "version", "name", "author", "description", "basedOn", "rules",
    "greyGap", "levelsAbove", "maxAccept", "turninBonus", "chainBonus", "sidePenalty", "maxDetour", "minRate", "rateBonus",
    "quests", "id", "step", "zone", "x", "y", "bands", "levels", "zones", "alliance", "horde", "notes",
    "skipQuests", "steps", "level", "kind", "text",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Make text safe to show in the game's UI.
function GuideFormat.Clean(s)
    s = s:gsub("|", "/")                   -- colour/texture/link escape codes
    s = s:gsub("[%z\1-\8\11-\31\127]", "") -- control characters
    return s
end

local function copyList(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

--- Deep copy of a guide's data fields (for drafts in the editor).
function GuideFormat.Copy(guide)
    local copy = {
        name = guide.name, author = guide.author, description = guide.description,
        base = guide.base, rules = {}, quests = {}, bands = {},
        skipQuests = copyList(guide.skipQuests), steps = {},
    }
    for k, v in pairs(guide.rules or {}) do copy.rules[k] = v end
    for i, q in ipairs(guide.quests or {}) do
        if q.step then
            copy.quests[i] = { step = q.step, text = q.text, zone = q.zone, x = q.x, y = q.y }
        else
            copy.quests[i] = { id = q.id, name = q.name }
        end
    end
    for i, b in ipairs(guide.bands or {}) do
        copy.bands[i] = { min = b.min, max = b.max, Alliance = copyList(b.Alliance),
                          Horde = copyList(b.Horde), notes = copyList(b.notes) }
    end
    for i, s in ipairs(guide.steps or {}) do copy.steps[i] = { level = s.level, kind = s.kind, text = s.text } end
    return copy
end

---------------------------------------------------------------------------
-- Checking a decoded table
---------------------------------------------------------------------------

local Reader = {}
Reader.__index = Reader

local function newReader()
    return setmetatable({ errors = {}, warnings = {} }, Reader)
end

function Reader:error(path, message)
    self.errors[#self.errors + 1] = { path = path, message = message }
end

function Reader:warn(path, message)
    self.warnings[#self.warnings + 1] = { path = path, message = message }
end

function Reader:string(value, path, maxLen, required)
    if value == nil or value == "" then
        if required then self:error(path, "is required") end
        return nil
    end
    if type(value) ~= "string" then
        self:error(path, "must be text")
        return nil
    end
    if value:find("|", 1, true) then
        self:warn(path, 'contained "|", which was replaced with "/"')
    end
    value = trim(GuideFormat.Clean(value))
    if #value > maxLen then
        self:warn(path, ("was longer than %d characters and was shortened"):format(maxLen))
        value = value:sub(1, maxLen)
    end
    return value
end

function Reader:integer(value, path, min, max)
    if type(value) ~= "number" or value ~= math.floor(value) then
        self:error(path, "must be a whole number")
        return nil
    end
    if value < min or value > max then
        self:error(path, ("must be between %d and %d"):format(min, max))
        return nil
    end
    return value
end

function Reader:list(value, path, maxItems)
    if value == nil then return {} end
    if type(value) ~= "table" then
        self:error(path, "must be a list [ ... ]")
        return {}
    end
    if #value > maxItems then
        self:error(path, ("has more than %d entries"):format(maxItems))
        return {}
    end
    return value
end

function Reader:zones(value, path)
    local zones = {}
    for i, z in ipairs(self:list(value, path, GuideFormat.MAX_ZONES)) do
        local name = self:string(z, ("%s[%d]"):format(path, i), 60, true)
        if name then zones[#zones + 1] = (name:upper() == START) and START or name end
    end
    return zones
end

function Reader:questId(value, path)
    return self:integer(value, path, 1, 10000000)
end

--- A map coordinate, 0-100, rounded to one decimal place.
function Reader:coord(value, path)
    if type(value) ~= "number" or value ~= value or value < 0 or value > 100 then
        self:error(path, "must be a map coordinate from 0 to 100")
        return nil
    end
    return math.floor(value * 10 + 0.5) / 10
end

--- A non-quest step in the quest list.
function Reader:listStep(q, path)
    local kind = type(q.step) == "string" and GuideFormat.LIST_STEP_KINDS[q.step:lower()]
    if not kind then
        self:error(path .. ".step", 'must be "note", "buy", "train", "hearth" or "goto"')
        return nil
    end
    local text = q.text ~= nil and self:string(q.text, path .. ".text", 200) or nil
    local step = { step = kind, text = text }
    if q.zone ~= nil or q.x ~= nil or q.y ~= nil then
        step.zone = self:string(q.zone, path .. ".zone", 60, true)
        step.x = self:coord(q.x, path .. ".x")
        step.y = self:coord(q.y, path .. ".y")
        if not (step.zone and step.x and step.y) then return nil end
    end
    if kind == "GOTO" and not step.zone then
        self:error(path, 'a "goto" step needs "zone", "x" and "y"')
        return nil
    end
    if not text and (kind == "NOTE" or kind == "BUY") then
        self:error(path .. ".text", "is needed for a note or buy step")
        return nil
    end
    return step
end

local KNOWN_KEYS = {
    format = true, version = true, name = true, author = true, description = true, basedOn = true,
    rules = true, quests = true, bands = true, skipQuests = true, steps = true,
}

local function readRules(r, raw, guide)
    guide.rules = {}
    for k, v in pairs(GuideFormat.BASES[guide.base]) do guide.rules[k] = v end
    if raw.rules == nil then return end
    if type(raw.rules) ~= "table" then
        r:error("rules", "must be an object { ... }")
        return
    end
    local known = {}
    for _, rule in ipairs(GuideFormat.RULES) do known[rule.key] = rule end
    for key, value in pairs(raw.rules) do
        local rule = known[key]
        if not rule then
            r:error("rules." .. tostring(key), "isn't a known rule")
        else
            local n = r:integer(value, "rules." .. key, rule.min, rule.max)
            if n then guide.rules[key] = n end
        end
    end
end

local function readQuests(r, raw, guide)
    guide.quests = {}
    local seen = {}
    for i, q in ipairs(r:list(raw.quests, "quests", GuideFormat.MAX_QUESTS)) do
        local path = ("quests[%d]"):format(i)
        local id, name
        if type(q) == "table" and q.step ~= nil then
            local step = r:listStep(q, path)
            if step then guide.quests[#guide.quests + 1] = step end
        elseif type(q) == "number" then
            id = r:questId(q, path)
        elseif type(q) == "table" then
            id = r:questId(q.id, path .. ".id")
            name = r:string(q.name, path .. ".name", 100)
        else
            r:error(path, 'must be a quest ID, { "id": ..., "name": ... } or { "step": ..., "text": ... }')
        end
        if id then
            if seen[id] then
                r:warn(path, ("quest %d is listed twice; the second was removed"):format(id))
            else
                seen[id] = true
                guide.quests[#guide.quests + 1] = { id = id, name = name }
            end
        end
    end
end

local function readBands(r, raw, guide)
    guide.bands = {}
    for i, b in ipairs(r:list(raw.bands, "bands", GuideFormat.MAX_BANDS)) do
        local path = ("bands[%d]"):format(i)
        if type(b) ~= "table" then
            r:error(path, "must be an object { ... }")
        else
            local levels = b.levels
            local min, max
            if type(levels) == "table" and #levels >= 1 and #levels <= 2 then
                min = r:integer(levels[1], path .. ".levels[1]", 1, 60)
                max = r:integer(levels[2] or levels[1], path .. ".levels[2]", 1, 60)
            else
                r:error(path .. ".levels", "must be [from, to], e.g. [11, 20]")
            end
            local both = r:zones(b.zones, path .. ".zones")
            local band = {
                min = min or 1, max = max or 1, notes = {}, path = path,
                Alliance = #both > 0 and both or r:zones(b.alliance, path .. ".alliance"),
                Horde = #both > 0 and copyList(both) or r:zones(b.horde, path .. ".horde"),
            }
            if #both > 0 and (b.alliance or b.horde) then
                r:warn(path, '"zones" sets both factions, so "alliance" and "horde" were ignored')
            end
            for j, note in ipairs(r:list(b.notes, path .. ".notes", 20)) do
                local text = r:string(note, ("%s.notes[%d]"):format(path, j), 300, true)
                if text then band.notes[#band.notes + 1] = text end
            end
            if min and max then guide.bands[#guide.bands + 1] = band end
        end
    end
end

local function readExtras(r, raw, guide)
    guide.skipQuests = {}
    for i, id in ipairs(r:list(raw.skipQuests, "skipQuests", GuideFormat.MAX_SKIP)) do
        local n = r:questId(id, ("skipQuests[%d]"):format(i))
        if n then guide.skipQuests[#guide.skipQuests + 1] = n end
    end

    guide.steps = {}
    for i, s in ipairs(r:list(raw.steps, "steps", GuideFormat.MAX_STEPS)) do
        local path = ("steps[%d]"):format(i)
        if type(s) ~= "table" then
            r:error(path, "must be an object { ... }")
        else
            local level = r:integer(s.level, path .. ".level", 1, 60)
            local kind = type(s.kind) == "string" and GuideFormat.STEP_KINDS[s.kind:lower()]
            if not kind then r:error(path .. ".kind", 'must be "train", "buy", "note" or "hearth"') end
            local text = r:string(s.text, path .. ".text", 200, true)
            if level and kind and text then
                guide.steps[#guide.steps + 1] = { level = level, kind = kind, text = text }
            end
        end
    end
end

--- Turn a decoded table (from JSON or saved data) into a checked guide.
-- @return guide, or nil; errors; warnings (each { path, message })
function GuideFormat.FromData(raw)
    local r = newReader()
    if type(raw) ~= "table" then
        r:error("guide", "must be an object { ... }")
        return nil, r.errors, r.warnings
    end
    for key in pairs(raw) do
        if not KNOWN_KEYS[key] then r:warn(tostring(key), "isn't a guide setting and was ignored") end
    end
    if type(raw.version) == "number" and raw.version > GuideFormat.VERSION then
        r:warn("version", "is newer than this Questwalker understands - update the addon")
    end

    local guide = {
        name = r:string(raw.name, "name", 60, true),
        author = r:string(raw.author, "author", 60),
        description = r:string(raw.description, "description", 300),
        base = raw.basedOn or "efficient",
    }
    if not GuideFormat.BASES[guide.base] then
        r:error("basedOn", 'must be "story" or "efficient"')
        guide.base = "efficient"
    end

    readRules(r, raw, guide)
    readQuests(r, raw, guide)
    readBands(r, raw, guide)
    readExtras(r, raw, guide)

    GuideFormat.Validate(guide, r.errors, r.warnings)
    for _, b in ipairs(guide.bands) do b.path = nil end

    if #r.errors > 0 then return nil, r.errors, r.warnings end
    return guide, r.errors, r.warnings
end

--- Structural checks: a name, and bands covering 1-60 in order.
function GuideFormat.Validate(guide, errors, warnings)
    local function err(path, line, message)
        errors[#errors + 1] = { path = path, line = line, message = message }
    end
    if not guide.name or trim(guide.name) == "" then
        local reported = false
        for _, e in ipairs(errors) do if e.path == "name" then reported = true end end
        if not reported then err(nil, nil, "The guide needs a name.") end
    end
    if #guide.bands == 0 then
        err(nil, nil, "The guide needs at least one level band (zones for levels 1-60).")
        return
    end

    local expected = 1
    for _, b in ipairs(guide.bands) do
        if b.min > b.max then
            err(b.path, b.line, ("levels %d-%d run backwards"):format(b.min, b.max))
        elseif b.min > expected then
            err(b.path, b.line, ("levels %d-%d aren't covered by any band"):format(expected, b.min - 1))
        elseif b.min < expected then
            err(b.path, b.line, ("levels %d-%d overlap the band before"):format(b.min, b.max))
        end
        if #b.Alliance == 0 or #b.Horde == 0 then
            err(b.path, b.line, ("levels %d-%d need zones for both factions"):format(b.min, b.max))
        end
        expected = math.max(expected, b.max + 1)
    end
    if expected <= 60 then
        warnings[#warnings + 1] = { message = ("Levels %d-60 aren't covered; the last band is used for them."):format(expected) }
    end
end

--- Run the checks on a guide the editor has built up.
-- @return true/false, errors, warnings
function GuideFormat.Check(guide)
    return GuideFormat.FromData(GuideFormat.ToData(guide))
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

--- Guide -> plain table in the JSON shape (also what's saved to disk).
function GuideFormat.ToData(guide)
    local data = {
        format = GuideFormat.FORMAT_NAME,
        version = GuideFormat.VERSION,
        name = guide.name,
        author = guide.author,
        description = guide.description,
        basedOn = guide.base,
        rules = {},
        quests = {},
        bands = {},
    }
    -- Only rules that differ from the base, so exports stay short.
    local defaults = GuideFormat.BASES[guide.base] or {}
    for _, rule in ipairs(GuideFormat.RULES) do
        local v = guide.rules and guide.rules[rule.key]
        if v ~= nil and v ~= defaults[rule.key] then data.rules[rule.key] = v end
    end
    if next(data.rules) == nil then data.rules = nil end

    for i, q in ipairs(guide.quests or {}) do
        if q.step then
            local out = { step = GuideFormat.KindWord(q.step), text = q.text }
            if q.zone then out.zone, out.x, out.y = q.zone, q.x, q.y end
            data.quests[i] = out
        else
            data.quests[i] = q.name and { id = q.id, name = q.name } or { id = q.id }
        end
    end
    for i, b in ipairs(guide.bands or {}) do
        local out = { levels = { b.min, b.max } }
        if sameList(b.Alliance, b.Horde) then
            out.zones = copyList(b.Alliance)
        else
            out.alliance = copyList(b.Alliance)
            out.horde = copyList(b.Horde)
        end
        if #(b.notes or {}) > 0 then out.notes = copyList(b.notes) end
        data.bands[i] = out
    end
    if #(guide.skipQuests or {}) > 0 then data.skipQuests = copyList(guide.skipQuests) end
    if #(guide.steps or {}) > 0 then
        data.steps = {}
        for i, s in ipairs(guide.steps) do
            local kind
            for word, k in pairs(GuideFormat.STEP_KINDS) do if k == s.kind then kind = word end end
            data.steps[i] = { level = s.level, kind = kind, text = s.text }
        end
    end
    return data
end

function GuideFormat.ToJson(guide)
    return ns.Json.Encode(GuideFormat.ToData(guide), KEY_ORDER) .. "\n"
end

--- JSON (or 0.6 guide text) -> guide.
-- @return guide, or nil; errors; warnings
function GuideFormat.FromJson(text)
    if type(text) ~= "string" or trim(text) == "" then
        return nil, { { message = "Nothing to read - paste a guide first." } }, {}
    end
    if ns.LegacyText.Detect(text) then
        return ns.LegacyText.Parse(text)
    end
    local data, err = ns.Json.Decode(text)
    if err then
        return nil, { { line = err.line, column = err.column, message = "JSON: " .. err.message } }, {}
    end
    return GuideFormat.FromData(data)
end

--- A starting point for a brand-new guide.
function GuideFormat.NewGuide(name)
    local guide = {
        name = name or "My Guide",
        base = "efficient",
        quests = {},
        bands = {
            { min = 1, max = 10, Alliance = { START }, Horde = { START }, notes = {} },
            { min = 11, max = 60, Alliance = { "Westfall" }, Horde = { "The Barrens" }, notes = {} },
        },
        skipQuests = {},
        steps = {},
        rules = {},
    }
    for k, v in pairs(GuideFormat.BASES.efficient) do guide.rules[k] = v end
    return guide
end

--- "Line 3, column 5: ..." / "quests[2].id: ..." / "..." for the editor.
function GuideFormat.Describe(m)
    if m.line then
        local where = m.column and ("Line %d, column %d"):format(m.line, m.column) or ("Line %d"):format(m.line)
        return where .. ": " .. m.message
    end
    if m.path then return m.path .. " " .. m.message end
    return m.message
end
