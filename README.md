# Questwalker

A step-by-step leveling guide for **World of Warcraft: Forever**, in the style of RestedXP. It takes you from quest giver to quest giver with a waypoint arrow, and it updates as you accept, progress and hand in quests. It also tells you when to visit your trainer and when to buy things.

It reads your race, class, faction and level. From those it picks a leveling route, a spec to play and dungeons that fit your level, and it tracks your rested XP.

## Guides

A guide decides which zones you level in and how the step guide picks quests. Questwalker comes with a **Speedrun** and a **Story** guide, levels 1-60, for each starting area: **Orc & Troll**, **Tauren**, **Undead**, **Human**, **Dwarf & Gnome**, **Night Elf** and **Skyborne**. The Guides tab shows the two for your race, plus your own guides.

| | **Speedrun** | **Story** |
| --- | --- | --- |
| **Goal** | The quickest quest path to 60 for your race | The important quests of each zone, enough to level into the next |
| **Zones** | Your race's starting zones, then the densest zones (Riverglades carries 35-45) | Your race's starting zones, then the main zones for each level range |
| **Quests offered** | From 2 levels below you to 2 above | From 3 below you to 3 above (no grey quests) |
| **Skipped** | Quests whose objectives are more than 350 yards from the quest giver | Stand-alone side quests count as 350 yards further away, so they're only picked up when they're on the way |
| **Ordering** | Hand-ins first (120 yd bonus), then the nearest step | Quest chains first: follow-ups jump the queue (250 yd bonus), so each zone's story is told in order |

Each character follows one guide; pick it in the **Guides** tab. Every character starts on its race's Speedrun guide: a new character on the first quest, and an existing one on the best quest for its level and where it's standing. When you out-level your zone, the guide moves you on to the next one and says so.

### Your own guides

In the **Guides** tab:

- **Copy** makes your own version of any guide. Copying a built-in guide also fills in the full quest list those guides would pick for your character, so you can trim and reorder it.
- **New guide** starts from scratch.
- **Edit** opens the guide editor. **View** does the same for the read-only built-ins.
- **Export** shows the guide's JSON already selected, ready for Ctrl+C. Paste it into Discord, a forum or a file.
- **Import** takes a pasted guide.
- **Delete** removes your guide. Click it twice to confirm.

Your guides are saved account-wide, so every character can use them. If you edit the guide you're following, the step guide updates straight away.

### The guide editor

| Tab | What you do there |
| --- | --- |
| **Quests** | Your guide's quests, in order, with level and zone. Select one and use **Top**, **Up**, **Down**, **Bottom** or **Remove**. On the right, type part of a quest's name ("famil") or a quest ID to search QuestieDB, select a result, and click **Add after selected**. Quests already in the guide are marked. Below that, **Add a step** puts a step that isn't a quest after the selected entry: pick the kind (Note, Buy, Train, Hearth, Go to), type the text, optionally press **Use my location**, then **Add step**. Select a step in the list to change it with **Update step**. Steps move and delete like quests. |
| **Details** | Name, author, description, and whether it's based on **Story** or **Efficient** (Speedrun), which sets the default rules. |
| **JSON** | The whole guide as JSON, for the less common settings: zones per level, rules, skipped quests and extra steps. Changes here carry over to the other tabs. If the JSON doesn't parse, the editor keeps you here and shows the line and column. |

**Check** validates the guide without saving. **Save** always validates, so a broken guide is never stored.

**How a quest list is followed:**

- The step guide picks up the next quests on your list, in order. The next three get a strong head start, so they come first even when other quest givers are closer.
- Hand-ins and objectives still fit in by distance.
- Listed quests are offered wherever their giver stands, and whatever their level. Only the quest's own required level and earlier quests in its chain still count.
- Once nothing on the list is available, the guide's zones take over, so you're never stuck.

Guides without a list, like the built-in Speedrun and Story guides, use their zones from the start.

### Guide format (JSON)

JSON is easier to share than XML: it's shorter to paste, any text editor or online checker can validate it, and there are no closing tags to get wrong. A guide looks like this:

