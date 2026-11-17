--[[
    Questwalker - Guide/QuestValue.lua

    How much a quest is worth to a speed runner: the XP it gives you now,
    divided by the time it should take. Speedrun uses this to skip quests
    that pay badly for the time they take and to prefer the best ones.

    XP     Questie's XP table, adjusted for your level the way the game does
           it, once Questie has started. Otherwise an estimate from the
           quest's level (about 80 XP per quest level, then the same
           adjustment for your level).

    Time   seconds =
             travel  (quest giver -> nearest objective -> hand-in) / run speed
           + work    for each objective: how many it asks for (the number in
                     the quest text, or 8) x seconds per kill / item / object.
                     Elites count as several kills, and items are assumed to
                     drop from about two kills in three.
           + a fixed overhead for talking, looting and reading.

    Everything here is an estimate; it only has to rank quests sensibly
    against each other.

    Elite tips: for objectives that are elite creatures, the nearest town
    guards (if any are close) - "pull it to the guards".
]]

local _, ns = ...

local QuestValue = {}
ns.QuestValue = QuestValue

QuestValue.RUN_SPEED = 7          -- yards per second on foot
QuestValue.KILL_SECONDS = 30      -- per normal kill, including a short rest
QuestValue.ELITE_FACTOR = 4       -- an elite takes about four kills' time
QuestValue.DROP_FACTOR = 1.5      -- kills needed per quest item
QuestValue.OBJECT_SECONDS = 12    -- per object clicked or picked up
QuestValue.OVERHEAD_SECONDS = 45  -- talking, looting, reading per quest
QuestValue.DEFAULT_COUNT = 8      -- when the quest text gives no number
QuestValue.GUARD_RANGE = 300      -- yards: guards this close make an elite soloable

local ELITE_RANKS = { [1] = true, [2] = true, [3] = true } -- elite, rare elite, boss

--- The game's adjustment of quest XP for your level (from cmangos, as
--- Questie uses it): full XP up to 5 levels above the quest, then less.
function QuestValue.AdjustXP(xp, questLevel, level)
    local multiplier = math.max(1, math.min(10, 2 * (questLevel - level) + 20))
    return xp * multiplier / 10
end

--- XP the quest gives you now.
function QuestValue.XP(questID, level)
    local exact = ns.QuestieData.QuestXP(questID)
    if exact then return exact end
    local qLevel = ns.QuestieData.Field("Quest", questID, "questLevel")
    if type(qLevel) ~= "number" or qLevel <= 0 then return nil end
    return QuestValue.AdjustXP(80 * qLevel, qLevel, level)
end

