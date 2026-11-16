-- The guide schema: JSON in and out, checks, safety, and 0.6 text guides.

local VALID = [[
{
  "format": "Questwalker guide",
  "version": 2,
  "name": "Hillsbrad Rush",
  "author": "Mike",
  "description": "My fastest Horde route.",
  "basedOn": "efficient",
  "rules": { "greyGap": 3, "maxDetour": 200 },
  "quests": [ { "id": 788, "name": "Your Place In The World" }, 789 ],
  "bands": [
    { "levels": [1, 10], "zones": ["start"], "notes": ["Talents open at level 10."] },
    { "levels": [11, 60], "alliance": ["Westfall", "Loch Modan"], "horde": ["The Barrens"] }
  ],
  "skipQuests": [123, 456],
  "steps": [
    { "level": 12, "kind": "buy", "text": "Buy bags before leaving town." },
    { "level": 14, "kind": "Train", "text": "Visit your trainer." }
  ]
}
]]

local function messages(list)
    local out = {}
    for _, m in ipairs(list or {}) do out[#out + 1] = (m.path and (m.path .. " ") or "") .. m.message end
    return table.concat(out, " | ")
end

return {
    { "reads every part of a guide", function(T)
        local ns = T.fresh()
        local g, errors = ns.GuideFormat.FromJson(VALID)
        T.truthy(g, messages(errors))
        T.eq(g.name, "Hillsbrad Rush")
        T.eq(g.base, "efficient")
        T.eq(g.rules.greyGap, 3, "explicit rule")
        T.eq(g.rules.levelsAbove, 2, "default from the efficient base")
        T.eq(#g.quests, 2)
        T.eq(g.quests[1].name, "Your Place In The World")
        T.eq(g.quests[2].id, 789, "bare IDs are fine")
        T.eq(g.bands[1].Alliance[1], "START", "START is case-insensitive")
        T.eq(g.bands[1].Horde[1], "START", "zones = both factions")
        T.eq(g.bands[2].Horde[1], "The Barrens")
        T.eq(table.concat(g.skipQuests, ","), "123,456")
        T.eq(g.steps[2].kind, "TRAIN", "kinds are case-insensitive")
    end },

    { "export then import gives the same guide", function(T)
        local ns = T.fresh()
        local g = ns.GuideFormat.FromJson(VALID)
        local json = ns.GuideFormat.ToJson(g)
        local again = ns.GuideFormat.FromJson(json)
        T.eq(ns.GuideFormat.ToJson(again), json)
        T.contains(json, '"format": "Questwalker guide"')
        T.contains(json, '"levels": [1, 10]')
        T.truthy(not json:find('"levelsAbove"'), "rules equal to the base are left out")
    end },

    { "JSON syntax errors give line and column", function(T)
        local ns = T.fresh()
        local g, errors = ns.GuideFormat.FromJson('{\n  "name": "X",\n  "bands": [ }')
        T.eq(g, nil)
        T.contains(ns.GuideFormat.Describe(errors[1]), "Line 3, column")
    end },

    { "wrong types and values are reported by path", function(T)
        local ns = T.fresh()
        local _, errors = ns.GuideFormat.FromJson([[{
          "name": 5, "basedOn": "chaos", "rules": { "greyGap": 99, "speed": 2 },
          "quests": [ { "id": "abc" }, -4 ],
          "bands": [ { "levels": [1, 60], "zones": ["A"] } ],
          "steps": [ { "level": 70, "kind": "dance", "text": "" } ]
        }]])
        local text = messages(errors)
        T.contains(text, "name must be text")
        T.contains(text, 'basedOn must be "story" or "efficient"')
        T.contains(text, "rules.greyGap must be between 0 and 60")
        T.contains(text, "rules.speed isn't a known rule")
        T.contains(text, "quests[1].id must be a whole number")
        T.contains(text, "quests[2] must be between 1 and")
        T.contains(text, "steps[1].level must be between 1 and 60")
        T.contains(text, "steps[1].kind must be")
    end },

    { "level bands must cover 1-60 without gaps or overlaps", function(T)
        local ns = T.fresh()
        local function bands(json)
            return ns.GuideFormat.FromJson('{"name": "X", "bands": [' .. json .. ']}')
        end
        local _, errors = bands('{"levels": [1, 10], "zones": ["A"]}, {"levels": [15, 60], "zones": ["B"]}')
        T.contains(messages(errors), "levels 11-14 aren't covered")
        _, errors = bands('{"levels": [1, 10], "zones": ["A"]}, {"levels": [8, 60], "zones": ["B"]}')
        T.contains(messages(errors), "overlap")
        _, errors = bands('{"levels": [1, 60], "alliance": ["A"]}')
        T.contains(messages(errors), "need zones for both factions")
        local g, _, warnings = bands('{"levels": [1, 30], "zones": ["A"]}')
        T.truthy(g, "a short guide is allowed")
        T.contains(messages(warnings), "Levels 31-60 aren't covered")
    end },

    { "duplicates and unknown settings are cleaned up with a warning", function(T)
        local ns = T.fresh()
        local g, _, warnings = ns.GuideFormat.FromJson(
            '{"name": "X", "colour": "red", "quests": [5, 5], "bands": [{"levels": [1, 60], "zones": ["A"]}]}')
        T.eq(#g.quests, 1)
        local text = messages(warnings)
        T.contains(text, "listed twice")
        T.contains(text, "colour isn't a guide setting")
    end },

    { "pasted text can't inject UI escape codes", function(T)
        local ns = T.fresh()
        local g, _, warnings = ns.GuideFormat.FromJson(
            '{"name": "Evil |cffff0000Red|r", "bands": [{"levels": [1, 60], "zones": ["A|Hlink|h"]}]}')
        T.truthy(not g.name:find("|", 1, true), "no pipes in the name")
        T.truthy(not g.bands[1].Alliance[1]:find("|", 1, true), "no pipes in zones")
        T.contains(messages(warnings), 'contained "|"')
    end },

    { "0.6 text guides still import, priority quests becoming the quest list", function(T)
        local ns = T.fresh()
        local g, errors = ns.GuideFormat.FromJson(
            "guide: Old One\nbased on: story\n[1-60]\nboth: Durotar\npriority quests: 7, 8\nskip quests: 9\n")
        T.truthy(g, messages(errors))
        T.eq(g.name, "Old One")
        T.eq(g.base, "story")
        T.eq(g.quests[1].id, 7)
        T.eq(g.quests[2].id, 8)
        T.eq(g.skipQuests[1], 9)
    end },

    { "a new guide is valid as it stands", function(T)
        local ns = T.fresh()
        local g, errors, warnings = ns.GuideFormat.Check(ns.GuideFormat.NewGuide("Mine"))
        T.truthy(g, messages(errors))
        T.eq(#warnings, 0)
    end },

    { "empty input says what to do", function(T)
        local ns = T.fresh()
        local _, errors = ns.GuideFormat.FromJson("   ")
        T.contains(messages(errors), "paste a guide")
    end },
}
