-- Objectives in several places (three rifles on three bodies): every spot
-- still needed is shown, and the arrow heads for the nearest.

local fixtures = require("fixtures")

-- Three rifles, each from its own body, in Durotar (zone 14).
local function rifles(db)
    db.Object[3001] = { name = "Fallen Mountaineer", spawns = { [14] = { { 52, 50 } } } }
    db.Object[3002] = { name = "Frozen Mountaineer", spawns = { [14] = { { 60, 40 } } } }
    db.Object[3003] = { name = "Buried Mountaineer", spawns = { [14] = { { 40, 65 } } } }
    db.Item[4001] = { name = "Bingham's Rifle", objectDrops = { 3001 } }
    db.Item[4002] = { name = "Tormund's Rifle", objectDrops = { 3002 } }
    db.Item[4003] = { name = "Halvar's Rifle", objectDrops = { 3003 } }
    db.Quest[106].objectives = { nil, nil, { { 4001 }, { 4002 }, { 4003 } } }
end

local function stepFor(state, id)
    for _, s in ipairs(state.steps) do
        if s.kind == "COMPLETE" and s.questIDs[1] == id then return s end
    end
    return nil
end

return {
    { "all three rifles are shown, nearest first", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        rifles(db)
        fixtures.addToLog(mock, 106, "Treacherous Cold", false, {
            { text = "Bingham's Rifle: 0/1", finished = false },
            { text = "Tormund's Rifle: 0/1", finished = false },
            { text = "Halvar's Rifle: 0/1", finished = false },
        })
        local state = fixtures.login(ns)
        local step = stepFor(state, 106)
        T.truthy(step and step.targets, "several spots")
        T.eq(#step.targets, 3)
        T.eq(step.target.label, "Fallen Mountaineer", "the nearest (52, 50)")
    end },

    { "a rifle you've got is left out", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        rifles(db)
        fixtures.addToLog(mock, 106, "Treacherous Cold", false, {
            { text = "Bingham's Rifle: 1/1", finished = true },
            { text = "Tormund's Rifle: 0/1", finished = false },
            { text = "Halvar's Rifle: 0/1", finished = false },
        })
        local step = stepFor(fixtures.login(ns), 106)
        T.eq(#step.targets, 2)
        for _, t in ipairs(step.targets) do T.truthy(t.label ~= "Fallen Mountaineer") end
    end },

    { "one body with three spawns: each spawn, and visited ones drop off", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Object[3001] = { name = "Dead Mountaineer", spawns = { [14] = { { 50.5, 50 }, { 60, 40 }, { 40, 65 } } } }
        db.Item[4001] = { name = "Mountaineer's Rifle", objectDrops = { 3001 } }
        db.Quest[106].objectives = { nil, nil, { { 4001, 3 } } }
        fixtures.addToLog(mock, 106, "Treacherous Cold", false, { { text = "Mountaineer's Rifle: 0/3", finished = false } })
        local state = fixtures.login(ns) -- you're standing at (50, 50): the first body is visited
        local step = stepFor(state, 106)
        T.eq(#step.targets, 2, "the one you're at is done")
        T.truthy(step.target.x ~= 0.505)
    end },

    { "creatures you walk past stay on the list", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Npc[2001].spawns = { [14] = { { 50.5, 50 } } }      -- right next to you
        db.Npc[2002] = { name = "Bristleback", spawns = { [14] = { { 60, 40 } } } }
        db.Quest[106].objectives = { { { 2001, 4 }, { 2002, 4 } } }
        fixtures.addToLog(mock, 106, "Two Mobs", false, { { text = "Boar slain: 1/4", finished = false } })
        local step = stepFor(fixtures.login(ns), 106)
        T.eq(#step.targets, 2, "both kinds still needed")
    end },

    { "every spot is numbered on the world map", function(T)
        local ns = T.fresh()
        local step = { title = "Rifles", targets = {
            { mapID = 1411, x = 0.5, y = 0.5 }, { mapID = 1411, x = 0.6, y = 0.4 }, { mapID = 1411, x = 0.505, y = 0.5 },
        } }
        step.target = step.targets[1]
        local markers = ns.MapPins.Layout({ step }, 1411)
        T.eq(#markers, 2, "two close spots share a marker")
        T.eq(ns.MapPins.Label(markers[1].numbers), "1", "not '1, 1'")
    end },
}
