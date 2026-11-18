-- Numbered markers on the world map for the guide's next steps.

local fixtures = require("fixtures")

local function step(title, mapID, x, y)
    return { title = title, lines = {}, target = { mapID = mapID, x = x, y = y } }
end

local function worldMap(mock, mapID)
    local map = mock.newFrame()
    map.shown = true
    map.mapID = mapID
    map.GetMapID = function(self) return self.mapID end
    map.ScrollContainer = mock.newFrame()
    map.ScrollContainer.GetCanvasScale = function() return 1 end
    map.ScrollContainer.Child = mock.newFrame()
    map.ScrollContainer.Child:SetSize(1000, 700)
    _G.WorldMapFrame = map
    return map
end

return {
    { "numbers each step's spot on the map, in order", function(T)
        local ns = T.fresh()
        local markers = ns.MapPins.Layout({
            step("Talk to A", 1411, 0.4, 0.5), step("Kill boars", 1411, 0.6, 0.3), step("Go to Tirisfal", 1420, 0.5, 0.5),
        }, 1411)
        T.eq(#markers, 2, "the Tirisfal step isn't on this map")
        T.eq(markers[1].numbers[1], 1); T.truthy(markers[1].current)
        T.eq(markers[2].numbers[1], 2); T.eq(markers[2].x, 0.6)
    end },

    { "steps at the same spot share one marker", function(T)
        local ns = T.fresh()
        local markers = ns.MapPins.Layout({
            step("Accept", 1411, 0.45, 0.5), step("Kill", 1411, 0.7, 0.7), step("Turn in", 1411, 0.452, 0.5),
        }, 1411)
        T.eq(#markers, 2)
        T.eq(ns.MapPins.Label(markers[1].numbers), "1, 3")
        T.eq(ns.MapPins.Label({ 4, 5, 6 }), "4-6")
    end },

    { "steps in other zones show on the continent map", function(T)
        local ns = T.fresh()
        local markers = ns.MapPins.Layout({ step("Durotar", 1411, 0.5, 0.5), step("Barrens", 1413, 0.5, 0.5) }, 1414)
        T.eq(#markers, 2)
        T.truthy(math.abs(markers[1].x - 500 / 3000) < 1e-9)
        T.truthy(math.abs(markers[2].x - 2500 / 3000) < 1e-9)
    end },

    { "draws the plan on the open world map, and can be turned off", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        worldMap(mock, 1411)
        local state = fixtures.login(ns)
        local shown = ns.MapPins.Shown()
        T.truthy(#shown > 0, "markers drawn")
        T.eq(shown[1]:sub(1, 1), "1", "the current step is 1")
        T.truthy(#state.steps >= #shown)
        ns.MainFrame.ShowTab("settings")
        ns.SettingsTab.Click("SETTING_MAP_NUMBERS", false)
        T.eq(#ns.MapPins.Shown(), 0, "off")
        ns.SettingsTab.Click("SETTING_MAP_NUMBERS", true)
        T.truthy(#ns.MapPins.Shown() > 0, "back on")
    end },

    { "nothing breaks without a world map", function(T)
        local ns, mock = T.fresh()
        fixtures.durotar(mock)
        _G.WorldMapFrame = nil
        fixtures.login(ns)
        T.eq(#ns.MapPins.Shown(), 0)
    end },
}
