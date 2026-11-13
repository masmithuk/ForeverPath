# ForeverPath

A leveling companion for **World of Warcraft: Forever**. It reads your race, class, faction and level, then shows you which leveling spec to play, where to quest now and next, which dungeons fit your level, and how much rested XP you have.

It's inspired by RestedXP, but it's lighter. ForeverPath suggests routes. It doesn't give you step-by-step quest waypoints.

## Features

- **Detects your character automatically.** It covers all 10 Forever races, including the Skyborne and their faction-specific classes. It also points out when you're playing one of the six new race/class combinations, such as an Undead Paladin or a Dwarf Shaman.
- **Three routes:**
  - **Forever Frontier.** Sends you through the new content: Zephras Isle, Riverglades, Shen'dralas and Mount Hyjal, plus the new dungeons.
  - **Classic Questing.** The familiar vanilla path.
  - **Dungeon Runner.** Quest near dungeon entrances and run every dungeon in your range.
- **Picks a starting route for your class.** Warriors and Priests start on Dungeon Runner, Rogues on Classic Questing, and everyone else on Forever Frontier. You can switch at any time, and your choice is saved per character.
- **Gives class advice.** You get a leveling spec, an alternative, the class's launch leveling tier and practical tips.
- **Suggests dungeons.** All Classic and new Forever dungeons in your level range are listed. Dungeons deep in enemy territory go to the bottom of the list.
- **Tracks rested XP.** It shows your rested pool as a percentage of the level, how much XP you need for the next level, and whether you're resting.
- **Announces level-ups.** When you enter a new band, it names the next zones in chat. It also announces milestones such as talents at 10, Tame Beast for Hunters, Legacy around 25, and riding and dual spec at 40.

## Install

1. Download or clone this repository.
2. Copy the `ForeverPath` folder (the one that contains `ForeverPath.toc`) into:
   - **Windows:** `World of Warcraft\_forever_\Interface\AddOns\`
   - **macOS:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
3. Check that the path ends in `AddOns/ForeverPath/ForeverPath.toc`.
4. Enable ForeverPath in the AddOns list on the character select screen.

## Usage

| Command | What it does |
|---|---|
| `/fp` | Toggle the window |
| `/fp route frontier\|classic\|dungeon` | Choose a route |
| `/fp next` | Print your current and next zones to chat |
| `/fp reset` | Reset the window position |
| `/fp help` | List commands |

You can also open the window from the minimap's addon compartment. Press Esc to close it, and drag it to move it.

## Project layout

```
ForeverPath.toc      Load order and metadata (Interface 16001 = Forever 1.60.1)
Core/Init.lua        Namespace and event dispatcher
Locales/enUS.lua     UI strings
Data/                Races, classes, dungeons, routes, milestones (all plain tables)
Core/Util.lua        Helpers (secret-value guards, formatting, defaults)
Core/Settings.lua    SavedVariables with defaults and schema versioning
Core/Character.lua   Reads race/class/faction/level into a profile
Core/Advisor.lua     Pure planning logic: profile -> plan
UI/Text.lua          Plan -> window text
UI/MainFrame.lua     The window
Core/Commands.lua    Slash commands
Core/Bootstrap.lua   Event wiring
tests/               Lua 5.1 tests with a mocked WoW API
```

The code is layered so that most of it runs without the game. **Data** is plain tables, **Advisor** is pure functions, and **UI** is a thin shell. All game API calls go through small adapters that the tests replace with fakes.

## Development

You need Lua 5.1 and [luacheck](https://github.com/lunarmodules/luacheck).

```sh
lua5.1 tests/run.lua   # unit and smoke tests
luacheck .             # lint
```

GitHub Actions runs both on every push and pull request.

### Updating the advice

Leveling data is opinion-based and goes out of date with balance patches. All of it lives in `Data/`:

- **Changing a class spec or tip:** edit `Data/Classes.lua`.
- **Changing zones in a route:** edit `Data/Routes.lua`. The tests check that every route still covers levels 1 to 60 with no gaps.
- **Adding a race:** add it to `Data/Races.lua`, keyed by the `raceFile` from `UnitRace("player")`.

### Notes on the Forever client

- The interface number is **16001**. You can confirm it in game with `/dump select(4, GetBuildInfo())`.
- Forever uses the modern (Midnight-era) addon API. Old globals such as `GetSpellInfo` and `GetTalentInfo` don't exist, and some unit values can be "secret". ForeverPath only reads basic character info and XP, and it checks every value with `issecretvalue`.
- The Skyborne `raceFile` token wasn't documented at launch, so race detection falls back to matching names ("Skyborne", "High Order" and "Windshaper").

## Data sources

The data was gathered in November 2026, shortly after Forever launched on 4 November 2026. The sources were:

- Warcraft Wiki for races, new dungeons and level ranges
- RankedBoost's WoW Forever leveling guide for zone bands and travel notes
- Tier lists from AxeeTech, Timesaver and MMOnster for leveling specs
- Icy Veins and Gfinity for race/class combinations

Where sources disagreed, the Warcraft Wiki range was used. For example, Excavation Site: Wetlands is listed as both 24-29 and 26-31. Shen'dralas had no confirmed level range at launch.

## License

[MIT](LICENSE)
