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
}
