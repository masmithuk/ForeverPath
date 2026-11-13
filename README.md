# ForeverPath

A step-by-step leveling guide for **World of Warcraft: Forever**, in the style of RestedXP. It takes you from quest giver to quest giver with a waypoint arrow, and it updates as you accept, progress and hand in quests. It also tells you when to visit your trainer and when to buy things.

It reads your race, class, faction and level. From those it picks a leveling route, a spec to play and dungeons that fit your level, and it tracks your rested XP.

## The step guide

The guide window shows your current step, the next few steps and a short list of reminders. Steps are built live from three sources:

| Step | Where it comes from |
|---|---|
| **Talk to (NPC) - Accept: (quests)** | Quests you can pick up now in your route's zones. QuestieDB supplies the quest givers and checks prerequisites, race, class, faction and level. |
| **Complete: (quest)** | Quests in your log. The step shows live objective progress, and the arrow points to Blizzard's own quest waypoint or the nearest QuestieDB spawn. |
| **Turn in to (NPC)** | Finished quests in your log, pointing to the NPC who ends the quest. |
| **Train at (trainer)** | Every two levels from level 4, pointing to your nearest class trainer. |
| **Reminders** | Setting your hearthstone, buying bags, spending talents, learning First Aid, Riding and dual spec, plus class-specific steps. |

Steps advance on their own:

- Accepting, progressing, handing in or abandoning a quest updates the guide immediately.
- Opening your class trainer completes the training step.
- Binding your hearthstone completes the hearth reminder.
- Reminders the game can't detect, like buying bags, are ticked off by clicking them or typing `/fp done`.

**Route order.** Steps are ordered as a walking route. From where you're standing, the guide always picks the nearest next step, and hand-ins get a small head start. The current step stays first until you finish or skip it, so the arrow doesn't jump around as you walk. Once you've walked about 150 yards, the rest of the list is re-sorted.

**Staying on your route.** On **Automatic**, new quests are only suggested in the zone you're in and in the zones of your current route band, which keeps the guide on the route you picked. If you pick a guide in the guide browser instead, new quests come only from that zone. Quests already in your log are always included, wherever they are.

### What it needs

