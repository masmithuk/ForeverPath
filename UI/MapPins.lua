--[[
    Questwalker - UI/MapPins.lua

    Numbered markers on the world map: where each of the guide's next steps
    is. 1 is the step you're on (gold), then 2, 3, ... in the order the
    guide will take them. Steps at the same spot share one marker ("2, 3").
    Hover a marker to see its step.

    Works on any map you look at: a step in another zone is placed through
    world coordinates when the game can (continent maps show the whole
    route). Off with Settings > "Number the steps on the world map".

    Layout() is pure (steps + map in, markers out) and unit-tested; the
    rest only draws.
]]

local _, ns = ...

local MapPins = {}
ns.MapPins = MapPins

MapPins.MAX_STEPS = 10
local SAME_SPOT = 0.012   -- markers closer than this (map fraction) merge
local PIN_SIZE = 22
local PIN_LEVEL = 2200    -- above Blizzard's and Questie's map pins
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local lastSteps = {}
local pins = {}
local drawn = { mapID = nil, scale = nil, width = nil, dirty = true }
local hooked = false

local function enabled()
    local g = ns.Settings and ns.Settings.account and ns.Settings.account.guide
    return not g or g.mapNumbers ~= false
end

--- Where a step's target falls on `mapID`, as 0-1 fractions, or nil.
function MapPins.Project(t, mapID)
    if not t or not t.mapID or not t.x or not t.y then return nil end
    if t.mapID == mapID then return t.x, t.y end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then
        return nil
    end
    local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, t.mapID, CreateVector2D(t.x, t.y))
    if not ok or not continent or not world then return nil end
    local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, world, mapID)
    if not ok2 or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

--- The markers to draw on `mapID` for the planned steps.
-- @return list of { x, y, numbers = {1, 3}, steps = {step, ...}, current = bool }
function MapPins.Layout(steps, mapID)
    local markers = {}
    if not mapID then return markers end
    for i, step in ipairs(steps or {}) do
        if i > MapPins.MAX_STEPS then break end
        local x, y = MapPins.Project(step.target, mapID)
        if x then
            local into
            for _, m in ipairs(markers) do
                if math.abs(m.x - x) < SAME_SPOT and math.abs(m.y - y) < SAME_SPOT then into = m; break end
            end
            if into then
                into.numbers[#into.numbers + 1] = i
                into.steps[#into.steps + 1] = step
            else
                markers[#markers + 1] = { x = x, y = y, numbers = { i }, steps = { step }, current = i == 1 }
            end
        end
    end
    return markers
end

--- "1", "2, 3" or "4-7" for a marker.
function MapPins.Label(numbers)
    local n = #numbers
    if n == 1 then return tostring(numbers[1]) end
    if n > 2 and numbers[n] - numbers[1] == n - 1 then return numbers[1] .. "-" .. numbers[n] end
    if n > 3 then return numbers[1] .. ", " .. numbers[2] .. "+" end
    local parts = {}
    for i, v in ipairs(numbers) do parts[i] = tostring(v) end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function canvas()
    local map = _G.WorldMapFrame
    local scroll = map and map.ScrollContainer
    return map, scroll, scroll and scroll.Child
end

local function showTooltip(pin)
    local m = pin.marker
    if not m or not GameTooltip then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    for k, step in ipairs(m.steps) do
        if k > 1 then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(m.numbers[k] .. ". " .. (step.title or ""), 1, 0.82, 0)
        for _, line in ipairs(step.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

local function newPin(parent)
    local pin = CreateFrame("Button", nil, parent)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin.bg = pin:CreateTexture(nil, "BACKGROUND")
    pin.bg:SetAllPoints()
    pin.bg:SetTexture(CIRCLE)
    pin.ring = pin:CreateTexture(nil, "BORDER")
    pin.ring:SetPoint("TOPLEFT", -2, 2)
    pin.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    pin.ring:SetTexture(CIRCLE)
    pin.ring:SetVertexColor(0, 0, 0, 0.9)
    pin.text = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pin.text:SetPoint("CENTER", 0, 0)
    pin:SetScript("OnEnter", showTooltip)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return pin
end

local function hideAll(from)
    for i = from or 1, #pins do pins[i]:Hide() end
end

--- Redraw the markers for the map being shown.
function MapPins.Draw()
    local map, scroll, child = canvas()
    if not (child and map:IsShown()) or not enabled() then
        hideAll()
        return
    end
    local mapID = map.GetMapID and map:GetMapID()
    local scale = scroll.GetCanvasScale and scroll:GetCanvasScale() or 1
    local width, height = child:GetWidth(), child:GetHeight()
    drawn.mapID, drawn.scale, drawn.width, drawn.dirty = mapID, scale, width, false
    if not width or width <= 0 then return end

    local markers = MapPins.Layout(lastSteps, mapID)
    for i, m in ipairs(markers) do
        local pin = pins[i] or newPin(child)
        pins[i] = pin
        pin.marker = m
        -- Same size on screen at any zoom.
        local s = 1 / (scale > 0 and scale or 1)
        pin:SetScale(s)
        pin:SetFrameLevel(PIN_LEVEL)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", child, "TOPLEFT", m.x * width / s, -m.y * height / s)
        pin.text:SetText(MapPins.Label(m.numbers))
        local label = pin.text:GetText() or ""
        pin:SetWidth(PIN_SIZE + math.max(0, #label - 2) * 5)
        if m.current then
            pin.bg:SetVertexColor(1, 0.75, 0.1, 1)
            pin.text:SetTextColor(0, 0, 0)
        else
            pin.bg:SetVertexColor(0.12, 0.35, 0.65, 0.95)
            pin.text:SetTextColor(1, 1, 1)
        end
        pin:Show()
    end
    hideAll(#markers + 1)
end

--- Watch the world map: redraw when it opens, changes map or zooms.
local function hook()
    local map, scroll = canvas()
    if hooked or not map then return end
    hooked = true
    if map.HookScript then map:HookScript("OnShow", function() drawn.dirty = true end) end
    if hooksecurefunc and map.OnMapChanged then
        hooksecurefunc(map, "OnMapChanged", function() drawn.dirty = true end)
    end
    -- Zooming and map changes are cheap to spot, so check while it's open.
    local watcher = CreateFrame("Frame", nil, map)
    local elapsed = 0
    watcher:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < 0.1 then return end
        elapsed = 0
        local mapID = map.GetMapID and map:GetMapID()
        local scale = scroll and scroll.GetCanvasScale and scroll:GetCanvasScale() or 1
        local width = scroll and scroll.Child and scroll.Child:GetWidth()
        if drawn.dirty or mapID ~= drawn.mapID or scale ~= drawn.scale or width ~= drawn.width then
            MapPins.Draw()
        end
    end)
end

--- New plan from the Engine. (The map is hooked on first use, so a world
--- map that loads on demand is picked up too.)
function MapPins.Update(steps)
    lastSteps = steps or {}
    hook()
    drawn.dirty = true
    local map = _G.WorldMapFrame
    if map and map:IsShown() then MapPins.Draw() end
end

--- Labels of the markers on show, in order (for tests and /qw debug).
function MapPins.Shown()
    local out = {}
    for _, pin in ipairs(pins) do
        if pin:IsShown() then out[#out + 1] = pin.text:GetText() end
    end
    return out
end

--- Turn the numbers on or off (Settings).
function MapPins.SetEnabled(on)
    ns.Settings.account.guide.mapNumbers = on and true or false
    drawn.dirty = true
    MapPins.Draw()
end