--- The numbers a quest's text asks for ("Bring 10 ghoul fangs, 10 skeleton
--- fingers and 5 vials" -> { 10, 10, 5 }).
function QuestValue.Counts(text)
    local counts = {}
    if type(text) ~= "string" then return counts end
    for n in text:gmatch("(%d+)") do
        local v = tonumber(n)
        if v and v > 0 and v <= 40 then counts[#counts + 1] = v end
    end
    return counts
end

local function isElite(npcID)
    return ELITE_RANKS[ns.QuestieData.Field("Npc", npcID, "rank") or 0] == true
end

--- Seconds of work for the quest's objectives.
function QuestValue.WorkSeconds(questID)
    local data = ns.QuestieData
    local objectives = data.Field("Quest", questID, "objectives")
    if type(objectives) ~= "table" then return 0 end
    local text = data.Field("Quest", questID, "objectivesText")
    if type(text) == "table" then text = table.concat(text, " ") end
    local counts = QuestValue.Counts(text)
    local nextCount = 1
    local function count()
        local c = counts[nextCount] or QuestValue.DEFAULT_COUNT
        nextCount = nextCount + 1
        return c
    end

    local seconds = 0
    for _, creature in ipairs(objectives[1] or {}) do
        local per = QuestValue.KILL_SECONDS * (isElite(creature[1]) and QuestValue.ELITE_FACTOR or 1)
        seconds = seconds + count() * per
    end
    for _ in ipairs(objectives[2] or {}) do
        seconds = seconds + count() * QuestValue.OBJECT_SECONDS
    end
    for _, item in ipairs(objectives[3] or {}) do
        local drops = data.Field("Item", item[1], "npcDrops") or {}
        local per
        if #drops > 0 then
            local elite = true
            for _, npcID in ipairs(drops) do if not isElite(npcID) then elite = false end end
            per = QuestValue.KILL_SECONDS * QuestValue.DROP_FACTOR * (elite and QuestValue.ELITE_FACTOR or 1)
        else
            per = QuestValue.OBJECT_SECONDS -- picked up from the ground or an object
        end
        seconds = seconds + count() * per
    end
    return seconds
end

--- A spawn point's world position (worked out once, then kept on it).
local function worldOf(p)
    if p and p.world == nil then
        p.world = ns.GameApi.GetWorldPosition(p.mapID, p.x, p.y) or false
    end
    return p and p.world or nil
end
QuestValue.WorldOf = worldOf

local function nearestPoint(from, actors)
    local best, bestDist
    for _, actor in ipairs(actors) do
        for _, p in ipairs(actor.points or {}) do
            if worldOf(p) and from and p.world.continent == from.continent then
                local d = ns.Util.Distance(from, p.world)
                if not bestDist or d < bestDist then best, bestDist = p, d end
            end
        end
    end
    return best, bestDist
end

--- Seconds walking: giver -> nearest objective -> hand-in.
function QuestValue.TravelSeconds(questID, faction)
    local data = ns.QuestieData
    local starters = data.GetStarters(questID, faction)
    local start = starters[1] and starters[1].points and starters[1].points[1]
    if not worldOf(start) then return 0 end
    local giver = start.world
    local yards = 0
    local objective, toObjective = nearestPoint(giver, data.GetObjectiveTargets(questID))
    local from = giver
    if objective then
        yards = yards + toObjective
        from = objective.world
    end
    local finishers = data.GetFinishers and data.GetFinishers(questID, faction) or {}
    local _, toFinish = nearestPoint(from, finishers)
    if toFinish then yards = yards + toFinish end
    return yards / QuestValue.RUN_SPEED
end

--- Estimated minutes to do the quest from its giver to its hand-in.
function QuestValue.Minutes(questID, faction)
    local seconds = QuestValue.OVERHEAD_SECONDS + QuestValue.WorkSeconds(questID)
        + QuestValue.TravelSeconds(questID, faction)
    return seconds / 60
end

--- XP per minute, or nil when the XP isn't known.
function QuestValue.Rate(questID, level, faction)
    local xp = QuestValue.XP(questID, level)
    if not xp then return nil end
    return xp / math.max(1, QuestValue.Minutes(questID, faction))
end

--- The middle value of a list of numbers (nil for an empty list).
function QuestValue.Median(values)
    if #values == 0 then return nil end
    local sorted = {}
    for i, v in ipairs(values) do sorted[i] = v end
    table.sort(sorted)
    local mid = math.floor((#sorted + 1) / 2)
    if #sorted % 2 == 0 then return (sorted[mid] + sorted[mid + 1]) / 2 end
    return sorted[mid]
end

---------------------------------------------------------------------------
-- Elites
---------------------------------------------------------------------------

--- Elite creatures the quest needs: list of { name, level }.
function QuestValue.Elites(questID)
    local data = ns.QuestieData
    local out, seen = {}, {}
    for _, target in ipairs(data.GetObjectiveTargets(questID)) do
        if target.kind == "npc" and not seen[target.id] and isElite(target.id) then
            seen[target.id] = true
            out[#out + 1] = { id = target.id, name = target.name,
                              level = data.Field("Npc", target.id, "maxLevel") or data.Field("Npc", target.id, "minLevel"),
                              points = target.points }
        end
    end
    return out
end

--- A tip for soloing an elite: the nearest friendly guards, if they're
--- close enough to pull it to. Returns the tip text, or nil.
function QuestValue.EliteTip(elite, faction, origin)
    local L = ns.L
    local from = origin
    local best, bestDist = nil, nil
    for _, p in ipairs(elite.points or {}) do
        if worldOf(p) then
            local d = from and from.continent == p.world.continent and ns.Util.Distance(from, p.world) or 0
            if not bestDist or d < bestDist then best, bestDist = p, d end
        end
    end
    local where = best and best.world
    local levelText = elite.level and (" " .. L.ELITE_LEVEL_FMT:format(elite.level)) or ""
    if not where then return L.ELITE_GROUP_FMT:format(elite.name, levelText) end
    local guards = ns.QuestieData.GetNpcsByTitle(ns.QuestieData.GUARD_TITLE, faction)
    local guardPoint, guardDist = nearestPoint(where, guards)
    if guardPoint and guardDist <= QuestValue.GUARD_RANGE then
        local guardName
        for _, g in ipairs(guards) do
            for _, p in ipairs(g.points or {}) do if p == guardPoint then guardName = g.name end end
        end
        return L.ELITE_GUARDS_FMT:format(elite.name, levelText, guardName or "guards", math.floor(guardDist + 0.5))
    end
    return L.ELITE_GROUP_FMT:format(elite.name, levelText)
end
