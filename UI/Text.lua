--[[
    ForeverPath - UI/Text.lua

    Turns a plan (from Core/Advisor.lua) into the coloured text shown in the
    main window. Kept separate from frame code so it can be tested and so
    the window stays a thin shell.
]]

local _, ns = ...

local Text = {}
ns.Text = Text

local L = ns.L
local Util = ns.Util
local C = Util.Color

local function heading(lines, text)
    if #lines > 0 then lines[#lines + 1] = " " end
    lines[#lines + 1] = C("accent", text)
end

local function bullet(lines, text, color)
    lines[#lines + 1] = "  - " .. (color and C(color, text) or text)
end

local function renderHeader(lines, profile)
    local faction = profile.faction == "Neutral" and L.NEUTRAL or profile.faction
    lines[#lines + 1] = C("accent", L.HEADER_FMT:format(
        profile.raceName, profile.className, profile.level, faction))
    if profile.isNewCombo then
        lines[#lines + 1] = C("new", L.NEW_COMBO)
    end
    if not profile.race then
        lines[#lines + 1] = C("warn", L.UNKNOWN_RACE:format(profile.raceName))
    end
end

local function renderXp(lines, profile, xp)
    if not xp then return end
    heading(lines, L.RESTED_HEADER)
    if xp.atCap then
        bullet(lines, L.RESTED_MAX_LEVEL, "muted")
        return
    end
    if xp.rested and xp.rested > 0 then
        bullet(lines, L.RESTED_FMT:format(Util.FormatNumber(xp.rested), xp.restedPct or 0), "good")
    else
        bullet(lines, L.RESTED_NONE, "muted")
    end
    if xp.resting then
        bullet(lines, L.RESTED_RESTING, "good")
    end
    if xp.toLevel then
        bullet(lines, L.XP_TO_LEVEL_FMT:format(Util.FormatNumber(xp.toLevel), profile.level + 1))
    end
end

local function renderClass(lines, profile)
    local class = profile.class
    if not class then return end
    heading(lines, L.CLASS_HEADER:format(class.name))
    bullet(lines, L.LEVEL_SPEC:format(C("good", class.spec)) .. " - " .. class.why)
    bullet(lines, L.ALT_SPEC:format(class.altSpec), "muted")
    bullet(lines, L.LEVEL_TIER:format(class.tier), "muted")
    for _, tip in ipairs(class.tips) do
        bullet(lines, tip)
    end
end

local function renderBand(lines, label, entry, highlight)
    if not entry then return end
    local b = entry.band
    local title = L.BAND_FMT:format(label, b.min, b.max)
    lines[#lines + 1] = "  " .. C(highlight and "good" or "muted", title)
    lines[#lines + 1] = "    " .. L.QUEST_IN:format(Util.Join(entry.zones))
    for _, note in ipairs(entry.notes or {}) do
        lines[#lines + 1] = "    " .. C("muted", note)
    end
end

local function renderRoute(lines, plan, showAll)
    heading(lines, L.ROUTE_HEADER:format(plan.route.name))
    lines[#lines + 1] = "  " .. C("muted", plan.route.description)
    if showAll then
        for i, entry in ipairs(plan.allBands) do
            local label = (i == plan.bandIndex) and L.NOW or L.LEVELS
            renderBand(lines, label, entry, i == plan.bandIndex)
        end
    else
        renderBand(lines, L.NOW, plan.current, true)
        renderBand(lines, L.NEXT, plan.next, false)
    end
end

local function renderDungeons(lines, plan, profile)
    heading(lines, L.DUNGEON_HEADER)
    if #plan.dungeons == 0 then
        bullet(lines, L.DUNGEON_NONE, "muted")
        return
    end
    for _, d in ipairs(plan.dungeons) do
        local where = d.zone
        if d.territory and d.territory ~= profile.faction then
            where = where .. ", " .. L.FACTION_TERRITORY:format(d.territory)
        end
        local line = L.DUNGEON_FMT:format(d.name, d.min, d.max, where)
        if d.isNew then
            line = line .. " " .. C("new", "[" .. L.NEW_TAG .. "]")
        end
        bullet(lines, line)
    end
end

local function renderMilestones(lines, plan)
    if #plan.milestones == 0 then return end
    heading(lines, L.MILESTONE_HEADER)
    for _, m in ipairs(plan.milestones) do
        bullet(lines, ("%d: %s"):format(m.level, m.text))
    end
end

local function renderGeneral(lines)
    heading(lines, L.GENERAL_HEADER)
    for _, tip in ipairs(ns.Data.GeneralTips) do
        bullet(lines, tip, "muted")
    end
end

--- Build the full window text.
-- @param profile from Character.Detect
-- @param plan    from Advisor.BuildPlan
-- @param xp      from Advisor.GetXpInfo (optional)
-- @param opts    { showAllBands = bool }
function Text.Render(profile, plan, xp, opts)
    opts = opts or {}
    local lines = {}
    renderHeader(lines, profile)
    renderXp(lines, profile, xp)
    renderClass(lines, profile)

    -- The dungeon route leads with dungeons; others lead with zones.
    if plan.route.dungeonFirst then
        renderDungeons(lines, plan, profile)
        renderRoute(lines, plan, opts.showAllBands)
    else
        renderRoute(lines, plan, opts.showAllBands)
        renderDungeons(lines, plan, profile)
    end

    renderMilestones(lines, plan)
    renderGeneral(lines)
    return table.concat(lines, "\n")
end

--- A one-line summary for chat, e.g. after a level-up.
function Text.Summary(plan)
    return Util.Join(plan.current.zones)
end
