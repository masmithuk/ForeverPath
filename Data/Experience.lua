--[[
    Questwalker - Data/Experience.lua

    Experience numbers for the Grind step (Classic values; WoW Forever's
    curve is close enough to estimate kills). The live XP bar and rested
    XP are read every time, so XP bonuses keep the estimate honest.

      XP_TO_LEVEL[n]   XP needed to go from level n to n + 1
      MobXP(p, m)      XP for killing a level m mob at level p
      KillsNeeded(...) kills to earn an amount of XP, using rested XP first
]]

local _, ns = ...

local Experience = {}
ns.Data.Experience = Experience

Experience.XP_TO_LEVEL = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
    8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
    25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
    95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
    153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}

-- "Zero difference": how many levels below you a mob can be before it gives
-- no XP, by your level.
local function zeroDifference(level)
    if level < 8 then return 5 end
    if level < 10 then return 6 end
    if level < 12 then return 7 end
    if level < 16 then return 8 end
    if level < 20 then return 9 end
    if level < 30 then return 11 end
    if level < 40 then return 12 end
    if level < 45 then return 13 end
    if level < 50 then return 14 end
    if level < 55 then return 15 end
    if level < 60 then return 16 end
    return 17
end

--- XP for killing a normal mob of level `mob` at level `player`.
function Experience.MobXP(player, mob)
    local base = player * 5 + 45
    if mob >= player then
        return base * (1 + 0.05 * math.min(4, mob - player))
    end
    local factor = 1 - (player - mob) / zeroDifference(player)
    return factor > 0 and base * factor or 0
end

--- XP still needed to reach `target` from `level`, given the XP bar.
function Experience.XPToReach(level, target, xp, xpMax)
    local need = math.max(0, (xpMax or Experience.XP_TO_LEVEL[level] or 0) - (xp or 0))
    for l = level + 1, target - 1 do need = need + (Experience.XP_TO_LEVEL[l] or 0) end
    return need
end

--- Kills to earn `need` XP at `perKill` each. Rested XP doubles a kill's XP
--- until the rested pool is used up.
function Experience.KillsNeeded(need, perKill, rested)
    if perKill <= 0 then return nil end
    rested = rested or 0
    if 2 * rested >= need then return math.ceil(need / (2 * perKill)) end
    return math.ceil(rested / perKill + (need - 2 * rested) / perKill)
end
