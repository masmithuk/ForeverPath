--[[
    Questwalker - UI/Compass.lua

    A compass bar across the top of the screen (like ESO's or Skyrim's).
    As you turn, N, NE, E ... slide past, and markers show where things are:

      1, 2, 3 ...  the guide's next steps, numbered as in the guide window
                   and on the world map. 1 (gold) is the step you're on;
                   when it's behind you it waits at the edge with an arrow
                   showing which way to turn. Hover for what to do and how
                   far it is.
      names        party members, in their class colours. Hover for how
                   far away they are.

    The bar shows 90 degrees either side of where you're facing.
    Shift-drag to move it. Turned off with Settings > "Compass at the top
    of the screen". It hides itself where the game gives no position
    (inside instances).

    The maths (Axes, Bearing, Relative, Offset, Layout) is pure and tested.
]]

local _, ns = ...

local Compass = {}
ns.Compass = Compass

local L = ns.L

Compass.WIDTH = 560
Compass.HEIGHT = 30
Compass.FOV = math.pi / 2        -- radians shown either side of the centre
Compass.MAX_STEPS = 10
local TWO_PI = 2 * math.pi
local UPDATE_EVERY = 0.03
local MARKER_SIZE = 18

local DIRECTIONS = {
    { "N", 0 }, { "NE", 1 }, { "E", 2 }, { "SE", 3 }, { "S", 4 }, { "SW", 5 }, { "W", 6 }, { "NW", 7 },
}

local frame
local lastSteps = {}
local axesCache = {}

local function settings() return ns.Settings.account end

local function enabled()
    local g = settings() and settings().guide
    return not g or g.compass ~= false
end

---------------------------------------------------------------------------
-- Maths (pure)
---------------------------------------------------------------------------

--- Which way east and south point in world coordinates on a map. Worked
--- out from the map itself, so it doesn't depend on the game's axis
--- conventions. Cached per map.
-- @return { continent, east = {x, y}, south = {x, y} } or nil
function Compass.Axes(mapID)
    if not mapID then return nil end
    if axesCache[mapID] then return axesCache[mapID] end
    local GA = ns.GameApi
    local o, e, s = GA.GetWorldPosition(mapID, 0, 0), GA.GetWorldPosition(mapID, 1, 0), GA.GetWorldPosition(mapID, 0, 1)
    if not (o and e and s) then return nil end
    local function unit(p)
        local dx, dy = p.x - o.x, p.y - o.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len == 0 then return nil end
        return { x = dx / len, y = dy / len }
    end
    local east, south = unit(e), unit(s)
    if not (east and south) then return nil end
    local axes = { continent = o.continent, east = east, south = south }
    axesCache[mapID] = axes
    return axes
end

--- Compass bearing from one world position to another: radians clockwise
--- from north, 0 to 2*pi. nil when they're on different continents.
function Compass.Bearing(from, to, axes)
    if not (from and to and axes) or from.continent ~= to.continent then return nil end
    local dx, dy = to.x - from.x, to.y - from.y
    local east = dx * axes.east.x + dy * axes.east.y
    local south = dx * axes.south.x + dy * axes.south.y
    if east == 0 and south == 0 then return nil end
    return math.atan2(east, -south) % TWO_PI
end

--- Angle of a bearing relative to where you face: 0 ahead, negative to
--- the left, positive to the right (-pi to pi). `facing` is the game's
--- GetPlayerFacing(): 0 = north, increasing anticlockwise.
function Compass.Relative(bearing, facing)
    local rel = (bearing + facing) % TWO_PI
    if rel > math.pi then rel = rel - TWO_PI end
    return rel
end

--- Pixels from the bar's centre for a relative angle, or nil when it's off
--- the bar.
function Compass.Offset(rel, halfWidth, fov)
    fov = fov or Compass.FOV
    if math.abs(rel) > fov then return nil end
    return rel / fov * halfWidth
end

