-- Data integrity: catches typos and gaps when the data files are edited.

return {
    { "every route covers levels 1-60 with no gaps or overlaps", function(T)
        local ns = T.fresh()
        for id, route in pairs(ns.Data.Routes) do
            local expected = 1
            for i, b in ipairs(route.bands) do
                T.eq(b.min, expected, id .. " band " .. i .. " min")
                T.truthy(b.max >= b.min, id .. " band " .. i .. " max >= min")
                T.truthy(#b.Alliance > 0 and #b.Horde > 0, id .. " band " .. i .. " has zones")
                expected = b.max + 1
            end
            T.eq(expected - 1, 60, id .. " ends at 60")
        end
    end },

    { "route order lists every route exactly once", function(T)
        local ns = T.fresh()
        local seen, count = {}, 0
        for _, id in ipairs(ns.Data.RouteOrder) do
            T.truthy(ns.Data.Routes[id], "route exists: " .. id)
            T.truthy(not seen[id], "no duplicate: " .. id)
            seen[id] = true
        end
        for _ in pairs(ns.Data.Routes) do count = count + 1 end
        T.eq(#ns.Data.RouteOrder, count, "route count")
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
            T.truthy(ns.Data.Routes[c.defaultRoute], file .. " default route exists")
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
