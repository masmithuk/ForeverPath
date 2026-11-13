-- Pure planner tests: merging and ordering without any game state.

local function step(key, kind, wx, wy, extra)
    local s = {
        key = key, kind = kind, title = key, lines = { key }, questIDs = { key },
        target = wx and { mapID = 1, x = 0, y = 0, world = { continent = 1, x = wx, y = wy } } or nil,
    }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

local function keys(list)
    local out = {}
    for i, s in ipairs(list) do out[i] = s.key end
    return table.concat(out, ",")
end

return {
    { "accepts at the same NPC merge into one step", function(T)
        local ns = T.fresh()
        local merged = ns.Planner.Merge({
            step("a", "ACCEPT", 0, 0, { actor = "npc:1" }),
            step("b", "ACCEPT", 0, 0, { actor = "npc:1" }),
            step("c", "ACCEPT", 0, 0, { actor = "npc:2" }),
            step("d", "TURNIN", 0, 0, { actor = "npc:1" }),
        })
        T.eq(#merged, 3, "three steps")
        T.eq(#merged[1].questIDs, 2, "both quests kept")
        T.eq(merged[1].lines[2], "b", "lines kept")
    end },

    { "merging doesn't modify the input steps", function(T)
        local ns = T.fresh()
        local a = step("a", "ACCEPT", 0, 0, { actor = "npc:1" })
        ns.Planner.Merge({ a, step("b", "ACCEPT", 0, 0, { actor = "npc:1" }) })
        T.eq(#a.questIDs, 1)
    end },

    { "orders by walking to the nearest remaining step", function(T)
        local ns = T.fresh()
        local origin = { continent = 1, x = 0, y = 0 }
        local ordered = ns.Planner.Order(origin, {
            step("far", "ACCEPT", 100, 0),
            step("near", "ACCEPT", 10, 0),
            step("middle", "ACCEPT", 50, 0),
        })
        T.eq(keys(ordered), "near,middle,far")
    end },

    { "the pinned step stays first", function(T)
        local ns = T.fresh()
        local origin = { continent = 1, x = 0, y = 0 }
        local ordered = ns.Planner.Order(origin, {
            step("far", "ACCEPT", 100, 0),
            step("near", "ACCEPT", 10, 0),
        }, "far")
        T.eq(keys(ordered), "far,near")
    end },

    { "turn-ins win close calls, other continents go last", function(T)
        local ns = T.fresh()
        local origin = { continent = 1, x = 0, y = 0 }
        local ordered = ns.Planner.Order(origin, {
            step("elsewhere", "ACCEPT", 1, 0, { target = { mapID = 2, x = 0, y = 0,
                world = { continent = 0, x = 1, y = 0 } } }),
            step("accept", "ACCEPT", 30, 0),
            step("turnin", "TURNIN", 60, 0),
            step("unknown", "COMPLETE"),
        })
        T.eq(ordered[1].key, "turnin", "turn-in bonus")
        T.eq(ordered[#ordered].key, "elsewhere", "other continent last")
    end },

    { "same spot ties break by kind: turn in before accepting", function(T)
        local ns = T.fresh()
        local ordered = ns.Planner.Order({ continent = 1, x = 0, y = 0 }, {
            step("z-accept", "ACCEPT", 100, 0),
            step("a-complete", "COMPLETE", 100, 0),
            step("m-turnin", "TURNIN", 160, 0),
        })
        T.eq(keys(ordered), "m-turnin,z-accept,a-complete")
    end },

    { "limit caps the number of steps", function(T)
        local ns = T.fresh()
        local list = {}
        for i = 1, 10 do list[i] = step("s" .. i, "ACCEPT", i, 0) end
        T.eq(#ns.Planner.Order({ continent = 1, x = 0, y = 0 }, list, nil, 4), 4)
    end },

    { "nearest point picks the closest spawn", function(T)
        local ns = T.fresh()
        local best = ns.Planner.Nearest({ continent = 1, x = 0, y = 0 }, {
            { world = { continent = 1, x = 50, y = 0 } },
            { world = { continent = 1, x = 5, y = 0 }, id = "close" },
        })
        T.eq(best.id, "close")
    end },

    { "flag check works above 32 bits (Skyborne race masks)", function(T)
        local ns = T.fresh()
        T.eq(ns.Util.HasFlag(8589934592, 8589934592), true, "2^33 set")
        T.eq(ns.Util.HasFlag(8589934592 + 16, 16), true, "low bit with high bit")
        T.eq(ns.Util.HasFlag(8589934592, 16), false, "unset")
        T.eq(ns.Util.HasFlag(nil, 16), false, "nil mask")
    end },
}
