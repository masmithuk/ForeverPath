-- The three leveling modes, Shortest Path Forever routing and the Target button.

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

local function setup(T, mode, level)
    local ns, mock = T.fresh()
    local db = fixtures.durotar(mock, { level = level or 8, mode = mode })
    extend(mock, db)
    -- Keep training out of the way of these tests.
    ForeverPathCharDB.guide.trainedLevel = 60
    return ns, mock
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

    { "Story keeps everything, including detours and low quests", function(T)
        local ns = setup(T, "story", 6)
        local state = fixtures.login(ns)
        local lines = table.concat(acceptLines(state), "|")
        T.contains(lines, "Long Walk")
        T.contains(lines, "Grey Quest")
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

    { "Dungeon mode picks up dungeon quests anywhere", function(T)
        local ns = setup(T, "dungeon", 16)
        local state = fixtures.login(ns)
        local lines = table.concat(acceptLines(state), "|")
        T.contains(lines, "Serpentbloom (Wailing Caverns)")
        T.contains(lines, "Leaders of the Fang (Wailing Caverns)")
    end },

    { "other modes don't send you across the world for dungeon quests", function(T)
        local ns = setup(T, "story", 16)
        local state = fixtures.login(ns)
        T.truthy(not table.concat(acceptLines(state), "|"):find("Serpentbloom"))
    end },

    { "dungeon quests in your log merge into one Run step", function(T)
        local ns, mock = setup(T, "dungeon", 16)
        fixtures.addToLog(mock, 120, "Serpentbloom", false)
        fixtures.addToLog(mock, 121, "Leaders of the Fang", false)
        local state = fixtures.login(ns)
        local run = fixtures.findStep(state, "dungeon:dungeon:wailing caverns")
        T.truthy(run, "one Run step")
        T.eq(run.title, "Run Wailing Caverns")
        T.eq(#run.questIDs, 2)
        T.contains(run.lines, "  Entrance: The Barrens")
    end },

    { "Dungeon mode's guide browser lists dungeons and their quests", function(T)
        local ns = setup(T, "dungeon", 16)
        fixtures.login(ns)
        local ctx = ns.Engine.BuildContext()
        local guides = ns.Catalog.List(ctx.profile, "dungeon")
        T.eq(guides[1].isDungeon, true)
        T.eq(guides[1].min, 13, "lowest dungeons first")
        local overview = ns.Catalog.Overview("Wailing Caverns", ctx)
        T.eq(overview.total, 2)
        T.eq(overview.quests[1].giver, "Apothecary Zamah")
        T.contains(ns.GuidesTab.DetailText(guides[3], overview), "Entrance:")
    end },

    { "choosing a dungeon guide limits pickups to that dungeon", function(T)
        local ns = setup(T, "dungeon", 16)
        fixtures.login(ns)
        ns.Engine.SetGuide("Ragefire Chasm")
        T.truthy(not table.concat(acceptLines(ns.Engine.state), "|"):find("Wailing Caverns"))
        ns.Engine.SetGuide("Wailing Caverns")
        T.contains(table.concat(acceptLines(ns.Engine.state), "|"), "Serpentbloom")
    end },

    { "switching mode forgets the guide chosen in the old mode", function(T)
        local ns = setup(T, "story")
        fixtures.login(ns)
        ns.Engine.SetGuide("Durotar")
        ns.MainFrame.SetRoute("dungeon")
        T.eq(ForeverPathCharDB.guideId, nil)
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
        T.eq(route.owner, "ForeverPath")
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
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Vile Familiar")
        T.truthy(ForeverPathTargetButton:IsShown())
        T.contains(ForeverPathTargetButton:GetText(), "Vile Familiar")
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
        T.truthy(not ForeverPathTargetButton:IsShown(), "hidden with nothing to target")
    end },

    { "creatures that drop quest items are targeted", function(T)
        local ns, mock = setup(T, "story")
        mock.db.Item[5001] = { name = "Familiar Fang", npcDrops = { 2002 } }
        mock.db.Quest[101].objectives = { nil, nil, { { 5001 } } }
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Familiar Fang: 0/4" })
        fixtures.login(ns)
        T.eq(ns.TargetButton.GetMacro(), "/targetexact Distant Boar")
    end },

    { "the Target button only changes outside combat", function(T)
        local ns, mock = setup(T, "story")
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        fixtures.login(ns)
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
        T.eq(ForeverPathDB.targetButton, false)
        T.truthy(not ForeverPathTargetButton:IsShown())
    end },
}
