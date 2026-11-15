-- Guide engine end to end: events in, steps and waypoints out.

local fixtures = require("fixtures")

local function hasKey(state, key)
    return fixtures.findStep(state, key) ~= nil
end

return {
    { "plans quest givers and the trainer in walking order", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local state = fixtures.login(ns)
        local titles = fixtures.titles(state)
        T.eq(titles[1], "Talk to Foreman Thazz'ril", "nearest first (20 yd)")
        T.eq(titles[2], "Train at Mai'ah", "then trainer (level 8 training due)")
        T.eq(titles[3], "Talk to Zureetha Fargaze")
        T.eq(#state.steps, 3, "ineligible quests left out")
    end },

    { "sets the built-in map pin when TomTom is absent", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        T.eq(mock.userWaypoint.uiMapID, 1411)
        T.eq(mock.userWaypoint.y, 0.52)
    end },

    { "uses TomTom when installed and swaps waypoints between steps", function(T)
        local ns, mock = T.fresh()
        local tt = mock.installTomTom()
        fixtures.durotar(mock)
        mock.completed[108] = true -- Story mode would keep us at the Foreman for it
        fixtures.login(ns)
        T.eq(#tt.waypoints, 1)
        T.eq(tt.waypoints[1].title, "Talk to Foreman Thazz'ril")
        T.eq(mock.userWaypoint, nil, "no built-in pin too")

        -- Accept the Foreman's quest: that step goes, the arrow moves on.
        fixtures.addToLog(mock, 102, "Lazy Peons", false, { "Peons awoken: 0/5" })
        ns:FireEvent("QUEST_ACCEPTED", 102)
        T.eq(#tt.removed, 1, "old waypoint removed")
        T.eq(tt.waypoints[#tt.waypoints].title, "Train at Mai'ah")
    end },

    { "accepted quests become objective steps with live progress", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        local state = fixtures.login(ns)
        local step = fixtures.findStep(state, "complete:101")
        T.truthy(step, "objective step")
        T.eq(step.lines[2], "  Vile Familiar slain: 2/8")
        T.eq(step.target.x, 0.6, "nearest familiar spawn from QuestieDB")
    end },

    { "Blizzard's quest waypoint beats QuestieDB for objectives", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        mock.questWaypoints[101] = { mapID = 1411, x = 0.3, y = 0.3 }
        local state = fixtures.login(ns)
        T.eq(fixtures.findStep(state, "complete:101").target.x, 0.3)
    end },

    { "turning in unlocks the follow-up quest", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.addToLog(mock, 101, "Vile Familiars", true)
        local state = fixtures.login(ns)
        T.truthy(hasKey(state, "turnin:npc:1001"), "turn-in step")
        T.truthy(not hasKey(state, "accept:npc:1001") or
            not fixtures.findStep(state, "accept:npc:1001").lines[1]:find("Medallion"), "follow-up not yet")

        fixtures.removeFromLog(mock, 101)
        ns:FireEvent("QUEST_TURNED_IN", 101) -- not yet flagged completed by the client
        state = ns.Engine.state
        local accept = fixtures.findStep(state, "accept:npc:1001")
        T.truthy(accept, "Zureetha has something new")
        T.contains(accept.lines, "Accept: Burning Blade Medallion")
    end },

    { "skip hides a quest until unskip", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local state = fixtures.login(ns)
        local skipped = ns.Engine.SkipCurrent()
        T.eq(skipped.title, "Talk to Foreman Thazz'ril")
        T.truthy(not hasKey(ns.Engine.state, "accept:npc:1002"), "gone")
        T.eq(ForeverPathCharDB.guide.skipped[102], true, "saved per character")
        ns.Engine.UnskipAll()
        T.truthy(hasKey(ns.Engine.state, "accept:npc:1002"), "back")
        T.truthy(state, "state")
    end },

    { "opening the class trainer clears the training step", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        mock.tradeskillTrainer = true
        ns:FireEvent("TRAINER_SHOW")
        T.truthy(hasKey(ns.Engine.state, "train:8"), "profession trainers don't count")
        mock.tradeskillTrainer = false
        ns:FireEvent("TRAINER_SHOW")
        T.truthy(not hasKey(ns.Engine.state, "train:8"), "trained")
        T.eq(ForeverPathCharDB.guide.trainedLevel, 8)
    end },

    { "training is due again two levels later", function(T)
        local ns = T.fresh()
        T.eq(ns.Sources.DueTrainingLevel(3, 0), nil, "too early")
        T.eq(ns.Sources.DueTrainingLevel(9, 0), 8)
        T.eq(ns.Sources.DueTrainingLevel(9, 8), nil, "up to date")
        T.eq(ns.Sources.DueTrainingLevel(10, 8), 10)
    end },

    { "class training is a step only when the trainer is near", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local state = fixtures.login(ns)
        T.truthy(hasKey(state, "train:8"), "Mai'ah is ~30 yards away")
        mock.player.position = { mapID = 1411, x = 0.05, y = 0.95 }
        ns.Engine.Replan()
        T.truthy(not hasKey(ns.Engine.state, "train:8"), "too far away - no step")
    end },

    { "set hearthstone when an innkeeper is near and it's bound elsewhere", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        db.Npc[3002] = { name = "Innkeeper Grosk", subName = "Innkeeper", friendlyToFaction = "H",
                         spawns = { [14] = { { 49, 49 } } } }
        local state = fixtures.login(ns)
        local step = fixtures.findStep(state, "hearth:npc:3002")
        T.truthy(step, "hearth step")
        T.contains(step.lines[1], "Razor Hill")
        mock.bindLocation = "Valley of Trials"
        ns:FireEvent("HEARTHSTONE_BOUND")
        T.truthy(not hasKey(ns.Engine.state, "hearth:npc:3002"), "bound here - step gone")
    end },

    { "skipping an inn keeps it skipped, and Back brings it back", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        ForeverPathCharDB.guide.trainedLevel = 60
        db.Npc[3002] = { name = "Innkeeper Grosk", subName = "Innkeeper", friendlyToFaction = "H",
                         spawns = { [14] = { { 50, 50 } } } }
        local state = fixtures.login(ns)
        T.eq(state.steps[1].key, "hearth:npc:3002", "standing next to the innkeeper")
        ns.Engine.SkipCurrent()
        T.truthy(not hasKey(ns.Engine.state, "hearth:npc:3002"))
        ns.Engine.Back()
        T.truthy(hasKey(ns.Engine.state, "hearth:npc:3002"))
    end },

    { "profession training follows the professions you've learned", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 12 })
        db.Npc[3003] = { name = "Miao'zan", subName = "Alchemy Trainer", friendlyToFaction = "H",
                         spawns = { [14] = { { 51, 51 } } } }
        db.Npc[3004] = { name = "Krunn", subName = "Mining Trainer", friendlyToFaction = "H",
                         spawns = { [14] = { { 51, 49 } } } }
        mock.skills = { { name = "Alchemy", skill = 70, max = 75 } }
        local state = fixtures.login(ns)
        T.truthy(hasKey(state, "profession:Alchemy:75"), "Alchemy 70/75, trainer nearby")
        T.truthy(not hasKey(state, "profession:Mining:75"), "you don't know Mining")
        mock.skills[1].max = 150
        ns:FireEvent("SKILL_LINES_CHANGED")
        T.truthy(not hasKey(ns.Engine.state, "profession:Alchemy:150"), "70/150 - not ready yet")
    end },

    { "profession rank rules", function(T)
        local ns = T.fresh()
        local need = ns.Sources.ProfessionNeedsTraining
        T.truthy(need({ skill = 50, max = 75 }, 10), "close to the cap")
        T.truthy(not need({ skill = 50, max = 75 }, 9), "Journeyman needs level 10")
        T.truthy(not need({ skill = 20, max = 75 }, 10), "far from the cap")
        T.truthy(not need({ skill = 140, max = 150 }, 19), "Expert needs level 20")
        T.truthy(need({ skill = 140, max = 150 }, 20))
        T.truthy(not need({ skill = 300, max = 300 }, 60), "maxed")
    end },

    { "without QuestieDB the guide still follows your quest log", function(T)
        local ns, mock = T.fresh()
        mock.player.level = 8
        fixtures.addToLog(mock, 900, "Something Old", false)
        mock.questWaypoints[900] = { mapID = 1411, x = 0.7, y = 0.7 }
        local state = fixtures.login(ns)
        T.eq(state.dataStatus, "missing")
        T.eq(state.steps[1].title, "Complete: Something Old")
        T.contains(ns.GuideFrame.StatusText(state.dataStatus, "auto"), "Install Questie")
    end },

    { "walking far re-orders the steps", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        ns.Engine.SetEnabled(true)
        -- Next to Zureetha now; the sticky current step is the Foreman,
        -- but skipping it should pick Zureetha, not the trainer.
        mock.player.position = { mapID = 1411, x = 0.44, y = 0.5 }
        mock.tickers[1].fn()
        ns.Engine.SkipCurrent()
        T.eq(ns.Engine.state.steps[1].title, "Talk to Zureetha Fargaze")
    end },

    { "turning the guide off clears the waypoint", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        SlashCmdList.FOREVERPATH("guide off")
        T.eq(mock.userWaypoint, nil)
        T.eq(#ns.Engine.state.steps, 0)
    end },

    { "waypoint command switches providers", function(T)
        local ns, mock = T.fresh()
        mock.installTomTom()
        fixtures.durotar(mock)
        fixtures.login(ns)
        SlashCmdList.FOREVERPATH("waypoints builtin")
        T.eq(ForeverPathDB.guide.waypoints, "builtin")
        T.eq(mock.userWaypoint.uiMapID, 1411)
        SlashCmdList.FOREVERPATH("waypoints sideways")
        T.contains(mock.printed[#mock.printed], "auto, shortestpath, tomtom, builtin, off")
    end },

    { "guide window renders the current step and distance", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local state = fixtures.login(ns)
        T.contains(ForeverPathGuideFrame.current:GetText(), "Talk to Foreman Thazz'ril")
        T.eq(ns.GuideFrame.FormatDistance(state.origin, state.steps[1]), "20 yd")
        T.contains(ns.GuideFrame.UpcomingText(state.steps), "2. Train at Mai'ah")
    end },

    { "objective progress doesn't redo the availability scan", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        local calls = 0
        local original = ns.QuestieData.IsDoable
        ns.QuestieData.IsDoable = function(...) calls = calls + 1; return original(...) end
        ns:FireEvent("QUEST_LOG_UPDATE")
        T.eq(calls, 0, "cached")
        ns:FireEvent("QUEST_ACCEPTED", 999)
        T.truthy(calls > 0, "recomputed after a real change")
    end },

    { "/fp done explains when nothing is manual", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock, { level = 3 })
        fixtures.login(ns)
        SlashCmdList.FOREVERPATH("done")
        T.contains(mock.printed[#mock.printed], "complete on their own")
    end },
}
