--[[
    ForeverPath - Core/Character.lua

    Reads the player's race, class, faction and level and normalises them
    into a "profile" table the Advisor understands.

    All WoW API access goes through an injectable `api` table so the logic
    can be tested outside the game (see tests/).
]]

local _, ns = ...

local Character = {}
ns.Character = Character

--- Default API adapter: thin wrappers over the real game functions.
Character.defaultApi = {
    UnitRace = function() return UnitRace("player") end,
    UnitClass = function() return UnitClass("player") end,
    UnitLevel = function() return UnitLevel("player") end,
    UnitFactionGroup = function() return UnitFactionGroup("player") end,
}

local function normalise(token)
    -- Parenthesised: gsub also returns a match count we don't want.
    return ((token or ""):lower():gsub("[^%a]", ""))
end

--- Map a raceFile / localized race name to a key in ns.Data.Races.
--- Returns nil when the race is unknown.
function Character.ResolveRaceKey(raceFile, localizedName)
    local races = ns.Data.Races
    if raceFile and races[raceFile] then
        return raceFile
    end

    -- Fall back to fuzzy matching, which also catches the Skyborne
    -- sub-races whose tokens weren't documented at launch.
    local candidates = { normalise(raceFile), normalise(localizedName) }
    for key, race in pairs(races) do
        local names = { normalise(key), normalise(race.name) }
        for _, alias in ipairs(race.aliases or {}) do
            names[#names + 1] = alias
        end
        for _, candidate in ipairs(candidates) do
            if candidate ~= "" then
                for _, name in ipairs(names) do
                    if candidate == name or candidate:find(name, 1, true) then
                        return key
                    end
                end
            end
        end
    end
    return nil
end

--- Allowed classes for a race on a given faction.
function Character.GetRaceClasses(race, faction)
    if race.classes then
        return race.classes
    end
    if race.classesByFaction then
        return race.classesByFaction[faction] or {}
    end
    return {}
end

--- Build the player profile.
-- @param api optional adapter (defaults to the live game API)
-- @return table profile
function Character.Detect(api)
    api = api or Character.defaultApi
    local Util = ns.Util

    local localizedRace, raceFile = api.UnitRace()
    local localizedClass, classFile = api.UnitClass()
    local faction = Util.SafeString(api.UnitFactionGroup())
    local level = Util.SafeNumber(api.UnitLevel()) or 1

    local raceKey = Character.ResolveRaceKey(raceFile, localizedRace)
    local race = raceKey and ns.Data.Races[raceKey] or nil
    local class = ns.Data.Classes[classFile]

    if faction ~= "Alliance" and faction ~= "Horde" then
        faction = "Neutral"
    end

    local isNewCombo = false
    if race and classFile then
        isNewCombo = Character.GetRaceClasses(race, faction)[classFile] == "new"
    end

    return {
        raceKey = raceKey,
        raceName = (race and race.name) or localizedRace or "Unknown",
        race = race,
        classFile = classFile,
        className = (class and class.name) or localizedClass or "Unknown",
        class = class,
        level = level,
        faction = faction,
        isNewCombo = isNewCombo,
    }
end
