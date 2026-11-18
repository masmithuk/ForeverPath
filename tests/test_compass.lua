-- The compass bar: directions, step markers and party members.
-- Mock maps: world x grows east, world y grows south (1000 yards a zone).

local fixtures = require("fixtures")

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function at(x, y) return { continent = 1, x = x, y = y } end

local function find(layout, kind, label)
    for _, m in ipairs(layout.markers) do
        if m.kind == kind and m.label == label then return m end
    end
    return nil
end

return {
    { "bearings: north is 0, then clockwise", function(T)
        local ns = T.fresh()
        local axes = ns.Compass.Axes(1411)
        T.truthy(axes, "axes from the map")
        local here = at(500, 500)
        T.truthy(near(ns.Compass.Bearing(here, at(500, 400), axes), 0), "north")
        T.truthy(near(ns.Compass.Bearing(here, at(600, 500), axes), math.pi / 2), "east")
        T.truthy(near(ns.Compass.Bearing(here, at(500, 600), axes), math.pi), "south")
        T.truthy(near(ns.Compass.Bearing(here, at(400, 500), axes), 3 * math.pi / 2), "west")
        T.eq(ns.Compass.Bearing(here, { continent = 0, x = 1, y = 1 }, axes), nil, "other continent")
    end },

    { "facing west, north is on your right", function(T)
        local ns = T.fresh()
        local west = math.pi / 2 -- the game's facing turns anticlockwise
        T.truthy(near(ns.Compass.Relative(0, west), math.pi / 2), "north to the right")
        T.truthy(near(ns.Compass.Relative(3 * math.pi / 2, west), 0), "west ahead")
        T.truthy(near(ns.Compass.Relative(math.pi, west), -math.pi / 2), "south to the left")
    end },

    { "directions slide across the bar", function(T)
        local ns = T.fresh()
        local layout = ns.Compass.Layout({}, { mapID = 1411, world = at(500, 500) }, 0, {}, 100)
        local where = {}
        for _, d in ipairs(layout.directions) do where[d.label] = d.offset end
        T.truthy(near(where.N, 0), "N in the middle")
        T.truthy(near(where.E, 100) and near(where.W, -100), "E right, W left")
        T.truthy(near(where.NE, 50))
        T.eq(where.S, nil, "S is behind you")
    end },

    { "steps are numbered; the current one waits at the edge when behind you", function(T)
        local ns = T.fresh()
        local steps = {
            { title = "Turn in", target = { world = at(500, 600) } },  -- south: behind
            { title = "Kill", target = { world = at(600, 400) } },     -- north-east
            { title = "Far behind", target = { world = at(450, 700) } },
        }
        local layout = ns.Compass.Layout(steps, { mapID = 1411, world = at(500, 500) }, 0, {}, 100)
        local first, second = find(layout, "step", "1"), find(layout, "step", "2")
        T.truthy(first and first.current and first.edge, "1 at an edge")
        T.truthy(second and near(second.offset, 50), "2 at NE")
        T.truthy(near(second.distance, math.sqrt(2) * 100), "distance in yards")
        T.eq(find(layout, "step", "3"), nil, "later steps behind you aren't shown")
    end },

    { "party members show by name", function(T)
        local ns = T.fresh()
        local party = { { unit = "party1", name = "Thrall", class = "SHAMAN", world = at(600, 500) } }
        local layout = ns.Compass.Layout({}, { mapID = 1411, world = at(500, 500) }, 0, party, 100)
        local m = find(layout, "party", "Thrall")
        T.truthy(m and near(m.offset, 100), "east of you")
    end },

    { "the bar follows the plan and the party in game, and can be turned off", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        mock.player.facing = math.pi / 2 -- west, towards Zureetha
        mock.party.party1 = { name = "Rokhan", class = "HUNTER", position = { mapID = 1411, x = 0.4, y = 0.5 } }
        local state = fixtures.login(ns)
        ns.Compass.Draw()
        local layout = ns.Compass.Shown()
        T.truthy(layout, "shown by default")
        T.truthy(#layout.directions > 0)
        T.truthy(find(layout, "party", "Rokhan"), "party member")
        local one = find(layout, "step", "1")
        T.truthy(one, "current step: " .. tostring(state.steps[1] and state.steps[1].title))
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_COMPASS", false)
        T.eq(ns.Compass.Shown(), nil, "off")
        ns.SettingsTab.Click("SETTING_COMPASS", true)
        T.truthy(ns.Compass.Shown(), "back on")
    end },

    { "no position (an instance): an empty bar, no errors", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        mock.player.facing = nil
        fixtures.login(ns)
        ns.Compass.Draw()
        local layout = ns.Compass.Shown()
        T.eq(layout and #layout.markers, 0)
    end },
}
