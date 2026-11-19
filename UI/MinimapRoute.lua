--[[
    Questwalker - UI/MinimapRoute.lua

    The Questwalker arrow's route as yellow dots on the minimap, from you
    towards where you're heading (the step, or the flight master or dock
    on the way). Dots stop at the minimap's edge. Follows the minimap's
    zoom, indoors and outdoors, and "Rotate Minimap".

    Turned off with Settings > "Route line on the minimap". Only drawn with
    the Questwalker arrow (Shortest Path Forever draws its own lines).

    Layout() is pure and tested; Update() places the dots.
]]

local _, ns = ...

local MinimapRoute = {}
ns.MinimapRoute = MinimapRoute

-- Yards across the whole minimap at each zoom level (0 = most zoomed out),
-- the figures map-pin libraries use for the Classic minimap.
MinimapRoute.OUTDOOR_YARDS = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
MinimapRoute.INDOOR_YARDS = { [0] = 300, 240, 180, 120, 80, 50 }
MinimapRoute.DOT_GAP = 7      -- pixels between dots
MinimapRoute.DOT_SIZE = 4
MinimapRoute.EDGE_MARGIN = 4  -- pixels kept clear of the minimap's rim

local dots = {}
local layer

local function enabled()
    local g = ns.Settings and ns.Settings.account and ns.Settings.account.guide
    return not g or g.minimapRoute ~= false
end

--- Dot positions in pixels from the minimap's centre (x right, y up).
-- @param east, south yards from you to where you're heading
-- @param opts { diameterYards, widthPx, rotate = facing or nil }
function MinimapRoute.Layout(east, south, opts)
    local out = {}
    if not (east and south and opts and opts.diameterYards and opts.widthPx) then return out end
    local pxPerYard = opts.widthPx / opts.diameterYards
    local x, y = east * pxPerYard, -south * pxPerYard
    if opts.rotate then
        -- The minimap turns so you face up: turn the route the same way.
        -- Facing f is anticlockwise from north, so where you face sits at
        -- angle pi/2 + f; turning by -f brings it to the top.
        local f = opts.rotate
        local c, s = math.cos(-f), math.sin(-f)
        x, y = x * c - y * s, x * s + y * c
    end
    local len = math.sqrt(x * x + y * y)
    local maxLen = opts.widthPx / 2 - MinimapRoute.EDGE_MARGIN
    local reach = math.min(len, maxLen)
    if len == 0 then return out end
    local ux, uy = x / len, y / len
    local d = MinimapRoute.DOT_GAP
    while d < reach do
        out[#out + 1] = { x = ux * d, y = uy * d }
        d = d + MinimapRoute.DOT_GAP
    end
    return out
end

local function hide(from)
    for i = from or 1, #dots do dots[i]:Hide() end
end

--- Yards across the minimap right now.
function MinimapRoute.DiameterYards()
    local minimap = _G.Minimap
    local zoom = minimap and minimap.GetZoom and minimap:GetZoom() or 0
    local indoors = IsIndoors and IsIndoors()
    local list = indoors and MinimapRoute.INDOOR_YARDS or MinimapRoute.OUTDOOR_YARDS
    return list[zoom] or list[0]
end

--- Draw the route from `player` ({mapID, world}) to `point` (a place), or
--- clear it with nil.
function MinimapRoute.Update(player, point, facing)
    local minimap = _G.Minimap
    if not (minimap and player and point and point.world and enabled()) then
        hide()
        return
    end
    local axes = ns.Compass.Axes(player.mapID)
    local from, to = player.world, point.world
    if not axes or from.continent ~= to.continent then
        hide()
        return
    end
    local dx, dy = to.x - from.x, to.y - from.y
    local east = dx * axes.east.x + dy * axes.east.y
    local south = dx * axes.south.x + dy * axes.south.y
    local rotating = GetCVar and GetCVar("rotateMinimap") == "1"
    local width = minimap:GetWidth()
    if not width or width <= 0 then width = 140 end
    local list = MinimapRoute.Layout(east, south, {
        diameterYards = MinimapRoute.DiameterYards(),
        widthPx = width,
        rotate = rotating and facing or nil,
    })

    if not layer then
        layer = CreateFrame("Frame", nil, minimap)
        layer:SetAllPoints(minimap)
        layer:SetFrameLevel((minimap:GetFrameLevel() or 1) + 5)
    end
    for i, p in ipairs(list) do
        local dot = dots[i]
        if not dot then
            dot = layer:CreateTexture(nil, "OVERLAY")
            dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            dot:SetVertexColor(1, 0.82, 0.1, 0.95)
            dot:SetSize(MinimapRoute.DOT_SIZE, MinimapRoute.DOT_SIZE)
            dots[i] = dot
        end
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", minimap, "CENTER", p.x, p.y)
        dot:Show()
    end
    hide(#list + 1)
    MinimapRoute.count = #list
end

function MinimapRoute.Clear()
    hide()
    MinimapRoute.count = 0
end

--- Turn the route on or off (Settings).
function MinimapRoute.SetEnabled(on)
    ns.Settings.account.guide.minimapRoute = on and true or false
    if not on then MinimapRoute.Clear() end
end
