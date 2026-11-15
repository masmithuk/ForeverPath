--[[
    ForeverPath - Guide/GuideFormat.lua

    The text format every guide is stored, edited, exported and imported in.
    It is plain text so players can read it, edit it in the game or in any
    text editor, and paste it to each other.

        # Lines starting with # are comments.
        guide: Hillsbrad Rush
        author: Mike
        description: My fastest Horde route.
        based on: efficient
        rules: greyGap=2 levelsAbove=2 maxAccept=10 turninBonus=120 chainBonus=0 maxDetour=350

        [1-10]
        both: START
        note: Talents open at level 10.

        [11-20]
        alliance: Westfall, Loch Modan
        horde: The Barrens, Silverpine Forest

        skip quests: 123, 456
        priority quests: 789
        step 12 buy: Buy bags before leaving town.

    Parsing never runs code from the text (no loadstring), caps every size,
    and strips the "|" character, which the game would read as colour,
    texture or link codes. Errors and warnings carry line numbers.

    tests/test_guideformat.lua covers parsing, validation and round trips.
]]

local _, ns = ...

local GuideFormat = {}
ns.GuideFormat = GuideFormat

GuideFormat.VERSION = 1
GuideFormat.MAX_TEXT = 30000
GuideFormat.MAX_LINE = 500
GuideFormat.MAX_BANDS = 60
GuideFormat.MAX_ZONES = 20
GuideFormat.MAX_LIST = 500
GuideFormat.MAX_STEPS = 100

local START = "START"

--- Defaults for each "based on" value. Rules in the guide override these.
GuideFormat.BASES = {
    story = { greyGap = 10, levelsAbove = 3, maxAccept = 30, turninBonus = 60, chainBonus = 150, maxDetour = 0 },
    efficient = { greyGap = 2, levelsAbove = 2, maxAccept = 10, turninBonus = 120, chainBonus = 0, maxDetour = 350 },
}

-- Rules players may set, with allowed ranges, in the order they're written.
GuideFormat.RULES = {
    { key = "greyGap",     min = 0, max = 60 },
    { key = "levelsAbove", min = 0, max = 10 },
    { key = "maxAccept",   min = 1, max = 50 },
    { key = "turninBonus", min = 0, max = 2000 },
    { key = "chainBonus",  min = 0, max = 2000 },
    { key = "maxDetour",   min = 0, max = 10000 }, -- 0 = no detour limit
}

