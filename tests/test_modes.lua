-- The Story and Efficient guides, Shortest Path Forever routing and the Target button.

local fixtures = require("fixtures")

local function acceptLines(state)
    local lines = {}
    for _, s in ipairs(state.steps) do
        if s.kind == "ACCEPT" then
            for _, l in ipairs(s.lines) do lines[#lines + 1] = l end
        end
    end
    return lines
end

--- Extra fixture data: a far-flung quest and Wailing Caverns quests.
local function extend(mock, db)
    -- 112: giver is the Foreman, but its creatures live at the far edge.
    db.Quest[112] = { name = "Long Walk", startedBy = { { 1002 } }, requiredLevel = 4, questLevel = 6,
                      objectives = { { { 2002 } } } }
    db.Npc[2002] = { name = "Distant Boar", spawns = { [14] = { { 95, 95 } } } }
    -- 120/121: Wailing Caverns (17-24) quests from a giver in Mulgore,
    -- which none of the modes' level 11-20 zones include.
    mock.maps[1412] = { name = "Mulgore", areaID = 215, continent = 1, offset = 1000 }
    mock.maps[1454] = { name = "Orgrimmar", areaID = 1637, continent = 1, offset = 3000 }
    mock.areaNames = { [718] = "Wailing Caverns" }
    db.Quest[120] = { name = "Serpentbloom", startedBy = { { 1005 } }, requiredLevel = 14, questLevel = 18,
                      zoneOrSort = 718 }
    db.Quest[121] = { name = "Leaders of the Fang", startedBy = { { 1005 } }, requiredLevel = 14, questLevel = 18,
                      zoneOrSort = 718 }
    db.Npc[1005] = { name = "Apothecary Zamah", friendlyToFaction = "H", spawns = { [215] = { { 50, 50 } } } }
end

local function setup(T, mode, level, keepRates)
    local ns, mock = T.fresh()
    local db = fixtures.durotar(mock, { level = level or 8, mode = mode })
    extend(mock, db)
    -- Keep training out of the way of these tests.
    QuestwalkerCharDB.guide.trainedLevel = 60
    -- The XP-per-minute rules have tests of their own (below).
    if not keepRates then
        for _, g in ipairs(ns.Library.List()) do
            if g.builtin then g.rules.minRate, g.rules.rateBonus = 0, 0 end
        end
    end
    return ns, mock, db
end

local function fakeShortestPath(mock, version, accept)
    local api = { version = version or 2, routes = {}, cancelled = 0 }
    function api.NavigateRoute(owner, stops)
        if accept == false or mock.inCombat then return false end
        api.routes[#api.routes + 1] = { owner = owner, stops = stops }
        return true
    end
    function api.Cancel() api.cancelled = api.cancelled + 1; return true end
    _G.ShortestPathForever = { API = api }
    return api
end

return {
    ---------------------------------------------------------------------
    -- Modes
    ---------------------------------------------------------------------
    { "Efficient skips low-value and out-of-the-way quests", function(T)
        local ns = setup(T, "efficient", 6)
        local state = fixtures.login(ns)
        local lines = table.concat(acceptLines(state), "|")
        T.contains(lines, "Vile Familiars", "level 5 quest at level 6 is fine")
        T.truthy(not lines:find("Long Walk"), "objective 600+ yd from its giver skipped")
        T.truthy(not lines:find("Grey Quest"), "grey quest skipped")
    end },

    { "Story keeps detours but skips grey quests", function(T)
        local ns = setup(T, "story", 6)
        local state = fixtures.login(ns)
        local lines = table.concat(acceptLines(state), "|")
        T.contains(lines, "Long Walk", "no detour limit")
        T.truthy(not lines:find("Grey Quest"), "grey side quests are pointless")
    end },

    { "Story takes quest chains before stand-alone side quests", function(T)
        local ns = setup(T, "story", 6)
        local state = fixtures.login(ns)
        -- Zureetha (50 yd) starts a chain (101 -> 103); the Foreman (20 yd)
        -- only has stand-alone side quests.
        T.eq(state.steps[1].title, "Talk to Zureetha Fargaze")
        T.truthy(ns.QuestieData.IsChainQuest(101), "101 leads on to 103")
        T.truthy(not ns.QuestieData.IsChainQuest(102), "102 stands alone")
        T.truthy(fixtures.findStep(state, "accept:npc:1002"), "side quests still on offer, just later")
    end },

    { "Speedrun takes the nearest worthwhile quests, chain or not", function(T)
        local ns = setup(T, "efficient", 6)
        local state = fixtures.login(ns)
        T.eq(state.steps[1].title, "Talk to Foreman Thazz'ril")
    end },

    { "Story follows a chain before nearer unrelated quests", function(T)
        local ns, mock = setup(T, "story")
        mock.completed[101] = true
        local state = fixtures.login(ns)
        -- Zureetha (50 yd, follow-up 103) beats the Foreman (20 yd).
        T.eq(state.steps[1].title, "Talk to Zureetha Fargaze")
        T.contains(state.steps[1].lines, "Accept: Burning Blade Medallion")
    end },

    { "Efficient doesn't add a chain bonus", function(T)
        local ns, mock = setup(T, "efficient", 6)
        mock.completed[101] = true
        local state = fixtures.login(ns)
        T.eq(state.steps[1].title, "Talk to Foreman Thazz'ril")
    end },

    { "dungeon quests in your log merge into one Run step", function(T)
        local ns, mock = setup(T, "story", 16)
        fixtures.addToLog(mock, 120, "Serpentbloom", false)
        fixtures.addToLog(mock, 121, "Leaders of the Fang", false)
        local state = fixtures.login(ns)
        local run = fixtures.findStep(state, "dungeon:dungeon:wailing caverns")
        T.truthy(run, "one Run step")
        T.eq(run.title, "Run Wailing Caverns")
        T.eq(#run.questIDs, 2)
        T.contains(run.lines, "  Entrance: The Barrens")
    end },

    ---------------------------------------------------------------------
    -- Shortest Path Forever
    ---------------------------------------------------------------------
    { "Shortest Path Forever gets the next steps as one held route", function(T)
        local ns, mock = setup(T, "story")
        mock.installTomTom()
        local spf = fakeShortestPath(mock)
        fixtures.login(ns)
        T.eq(#spf.routes, 1, "one journey")
        local route = spf.routes[1]
        T.eq(route.owner, "Questwalker")
        T.truthy(#route.stops >= 2, "several stops")
        T.eq(route.stops[1].hold, true, "waits at the current step")
        T.eq(route.stops[2].hold, nil)
        T.eq(route.stops[1].kind, "pickup")
        T.eq(#mock.tomtom.waypoints, 0, "preferred over TomTom")
    end },

    { "identical routes aren't re-sent", function(T)
        local ns, mock = setup(T, "story")
        local spf = fakeShortestPath(mock)
        fixtures.login(ns)
        ns:FireEvent("QUEST_LOG_UPDATE")
        ns:FireEvent("QUEST_LOG_UPDATE")
        T.eq(#spf.routes, 1)
    end },

    { "a route refused in combat is sent when combat ends", function(T)
        local ns, mock = setup(T, "story")
        local spf = fakeShortestPath(mock)
        mock.inCombat = true
        fixtures.login(ns)
        T.eq(#spf.routes, 0, "refused in combat")
        mock.inCombat = false
        ns:FireEvent("PLAYER_REGEN_ENABLED")
        T.eq(#spf.routes, 1, "sent after combat")
    end },

    { "unknown Shortest Path API versions fall back to TomTom", function(T)
        local ns, mock = setup(T, "story")
        mock.installTomTom()
        local spf = fakeShortestPath(mock, 3)
        fixtures.login(ns)
        T.eq(#spf.routes, 0)
        T.eq(#mock.tomtom.waypoints, 1)
    end },

    { "turn-in stops tell Shortest Path which quests are handed in", function(T)
        local ns = setup(T, "story")
        local stops = ns.Waypoints.BuildStops({
            { kind = "TURNIN", title = "Turn in", questIDs = { 7 },
              target = { mapID = 1411, x = 0.1, y = 0.2 } },
            { kind = "NOTE", title = "No location", questIDs = {} },
        })
        T.eq(#stops, 1, "steps without a location are left out")
        T.eq(stops[1].handins[1], 7)
        T.eq(stops[1].kind, "turnin")
    end },

    ---------------------------------------------------------------------
    -- Target button
    ---------------------------------------------------------------------
    { "Target button targets the nearest creature for your objectives", function(T)
        local ns, mock = setup(T, "story")
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        fixtures.login(ns)
        ns.Engine.FocusQuest(101)
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Vile Familiar")
        T.truthy(QuestwalkerTargetButton:IsShown())
        T.contains(QuestwalkerTargetButton:GetText(), "Vile Familiar")
    end },

    { "finished kill objectives and hand-ins aren't targeted", function(T)
        local ns, mock = setup(T, "story")
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        mock.questLog[1].objectives = nil
        -- Report the kill objective as finished.
        local getObjectives = _G.C_QuestLog.GetQuestObjectives
        _G.C_QuestLog.GetQuestObjectives = function(id)
            if id == 101 then return { { text = "Vile Familiar slain: 8/8", finished = true } } end
            return getObjectives(id)
        end
        fixtures.login(ns)
        T.eq(ns.TargetButton.GetMacro(), "")
        T.truthy(not QuestwalkerTargetButton:IsShown(), "hidden with nothing to target")
    end },

    { "creatures that drop quest items are targeted", function(T)
        local ns, mock = setup(T, "story")
        mock.db.Item[5001] = { name = "Familiar Fang", npcDrops = { 2002 } }
        mock.db.Quest[101].objectives = { nil, nil, { { 5001 } } }
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Familiar Fang: 0/4" })
        fixtures.login(ns)
        ns.Engine.FocusQuest(101)
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Distant Boar")
    end },

    { "the Target button only changes outside combat", function(T)
        local ns, mock = setup(T, "story")
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        fixtures.login(ns)
        ns.Engine.FocusQuest(101)
        mock.inCombat = true
        mock.db.Quest[101].objectives = { { { 2002 } } }
        ns.QuestieData.Reset()
        ns.Engine.Replan()
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Vile Familiar", "unchanged in combat")
        mock.inCombat = false
        ns:FireEvent("PLAYER_REGEN_ENABLED")
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Distant Boar", "applied after combat")
    end },

    { "the Target button can be turned off in Settings", function(T)
        local ns, mock = setup(T, "story")
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        fixtures.login(ns)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_TARGET", false)
        T.eq(QuestwalkerDB.targetButton, false)
        T.truthy(not QuestwalkerTargetButton:IsShown())
    end },

    ---------------------------------------------------------------------
    -- Speedrun: XP for the time it takes
    ---------------------------------------------------------------------
    { "Speedrun skips quests that pay badly for the time they take", function(T)
        local ns, _, db = setup(T, "efficient", 23, true)
        -- Four quick level 23 errands at the Foreman, and one level 20 quest
        -- that sends you far away to collect 20 drops for little XP.
        for id = 140, 143 do
            db.Quest[id] = { name = "Quick Errand " .. id, startedBy = { { 1002 } }, finishedBy = { { 1002 } },
                             requiredLevel = 18, questLevel = 23 }
        end
        db.Npc[2010] = { name = "Far Stalker", minLevel = 20, spawns = { [14] = { { 95, 5 } } } }
        db.Item[9001] = { name = "Stalker Hide", npcDrops = { 2010 } }
        db.Quest[150] = { name = "Slow Hides", startedBy = { { 1002 } }, finishedBy = { { 1001 } },
                          requiredLevel = 18, questLevel = 21, objectivesText = { "Bring me 20 Stalker Hides." },
                          objectives = { nil, nil, { { 9001 } } } }
        local state = fixtures.login(ns)
        local offered = table.concat(acceptLines(state), "|")
        T.contains(offered, "Quick Errand")
        T.truthy(not offered:find("Slow Hides"), "not worth the time on Speedrun")
    end },

    { "Story still offers slow quests", function(T)
        local ns, _, db = setup(T, "story", 23, true)
        db.Quest[150] = { name = "Slow Hides", startedBy = { { 1002 } }, requiredLevel = 18, questLevel = 22,
                          objectivesText = { "Bring me 20 Stalker Hides." } }
        local state = fixtures.login(ns)
        T.contains(table.concat(acceptLines(state), "|"), "Slow Hides")
    end },

    { "quest value: XP, counts, work and the game's level adjustment", function(T)
        local ns, _, db = setup(T, "efficient", 23, true)
        local V = ns.QuestValue
        T.eq(table.concat(V.Counts("Bring 10 ghoul fangs, 10 skeleton fingers and 5 vials"), ","), "10,10,5")
        T.eq(V.AdjustXP(1000, 20, 23), 1000, "full XP within 5 levels")
        T.eq(V.AdjustXP(1000, 20, 28), 400, "less XP once the quest is well below you")
        T.eq(V.AdjustXP(1000, 20, 40), 100, "never below a tenth")
        T.eq(V.Median({ 5, 1, 3 }), 3)
        T.eq(V.Median({ 1, 2, 3, 4 }), 2.5)
        -- Elite kills cost more time than normal ones.
        db.Npc[2001].rank = 1
        local elite = V.WorkSeconds(101)
        db.Npc[2001].rank = 0
        T.truthy(elite > V.WorkSeconds(101))
    end },

    { "Questie's XP table is used once Questie has started", function(T)
        local ns = setup(T, "efficient", 23, true)
        _G.Questie = { started = true }
        _G.QuestieLoader = { ImportModule = function(_, name)
            if name == "QuestXP" then return { GetQuestLogRewardXP = function(_, id) return id == 101 and 1234 or 0 end } end
        end }
        T.eq(ns.QuestValue.XP(101, 23), 1234)
        T.truthy(ns.QuestValue.XP(102, 23) ~= nil, "estimate when the table has nothing")
    end },

    ---------------------------------------------------------------------
    -- Elites
    ---------------------------------------------------------------------
    { "an elite objective says how to solo it with nearby guards", function(T)
        local ns, mock, db = setup(T, "efficient", 23)
        db.Npc[2001].rank, db.Npc[2001].maxLevel = 1, 25
        db.Quest[101].questLevel, db.Quest[101].requiredLevel = 23, 18
        db.Npc[3010] = { name = "Razor Hill Grunt", friendlyToFaction = "H", spawns = { [14] = { { 58, 58 } } } }
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 0/8" })
        local state = fixtures.login(ns)
        local step = fixtures.findStep(state, "complete:101")
        T.contains(table.concat(step.lines, "|"), "Vile Familiar (level 25 elite): to solo it, pull it to the Razor Hill Grunt")
    end },

    { "an elite with no guards nearby suggests a group", function(T)
        local ns, mock, db = setup(T, "efficient", 23)
        db.Npc[2001].rank = 1
        db.Quest[101].questLevel, db.Quest[101].requiredLevel = 23, 18
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 0/8" })
        local state = fixtures.login(ns)
        T.contains(table.concat(fixtures.findStep(state, "complete:101").lines, "|"), "find a group")
    end },

    { "guard names are recognised", function(T)
        local ns = T.fresh()
        for _, n in ipairs({ "Stormwind City Guard", "Orgrimmar Grunt", "Darnassus Sentinel", "Deathguard Burgess" }) do
            T.truthy(ns.QuestieData.IsGuardName(n), n)
        end
        T.truthy(not ns.QuestieData.IsGuardName("Guardian of Blizzard"), "not a word inside another")
        T.truthy(not ns.QuestieData.IsGuardName("Kaltunk"))
    end },

    { "travel counts towards a quest's time", function(T)
        local ns, _, db = setup(T, "efficient", 23, true)
        db.Quest[160] = { name = "Next Door", startedBy = { { 1002 } }, finishedBy = { { 1002 } }, questLevel = 23 }
        db.Quest[161] = { name = "Far Away", startedBy = { { 1002 } }, finishedBy = { { 1002 } }, questLevel = 23,
                          objectives = { { { 2002 } } } } -- Distant Boar at the far edge
        T.eq(ns.QuestValue.TravelSeconds(160, "Horde"), 0)
        T.truthy(ns.QuestValue.TravelSeconds(161, "Horde") > 60, "there and back is a long walk")
    end },
}
