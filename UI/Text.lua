--[[
    Questwalker - UI/Text.lua

    Turns a plan (from Core/Advisor.lua) into the coloured text shown on the
    main window's Home tab. Kept separate from frame code so it can be tested and so
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

local function renderGuide(lines, plan, step)
    heading(lines, L.HOME_GUIDE_HEADER)
    bullet(lines, L.HOME_FOLLOWING_FMT:format(C("good", plan.route.name)))
    local cur, nxt = plan.current, plan.next
    if cur then
        bullet(lines, L.HOME_NOW_FMT:format(Util.Join(cur.zones), cur.band.min, cur.band.max))
        for _, note in ipairs(cur.notes or {}) do bullet(lines, note, "muted") end
    end
    if nxt then
        bullet(lines, L.HOME_NEXT_FMT:format(nxt.band.min, Util.Join(nxt.zones)), "muted")
    end
    bullet(lines, L.HOME_STEP_FMT:format(step and step.title or L.GUIDE_NOTHING))
    if ns.Waypoints.NeedsArrowAddon(ns.Settings.account.guide.waypoints) then
        bullet(lines, L.HOME_NEEDS_ARROW, "warn")
    end
end

local function renderClassTips(lines, profile)
    local class = profile.class
    if not class then return end
    heading(lines, L.CLASS_HEADER:format(class.name))
    bullet(lines, L.LEVEL_SPEC:format(C("good", class.spec)) .. " - " .. class.why)
    for i = 1, math.min(2, #class.tips) do bullet(lines, class.tips[i], "muted") end
end

local function renderHelp(lines)
    heading(lines, L.HOME_HELP_HEADER)
    for _, key in ipairs({ "HOME_HELP_WINDOW", "HOME_HELP_STEPS", "HOME_HELP_GUIDES", "HOME_HELP_SETTINGS",
                           "HOME_HELP_TARGET", "HOME_HELP_MINIMAP" }) do
        bullet(lines, L[key])
    end
end

--- The Home tab: who you are, the guide you follow and where you are in
--- it, rested XP, class tips, dungeons for your level, and what each part
--- of Questwalker does.
-- @param profile from Character.Detect
-- @param plan    from Advisor.BuildPlan
-- @param xp      from Advisor.GetXpInfo (optional)
-- @param step    the guide's current step (optional)
function Text.Home(profile, plan, xp, step)
    local lines = {}
    renderHeader(lines, profile)
    renderGuide(lines, plan, step)
    renderXp(lines, profile, xp)
    renderClassTips(lines, profile)
    renderDungeons(lines, plan, profile)
    renderHelp(lines)
    return table.concat(lines, "\n")
end

--- A one-line summary for chat, e.g. after a level-up.
function Text.Summary(plan)
    return Util.Join(plan.current.zones)
end
