--[[
    Questwalker - UI/Navigator.lua

    The built-in arrow: sat-nav style directions to the current step,
    without any other addon.

        [arrow]  Turn left
                 240 yd - about 35 sec
                 Talk to Zureetha Fargaze

    The arrow turns as you do and goes from green (ahead) to red (behind
    you). The big line is the instruction: Go straight, Bear left, Turn
    right, Turn around, Arriving, You've arrived. For long trips it plans
    the journey (Guide/Travel.lua) and guides you one leg at a time: "Go to
    the flight master", "Fly to Camp Taurajo", "Use your Hearthstone",
    "Take the zeppelin to Grom'gol". The route is drawn as dots on the
    world map.

    It remembers what it needs as you play: the flight masters you've
    opened a flight map at (only discovered paths are used) and where you
    set your hearthstone.

    Chosen with Settings > Waypoint arrow > "Questwalker arrow"; it's the
    automatic choice unless Shortest Path Forever is installed. Shift-drag
    to move it.
]]

local _, ns = ...

local Navigator = {}
ns.Navigator = Navigator

local L = ns.L
local Travel = ns.Travel

local HEARTHSTONE = 6948
local ARRIVED = 8          -- yards
local ARRIVING = 35
local LEG_DONE = 12        -- close enough to a flight master or dock
local REPLAN_EVERY = 1     -- seconds
local DRAW_EVERY = 0.05
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"

local frame
local target        -- the current step's stop { map, x, y, title }
local plan          -- the journey (Travel.Plan)
local planKind      -- signature of the plan's shape, for hysteresis
local arrivedFor    -- target signature we've played the arrival sound for
local sinceReplan = math.huge
local pending = 0

local function charGuide() return ns.Settings.char.guide end

---------------------------------------------------------------------------
-- What the navigator remembers
---------------------------------------------------------------------------