--- Party members' world positions: { { unit, name, class, world } }.
function Compass.PartyPositions(mapID)
    local out = {}
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition and UnitExists) then return out end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local ok, vec = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
            local x, y
            if ok and vec then x, y = vec:GetXY() end
            local world = x and y and ns.GameApi.GetWorldPosition(mapID, x, y)
            if world then
                local _, class = UnitClass(unit)
                out[#out + 1] = { unit = unit, name = UnitName(unit), class = class, world = world }
            end
        end
    end
    return out
end

--- Everything to draw on the bar.
-- @param steps the Engine's planned steps
-- @param player { mapID, world } and facing (radians)
-- @param party from PartyPositions
-- @return { directions = { {label, offset} }, markers = { {kind, label, offset, edge, step, distance, ...} } }
function Compass.Layout(steps, player, facing, party, halfWidth)
    local result = { directions = {}, markers = {} }
    if not (player and player.world and facing) then return result end
    local axes = Compass.Axes(player.mapID)
    if not axes then return result end
    halfWidth = halfWidth or Compass.WIDTH / 2

    for _, d in ipairs(DIRECTIONS) do
        local offset = Compass.Offset(Compass.Relative(d[2] * math.pi / 4, facing), halfWidth)
        if offset then result.directions[#result.directions + 1] = { label = d[1], offset = offset } end
    end

    for i, step in ipairs(steps or {}) do
        if i > Compass.MAX_STEPS then break end
        for k, t in ipairs(step.targets or { step.target }) do
            local to = t and t.world
            local bearing = to and Compass.Bearing(player.world, to, axes)
            if bearing then
                local rel = Compass.Relative(bearing, facing)
                local offset = Compass.Offset(rel, halfWidth)
                local edge
                if not offset and i == 1 and k == 1 then
                    -- The current step waits at the edge, pointing the way to turn.
                    edge = rel < 0 and "left" or "right"
                    offset = (rel < 0 and -1 or 1) * halfWidth
                end
                if offset then
                    result.markers[#result.markers + 1] = {
                        kind = "step", label = tostring(i), number = i, current = i == 1, offset = offset,
                        edge = edge, step = step, distance = ns.Util.Distance(player.world, to),
                        spot = t.label,
                    }
                end
            end
        end
    end

    for _, member in ipairs(party or {}) do
        local bearing = Compass.Bearing(player.world, member.world, axes)
        local offset = bearing and Compass.Offset(Compass.Relative(bearing, facing), halfWidth)
        if offset then
            result.markers[#result.markers + 1] = {
                kind = "party", label = member.name or member.unit, class = member.class, offset = offset,
                unit = member.unit, distance = ns.Util.Distance(player.world, member.world),
            }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function yards(d)
    return d and ("%d yd"):format(math.floor(d + 0.5)) or ""
end

local function showTooltip(widget)
    local m = widget.marker
    if not m or not GameTooltip then return end
    GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
    if m.kind == "step" then
        GameTooltip:AddLine(m.number .. ". " .. (m.step.title or ""), 1, 0.82, 0)
        for _, line in ipairs(m.step.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    else
        GameTooltip:AddLine(m.label, 1, 1, 1)
    end
    GameTooltip:AddLine(yards(m.distance), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.4, 0.8, 1
end

local function newMarker(parent)
    local m = CreateFrame("Button", nil, parent)
    m:SetSize(MARKER_SIZE, MARKER_SIZE)
    m.bg = m:CreateTexture(nil, "ARTWORK")
    m.bg:SetAllPoints()
    m.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.text:SetPoint("CENTER", 0, 0)
    m.arrow = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m:SetScript("OnEnter", showTooltip)
    m:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return m
end

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    settings().compass = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function create()
    local f = CreateFrame("Frame", "QuestwalkerCompass", UIParent)
    f:SetSize(Compass.WIDTH, Compass.HEIGHT)
    local saved = settings().compass
    if type(saved) == "table" and saved.point then
        f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -12)
    end
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false) -- clicks pass through, except on markers and the grip
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.45)
    f.line = f:CreateTexture(nil, "BORDER")
    f.line:SetPoint("BOTTOMLEFT", 0, 0)
    f.line:SetPoint("BOTTOMRIGHT", 0, 0)
    f.line:SetHeight(1)
    f.line:SetColorTexture(1, 0.82, 0, 0.6)
    f.centre = f:CreateTexture(nil, "BORDER")
    f.centre:SetSize(2, 8)
    f.centre:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.centre:SetColorTexture(1, 1, 1, 0.8)

    -- A small grip at the left end: Shift-drag it to move the bar.
    f.grip = CreateFrame("Button", nil, f)
    f.grip:SetSize(12, Compass.HEIGHT)
    f.grip:SetPoint("RIGHT", f, "LEFT", 0, 0)
    f.grip.tex = f.grip:CreateTexture(nil, "ARTWORK")
    f.grip.tex:SetAllPoints()
    f.grip.tex:SetColorTexture(1, 0.82, 0, 0.25)
    f.grip:RegisterForDrag("LeftButton")
    f.grip:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not ns.GameApi.InCombat() then f:StartMoving() end
    end)
    f.grip:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition(f)
    end)
    f.grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.COMPASS_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.COMPASS_MOVE_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    f.directions, f.markers = {}, {}
    for i, d in ipairs(DIRECTIONS) do
        local text = f:CreateFontString(nil, "ARTWORK", #d[1] == 1 and "GameFontNormal" or "GameFontHighlightSmall")
        text:SetText(d[1])
        f.directions[i] = text
    end

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < UPDATE_EVERY then return end
        elapsed = 0
        Compass.Draw()
    end)
    return f