```json
{
  "format": "Questwalker guide",
  "version": 2,
  "name": "Hillsbrad Rush",
  "author": "Mike",
  "description": "My fastest Horde route.",
  "basedOn": "efficient",
  "rules": { "greyGap": 3, "maxDetour": 200 },
  "quests": [
    { "id": 788, "name": "Your Place In The World" },
    { "id": 789, "name": "Cutting Teeth" }
  ],
  "bands": [
    { "levels": [1, 10], "zones": ["START"], "notes": ["Talents open at level 10."] },
    { "levels": [11, 60], "alliance": ["Westfall"], "horde": ["The Barrens"] }
  ],
  "skipQuests": [123, 456],
  "steps": [ { "level": 12, "kind": "buy", "text": "Buy bags before leaving town." } ]
}
```

| Key | Meaning |
| --- | --- |
| `name` | Required. `author` and `description` are optional. |
| `basedOn` | `"story"` or `"efficient"`. Each one's rules are the defaults. |
| `rules` | Optional overrides, all whole numbers:<br>• `greyGap`: skip quests this many levels below you<br>• `levelsAbove`: allow quests this many levels above you<br>• `maxAccept`: quest givers considered at once<br>• `turninBonus` and `chainBonus`: yards a hand-in or story follow-up counts as closer<br>• `maxDetour`: skip quests whose objectives are this far from the giver (0 = no limit)<br>• `minRate`: skip quests paying less than this percentage of the typical XP per minute on offer (0 = off; Speedrun 50)<br>• `rateBonus`: yards a quest that pays well for its time counts as closer, or a poor one as further (0 = off; Speedrun 250) |
| `quests` | Your quests, in order. Each is `{ "id": 788, "name": "..." }` or just `788`. Only the id matters; the name is there for people reading the file. The list can also hold **steps that aren't quests**, see below. |
| `bands` | Zones per level range, covering 1-60 in order with no gaps or overlaps. `levels` is `[from, to]`. `zones` sets both factions; otherwise use `alliance` and `horde`. `"START"` means your race's starting zone. `notes` show on the Home tab. |
| `skipQuests` | Quest IDs the guide never picks up or auto-accepts. |
| `steps` | Extra steps from a level. `kind` is `train`, `buy`, `note` or `hearth`. `train` makes class training due from that level (it shows up when your trainer is nearby). `buy`, `note` and `hearth` become a step in the guide that you tick off with **Done**. |

Quest IDs are the numbers in Wowhead and Questie quest links, or search for the quest in the editor.

A few things are forgiving: trailing commas and `//` comments are allowed. Guides shared as 0.6 plain text still import, with their "priority quests" becoming the start of the quest list.

**Steps between quests.** Put these in the `quests` list wherever they belong:

```json
{ "step": "buy", "text": "Buy 6-slot bags from the vendor.", "zone": "Durotar", "x": 52.0, "y": 41.5 }
```

| `step` | What it does |
| --- | --- |
| `note` | Shows the text. You tick it off with **Done**. Needs `text`. |
| `buy` | Like a note, with a vendor icon. Needs `text`. |
| `train` | Without a location, points to your nearest class trainer. Clears when you open your class trainer. |
| `hearth` | Without a location, points to the nearest innkeeper. Clears when you set your hearthstone. |
| `goto` | Walk to a spot. Needs `zone`, `x` and `y`. Clears when you get within 20 yards. |

`text` is optional for `train`, `hearth` and `goto`. `zone` is the map name, and `x`/`y` are map coordinates from 0 to 100, as TomTom shows them. A step comes up once everything before it in the list is dealt with: earlier steps done, and no earlier quest still waiting to be picked up. Quests you can't do yet don't hold it back. Every step can also be ticked off with **Done**, skipped, or picked from the Steps tab.

Guides are read as data only, never run as code. Sizes are capped, and `|` is replaced because the game would read it as a colour or link code.

## The step guide

**How Speedrun picks quests:** each quest's XP per minute is estimated. The XP is what the game gives you at your level (from Questie's XP table, or an estimate from the quest's level). The time is the walk from the quest giver to the objectives and on to the hand-in, plus the work: the number of kills or items the quest text asks for, with elites counting as several kills and items as about one and a half kills each. Speedrun skips quests that pay less than half the typical rate on offer at your level, and puts the best ones first. Story doesn't use this.

The guide window shows your current step and the next few steps. Steps are built live from your quest log, QuestieDB and what's nearby:

