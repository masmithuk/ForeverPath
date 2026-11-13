--[[
    ForeverPath - Guide/Catalog.lua

    The guide browser's data: one guide per zone on a route, each with its
    level range and a quest overview.

    A guide's quests come from QuestieDB: every quest for your race, class
    and faction whose zone is that guide's zone. Each quest gets a status:

      done       already turned in
      ready      in your log and complete - hand it in
      active     in your log
      available  you can pick it up now
      level      you're not high enough yet
      locked     needs an earlier quest first

    Following a guide (Engine.SetGuide) makes the step guide suggest new
    quests only in that zone. "Automatic" follows your route band instead.
]]

local _, ns = ...

local Catalog = {}
ns.Catalog = Catalog



--- Zone guides for a route, in level order.
-- @return list of { id, name, min, max, recommended, active }
function Catalog.List(profile, routeId)
    local id = ns.Advisor.ResolveRouteId(profile, routeId)
    local route = ns.Data.Routes[id]
    local byName, list = {}, {}

    for _, band in ipairs(route.bands) do
        for _, zone in ipairs(ns.Advisor.ResolveZones(band, profile, false)) do
            local guide = byName[zone]
            if guide then
                guide.min = math.min(guide.min, band.min)
                guide.max = math.max(guide.max, band.max)
            else
                guide = { id = zone, name = zone, min = band.min, max = band.max }
                byName[zone] = guide
                list[#list + 1] = guide
            end
        end
    end

    local chosen = ns.Settings.char.guideId
    for _, guide in ipairs(list) do
        guide.recommended = profile.level >= guide.min and profile.level <= guide.max
        guide.active = guide.id == chosen
    end

    table.sort(list, function(a, b)
        if a.min ~= b.min then return a.min < b.min end
        return a.name < b.name
    end)
    return list
end

--- Status of one quest for this character.
function Catalog.QuestStatus(q, ctx)
    local id = q.id
    if ctx.isCompleted(id) then return "done" end
    local inLog = ctx.log[id]
    if inLog then return inLog.complete and "ready" or "active" end
    if (q.requiredLevel or 1) > ctx.level then return "level" end
    if ns.QuestieData.IsDoable(id, ctx) then return "available" end
    return "locked"
end

--- The quests in a zone guide.
-- @param guideId zone name
-- @param ctx from Engine.BuildContext()
-- @return { quests = list, total, done, dataStatus }
--   each quest: { id, name, level, requiredLevel, status, giver }
function Catalog.Overview(guideId, ctx)
    local overview = { quests = {}, total = 0, done = 0, dataStatus = ns.QuestieData.Status() }
    if not ns.QuestieData.IsReady() then return overview end

    local mapID = ns.ZoneMap.MapIdByName(guideId)
    if not mapID then return overview end

    for _, q in ipairs(ns.QuestieData.GetQuestsForMap(mapID)) do
        local givers = ns.QuestieData.GetStarters(q.id, ctx.profile.faction)
        -- No friendly quest giver means it's the other faction's quest.
        if #givers > 0 then
            local status = Catalog.QuestStatus(q, ctx)
            overview.quests[#overview.quests + 1] = {
                id = q.id,
                name = ns.QuestieData.GetQuestName(q.id) or ("Quest " .. q.id),
                level = q.questLevel or q.requiredLevel or 1,
                requiredLevel = q.requiredLevel or 1,
                status = status,
                giver = givers[1].name,
            }
            if status == "done" then overview.done = overview.done + 1 end
        end
    end
    overview.total = #overview.quests

    table.sort(overview.quests, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return overview
end