end

--- Where you are now: { mapID, world } and facing, or nil.
function Compass.PlayerNow()
    local pos = ns.GameApi.GetPlayerPosition()
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not pos or type(facing) ~= "number" then return nil end
    local world = ns.GameApi.GetWorldPosition(pos.mapID, pos.x, pos.y)
    if not world then return nil end
    return { mapID = pos.mapID, world = world }, facing
end

--- Redraw the bar for where you are and face now.
function Compass.Draw()
    if not frame then return end
    local player, facing = Compass.PlayerNow()
    local layout = Compass.Layout(lastSteps, player, facing,
        player and Compass.PartyPositions(player.mapID) or {}, Compass.WIDTH / 2)
    frame.layout = layout

    for _, text in ipairs(frame.directions) do text:Hide() end
    local labels = {}
    for i, d in ipairs(DIRECTIONS) do labels[d[1]] = frame.directions[i] end
    for _, d in ipairs(layout.directions) do
        local text = labels[d.label]
        text:ClearAllPoints()
        text:SetPoint("CENTER", frame, "CENTER", d.offset, 2)
        text:Show()
    end

    -- Party members sit low, steps high; later steps are drawn under earlier ones.
    local used = 0
    for i = #layout.markers, 1, -1 do
        local m = layout.markers[i]
        used = used + 1
        local w = frame.markers[used] or newMarker(frame)
        frame.markers[used] = w
        w.marker = m
        w:ClearAllPoints()
        w.arrow:SetText("")
        if m.kind == "step" then
            w:SetSize(m.current and MARKER_SIZE + 4 or MARKER_SIZE, m.current and MARKER_SIZE + 4 or MARKER_SIZE)
            w:SetPoint("CENTER", frame, "CENTER", m.offset, 0)
            w.text:SetText(m.label)
            if m.current then
                w.bg:SetVertexColor(1, 0.75, 0.1, 1)
                w.text:SetTextColor(0, 0, 0)
                w:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
            else
                w.bg:SetVertexColor(0.12, 0.35, 0.65, 0.95)
                w.text:SetTextColor(1, 1, 1)
                w:SetFrameLevel((frame:GetFrameLevel() or 1) + 20 - math.min(m.number, 15))
            end
            w.bg:Show()
            if m.edge then
                w.arrow:ClearAllPoints()
                if m.edge == "left" then
                    w.arrow:SetPoint("RIGHT", w, "LEFT", -1, 0)
                    w.arrow:SetText("<")
                else
                    w.arrow:SetPoint("LEFT", w, "RIGHT", 1, 0)
                    w.arrow:SetText(">")
                end
            end
        else
            local r, g, b = classColor(m.class)
            w:SetSize(64, 12)
            w:SetPoint("TOP", frame, "BOTTOM", m.offset, -1)
            w.bg:Hide()
            w.text:SetText(m.label)
            w.text:SetTextColor(r, g, b)
            w:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
        end
        w:Show()
    end
    for i = used + 1, #frame.markers do frame.markers[i]:Hide() end
end

--- Show or hide the bar to match the setting.
function Compass.Refresh()
    if not enabled() then
        if frame then frame:Hide() end
        return
    end
    frame = frame or create()
    frame:Show()
    Compass.Draw()
end

--- New plan from the Engine.
function Compass.Update(steps)
    lastSteps = steps or {}
    if enabled() and not frame then Compass.Refresh() end
end

--- Turn the compass on or off (Settings).
function Compass.SetEnabled(on)
    settings().guide.compass = on and true or false
    Compass.Refresh()
end

--- For tests: what's on the bar right now.
function Compass.Shown()
    if not (frame and frame:IsShown() and frame.layout) then return nil end
    return frame.layout
end