| Step | Where it comes from |
| --- | --- |
| **Talk to (NPC) - Accept: (quests)** | Quests you can pick up now in your guide's zones. QuestieDB supplies the quest givers and checks prerequisites, race, class, faction and level. |
| **Complete: (quest)** | Quests in your log. The step shows live objective progress, and the arrow points to Blizzard's own quest waypoint or the nearest QuestieDB spawn. If an objective is an elite, the step says how to solo it: pull it to the nearest friendly guards, if any are within about 300 yards, or find a group. Quests whose objectives are in the same area (within about 150 yards of each other) are one step, such as "Complete: Cutting Teeth & Wayward Weapons", and the Target button cycles through all their creatures. |
| **Turn in to (NPC)** | Finished quests in your log, pointing to the NPC who ends the quest. |
| **Train at (trainer)** | When new class abilities are due (every two levels from 4) **and** your class trainer is within about 400 yards. |
| **Set your hearthstone at (innkeeper)** | At the inn nearest to where you're questing (the middle of your current quest steps), when you're there and your hearthstone is bound somewhere else. Inns you pass while travelling aren't suggested. Skip it and that inn won't ask again. |
| **Train (profession) at (trainer)** | For professions you've learned, when you're close to your skill cap, old enough for the next rank (Journeyman 10, Expert 20, Artisan 35) and a trainer for it is nearby. |

There's no separate reminders list: these service steps only appear in the route when they matter and you're close by.

Steps advance on their own:

- Accepting, progressing, handing in or abandoning a quest updates the guide immediately.
- Opening your class trainer completes the training step.
- Binding your hearthstone or training a profession removes that step.
- A guide's own `note` and `buy` steps are ticked off with **Done** or `/qw done`.

**Route order.** Steps are ordered as a walking route. From where you're standing, the guide always picks the nearest next step, and hand-ins get a small head start. The current step stays first until you finish or skip it, so the arrow doesn't jump around as you walk. Once you've walked about 150 yards, the rest of the list is re-sorted.

**Staying on your route.** On **Automatic**, new quests are only suggested in the zone you're in and in the zones of your current route band, which keeps the guide on the route you picked. If you pick a guide in the guide browser instead, new quests come only from that zone. Quests already in your log are always included, wherever they are.

### What it needs

