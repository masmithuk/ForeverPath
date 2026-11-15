-- The guide text format: parsing, validation, safety and round trips.

local VALID = [[
# A comment
guide: Hillsbrad Rush
author: Mike
description: My fastest Horde route.
based on: efficient
rules: greyGap=3 maxDetour=200

[1-10]
both: start
note: Talents open at level 10.

[11-60]
alliance: Westfall, Loch Modan
horde: The Barrens, Silverpine Forest

skip quests: 123, 456
priority quests: 789
step 12 buy: Buy bags before leaving town.
step 14 train: Visit your trainer.
]]

local function messages(list)
    local out = {}
    for _, m in ipairs(list) do
        out[#out + 1] = (m.line and ("L" .. m.line .. " ") or "") .. m.message
    end
    return table.concat(out, " | ")
end

local function parse(ns, text)
    return ns.GuideFormat.Parse(text)
end

return {
    { "parses every part of a guide", function(T)
        local ns = T.fresh()
        local g, errors = parse(ns, VALID)
        T.truthy(g, "parsed: " .. messages(errors))
        T.eq(g.name, "Hillsbrad Rush")
        T.eq(g.author, "Mike")
        T.eq(g.base, "efficient")
        T.eq(g.rules.greyGap, 3, "explicit rule")
        T.eq(g.rules.maxDetour, 200)
        T.eq(g.rules.levelsAbove, 2, "default from the efficient base")
        T.eq(#g.bands, 2)
        T.eq(g.bands[1].Alliance[1], "START", "START is case-insensitive")
        T.eq(g.bands[1].notes[1], "Talents open at level 10.")
        T.eq(g.bands[2].Horde[2], "Silverpine Forest")
        T.eq(table.concat(g.skipQuests, ","), "123,456")
        T.eq(g.priorityQuests[1], 789)
        T.eq(g.steps[1].kind, "BUY")
        T.eq(g.steps[2].kind, "TRAIN")
        T.eq(g.steps[2].level, 14)
    end },

    { "Story base supplies Story's rules", function(T)
        local ns = T.fresh()
        local g = parse(ns, "guide: X\nbased on: story\n[1-60]\nboth: Durotar\n")
        T.eq(g.rules.chainBonus, 150)
        T.eq(g.rules.greyGap, 10)
    end },

    { "write then parse gives the same guide", function(T)
        local ns = T.fresh()
        local g = parse(ns, VALID)
        local text = ns.GuideFormat.Write(g)
        local again = parse(ns, text)
        T.eq(ns.GuideFormat.Write(again), text)
        T.eq(#again.steps, 2)
        T.eq(again.rules.maxDetour, 200)
    end },

    { "errors carry line numbers", function(T)
        local ns = T.fresh()
        local g, errors = parse(ns, "guide: X\n[1-60]\nboth: Durotar\nhordee: Oops\nrules: speed=9\n")
        T.eq(g, nil)
        local text = messages(errors)
        T.contains(text, 'L4 Unknown setting "hordee"')
        T.contains(text, 'L5 Unknown rule "speed=9"')
    end },

    { "level bands must cover 1-60 without gaps or overlaps", function(T)
        local ns = T.fresh()
        local _, errors = parse(ns, "guide: X\n[1-10]\nboth: A\n[15-60]\nboth: B\n")
        T.contains(messages(errors), "Levels 11-14 aren't covered")
        _, errors = parse(ns, "guide: X\n[1-10]\nboth: A\n[8-60]\nboth: B\n")
        T.contains(messages(errors), "overlaps")
        local g, _, warnings = parse(ns, "guide: X\n[1-30]\nboth: A\n")
        T.truthy(g, "a short guide is allowed")
        T.contains(messages(warnings), "Levels 31-60 aren't covered")
    end },

    { "each band needs zones for both factions", function(T)
        local ns = T.fresh()
        local _, errors = parse(ns, "guide: X\n[1-60]\nalliance: Westfall\n")
        T.contains(messages(errors), "needs zones for both factions")
    end },

    { "missing name, empty text and bad values are reported", function(T)
        local ns = T.fresh()
        local _, errors = parse(ns, "")
        T.contains(messages(errors), "empty")
        _, errors = parse(ns, "[1-60]\nboth: A\n")
        T.contains(messages(errors), "needs a name")
        _, errors = parse(ns, "guide: X\nbased on: chaos\nrules: greyGap=99\n[1-60]\nboth: A\n"
            .. "skip quests: 12, abc\nstep 70 note: hi\nstep 5 dance: hi\nnote: orphan\n")
        local text = messages(errors)
        T.contains(text, 'based on must be "story" or "efficient"')
        T.contains(text, "greyGap must be between 0 and 60")
        T.contains(text, '"abc" is not a quest ID')
        T.contains(text, "Step level must be 1-60")
        T.contains(text, "Step kind must be")
    end },

    { "notes must follow a band", function(T)
        local ns = T.fresh()
        local _, errors = parse(ns, "guide: X\nnote: too early\n[1-60]\nboth: A\n")
        T.contains(messages(errors), '"note:" must come after a [level-level] line')
    end },

    { "pasted text can't inject UI escape codes", function(T)
        local ns = T.fresh()
        local g, _, warnings = parse(ns,
            "guide: Evil |cffff0000Red|r |TInterface\\Icons\\X:0|t\n[1-60]\nboth: A|Hlink|h\n")
        T.truthy(g)
        T.truthy(not g.name:find("|", 1, true), "no pipes in the name")
        T.truthy(not g.bands[1].Alliance[1]:find("|", 1, true), "no pipes in zones")
        T.contains(messages(warnings), "isn't allowed")
    end },

    { "oversized guides are refused", function(T)
        local ns = T.fresh()
        local _, errors = parse(ns, ("#" .. string.rep("x", 99) .. "\n"):rep(400))
        T.contains(messages(errors), "too long")
    end },

    { "Windows line endings and single-level bands work", function(T)
        local ns = T.fresh()
        local g, errors = parse(ns, "guide: X\r\n[1-59]\r\nboth: A\r\n[60]\r\nboth: Mount Hyjal\r\n")
        T.truthy(g, messages(errors))
        T.eq(g.bands[2].min, 60)
        T.eq(g.bands[2].max, 60)
    end },

    { "the new-guide template is itself a valid guide", function(T)
        local ns = T.fresh()
        local g, errors, warnings = parse(ns, ns.GuideFormat.Template("Mine"))
        T.truthy(g, messages(errors))
        T.eq(#warnings, 0, "no warnings: " .. messages(warnings))
        T.eq(g.name, "Mine")
    end },
}