local function npcIdOf(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

--- Remember flight masters: the one you're talking to, and those whose
--- zone matches a discovered node on the flight map.
function Navigator.OnTaxiMap()
    local known = charGuide().flights or {}
    charGuide().flights = known
    local npc = npcIdOf("npc")
    if npc then known[npc] = true end
    if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
    local masters = ns.QuestieData.IsReady() and ns.QuestieData.GetFlightMasters(ns.Character.Detect().faction) or {}
    -- Flight masters per zone: a zone with just one can be matched by name.
    local byZone = {}
    for _, m in ipairs(masters) do
        local p = m.points and m.points[1]
        local zoneName = p and ns.GameApi.GetMapName(p.mapID)
        if zoneName then
            byZone[zoneName] = byZone[zoneName] or {}
            table.insert(byZone[zoneName], m)
        end
    end
    for i = 1, NumTaxiNodes() do
        local kind = TaxiNodeGetType(i)
        if kind == "REACHABLE" or kind == "CURRENT" then
            -- "Crossroads, The Barrens" -> "The Barrens"
            local node = TaxiNodeName(i) or ""
            local zone = node:match(",%s*(.+)$") or node
            local inZone = byZone[zone]
            if inZone and #inZone == 1 then known[inZone[1].id] = true end
        end
    end
end

--- Remember where you set your hearthstone.
function Navigator.OnHearthBound()
    local pos = ns.GameApi.GetPlayerPosition()
    if not pos then return end
    charGuide().bindPoint = { mapID = pos.mapID, x = pos.x, y = pos.y,
        name = ns.GameApi.GetBindLocation and ns.GameApi.GetBindLocation() or nil }
end

local function place(mapID, x, y, name)
    local world = mapID and ns.GameApi.GetWorldPosition(mapID, x, y)
    if not world then return nil end
    return { world = world, mapID = mapID, x = x, y = y, name = name }
end

local function hearthReady()
    local count = GetItemCount and GetItemCount(HEARTHSTONE) or 0
    if count < 1 then return false end
    local cooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not cooldown then return true end
    local start, duration = cooldown(HEARTHSTONE)
    return not start or start == 0 or duration == 0
end

--- Everything Travel.Plan needs about this character.
function Navigator.Options()
    local faction = ns.Character.Detect().faction
    local opts = { flights = {}, transports = {} }
    local known = charGuide().flights or {}
    if ns.QuestieData.IsReady() then
        for _, m in ipairs(ns.QuestieData.GetFlightMasters(faction)) do
            local p = known[m.id] and m.points and m.points[1]
            local pl = p and place(p.mapID, p.x, p.y, m.name)
            if pl then
                pl.zone = ns.GameApi.GetMapName(p.mapID)
                opts.flights[#opts.flights + 1] = pl
            end
        end
    end
    for _, t in ipairs(ns.Data.Transports or {}) do
        if not t.faction or t.faction == faction then
            local a = place(t.a.mapID, t.a.x / 100, t.a.y / 100, t.a.name)
            local b = place(t.b.mapID, t.b.x / 100, t.b.y / 100, t.b.name)
            if a and b then opts.transports[#opts.transports + 1] = { ride = t.kind, a = a, b = b } end
        end
    end
    local bind = charGuide().bindPoint
    if bind and hearthReady() then
        opts.hearth = place(bind.mapID, bind.x, bind.y, bind.name)
    end
    opts.mounted = IsMounted and IsMounted() or false
    return opts
end

---------------------------------------------------------------------------
-- Directions (pure)
---------------------------------------------------------------------------

--- The instruction for walking somewhere `rel` radians off your facing
--- (negative: to the left) and `distance` yards away.
function Navigator.Instruction(rel, distance)
    if distance <= ARRIVED then return L.NAV_ARRIVED end
    if distance <= ARRIVING then return L.NAV_ARRIVING end
    local deg = math.abs(rel) * 180 / math.pi
    local side = rel < 0 and "LEFT" or "RIGHT"
    if deg <= 20 then return L.NAV_STRAIGHT end
    if deg <= 60 then return L["NAV_BEAR_" .. side] end
    if deg <= 140 then return L["NAV_TURN_" .. side] end
    return L.NAV_TURN_AROUND
end

--- "about 35 sec" / "about 4 min".
function Navigator.Eta(seconds)
    if not seconds then return "" end
    if seconds < 60 then return L.NAV_ETA_SEC:format(math.max(5, math.floor(seconds / 5 + 0.5) * 5)) end
    return L.NAV_ETA_MIN:format(math.floor(seconds / 60 + 0.5))
end

--- What a leg asks you to do, as { main, detail, point (place to head for) }.
function Navigator.Describe(leg, stepTitle)
    if leg.kind == "walk" then
        return nil, stepTitle, leg.to
    elseif leg.kind == "fly" then
        return L.NAV_FLY_FMT:format(leg.to.zone or leg.to.name or "?"), L.NAV_FLY_FROM_FMT:format(leg.from.name or "?"), leg.from
    elseif leg.kind == "hearth" then
        return L.NAV_HEARTH, L.NAV_HEARTH_TO_FMT:format(leg.to.name or ns.GameApi.GetMapName(leg.to.mapID) or "?"), nil
    elseif leg.kind == "ride" then
        local main = (leg.ride == "zeppelin" and L.NAV_ZEPPELIN_FMT or L.NAV_BOAT_FMT):format(leg.to.name or "?")
        return main, leg.from.name, leg.from
    end
    return nil, stepTitle, nil
end

---------------------------------------------------------------------------
-- Planning
---------------------------------------------------------------------------

local function shape(p)
    if not p then return "" end
    local parts = {}
    for _, leg in ipairs(p.legs) do
        parts[#parts + 1] = leg.kind .. ":" .. tostring(leg.to and leg.to.name)
    end
    return table.concat(parts, ">")
end

--- Work out (or keep) the journey from where you are.
function Navigator.Replan(world)
    sinceReplan = 0
    if not (target and world) then plan = nil; return end
    local dest = place(target.map, target.x, target.y, target.title)
    if not dest then plan = nil; return end
    local fresh = Travel.Plan(world, dest, Navigator.Options())
    if not fresh then plan = nil; return end
    -- Drop legs already done (you're at the flight master or dock).
    while #fresh.legs > 1 and fresh.legs[1].kind == "walk" and (fresh.legs[1].distance or 0) <= LEG_DONE do
        table.remove(fresh.legs, 1)
    end
    local newShape = shape(fresh)
    local progressed = planKind and #newShape < #planKind and planKind:sub(-#newShape) == newShape
    if plan and planKind ~= newShape and not progressed then
        -- Only change route once the new one has been better for a few
        -- seconds, so the arrow doesn't flip between two close options.
        pending = (pending or 0) + 1
        if pending < 3 then return end
    end
    pending = 0
    plan, planKind = fresh, newShape
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    ns.Settings.account.navigator = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function create()
    local f = CreateFrame("Frame", "QuestwalkerNavigator", UIParent)
    f:SetSize(250, 64)
    local saved = ns.Settings.account.navigator
    if type(saved) == "table" and saved.point then
        f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -70)
    end
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not ns.GameApi.InCombat() then f:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition(f)
    end)
    f:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.NAV_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.NAV_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.45)
    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(52, 52)
    f.arrow:SetPoint("LEFT", f, "LEFT", 6, 0)
    f.arrow:SetTexture(ARROW_TEXTURE)
    f.main = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.main:SetPoint("TOPLEFT", f, "TOPLEFT", 64, -7)
    f.main:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    f.main:SetJustifyH("LEFT")
    f.distance = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.distance:SetPoint("TOPLEFT", f.main, "BOTTOMLEFT", 0, -3)
    f.distance:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    f.distance:SetJustifyH("LEFT")
    f.detail = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.detail:SetPoint("TOPLEFT", f.distance, "BOTTOMLEFT", 0, -3)
    f.detail:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    f.detail:SetJustifyH("LEFT")
    f.detail:SetTextColor(0.8, 0.8, 0.8)

    f:SetScript("OnUpdate", function(_, dt)
        f.elapsed = (f.elapsed or 0) + (dt or 0)
        sinceReplan = sinceReplan + (dt or 0)
        if f.elapsed < DRAW_EVERY then return end
        f.elapsed = 0
        Navigator.Draw()
    end)
    return f
end

--- Arrow colour for an angle off your facing: green ahead, red behind.
local function arrowColour(rel)
    local t = math.min(1, math.abs(rel) / math.pi)
    if t < 0.5 then return t * 2, 1, 0.1 end
    return 1, 1 - (t - 0.5) * 2, 0.1
end

--- Everything shown, for tests: { main, distance, detail, rel }.
Navigator.view = nil

--- Redraw for where you are now.
function Navigator.Draw()
    if not frame or not target then return end
    local player, facing = ns.Compass.PlayerNow()
    if player and (sinceReplan >= REPLAN_EVERY or not plan) then Navigator.Replan(player.world) end

    local view = { main = "", distance = "", detail = target.title or "" }
    if UnitOnTaxi and UnitOnTaxi("player") then
        view.main, view.detail = L.NAV_ON_FLIGHT, target.title or ""
        frame.arrow:Hide()
        if ns.MinimapRoute then ns.MinimapRoute.Clear() end
    elseif not player or not plan or not plan.legs[1] then
        view.main = L.NAV_NO_POSITION
        frame.arrow:Hide()
    else
        local leg = plan.legs[1]
        local main, detail, point = Navigator.Describe(leg, target.title)
        local d = point and Travel.Distance(player.world, point.world)
        local rel
        if point and facing then
            local axes = ns.Compass.Axes(player.mapID)
            local bearing = axes and ns.Compass.Bearing(player.world, point.world, axes)
            rel = bearing and ns.Compass.Relative(bearing, facing)
        end
        if leg.kind == "walk" then
            main = d and rel and Navigator.Instruction(rel, d) or ""
        elseif d and d > LEG_DONE and rel then
            -- On your way to the flight master or dock: say what's next.
            detail = (main or "") .. (detail and (" - " .. detail) or "")
            main = Navigator.Instruction(rel, d)
        end
        view.main, view.detail, view.rel = main or "", detail or "", rel
        if d then
            view.distance = ("%d yd - %s"):format(math.floor(d + 0.5), Navigator.Eta(plan.seconds))
        else
            view.distance = Navigator.Eta(plan.seconds)
        end
        if rel then
            frame.arrow:SetRotation(-rel)
            frame.arrow:SetVertexColor(arrowColour(rel))
            frame.arrow:Show()
        else
            frame.arrow:Hide()
        end
        if leg.kind == "walk" and #plan.legs == 1 and d and d <= ARRIVED then
            local sig = ("%s:%.4f:%.4f"):format(tostring(target.map), target.x, target.y)
            if arrivedFor ~= sig then
                arrivedFor = sig
                if PlaySound and SOUNDKIT and SOUNDKIT.MAP_PING then pcall(PlaySound, SOUNDKIT.MAP_PING) end
            end
        end
        if ns.MapPins and ns.MapPins.SetRoute and point then
            ns.MapPins.SetRoute(player, point)
        end
        if ns.MinimapRoute then ns.MinimapRoute.Update(player, point, facing) end
    end
    frame.main:SetText(view.main)
    frame.distance:SetText(view.distance)
    frame.detail:SetText(view.detail)
    Navigator.view = view
end

--- Point the navigator at a stop (the current step), or nil to hide it.
function Navigator.SetTarget(stop)
    target = stop
    plan, planKind = nil, nil
    sinceReplan = math.huge
    if not stop then
        if frame then frame:Hide() end
        Navigator.view = nil
        if ns.MapPins and ns.MapPins.SetRoute then ns.MapPins.SetRoute(nil) end
        if ns.MinimapRoute then ns.MinimapRoute.Clear() end
        return
    end
    frame = frame or create()
    frame:Show()
    Navigator.Draw()
end

function Navigator.IsShown()
    return frame ~= nil and frame:IsShown() and target ~= nil
end

function Navigator.Init()
    ns:RegisterEvent("TAXIMAP_OPENED", function() Navigator.OnTaxiMap() end)
    ns:RegisterEvent("HEARTHSTONE_BOUND", function() Navigator.OnHearthBound() end)
end
