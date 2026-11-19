-- The Questwalker arrow's route as dots on the minimap.

local fixtures = require("fixtures")

local function near(a, b) return math.abs(a - b) < 1e-6 end

return {
    { "dots run from the centre towards the destination", function(T)
        local ns = T.fresh()
        -- 100 yards east, 400 yards across a 140 px minimap: 35 px away.
        local dots = ns.MinimapRoute.Layout(100, 0, { diameterYards = 400, widthPx = 140 })
        T.eq(#dots, 4)
        for _, d in ipairs(dots) do T.truthy(d.x > 0 and near(d.y, 0), "east is right") end
        local north = ns.MinimapRoute.Layout(0, -100, { diameterYards = 400, widthPx = 140 })
        T.truthy(north[1].y > 0 and near(north[1].x, 0), "north is up")
    end },

    { "far away: the dots stop at the edge", function(T)
        local ns = T.fresh()
        local dots = ns.MinimapRoute.Layout(5000, 0, { diameterYards = 400, widthPx = 140 })
        local last = dots[#dots]
        T.truthy(last.x < 70 - ns.MinimapRoute.EDGE_MARGIN, "inside the rim")
        T.truthy(last.x > 50)
    end },

    { "with Rotate Minimap, where you face is up", function(T)
        local ns = T.fresh()
        local facingEast = 3 * math.pi / 2 -- the game's facing turns anticlockwise from north
        local dots = ns.MinimapRoute.Layout(100, 0, { diameterYards = 400, widthPx = 140, rotate = facingEast })
        T.truthy(dots[1].y > 0 and math.abs(dots[1].x) < 1e-6, "east is ahead, so up")
        local facingWest = math.pi / 2
        local behind = ns.MinimapRoute.Layout(100, 0, { diameterYards = 400, widthPx = 140, rotate = facingWest })
        T.truthy(behind[1].y < 0, "facing away: down")
    end },

    { "zoom and indoors change the scale", function(T)
        local ns, mock = T.fresh()
        _G.Minimap.GetZoom = function() return 5 end
        T.truthy(near(ns.MinimapRoute.DiameterYards(), 133 + 1 / 3))
        mock.indoors = true
        T.eq(ns.MinimapRoute.DiameterYards(), 50)
    end },

    { "drawn while the Questwalker arrow guides you, and can be turned off", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        mock.player.facing = 0
        fixtures.login(ns)
        ns.Navigator.Draw()
        T.truthy((ns.MinimapRoute.count or 0) > 0, "dots on the minimap")
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_MINIMAP_ROUTE", false)
        ns.Navigator.Draw()
        T.eq(ns.MinimapRoute.count, 0, "off")
    end },
}
