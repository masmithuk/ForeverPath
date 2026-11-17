-- Guide engine end to end: events in, steps and waypoints out.

local fixtures = require("fixtures")

local function guideStatus()
    return QuestwalkerGuideFrame.status:GetText() or ""
end

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
        T.eq(QuestwalkerCharDB.guide.skipped[102], true, "saved per character")
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
        T.eq(QuestwalkerCharDB.guide.trainedLevel, 8)
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

    { "the hearthstone goes to the inn nearest your quests, not the one you're at", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        -- Your quests are around (50,50); you've travelled to another inn at (10,10).
        db.Npc[3002] = { name = "Innkeeper Grosk", subName = "Innkeeper", friendlyToFaction = "H",
                         spawns = { [14] = { { 51, 51 } } } }
        db.Npc[3005] = { name = "Innkeeper Faraway", subName = "Innkeeper", friendlyToFaction = "H",
                         spawns = { [14] = { { 10, 10 } } } }
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        mock.player.position = { mapID = 1411, x = 0.10, y = 0.10 }
        local state = fixtures.login(ns)
        T.truthy(not hasKey(state, "hearth:npc:3005"), "not the inn you happen to be at")
        T.truthy(not hasKey(state, "hearth:npc:3002"), "the right inn is too far to suggest now")
        mock.player.position = { mapID = 1411, x = 0.51, y = 0.50 }
        ns.Engine.Replan()
        T.truthy(hasKey(ns.Engine.state, "hearth:npc:3002"), "suggested once you're at the right inn")
    end },

    { "the questing centre is the middle of your quest steps", function(T)
        local ns = T.fresh()
        local function at(kind, x, y) return { kind = kind, target = { world = { continent = 1, x = x, y = y } } } end
        local c = ns.Sources.QuestingCentre({ at("ACCEPT", 0, 0), at("COMPLETE", 100, 0), at("TURNIN", 50, 90),
            at("TRAIN", 9999, 9999), { kind = "COMPLETE", target = { world = { continent = 2, x = 5, y = 5 } } } }, 1)
        T.eq(c.x, 50)
        T.eq(c.y, 30)
        T.eq(ns.Sources.QuestingCentre({}, 1), nil)
    end },

    { "skipping an inn keeps it skipped, and Back brings it back", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        QuestwalkerCharDB.guide.trainedLevel = 60
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
        SlashCmdList.QUESTWALKER("guide off")
        T.eq(mock.userWaypoint, nil)
        T.eq(#ns.Engine.state.steps, 0)
    end },

    { "waypoint command switches providers", function(T)
        local ns, mock = T.fresh()
        mock.installTomTom()
        fixtures.durotar(mock)
        fixtures.login(ns)
        SlashCmdList.QUESTWALKER("waypoints builtin")
        T.eq(QuestwalkerDB.guide.waypoints, "builtin")
        T.eq(mock.userWaypoint.uiMapID, 1411)
        SlashCmdList.QUESTWALKER("waypoints sideways")
        T.contains(mock.printed[#mock.printed], "auto, shortestpath, tomtom, builtin, off")
    end },

    { "guide window renders the current step and distance", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        local state = fixtures.login(ns)
        T.contains(QuestwalkerGuideFrame.current:GetText(), "Talk to Foreman Thazz'ril")
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

    { "/qw done explains when nothing is manual", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock, { level = 3 })
        fixtures.login(ns)
        SlashCmdList.QUESTWALKER("done")
        T.contains(mock.printed[#mock.printed], "complete on their own")
    end },

    { "quests in the same area show up as one step in the guide", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock)
        QuestwalkerCharDB.guide.trainedLevel = 60
        db.Npc[2003] = { name = "Mottled Boar", spawns = { [14] = { { 61, 61 } } } }
        db.Quest[113] = { name = "Cutting Teeth", startedBy = { { 1002 } }, objectives = { { { 2003 } } } }
        fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
        fixtures.addToLog(mock, 113, "Cutting Teeth", false, { "Mottled Boar slain: 0/8" })
        local state = fixtures.login(ns)
        local step
        for _, s in ipairs(state.steps) do if s.kind == "COMPLETE" then step = s end end
        T.contains(step.title, "Vile Familiars & Cutting Teeth")
        T.contains(step.lines, "  Mottled Boar slain: 0/8")
        T.contains(step.lines, "  Vile Familiar slain: 2/8")
        -- Finishing one keeps the guide on the other.
        ns.Engine.FocusQuest(101)
        mock.questLog[2].objectives = nil
        fixtures.removeFromLog(mock, 113)
        ns:FireEvent("QUEST_REMOVED", 113)
        T.eq(ns.Engine.state.steps[1].key, "complete:101")
    end },

    { "out-levelling your zone sends you on to the next one, and says so", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        fixtures.durotar(mock, { level = 11, mode = "efficient" })
        QuestwalkerCharDB.guide.trainedLevel = 60
        local state = fixtures.login(ns)
        local step = state.steps[1]
        T.eq(step.title, "Talk to Barrens Scout", "Durotar's quests are grey now")
        T.eq(step.target.mapID, 1413)
        T.contains(step.lines, "You've out-levelled Durotar - head to The Barrens.")
        T.contains(table.concat(mock.printed, "\n"), "Time to move on to The Barrens")
        local count = #mock.printed
        ns.Engine.Replan()
        T.eq(#mock.printed, count, "announced once")
    end },

    { "no zone change while your zone is still in the guide", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        fixtures.durotar(mock, { level = 6, mode = "efficient" })
        local state = fixtures.login(ns)
        T.eq(state.steps[1].zoneChange, nil)
    end },

    { "a new character starts on its guide's first quest", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Orc", "Orc", 2 }
        local db = fixtures.durotar(mock, { level = 1, mode = "efficient" })
        db.Quest[4641] = { name = "Your Place In The World", startedBy = { { 10176 } }, requiredLevel = 1, questLevel = 2 }
        db.Npc[10176] = { name = "Kaltunk", friendlyToFaction = "H", spawns = { [14] = { { 43, 68 } } } }
        mock.player.position = { mapID = 1411, x = 0.43, y = 0.68 }
        local state = fixtures.login(ns)
        T.eq(ns.Engine.CurrentGuide().id, "speedrun-orc-troll")
        T.eq(state.steps[1].title, "Talk to Kaltunk")
    end },

    ---------------------------------------------------------------------
    -- Too hard for now
    ---------------------------------------------------------------------
    { "a quest in your log that's too high waits until you're close enough", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Dwarf", "Dwarf", 3 }
        local db = fixtures.durotar(mock, { level = 22, mode = "efficient" })
        db.Quest[101].questLevel, db.Quest[101].requiredLevel = 25, 18 -- like The Totem of Infliction
        fixtures.addToLog(mock, 101, "The Totem of Infliction", false, { "Ghoul Fang: 0/10" })
        local state = fixtures.login(ns)
        T.truthy(not hasKey(state, "complete:101"), "not suggested at 22")
        T.eq(state.onHold[1].title, "The Totem of Infliction")
        T.eq(state.onHold[1].level, 23, "Speedrun takes quests up to 2 levels above you")
        T.contains(guideStatus(), "On hold until you're stronger: The Totem of Infliction (level 23)")
        mock.player.level = 23
        ns:FireEvent("PLAYER_LEVEL_UP", 23)
        ns.Engine.Replan()
        T.truthy(hasKey(ns.Engine.state, "complete:101"), "back at 23")
    end },

    { "creatures far above your level make a quest too hard too", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 8, mode = "efficient" })
        db.Npc[2001].minLevel = 15 -- the quest says 5, its mobs say otherwise
        local state = fixtures.login(ns)
        T.truthy(not fixtures.findStep(state, "accept:npc:1001") or
            not table.concat(fixtures.findStep(state, "accept:npc:1001").questIDs, ","):find("101"),
            "not offered")
        T.eq(ns.QuestieData.ObjectiveLevel(101), 15)
        T.eq(select(2, ns.QuestieData.TooHard(101, 8, { levelsAbove = 2 })), 12)
        T.eq(ns.QuestieData.TooHard(101, 12, { levelsAbove = 2 }), false)
    end },

    { "picking a held quest in the Steps list overrides the hold", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 8, mode = "efficient" })
        db.Quest[101].questLevel = 15
        fixtures.addToLog(mock, 101, "Vile Familiars", false)
        local state = fixtures.login(ns)
        T.truthy(not hasKey(state, "complete:101"))
        ns.Engine.FocusQuest(101)
        T.eq(ns.Engine.state.steps[1].key, "complete:101", "you asked for it")
    end },

    { "an unfinished quest far below your level isn't suggested", function(T)
        local ns, mock = T.fresh()
        mock.player.race = { "Dwarf", "Dwarf", 3 }
        local db = fixtures.durotar(mock, { level = 22, mode = "efficient" })
        db.Quest[101].questLevel = 8
        fixtures.addToLog(mock, 101, "Old Errand", false, { "Vile Familiar slain: 2/8" })
        local state = fixtures.login(ns)
        T.truthy(not hasKey(state, "complete:101"), "level 8 quest at 22")
        T.eq(state.tooLow[1].level, 8)
        T.contains(guideStatus(), "Too low to be worth it: Old Errand (level 8)")
        ns.Engine.FocusQuest(101)
        T.eq(ns.Engine.state.steps[1].key, "complete:101", "unless you pick it in the Steps list")
    end },

    { "a finished low quest is handed in only when it's on your way", function(T)
        local ns, mock = T.fresh()
        local db = fixtures.durotar(mock, { level = 20, mode = "efficient" })
        db.Quest[101].questLevel = 5
        fixtures.addToLog(mock, 101, "Vile Familiars", true)
        local state = fixtures.login(ns)
        T.truthy(hasKey(state, "turnin:npc:1001") or fixtures.findStep(state, "turnin:npc:1001"),
            "Zureetha is right here (your map)")
        mock.player.position = { mapID = 1413, x = 0.5, y = 0.5 } -- in The Barrens now
        ns.Engine.Replan()
        T.truthy(not fixtures.findStep(ns.Engine.state, "turnin:npc:1001"), "not worth the trip back")
    end },

    { "quests in your level window aren't too low", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        fixtures.login(ns)
        T.eq(ns.QuestieData.TooLow(101, 7, { greyGap = 2 }), false, "level 5 at 7")
        T.eq(select(2, ns.QuestieData.TooLow(101, 8, { greyGap = 2 })), 5, "level 5 at 8")
    end },
}
