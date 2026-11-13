--[[
    A small Durotar scene for guide tests. Coordinates are 0-100 like
    QuestieDB; Durotar is area 14 / map 1411, The Barrens area 17 / map 1413.

    Player: Undead Mage (race 5, class 8), Horde, standing at Durotar 50,50.

    Quest givers
      1001 Zureetha       45,50  (gives 101, 103, 105, 106; ends 101)
      1002 Foreman        50,52  (gives 102, 108)
      1003 Barrens NPC    The Barrens 50,50 (gives 104)
      1004 Alliance NPC   55,55  (gives 110, friendly to Alliance only)
      3001 Mai'ah         52,48  Mage Trainer
]]

local fixtures = {}

function fixtures.durotar(mock, opts)
    opts = opts or {}
    mock.player.level = opts.level or 8
    -- Story mode keeps every quest in range; tests for other modes set it.
    ForeverPathCharDB.routeId = opts.mode or "story"
    mock.player.position = { mapID = 1411, x = 0.5, y = 0.5 }

    return mock.installQuestieDB({
        Quest = {
            [101] = { name = "Vile Familiars", startedBy = { { 1001 } }, finishedBy = { { 1001 } },
                      requiredLevel = 3, questLevel = 5, objectives = { { { 2001 } } } },
            [102] = { name = "Lazy Peons", startedBy = { { 1002 } }, finishedBy = { { 1002 } },
                      requiredLevel = 2, questLevel = 4 },
            [103] = { name = "Burning Blade Medallion", startedBy = { { 1001 } }, finishedBy = { { 1001 } },
                      requiredLevel = 4, questLevel = 6, preQuestSingle = { 101 } },
            [104] = { name = "Barrens Errand", startedBy = { { 1003 } }, requiredLevel = 10, questLevel = 12 },
            [105] = { name = "Human Only", startedBy = { { 1001 } }, requiredLevel = 1, questLevel = 5,
                      requiredRaces = 1 },
            [106] = { name = "Paladin Only", startedBy = { { 1001 } }, requiredLevel = 1, questLevel = 5,
                      requiredClasses = 2 },
            [107] = { name = "Needs Reputation", startedBy = { { 1002 } }, requiredLevel = 1, questLevel = 5,
                      requiredMinRep = { 76, 3000 } },
            [108] = { name = "Grey Quest", startedBy = { { 1002 } }, requiredLevel = 1, questLevel = 1 },
            [109] = { name = "Too High", startedBy = { { 1002 } }, requiredLevel = 30, questLevel = 32 },
            [110] = { name = "Enemy Giver", startedBy = { { 1004 } }, requiredLevel = 1, questLevel = 5 },
            [111] = { name = "Skyborne Horde", startedBy = { { 1002 } }, requiredLevel = 1, questLevel = 5,
                      requiredRaces = 8589934592 },
        },
        Npc = {
            [1001] = { name = "Zureetha Fargaze", friendlyToFaction = "H", spawns = { [14] = { { 45, 50 } } } },
            [1002] = { name = "Foreman Thazz'ril", friendlyToFaction = "H", spawns = { [14] = { { 50, 52 } } } },
            [1003] = { name = "Barrens Scout", friendlyToFaction = "H", spawns = { [17] = { { 50, 50 } } } },
            [1004] = { name = "Alliance Spy", friendlyToFaction = "A", spawns = { [14] = { { 55, 55 } } } },
            [2001] = { name = "Vile Familiar", spawns = { [14] = { { 60, 60 }, { 20, 20 } } } },
            [3001] = { name = "Mai'ah", subName = "Mage Trainer", friendlyToFaction = "H",
                       spawns = { [14] = { { 52, 48 } } } },
        },
    })
end

--- Put a quest in the fake log.
function fixtures.addToLog(mock, id, title, complete, objectives)
    table.insert(mock.questLog, { id = id, title = title, complete = complete or false, objectives = objectives })
end

function fixtures.removeFromLog(mock, id)
    for i, q in ipairs(mock.questLog) do
        if q.id == id then table.remove(mock.questLog, i); return end
    end
end

--- Log in: fire PLAYER_LOGIN so the guide indexes QuestieDB and plans.
function fixtures.login(ns)
    ns:FireEvent("PLAYER_LOGIN")
    return ns.Engine.state
end

--- Titles of the planned steps, in order.
function fixtures.titles(state)
    local out = {}
    for i, s in ipairs(state.steps) do out[i] = s.title end
    return out
end

function fixtures.findStep(state, key)
    for _, s in ipairs(state.steps) do
        if s.key == key then return s end
    end
    for _, s in ipairs(state.reminders) do
        if s.key == key then return s end
    end
    return nil
end

return fixtures
