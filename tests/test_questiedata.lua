-- QuestieDB adapter: detection, indexing, eligibility and locations.

local fixtures = require("fixtures")

local function ctxFor(mock, extra)
    local ctx = {
        level = mock.player.level,
        log = {},
        isCompleted = function(id) return mock.completed[id] == true end,
    }
    for k, v in pairs(extra or {}) do ctx[k] = v end
    return ctx
end

local function indexed(ns)
    local profile = ns.Character.Detect()
    ns.QuestieData.BuildIndex(profile, function(fn) fn() end)
    return profile
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

return {
    { "reports QuestieDB missing or incompatible", function(T)
        local ns, mock = T.fresh()
        T.eq(ns.QuestieData.Detect(), "missing")
        mock.installQuestieDB({}, false)
        ns.QuestieData.Reset()
        T.eq(ns.QuestieData.Detect(), "incompatible")
    end },

    { "index keeps only quests for this race and class", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        indexed(ns)
        T.eq(ns.QuestieData.Status(), "ready")
        local ids = ns.QuestieData.GetCandidates(8)
        T.truthy(contains(ids, 101), "normal quest")
        T.truthy(not contains(ids, 105), "human-only quest hidden")
        T.truthy(not contains(ids, 106), "paladin-only quest hidden")
        T.truthy(not contains(ids, 111), "Skyborne-only quest hidden (2^33 mask)")
    end },

    { "level window drops grey and too-high quests", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        indexed(ns)
        local ids = ns.QuestieData.GetCandidates(8)
        T.truthy(not contains(ids, 108), "grey quest")
        T.truthy(not contains(ids, 109), "too high")
        T.truthy(not contains(ids, 104), "required level 10")
    end },

    { "prerequisites, completion and log state", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        indexed(ns)
        local ctx = ctxFor(mock)
        T.eq(ns.QuestieData.IsDoable(103, ctx), false, "needs 101 first")
        mock.completed[101] = true
        T.eq(ns.QuestieData.IsDoable(103, ctx), true, "unlocked")
        T.eq(ns.QuestieData.IsDoable(101, ctx), false, "already done")
        ctx.log[102] = { title = "Lazy Peons" }
        T.eq(ns.QuestieData.IsDoable(102, ctx), false, "already in log")
        T.eq(ns.QuestieData.IsDoable(107, ctx), false, "reputation requirement left out")
    end },

    { "Questie's own IsDoable wins when the full addon is loaded", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        _G.Questie = { started = true }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "QuestieDB" then return { IsDoable = function(id) return id == 107 end } end
        end }
        local ctx = ctxFor(mock)
        T.eq(ns.QuestieData.IsDoable(107, ctx), true, "Questie says yes")
        T.eq(ns.QuestieData.IsDoable(101, ctx), false, "Questie says no")
    end },

    { "quest givers are converted to map points and filtered by faction", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local starters = ns.QuestieData.GetStarters(101, "Horde")
        T.eq(#starters, 1)
        T.eq(starters[1].name, "Zureetha Fargaze")
        local p = starters[1].points[1]
        T.eq(p.mapID, 1411, "area 14 -> map 1411 by name")
        T.eq(p.x, 0.45)
        T.eq(#ns.QuestieData.GetStarters(110, "Horde"), 0, "Alliance-only giver hidden")
    end },

    { "Questie's ZoneDB is used for area lookups when present", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        _G.Questie = { started = true }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "ZoneDB" then
                return { GetUiMapIdByAreaId = function(_, area) return area == 14 and 9999 or nil end }
            end
        end }
        ns.ZoneMap.Reset()
        T.eq(ns.ZoneMap.ToUiMap(14), 9999)
        T.eq(ns.ZoneMap.ToUiMap(17), 1413, "falls back to names")
    end },

    { "instance placeholder coordinates are ignored", function(T)
        local ns = T.fresh()
        T.eq(ns.ZoneMap.ToMapPoint(14, -1, -1), nil)
    end },

    { "objective targets include creatures and item droppers", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Item[5001] = { name = "Tusk", npcDrops = { 2001 } }
        db.Quest[101].objectives = { { { 2001 } }, nil, { { 5001 } } }
        local targets = ns.QuestieData.GetObjectiveTargets(101)
        T.eq(#targets, 2)
        T.eq(targets[2].name, "Vile Familiar")
    end },

    { "class trainers are indexed by subname", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        indexed(ns)
        local trainers = ns.QuestieData.GetTrainers("Horde")
        T.eq(#trainers, 1)
        T.eq(trainers[1].name, "Mai'ah")
    end },

    ---------------------------------------------------------------------
    -- Questie still starting up (a fresh character right after login)
    ---------------------------------------------------------------------
    { "Questie's answers aren't used until it has started", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        _G.Questie = { started = false }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "QuestieDB" then return { IsDoable = function() return false end } end
            if name == "ZoneDB" then return { GetUiMapIdByAreaId = function() return nil end } end
        end }
        local ctx = ctxFor(mock)
        T.eq(ns.QuestieData.IsDoable(102, ctx), true, "own checks while Questie loads")
        _G.Questie.started = true
        T.eq(ns.QuestieData.IsDoable(102, ctx), false, "Questie's answer once started")
    end },

    { "sub-zone spawns (Valley of Trials) map to their zone", function(T)
        local ns = T.fresh()
        T.eq(ns.ZoneMap.ToUiMap(6451), 1411, "Valley of Trials -> Durotar")
        T.eq(ns.ZoneMap.ToUiMap(6453), 1411, "Echo Isles -> Durotar")
    end },

    { "a failed lookup while Questie loads is tried again later", function(T)
        local ns = T.fresh()
        local known = false
        _G.Questie = { started = false }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "ZoneDB" then
                return { GetUiMapIdByAreaId = function(_, area) return known and area == 9001 and 1411 or nil end }
            end
        end }
        T.eq(ns.ZoneMap.ToUiMap(9001), nil)
        _G.Questie.started, known = true, true
        T.eq(ns.ZoneMap.ToUiMap(9001), 1411, "not cached as unknown")
    end },

    { "a new troll gets the starter quest even while Questie is still loading", function(T)
        local ns, mock = T.fresh()
        _G.UnitRace = function() return "Troll", "Troll", 8 end
        local db = fixtures.durotar(mock, { level = 1 })
        ForeverPathCharDB.routeId = nil -- a brand-new character: default guide
        ForeverPathCharDB.guide.trainedLevel = 60
        db.Quest[4641] = { name = "Your Place In The World", startedBy = { { 10176 } }, finishedBy = { { 3143 } },
                           requiredLevel = 1, questLevel = 2 }
        db.Npc[10176] = { name = "Kaltunk", friendlyToFaction = "H", spawns = { [6451] = { { 43.3, 68.5 } } } }
        db.Npc[3143] = { name = "Gornek", friendlyToFaction = "H", spawns = { [6451] = { { 42, 68 } } } }
        _G.Questie = { started = false }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "QuestieDB" then return { IsDoable = function() return false end } end
            if name == "ZoneDB" then return { GetUiMapIdByAreaId = function() return nil end } end
        end }
        local state = fixtures.login(ns)
        T.eq(ns.Advisor.ResolveRouteId(ns.Character.Detect(), ForeverPathCharDB.routeId), "efficient",
            "speedrun guide by default")
        local titles = {}
        for i, s in ipairs(state.steps) do titles[i] = s.title end
        T.contains(titles, "Talk to Kaltunk", "found while Questie loads")

        -- Questie finishes starting; its real answers come in.
        _G.Questie.started = true
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "QuestieDB" then return { IsDoable = function(id) return id == 4641 end } end
            if name == "ZoneDB" then
                return { GetUiMapIdByAreaId = function(_, area) return (area == 14 or area == 6451) and 1411 or nil end }
            end
        end }
        ns.Engine._onTick()
        T.eq(ns.Engine.state.steps[1].title, "Talk to Kaltunk", "still there once Questie is ready")
    end },

    { "/fp debug reports what the guide sees", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        SlashCmdList.FOREVERPATH("debug")
        local out = table.concat(mock.printed, "\n")
        T.contains(out, "QuestieDB ready")
        T.contains(out, "Questie started: false")
        T.contains(out, "quests available now")
    end },
}
