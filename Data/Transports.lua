--[[
    Questwalker - Data/Transports.lua

    Boats and zeppelins between continents, for the navigator. Each runs
    both ways between two docks. Positions are map coordinates (0-100) on
    the dock's zone map, close enough for an arrow to bring you to the
    pier or tower. `faction` is who the dock's town is friendly to (nil:
    anyone).
]]

local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Transports = {
    { kind = "zeppelin", faction = "Horde",
      a = { name = "Orgrimmar zeppelin tower", mapID = 1411, x = 50.8, y = 13.6 },
      b = { name = "Tirisfal zeppelin tower", mapID = 1420, x = 60.7, y = 58.8 } },
    { kind = "zeppelin", faction = "Horde",
      a = { name = "Orgrimmar zeppelin tower", mapID = 1411, x = 50.6, y = 12.6 },
      b = { name = "Grom'gol zeppelin tower", mapID = 1434, x = 31.4, y = 29.8 } },
    { kind = "boat", faction = "Alliance",
      a = { name = "Menethil Harbor docks", mapID = 1437, x = 4.6, y = 57.0 },
      b = { name = "Theramore docks", mapID = 1445, x = 71.5, y = 56.4 } },
    { kind = "boat", faction = "Alliance",
      a = { name = "Menethil Harbor docks", mapID = 1437, x = 4.9, y = 63.5 },
      b = { name = "Auberdine docks", mapID = 1439, x = 32.4, y = 43.8 } },
    { kind = "boat",
      a = { name = "Booty Bay docks", mapID = 1434, x = 25.9, y = 73.1 },
      b = { name = "Ratchet docks", mapID = 1413, x = 63.7, y = 38.6 } },
}
