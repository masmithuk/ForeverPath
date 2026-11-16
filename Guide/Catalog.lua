--[[
    Questwalker - Guide/Catalog.lua

    Quest overviews per zone (used to build a guide's quest list when it
    has none of its own) and quest statuses.

    A zone's quests come from QuestieDB: every quest for your race, class
    and faction whose zone is that zone. Each quest gets a status:

      done       already turned in
      ready      in your log and complete - hand it in
      active     in your log
      available  you can pick it up now
      level      you're not high enough yet
      locked     needs an earlier quest first
]]

local _, ns = ...

local Catalog = {}
ns.Catalog = Catalog

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

--- Quest records for a zone.
local function guideQuests(zoneName)
    local mapID = ns.ZoneMap.MapIdByName(zoneName)
    return mapID and ns.QuestieData.GetQuestsForMap(mapID) or {}
end

--- The quests in a guide.
-- @param guideId zone name
-- @param ctx from Engine.BuildContext()
-- @return { quests = list, total, done, dataStatus }
--   each quest: { id, name, level, requiredLevel, status, giver }
function Catalog.Overview(guideId, ctx)
    local overview = { quests = {}, total = 0, done = 0, dataStatus = ns.QuestieData.Status() }
    if not ns.QuestieData.IsReady() then return overview end

    for _, q in ipairs(guideQuests(guideId)) do
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
