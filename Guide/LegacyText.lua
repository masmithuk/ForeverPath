--[[
    ForeverPath - Guide/LegacyText.lua

    Reads the plain-text guide format used by ForeverPath 0.6, so guides
    saved or shared with that version still load. New guides are JSON
    (see Guide/GuideFormat.lua); nothing writes this format any more.

    0.6's "priority quests" become the start of the guide's quest list.
]]

local _, ns = ...

local LegacyText = {}
ns.LegacyText = LegacyText

local GuideFormat -- resolved at call time (load order)
local START = "START"
local MAX_LINE, MAX_LIST, MAX_ZONES, MAX_BANDS, MAX_STEPS = 500, 500, 20, 60, 100

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyRules(rules)
    local out = {}
    for k, v in pairs(rules) do out[k] = v end
    return out
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
    for _, item in ipairs(splitList(value, MAX_LIST)) do
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
    for _, z in ipairs(splitList(value, MAX_ZONES)) do
        zones[#zones + 1] = (z:upper() == START) and START or z
    end
    return zones
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

--- Does this look like a 0.6 text guide rather than JSON?
function LegacyText.Detect(text)
    return type(text) == "string" and text:match("^%s*{") == nil and text:find("guide:", 1, true) ~= nil
end

--- Parse 0.6 guide text into the current guide shape.
-- @return guide table, or nil; list of errors; list of warnings
function LegacyText.Parse(text)
    GuideFormat = ns.GuideFormat
    local errors, warnings = {}, {}
    if type(text) ~= "string" or trim(text) == "" then
        return nil, { { message = "The guide is empty." } }, warnings
    end
    if #text > 30000 then
        return nil, { { message = "The guide is too long." } }, warnings
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
        if #line > MAX_LINE then
            errors[#errors + 1] = { line = lineNo, message = "Line is too long." }
        elseif line ~= "" and not line:match("^#") and not line:match("^%-%-") then
            local a, b = line:match("^%[%s*(%d+)%s*%-%s*(%d+)%s*%]$")
            local single = line:match("^%[%s*(%d+)%s*%]$")
            if single then a, b = single, single end

            if a then
                if #guide.bands >= MAX_BANDS then
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
                        elseif #guide.steps >= MAX_STEPS then
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

    -- 0.6 "priority quests" open the quest list.
    guide.quests = {}
    for _, id in ipairs(guide.priorityQuests) do
        guide.quests[#guide.quests + 1] = { id = id }
    end
    guide.priorityQuests = nil

    GuideFormat.Validate(guide, errors, warnings)
    for _, b in ipairs(guide.bands) do b.line = nil end

    if #errors > 0 then return nil, errors, warnings end
    return guide, errors, warnings
end