- **[Questie](https://www.curseforge.com/wow/addons/questie) with QuestieDB (Forever bundle): strongly recommended.** QuestieDB is where quest-giver locations come from. Questwalker reads it through its documented `LibQuestieDB` API (contract 4). If Questie itself is also loaded, Questwalker uses Questie's own availability check, which knows about hidden and event quests. Without QuestieDB, the guide only covers quests already in your log.
- **[Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever): recommended, and used first when installed.** It plans real routes on foot, by flight path and by boat. Questwalker hands it the next several steps through its public API (`ShortestPathForever.API.NavigateRoute`, versions 1 and 2) as one journey with numbered, quest-badged stops. The current stop is held until the step really completes, so walking up to a quest giver doesn't skip ahead. Routes refused during combat are sent again when combat ends.
- **[TomTom](https://www.curseforge.com/wow/addons/tomtom): the alternative.** It provides the on-screen arrow. Addons that work from TomTom waypoints, such as Well Trodden (walking trails) and Map Shortcuts, then follow Questwalker's steps too. With neither addon installed, Questwalker tells you to install one (in the guide window, on Home, in Settings and once at login) and places the game's own map pin meanwhile.

## Features

- **Detects your character automatically.** It covers all 10 Forever races, including the Skyborne and their faction-specific classes. It also points out when you're playing one of the six new race/class combinations, such as an Undead Paladin or a Dwarf Shaman.
- **Guides you can edit and share:** Speedrun and Story guides for every race are built in, and you can copy, write, export and import your own. See above.
- **Target button.** Click it, or press its key, to target the nearest creature you still need for a quest.
- **Gives class advice.** You get a leveling spec, an alternative, the class's launch leveling tier and practical tips.
- **Suggests dungeons.** All Classic and new Forever dungeons in your level range are listed. Dungeons deep in enemy territory go to the bottom of the list.
- **Tracks rested XP.** It shows your rested pool as a percentage of the level, how much XP you need for the next level, and whether you're resting.
- **Announces level-ups.** When you enter a new band, it names the next zones in chat. It also announces milestones such as talents at 10, Tame Beast for Hunters, Legacy around 25, and riding and dual spec at 40.

## Install

**From CurseForge:** search for **Questwalker** in the CurseForge app with your WoW Forever installation selected, or download the zip from the project page and extract it into your AddOns folder.

**From GitHub:**

1. Download the latest release zip, or clone this repository into a folder named `Questwalker`.
2. Copy the `Questwalker` folder (the one that contains `Questwalker.toc`) into:
   - **Windows:** `World of Warcraft\_forever_\Interface\AddOns\`
   - **macOS:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
3. Check that the path ends in `AddOns/Questwalker/Questwalker.toc`.
4. Enable Questwalker in the AddOns list on the character select screen.

## Using it in game

Everything runs from the game's own UI.

**Minimap button** (the map icon on the edge of the minimap):

- **Left-click:** show or hide the step guide window.
- **Right-click:** open or close the main window.
- **Drag:** move the button around the minimap.

**Step guide window:** shows your current step and the next few steps.

- **Steps** opens the Steps list (below).
- **Skip** hides the current step's quests.
- **Done** appears on steps you tick off yourself.
- **Header:** names the guide you're following.
- **Resizing:** drag the bottom-right corner to make it wider or narrower. The text wraps to fit and the width is remembered.

**Steps tab:** every quest in your guide, 1 to 60, in order. Opening it scrolls to where you are.

- **Header:** where you are ("You're at quest 12 of 40") and how many are done, skipped and missed.
- **List:** number, level, quest, quest giver and status (Done, Ready, In log, Skipped, Missed, Available, Level n, Locked). The step the guide is showing now is marked with `>`.
- **Missed** means an available quest you've already moved past in the guide.
- **In log - too low to bother** means an unfinished quest more than the guide's grey limit below you. It isn't suggested; Abandon unrelated quests clears it out, and Go to this step still works if you want it.
- **In log - too hard until n** means a quest you've picked up that's still too far above your level, by its own level or its creatures'. It's on hold (the guide window lists it) until you reach level n; Go to this step overrides that.
- **Not offered** means you talked to the quest giver and the quest wasn't on offer: it needs an item, reputation or an earlier quest that QuestieDB doesn't know about. The guide moves on, and checks again when you level up.
- **Filters:** All, To do, Skipped & missed, Done.
- **Go to this step** (or double-click) makes the selected quest the current step until it's done. If you can't do it yet, it says why.
- **Skip / Unskip** the selected quest, and **Undo last skip** to step back through your last 50 skips (kept per character, even after a `/reload`).
- **Best step** is for when you're lost. It forgets the step you picked and the step the guide was holding on to, then picks the best step from where you're standing. Skipped quests stay skipped. Also `/qw best` or `/qw lost`.

**Target button:** a small button labelled with a creature's name, such as "Target: Near Scorpid (1/3)". **Each press targets the next creature you still need for a quest, from nearest to furthest, then starts again at the nearest.** The label shows which creature the next press targets.

- **Which creatures:** only those for the **current step**, including creatures that drop its quest items. The button hides on steps without creatures to kill, such as picking up or handing in quests. It skips kill objectives you've already finished. Each creature appears once, sorted by its nearest spawn, up to 8.
- **Several creatures:** when the current step needs more than one (for example a group of quests in the same area), a button for each extra creature appears under the main one, each targeting just that creature. The main button still cycles through all of them. The extra buttons move with the main one and can have their own key bindings ("Target quest mob 2" to "6").
- **In combat:** cycling works in combat because a secure snippet inside the button steps through the list. The list itself only refreshes out of combat, because the game forbids changing it during a fight. A new list starts again at the nearest creature.
- **Keybinding:** bind a key under *Key Bindings > AddOns > Questwalker*. Don't include Shift in that key, because Shift-clicks are ignored so you can drag the button. One press is one step, whether or not you use "cast on key down".
- **Moving it:** Shift + left-drag, out of combat. Its position is saved.
- **Turning it off:** use the checkbox in Settings.

**Abandon unrelated quests** (Settings > Tools): abandons quests in your log that aren't part of your guide, meaning not on its quest list and not in its zones for your level or the next band, plus unfinished quests too far below your level. Quests ready to hand in, class quests and quests QuestieDB doesn't know are always kept. The first click lists them in chat and the button asks "Abandon N quests? Click again"; leaving the tab cancels.

**Quest automation:** talking to a quest giver accepts their quests and hands in finished ones, with the reward taken for you.

- **Never automated:** choosing between several rewards, quests that cost gold to complete, quests shared by other players, and escort confirmations are always left to you.
- **Accept filters**, all set in Settings: quests you skipped in the guide, grey quests and repeatable quests are skipped. A guide's `skip quests` list is respected. Turn on "Only accept quests my guide uses" if you want Speedrun's level and detour filters applied too (off by default, so every quest you're offered is taken). Dialog replacements such as DialogueUI work too. Quests QuestieDB doesn't know yet are accepted.
- **Questie:** if Questie's own auto-accept or auto-complete is on, Questwalker stands aside and Settings tells you, so the two don't fight over the same window.

**Main window**, with four tabs. Drag its bottom-right corner to resize it; every tab adjusts to the new size, and the size is remembered.

| Tab | What's in it |
| --- | --- |
| **Home** | Your character, the guide you're following, where you're levelling now and next, your current step, rested XP, class tips, dungeons for your level, and a short explanation of every part of Questwalker. Buttons show or hide the guide window and open Steps or Guides. |
| **Steps** | Every quest in your guide, as described above. |
| **Guides** | The Speedrun and Story guides for your race, then yours. Select one to see its details, then **Use this guide**, **Edit** (or **View** for built-ins), **Copy**, **New guide**, **Delete**, **Export** or **Import**. Edit and View open the guide editor described above. |
| **Settings** | Show or hide the guide window, the Target button and the minimap button; level-up messages; the waypoint arrow (a dropdown: Automatic, Shortest Path, TomTom, Map pin, Off); bring back skipped quests, **abandon unrelated quests** and reset window positions. Quest automation: accept, hand in, skip grey or repeatable quests, and (off by default) only quests your guide uses. The two columns stack when the window is narrow. |

The minimap's addon compartment also opens the main window, even if you hide the minimap button.

### Slash commands (optional)

Everything above can also be done with commands, which is handy for macros: `/qw`, `/qw guide [on|off]`, `/qw skip`, `/qw back`, `/qw done`, `/qw best`, `/qw unskip`, `/qw waypoints auto|shortestpath|tomtom|builtin|off`, `/qw route speedrun|story|<your guide>`, `/qw next`, `/qw debug`, `/qw reset` and `/qw help`.

## Project layout

```
Questwalker.toc      Load order and metadata (Interface 16001 = Forever 1.60.1)
Core/Init.lua        Namespace and event dispatcher
Locales/enUS.lua     UI strings
Data/                Races, classes, dungeons, built-in guides, milestones, suggestions (plain tables)
Core/Util.lua        Helpers (secret-value guards, formatting, 64-bit-safe flag checks)
Core/Settings.lua    SavedVariables with defaults and schema versioning
Core/GameApi.lua     Every quest-log, map and position call, guarded and swappable in tests
Core/ZoneMap.lua     QuestieDB area IDs (0-100 coordinates) -> uiMapIDs (0-1 coordinates)
Core/Character.lua   Reads race/class/faction/level into a profile
Core/Advisor.lua     Pure planning logic: profile -> zone route
Integrations/        QuestieDB adapter and waypoint providers (Shortest Path Forever, TomTom, map pin)
Guide/Sources.lua    Live game state -> candidate steps
Guide/Planner.lua    Pure: merge steps at the same NPC, order as a walking route
Guide/Engine.lua     Events -> replans, sticky current step, skip/done, chosen guide, caching
Guide/Json.lua       Safe JSON encode/decode (size/depth limits, line:column errors)
Guide/GuideFormat.lua  Guide schema: check, normalise, to/from JSON (no code execution)
Guide/LegacyText.lua Reads 0.6 plain-text guides so old exports still import
Guide/Library.lua    Built-in and player guides: save, copy, delete, import, export, quest lists
Guide/Catalog.lua    Quest overviews per zone and quest statuses
Guide/AutoQuest.lua  Auto accept / turn in: pure decisions plus the quest dialog events
UI/MainFrame.lua     Main window shell: tabs and route picker
UI/*Tab.lua          Home, Steps, Guides (library) and Settings tabs
UI/GuideEditor.lua   Guide editor: Quests (search/add/reorder), Details, JSON; export/import
UI/GuideFrame.lua    Step guide window
UI/MinimapButton.lua Library-free minimap button
UI/TargetButton.lua  Secure button cycling quest mobs nearest-to-furthest (Bindings.xml adds its key)
Core/Commands.lua    Slash commands
Core/Bootstrap.lua   Event wiring
tests/               Lua 5.1 tests with a mocked WoW API, QuestieDB and TomTom
```

The code is layered so that most of it runs without the game. **Data** is plain tables, and **Advisor** and **Planner** are pure functions. **Sources** and **Engine** only reach the game through `GameApi` and the integrations, which the tests replace with fakes. The UI is a thin shell. Optional addons are only ever reached through `_G` with type checks and `pcall`, so a missing or broken Questie or TomTom can't break Questwalker.

## Development

You need Lua 5.1 and [luacheck](https://github.com/lunarmodules/luacheck).

```sh
lua5.1 tests/run.lua   # unit and smoke tests
luacheck .             # lint
```

GitHub Actions runs both on every push and pull request.

### Releasing

1. Update `## Version` in `Questwalker.toc` and add a `## [x.y.z]` section to `CHANGELOG.md`.
2. Tag and push: `git tag v0.8.0 && git push origin v0.8.0`.
3. The **Release** workflow checks the tag against the TOC, lints and tests, builds `Questwalker-x.y.z.zip` (without tests and dev files), publishes a GitHub release with that version's changelog, and uploads the zip to CurseForge for WoW Forever. Tags with a hyphen (`v0.9.0-beta1`) go up as betas.

CurseForge needs two settings under the repository's **Settings > Secrets and variables > Actions**:

- **Secret `CF_API_KEY`:** an API token from your CurseForge account (<https://legacy.curseforge.com/account/api-tokens>).
- **Variable `CURSEFORGE_PROJECT_ID`:** the project ID shown on the project's CurseForge page.
- Optional **variable `CURSEFORGE_GAME_VERSION_ID`:** if the automatic WoW Forever game version lookup picks the wrong one.

Without them the GitHub release still happens and the CurseForge step is skipped with a warning.

### Updating the advice

Leveling data is opinion-based and goes out of date with balance patches. All of it lives in `Data/`:

- **Changing a class spec or tip:** edit `Data/Classes.lua`.
- **Changing zones in a route:** edit `Data/Routes.lua`. The tests check that every route still covers levels 1 to 60 with no gaps.
- **Adding a race:** add it to `Data/Races.lua`, keyed by the `raceFile` from `UnitRace("player")`.
- **Tuning service steps:** `Data/Services.lua` has the "nearby" distance, the training cadence, the professions list and the levels for each profession rank.

### Notes on the Forever client

- The interface number is **16001**. You can confirm it in game with `/dump select(4, GetBuildInfo())`.
- Forever uses the modern (Midnight-era) addon API. Old globals such as `GetSpellInfo` and `GetTalentInfo` don't exist, and some unit values can be "secret". Questwalker only reads basic character info and XP, and it checks every value with `issecretvalue`.
- The Skyborne `raceFile` token wasn't documented at launch, so race detection falls back to matching names ("Skyborne", "High Order" and "Windshaper").
- Skyborne race masks in QuestieDB go up to 2^33. That's beyond WoW's 32-bit `bit.band`, so flags are checked with plain arithmetic in `Util.HasFlag`.
- The guide never calls `C_SuperTrack.SetSuperTrackedUserWaypoint`, because Forever addon guidance warns against it. The built-in provider only places a map pin, so use TomTom for an on-screen arrow.

### Known limits

- **Data depends on QuestieDB.** Forever's newer quests, especially the new zones above level 40, are still being added to QuestieDB. Where it has no entry, the guide only knows about those quests once they're in your log.
- **Training cadence is assumed.** Class training every two levels and the profession rank levels follow Classic. Forever's schedule isn't published, so they're settings in `Data/Services.lua`.
- **Only English titles are found.** Trainers and innkeepers are matched by their English title, such as "Mage Trainer" or "Innkeeper", so other locales don't get these steps.
- **Not tested in the game yet.** It has been tested against a mocked client only.

## Data sources

The data was gathered in November 2026, shortly after Forever launched on 4 November 2026. The sources were:

- Warcraft Wiki for races, new dungeons and level ranges
- RankedBoost's WoW Forever leveling guide for zone bands and travel notes
- Tier lists from AxeeTech, Timesaver and MMOnster for leveling specs
- Icy Veins and Gfinity for race/class combinations
- Questie's `Public/` API and `LibQuestieDB` type declarations for the QuestieDB integration
- TomTom's `AddWaypoint` and `RemoveWaypoint` API for the arrow
- Shortest Path Forever's `docs/api.md` for journey routing

Where sources disagreed, the Warcraft Wiki range was used. For example, Excavation Site: Wetlands is listed as both 24-29 and 26-31. Shen'dralas had no confirmed level range at launch.

## License

[MIT](LICENSE)
