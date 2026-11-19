-- Questwalker's own arrow: journey planning and directions.

local fixtures = require("fixtures")

local function w(x, y, c) return { continent = c or 1, x = x, y = y } end
local function place(name, x, y, c) return { name = name, world = w(x, y, c) } end

return {
    { "short trips are walked", function(T)
        local ns = T.fresh()
        local plan = ns.Travel.Plan(w(0, 0), place("Step", 300, 0), {})
        T.eq(#plan.legs, 1); T.eq(plan.legs[1].kind, "walk")
        T.truthy(math.abs(plan.seconds - 300 / ns.Travel.RUN_SPEED) < 1e-6)
    end },

    { "long trips use flight paths you know", function(T)
        local ns = T.fresh()
        local flights = { place("Here FM", 100, 0), place("There FM", 4900, 0) }
        local plan = ns.Travel.Plan(w(0, 0), place("Step", 5000, 0), { flights = flights })
        T.eq(plan.legs[1].kind, "walk"); T.eq(plan.legs[1].to.name, "Here FM")
        T.eq(plan.legs[2].kind, "fly"); T.eq(plan.legs[2].to.name, "There FM")
        T.eq(plan.legs[3].kind, "walk")
        local walkOnly = ns.Travel.Plan(w(0, 0), place("Step", 5000, 0), {})
        T.truthy(plan.seconds < walkOnly.seconds)
    end },

    { "a ready hearthstone near the step wins", function(T)
        local ns = T.fresh()
        local plan = ns.Travel.Plan(w(0, 0), place("Step", 6000, 0), { hearth = place("Inn", 5950, 0) })
        T.eq(plan.legs[1].kind, "hearth")
        T.eq(plan.legs[2].kind, "walk")
        local near = ns.Travel.Plan(w(0, 0), place("Step", 100, 0), { hearth = place("Inn", 5950, 0) })
        T.eq(near.legs[1].kind, "walk", "not for a short walk")
    end },

    { "other continents: the boat or zeppelin", function(T)
        local ns = T.fresh()
        local transports = { { ride = "zeppelin", a = place("Org tower", 500, 0, 1), b = place("Tirisfal tower", 0, 0, 0) } }
        local plan = ns.Travel.Plan(w(0, 0, 1), place("Step", 200, 0, 0), { transports = transports })
        T.eq(plan.legs[1].to.name, "Org tower")
        T.eq(plan.legs[2].kind, "ride"); T.eq(plan.legs[2].to.name, "Tirisfal tower")
        T.eq(plan.legs[3].kind, "walk")
        T.eq(ns.Travel.Plan(w(0, 0, 1), place("Step", 0, 0, 0), {}), nil, "no way across")
    end },

    { "sat-nav instructions", function(T)
        local ns = T.fresh()
        local L, deg = ns.L, math.pi / 180
        T.eq(ns.Navigator.Instruction(5 * deg, 300), L.NAV_STRAIGHT)
        T.eq(ns.Navigator.Instruction(-40 * deg, 300), L.NAV_BEAR_LEFT)
        T.eq(ns.Navigator.Instruction(90 * deg, 300), L.NAV_TURN_RIGHT)
        T.eq(ns.Navigator.Instruction(170 * deg, 300), L.NAV_TURN_AROUND)
        T.eq(ns.Navigator.Instruction(170 * deg, 20), L.NAV_ARRIVING)
        T.eq(ns.Navigator.Instruction(0, 5), L.NAV_ARRIVED)
        T.eq(ns.Navigator.Eta(33), "about 35 sec")
        T.eq(ns.Navigator.Eta(200), "about 3 min")
    end },

    { "guides you to the current step in game", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        mock.player.facing = math.pi / 2 -- west
        local state = fixtures.login(ns)
        T.truthy(ns.Navigator.IsShown(), "shown with no arrow addon")
        local view = ns.Navigator.view
        T.truthy(view and view.main ~= "", "an instruction")
        T.contains(view.distance, "yd")
        T.eq(view.detail, state.steps[1].title)
    end },

    { "remembers flight masters from the flight map", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Npc[1010] = { name = "Doras", subName = "Wind Rider Master", friendlyToFaction = "H",
            spawns = { [14] = { { 45, 12 } } } }
        fixtures.login(ns)
        _G.UnitGUID = function(unit) return unit == "npc" and "Creature-0-1-1-1-1010-0" or "Player-1" end
        ns:FireEvent("TAXIMAP_OPENED")
        T.truthy(QuestwalkerCharDB.guide.flights[1010], "the one you talked to")
        local opts = ns.Navigator.Options()
        T.eq(#opts.flights, 1); T.eq(opts.flights[1].name, "Doras")
    end },
}
