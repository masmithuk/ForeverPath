-- Data integrity: catches typos and gaps when the data files are edited.

return {
    { "built-in guides are valid and cover levels 1-60", function(T)
        local ns = T.fresh()
        T.eq(#ns.Data.BuiltinGuides, 2, "Story and Efficient")
        for _, def in ipairs(ns.Data.BuiltinGuides) do
            local guide = ns.Library.Get(def.id)
            local errors, warnings = {}, {}
            ns.GuideFormat.Validate(guide, errors, warnings)
            T.eq(#errors, 0, def.id .. " errors: " .. tostring(errors[1] and errors[1].message))
            T.eq(#warnings, 0, def.id .. " warnings")
            T.eq(guide.bands[#guide.bands].max, 60, def.id .. " ends at 60")
        end
    end },

    { "built-in guides survive a round trip through the text format", function(T)
        local ns = T.fresh()
        for _, def in ipairs(ns.Data.BuiltinGuides) do
            local text = ns.Library.Text(def.id)
            local parsed, errors = ns.GuideFormat.Parse(text)
            T.truthy(parsed, def.id .. " parses: " .. tostring(errors[1] and errors[1].message))
            T.eq(ns.GuideFormat.Write(parsed), text, def.id .. " writes back identically")
            T.eq(#parsed.bands, #def.bands)
        end
    end },

    { "every class has complete advice and a valid default route", function(T)
        local ns = T.fresh()
        local n = 0
        for file, c in pairs(ns.Data.Classes) do
            n = n + 1
            for _, field in ipairs({ "name", "spec", "altSpec", "tier", "why" }) do
                T.truthy(type(c[field]) == "string" and c[field] ~= "", file .. "." .. field)
            end
            T.truthy(#c.tips > 0, file .. " has tips")
            T.truthy(ns.Library.Get(c.defaultRoute), file .. " default guide exists")
        end
        T.eq(n, 9, "nine classes")
    end },

    { "every race class is a known class", function(T)
        local ns = T.fresh()
        local function check(raceKey, classes)
            for classFile in pairs(classes) do
                T.truthy(ns.Data.Classes[classFile], raceKey .. " -> " .. classFile)
            end
        end
        for key, race in pairs(ns.Data.Races) do
            if race.classes then check(key, race.classes) end
            for _, classes in pairs(race.classesByFaction or {}) do check(key, classes) end
        end
    end },

    { "exactly six new combos on the original races", function(T)
        local ns = T.fresh()
        local count = 0
        for key, race in pairs(ns.Data.Races) do
            if key ~= "Skyborne" then
                for _, v in pairs(race.classes) do
                    if v == "new" then count = count + 1 end
                end
            end
        end
        T.eq(count, 6, "new combos")
    end },

    { "dungeon ranges are sane", function(T)
        local ns = T.fresh()
        for _, d in ipairs(ns.Data.Dungeons) do
            T.truthy(d.min >= 1 and d.max <= 60 and d.min <= d.max, d.name)
        end
    end },
}