- **[Questie](https://www.curseforge.com/wow/addons/questie) with QuestieDB (Forever bundle): strongly recommended.** QuestieDB is where quest-giver locations come from. ForeverPath reads it through its documented `LibQuestieDB` API (contract 4). If Questie itself is also loaded, ForeverPath uses Questie's own availability check, which knows about hidden and event quests. Without QuestieDB, the guide only covers quests already in your log.
- **[TomTom](https://www.curseforge.com/wow/addons/tomtom): recommended.** It provides the on-screen arrow. Addons that work from TomTom waypoints, such as Well Trodden (walking trails) and Map Shortcuts, then follow ForeverPath's steps too. Without TomTom, ForeverPath places the game's own map pin instead.

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

## Using it in game

Everything runs from the game's own UI.

**Minimap button** (the map icon on the edge of the minimap):
- **Left-click:** show or hide the step guide window.
- **Right-click:** open or close the main window.
- **Drag:** move the button around the minimap.

**Step guide window:** shows your current step, the next few steps and your reminders.
- **Skip** hides the current step's quests.
- **Done** appears on steps you tick off yourself.
- **Guides** opens the guide browser.
- **Reminders:** click one to mark it done.
- **Header:** names the guide you're following.

**Main window**, with three tabs. The route buttons at the top (Forever Frontier, Classic Questing, Dungeon Runner) apply to Guides and Plan.

| Tab | What's in it |
|---|---|
| **Guides** | A list of every zone guide on your route. Each guide shows its level range and how many of its quests you've done, guides for your level are gold, and the one you're following has an arrow. Click a guide to see all its quests: level, quest giver and your status (Done, Ready to turn in, In your log, Available, the level you need, or Requirements not met yet). **Follow this guide** keeps the step guide in that zone. **Automatic** goes back to following your route for your level. |
| **Plan** | Leveling spec and tips for your class, your route's level bands, dungeons for your level, upcoming milestones and rested XP. |
| **Settings** | Turn step-by-step guiding on or off, show or hide the guide window and the minimap button, and turn level-up announcements on or off. Choose the waypoint arrow (Automatic, TomTom, Map pin, Off). Bring back skipped quests, and reset window positions. |

The minimap's addon compartment also opens the main window, even if you hide the minimap button.

### Slash commands (optional)

Everything above can also be done with commands, which is handy for macros: `/fp`, `/fp guide [on|off]`, `/fp skip`, `/fp done`, `/fp unskip`, `/fp waypoints auto|tomtom|builtin|off`, `/fp route frontier|classic|dungeon`, `/fp next`, `/fp reset` and `/fp help`.

## Project layout

```
ForeverPath.toc      Load order and metadata (Interface 16001 = Forever 1.60.1)
Core/Init.lua        Namespace and event dispatcher
Locales/enUS.lua     UI strings
Data/                Races, classes, dungeons, routes, milestones, suggestions (plain tables)
Core/Util.lua        Helpers (secret-value guards, formatting, 64-bit-safe flag checks)
Core/Settings.lua    SavedVariables with defaults and schema versioning
Core/GameApi.lua     Every quest-log, map and position call, guarded and swappable in tests
Core/ZoneMap.lua     QuestieDB area IDs (0-100 coordinates) -> uiMapIDs (0-1 coordinates)
Core/Character.lua   Reads race/class/faction/level into a profile
Core/Advisor.lua     Pure planning logic: profile -> zone route
Integrations/        QuestieDB adapter and waypoint providers (TomTom, built-in pin)
Guide/Sources.lua    Live game state -> candidate steps
Guide/Planner.lua    Pure: merge steps at the same NPC, order as a walking route
Guide/Engine.lua     Events -> replans, sticky current step, skip/done, chosen guide, caching
Guide/Catalog.lua    Zone guides per route and their quest overviews (guide browser data)
UI/MainFrame.lua     Main window shell: tabs and route picker
UI/*Tab.lua          Guides (browser), Plan and Settings tabs
UI/GuideFrame.lua    Step guide window
UI/MinimapButton.lua Library-free minimap button
Core/Commands.lua    Slash commands
Core/Bootstrap.lua   Event wiring
tests/               Lua 5.1 tests with a mocked WoW API, QuestieDB and TomTom
```

The code is layered so that most of it runs without the game. **Data** is plain tables, and **Advisor** and **Planner** are pure functions. **Sources** and **Engine** only reach the game through `GameApi` and the integrations, which the tests replace with fakes. The UI is a thin shell. Optional addons are only ever reached through `_G` with type checks and `pcall`, so a missing or broken Questie or TomTom can't break ForeverPath.

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
- **Adding a reminder step:** add a row to `Data/Suggestions.lua`. `detect = "trainer"` or `"hearth"` makes it complete on its own. Without `detect`, the player clicks it off.

### Notes on the Forever client

- The interface number is **16001**. You can confirm it in game with `/dump select(4, GetBuildInfo())`.
- Forever uses the modern (Midnight-era) addon API. Old globals such as `GetSpellInfo` and `GetTalentInfo` don't exist, and some unit values can be "secret". ForeverPath only reads basic character info and XP, and it checks every value with `issecretvalue`.
- The Skyborne `raceFile` token wasn't documented at launch, so race detection falls back to matching names ("Skyborne", "High Order" and "Windshaper").
- Skyborne race masks in QuestieDB go up to 2^33. That's beyond WoW's 32-bit `bit.band`, so flags are checked with plain arithmetic in `Util.HasFlag`.
- The guide never calls `C_SuperTrack.SetSuperTrackedUserWaypoint`, because Forever addon guidance warns against it. The built-in provider only places a map pin, so use TomTom for an on-screen arrow.

### Known limits

- **Data depends on QuestieDB.** Forever's newer quests, especially the new zones above level 40, are still being added to QuestieDB. Where it has no entry, the guide only knows about those quests once they're in your log.
- **Training cadence is assumed.** The every-two-levels training reminder follows Classic. Forever's trainer schedule isn't published, so the cadence is a setting in `Data/Suggestions.lua`.
- **Only English trainers are found.** Class trainers are matched by their English title, such as "Mage Trainer", so other locales don't get a trainer location. They still get the reminder.
- **Not tested in the game yet.** It has been tested against a mocked client only.

## Data sources

The data was gathered in November 2026, shortly after Forever launched on 4 November 2026. The sources were:

- Warcraft Wiki for races, new dungeons and level ranges
- RankedBoost's WoW Forever leveling guide for zone bands and travel notes
- Tier lists from AxeeTech, Timesaver and MMOnster for leveling specs
- Icy Veins and Gfinity for race/class combinations
- Questie's `Public/` API and `LibQuestieDB` type declarations for the QuestieDB integration
- TomTom's `AddWaypoint` and `RemoveWaypoint` API for the arrow

Where sources disagreed, the Warcraft Wiki range was used. For example, Excavation Site: Wetlands is listed as both 24-29 and 26-31. Shen'dralas had no confirmed level range at launch.

## License

[MIT](LICENSE)