GuideFormat.STEP_KINDS = { train = "TRAIN", buy = "BUY", note = "NOTE", hearth = "HEARTH" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Make imported text safe to show in the game's UI.
function GuideFormat.Clean(s)
    s = s:gsub("|", "/")                -- colour/texture/link escape codes
    s = s:gsub("[%z\1-\8\11-\31\127]", "") -- control characters
    return s
end

local function splitList(value, maxItems)
    local items = {}
    for item in value:gmatch("[^,]+") do
        item = trim(item)
        if item ~= "" then items[#items + 1] = item end
        if #items >= maxItems then break end
    end
    return items
end

local function parseIdList(value, lineNo, errors)
    local ids = {}
    for _, item in ipairs(splitList(value, GuideFormat.MAX_LIST)) do
        local n = tonumber(item)
        if n and n > 0 and n == math.floor(n) then
            ids[#ids + 1] = n
        else
            errors[#errors + 1] = { line = lineNo, message = ("%q is not a quest ID"):format(item) }
        end
    end
    return ids
end

local function zoneList(value)
    local zones = {}
    for _, z in ipairs(splitList(value, GuideFormat.MAX_ZONES)) do
        zones[#zones + 1] = (z:upper() == START) and START or z
    end
    return zones
end

local function copyRules(rules)
    local out = {}
    for k, v in pairs(rules) do out[k] = v end
    return out
end

---------------------------------------------------------------------------
-- Parsing
---------------------------------------------------------------------------

local function parseRules(value, rules, lineNo, errors)
    local known = {}
    for _, r in ipairs(GuideFormat.RULES) do known[r.key:lower()] = r end
    for pair in value:gmatch("%S+") do
        local key, number = pair:match("^(%a+)=(%-?%d+)$")
        local rule = key and known[key:lower()]
        if not rule then
            errors[#errors + 1] = { line = lineNo, message = ("Unknown rule %q"):format(pair) }
        else
            local n = tonumber(number)
            if n < rule.min or n > rule.max then
                errors[#errors + 1] = { line = lineNo,
                    message = ("%s must be between %d and %d"):format(rule.key, rule.min, rule.max) }
            else
                rules[rule.key] = n
            end
        end
    end
end

--- Parse guide text.
-- @return guide table, or nil; list of errors; list of warnings
--   Each error/warning is { line = n or nil, message = "..." }.
--   The guide: { name, author, description, base, rules, bands,
--                skipQuests, priorityQuests, steps }
function GuideFormat.Parse(text)
    local errors, warnings = {}, {}
    if type(text) ~= "string" or trim(text) == "" then
        return nil, { { message = "The guide is empty." } }, warnings
    end
    if #text > GuideFormat.MAX_TEXT then
        return nil, { { message = ("The guide is too long (over %d characters)."):format(GuideFormat.MAX_TEXT) } }, warnings
    end
    if text:find("|", 1, true) then
        warnings[#warnings + 1] = { message = 'The "|" character isn\'t allowed and was replaced with "/".' }
    end
    text = GuideFormat.Clean(text:gsub("\r\n?", "\n"))

    local guide = {
        base = "efficient", bands = {}, skipQuests = {}, priorityQuests = {}, steps = {},
    }
    local explicitRules = {}
    local band -- current [a-b] section
    local lineNo = 0

    for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
        lineNo = lineNo + 1
        local line = trim(raw)
        if #line > GuideFormat.MAX_LINE then
            errors[#errors + 1] = { line = lineNo, message = "Line is too long." }
        elseif line ~= "" and not line:match("^#") and not line:match("^%-%-") then
            local a, b = line:match("^%[%s*(%d+)%s*%-%s*(%d+)%s*%]$")
            local single = line:match("^%[%s*(%d+)%s*%]$")
            if single then a, b = single, single end

            if a then
                if #guide.bands >= GuideFormat.MAX_BANDS then
                    errors[#errors + 1] = { line = lineNo, message = "Too many level bands." }
                else
                    band = { min = tonumber(a), max = tonumber(b), Alliance = {}, Horde = {}, notes = {}, line = lineNo }
                    guide.bands[#guide.bands + 1] = band
                end
            else
                local key, value = line:match("^([^:]+):%s*(.*)$")
                if not key then
                    errors[#errors + 1] = { line = lineNo, message = ('Expected "key: value" or [level-level], got %q'):format(line) }
                else
                    key = trim(key):lower():gsub("%s+", " ")
                    local stepLevel, stepKind = key:match("^step%s+(%d+)%s+(%a+)$")

                    if key == "guide" or key == "name" then
                        guide.name = value:sub(1, 60)
                    elseif key == "author" then
                        guide.author = value:sub(1, 60)
                    elseif key == "description" then
                        guide.description = value:sub(1, 300)
                    elseif key == "based on" then
                        local base = value:lower()
                        if GuideFormat.BASES[base] then
                            guide.base = base
                        else
                            errors[#errors + 1] = { line = lineNo, message = 'based on must be "story" or "efficient"' }
                        end
                    elseif key == "rules" then
                        parseRules(value, explicitRules, lineNo, errors)
                    elseif key == "skip quests" then
                        for _, id in ipairs(parseIdList(value, lineNo, errors)) do
                            guide.skipQuests[#guide.skipQuests + 1] = id
                        end
                    elseif key == "priority quests" then
                        for _, id in ipairs(parseIdList(value, lineNo, errors)) do
                            guide.priorityQuests[#guide.priorityQuests + 1] = id
                        end
                    elseif stepLevel then
                        local kind = GuideFormat.STEP_KINDS[stepKind]
                        local level = tonumber(stepLevel)
                        if not kind then
                            errors[#errors + 1] = { line = lineNo, message = "Step kind must be train, buy, note or hearth" }
                        elseif level < 1 or level > 60 then
                            errors[#errors + 1] = { line = lineNo, message = "Step level must be 1-60" }
                        elseif value == "" then
                            errors[#errors + 1] = { line = lineNo, message = "Step needs some text" }
                        elseif #guide.steps >= GuideFormat.MAX_STEPS then
                            errors[#errors + 1] = { line = lineNo, message = "Too many steps" }
                        else
                            guide.steps[#guide.steps + 1] = { level = level, kind = kind, text = value }
                        end
                    elseif key == "alliance" or key == "horde" or key == "both" or key == "note" then
                        if not band then
                            errors[#errors + 1] = { line = lineNo, message = ('"%s:" must come after a [level-level] line'):format(key) }
                        elseif key == "note" then
                            band.notes[#band.notes + 1] = value
                        else
                            for _, zone in ipairs(zoneList(value)) do
                                if key ~= "horde" then band.Alliance[#band.Alliance + 1] = zone end
                                if key ~= "alliance" then band.Horde[#band.Horde + 1] = zone end
                            end
                        end
                    else
                        errors[#errors + 1] = { line = lineNo, message = ("Unknown setting %q"):format(key) }
                    end
                end
            end
        end
    end

    -- Rules: the base's defaults, then anything the guide sets.
    guide.rules = copyRules(GuideFormat.BASES[guide.base])
    for k, v in pairs(explicitRules) do guide.rules[k] = v end

    GuideFormat.Validate(guide, errors, warnings)
    for _, b in ipairs(guide.bands) do b.line = nil end

    if #errors > 0 then return nil, errors, warnings end
    return guide, errors, warnings
end

--- Structural checks shared by parsing and the built-in guides' tests.
function GuideFormat.Validate(guide, errors, warnings)
    if not guide.name or trim(guide.name) == "" then
        errors[#errors + 1] = { message = 'The guide needs a name ("guide: My Guide").' }
    end
    if #guide.bands == 0 then
        errors[#errors + 1] = { message = "The guide needs at least one level band, like [1-10]." }
        return
    end

    local expected = 1
    for _, b in ipairs(guide.bands) do
        if b.min < 1 or b.max > 60 or b.min > b.max then
            errors[#errors + 1] = { line = b.line, message = ("[%d-%d] isn't a valid level range"):format(b.min, b.max) }
        elseif b.min ~= expected then
            if b.min > expected then
                errors[#errors + 1] = { line = b.line,
                    message = ("Levels %d-%d aren't covered by any band"):format(expected, b.min - 1) }
            else
                errors[#errors + 1] = { line = b.line, message = ("[%d-%d] overlaps the band before it"):format(b.min, b.max) }
            end
        end
        if #b.Alliance == 0 or #b.Horde == 0 then
            errors[#errors + 1] = { line = b.line,
                message = ("[%d-%d] needs zones for both factions (alliance:, horde: or both:)"):format(b.min, b.max) }
        end
        expected = math.max(expected, b.max + 1)
    end
    if expected <= 60 then
        warnings[#warnings + 1] = { message = ("Levels %d-60 aren't covered; the last band is used for them."):format(expected) }
    end
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

--- Guide table -> text. Parse(Write(g)) gives back the same guide.
function GuideFormat.Write(guide)
    local lines = {
        ("# ForeverPath guide (format %d). Lines starting with # are comments."):format(GuideFormat.VERSION),
        "guide: " .. guide.name,
    }
    if guide.author and guide.author ~= "" then lines[#lines + 1] = "author: " .. guide.author end
    if guide.description and guide.description ~= "" then lines[#lines + 1] = "description: " .. guide.description end
    lines[#lines + 1] = "based on: " .. (guide.base or "efficient")

    local rules = {}
    for _, r in ipairs(GuideFormat.RULES) do
        rules[#rules + 1] = ("%s=%d"):format(r.key, guide.rules[r.key] or 0)
    end
    lines[#lines + 1] = "rules: " .. table.concat(rules, " ")

    for _, b in ipairs(guide.bands) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = (b.min == b.max) and ("[%d]"):format(b.min) or ("[%d-%d]"):format(b.min, b.max)
        if sameList(b.Alliance, b.Horde) then
            lines[#lines + 1] = "both: " .. table.concat(b.Alliance, ", ")
        else
            lines[#lines + 1] = "alliance: " .. table.concat(b.Alliance, ", ")
            lines[#lines + 1] = "horde: " .. table.concat(b.Horde, ", ")
        end
        for _, note in ipairs(b.notes or {}) do lines[#lines + 1] = "note: " .. note end
    end

    local extras = {}
    if #(guide.skipQuests or {}) > 0 then
        extras[#extras + 1] = "skip quests: " .. table.concat(guide.skipQuests, ", ")
    end
    if #(guide.priorityQuests or {}) > 0 then
        extras[#extras + 1] = "priority quests: " .. table.concat(guide.priorityQuests, ", ")
    end
    for _, s in ipairs(guide.steps or {}) do
        local kind
        for word, k in pairs(GuideFormat.STEP_KINDS) do if k == s.kind then kind = word end end
        extras[#extras + 1] = ("step %d %s: %s"):format(s.level, kind, s.text)
    end
    if #extras > 0 then
        lines[#lines + 1] = ""
        for _, l in ipairs(extras) do lines[#lines + 1] = l end
    end
    return table.concat(lines, "\n") .. "\n"
end

--- A starting point for a brand-new guide, with the format explained.
function GuideFormat.Template(name)
    return table.concat({
        "# ForeverPath guide (format 1). Lines starting with # are comments.",
        "#",
        "# guide / author / description   name and details shown in the Guides tab",
        "# based on: story or efficient    Story = every quest; Efficient = speedrun",
        "# rules: ...                      optional overrides (see the README)",
        "# [1-10]                          a level band, followed by its zones:",
        "#   alliance: Zone, Zone          zones for Alliance (START = racial start zone)",
        "#   horde: Zone, Zone             zones for Horde",
        "#   both: Zone                    zones for both factions",
        "#   note: text                    a tip shown for this band",
        "# skip quests: 123, 456           quest IDs the guide never picks up",
        "# priority quests: 789            quest IDs picked up before anything else",
        "# step 12 buy: text               a reminder at a level (train, buy, note, hearth)",
        "",
        "guide: " .. (name or "My Guide"),
        "based on: efficient",
        "",
        "[1-10]",
        "both: START",
        "",
        "[11-60]",
        "alliance: Westfall",
        "horde: The Barrens",
        "",
    }, "\n")
end
