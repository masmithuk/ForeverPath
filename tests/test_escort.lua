-- Escort quests hold the guide; failed quests say to take them again.
-- Flight paths are learned from the whole flight map.

local fixtures = require("fixtures")

local function stepWithKind(state, kind)
    for i, s in ipairs(state.steps) do if s.kind == kind then return s, i end end
    return nil
end

return {
    { "an escort under way is the step, and the arrow waits", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Quest[106].objectivesText = { "Escort Corporal Keeshan back to Three Corners." }
        fixtures.addToLog(mock, 106, "Missing In Action", false, { { text = "Escort Corporal Keeshan", finished = false } })
        local state = fixtures.login(ns)
        local step, index = stepWithKind(state, "ESCORT")
        T.truthy(step, "escort step")
        T.eq(index, 1, "first")
        T.eq(step.title, "Escort Zureetha Fargaze")
        T.eq(#ns.Waypoints.BuildStops(state.steps), 0, "no arrow sending you off")
        T.truthy(not ns.GuideFrame.CurrentText(step):find(ns.L.GUIDE_NO_LOCATION, 1, true))
    end },

    { "once the escort is done, it's a normal hand-in", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Quest[106].objectivesText = { "Escort Corporal Keeshan back to Three Corners." }
        fixtures.addToLog(mock, 106, "Missing In Action", true)
        local state = fixtures.login(ns)
        T.eq(stepWithKind(state, "ESCORT"), nil)
        T.truthy(stepWithKind(state, "TURNIN"))
    end },

    { "ordinary quests aren't escorts", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        T.eq(ns.QuestieData.IsEscort(101), false)
    end },

    { "a failed quest: abandon it and take it again", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 106, "Missing In Action", false)
        _G.C_QuestLog.IsFailed = function(id) return id == 106 end
        local state = fixtures.login(ns)
        local step = stepWithKind(state, "FAILED")
        T.truthy(step, "failed step")
        T.eq(step.title, "Missing In Action failed")
        T.contains(step.lines[1], "Zureetha Fargaze")
    end },

    { "flight masters are learned from the flight map's nodes", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Npc[1010] = { name = "Ariena", subName = "Gryphon Master", friendlyToFaction = "AH",
            spawns = { [17] = { { 30, 60 } } } } -- The Barrens
        db.Npc[1011] = { name = "Dungar", subName = "Gryphon Master", friendlyToFaction = "AH",
            spawns = { [14] = { { 60, 40 } } } } -- Durotar
        fixtures.login(ns)
        _G.GetTaxiMapID = function() return 1413 end
        _G.C_TaxiMap = { GetAllTaxiNodes = function()
            return { { name = "Somewhere, Barrens", state = 1, position = { x = 0.302, y = 0.6 } } }
        end }
        ns:FireEvent("TAXIMAP_OPENED")
        local known = QuestwalkerCharDB.guide.flights
        T.truthy(known[1010], "by position")
        T.eq(known[1011], nil, "not on the map")
    end },

    { "without positions, short zone names still match", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Npc[1010] = { name = "Ariena", subName = "Gryphon Master", friendlyToFaction = "AH",
            spawns = { [17] = { { 30, 60 } } } }
        fixtures.login(ns)
        _G.C_TaxiMap = nil
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeName = function() return "Lakeshire, The Barr" end
        _G.TaxiNodeGetType = function() return "REACHABLE" end
        ns:FireEvent("TAXIMAP_OPENED")
        T.truthy(QuestwalkerCharDB.guide.flights[1010], "'The Barr' starts 'The Barrens'")
    end },
}
