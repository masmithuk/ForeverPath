# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.7.0] - 2026-11-15

### Added
- Guides can have their own **quest list**. The step guide follows it in order: the next three listed quests get a strong head start, and hand-ins and objectives still fit in by distance. When nothing on the list is available, the guide's zones take over.
- New guide editor:
  - **Quests** tab: the guide's quests with level and zone, Top/Up/Down/Bottom/Remove, and QuestieDB search by partial name or quest ID with "Add after selected".
  - **Details** tab: name, author, description, and Story or Efficient.
  - **JSON** tab: everything else, including zones, rules, skipped quests and steps.
- Viewing a built-in guide shows the full quest list it picks for your character. Copying one turns that list into your own editable list.
- Quest search across all of QuestieDB, so you can write guides for other races and factions too.

### Changed
- Guides are now **JSON** (format version 2) for export and import, and are saved as plain data. JSON has line and column errors, path-based messages (for example `quests[2].id must be a whole number`), and allows trailing commas and `//` comments.
- 0.6 text guides are converted automatically when they load or are imported. Their "priority quests" become the start of the quest list.

### Removed
- "Priority quests". Put those quests at the top of the quest list instead.

## [0.6.0] - 2026-11-15

### Added
- Your own guides. Every guide, built-in or yours, is plain text in a documented format: header, rules, level bands per faction, notes, skip and priority quest lists, and custom reminder steps.
- **Guides** tab, the guide library: use, edit, view, copy, create, delete (with confirmation), export and import.
- Guide editor window. It has Check and Save with line-numbered errors, export (text pre-selected for Ctrl+C), import and read-only view with "Copy & edit".
- Guides' skip lists, priority quests and custom steps drive the step guide and auto-accept.
- Player guides are saved account-wide. The parser never runs code and strips `|` escape codes.

### Changed
- The old zone browser is now the **Zones** tab, with "Follow this zone". The main window shows the current guide with a "Change guide" button.
- `/fp route` accepts any guide's id or name.

### Removed
- Dungeon mode. Characters using it move to Efficient. The "Run (dungeon)" step for dungeon quests already in your log is kept.

## [0.5.0] - 2026-11-15

### Changed
- The Target button now cycles. Each press targets the next quest creature, from nearest to furthest, then starts again. It works in combat through a secure pre-click snippet and moves one step per press in either key-down mode. The label shows the next target and its position, such as "(2/3)".
- Shift + left-drag moves the Target button, and Shift-clicks no longer target anything.

### Added
- Auto accept and auto turn-in when talking to quest givers. Finished quests are handed in first. Handles the gossip list, the older quest greeting, quest text, the progress check and the reward window.
- Safeguards:
  - Hold Shift (configurable) to pause for a conversation.
  - Never picks between several rewards or pays gold.
  - Ignores quests shared by players.
  - Tries each quest once per conversation, so a full log can't loop.
  - Stands aside when Questie's own automation is on.
- Accept filters: skipped quests, grey quests, repeatable quests, and "only quests my mode would pick", which uses the mode's level window, Efficient's detour limit and Dungeon mode's dungeon quests.
- Quest automation column in the Settings tab.

## [0.4.0] - 2026-11-13

### Changed
- The three routes are now three modes with their own rules, all in `Data/Routes.lua`:
  - **Story (Completionist):** every zone and every quest in a wide level range, with chain follow-ups first.
  - **Efficient (Speedrun):** dense zones, worthwhile quests only, no objectives more than 350 yards from their giver, and hand-ins first.
  - **Dungeon:** every quest for dungeons in your range from anywhere, filler quests only near entrances, and dungeon pickups first.
- Saved route choices carry over (Classic becomes Story, Frontier becomes Efficient). Switching mode clears the chosen guide.
- Planner bonuses come from the mode's rules instead of being hard-coded.

### Added
- Dungeon mode's guide browser lists dungeons, each with its entrance zone and quests.
- **Run (dungeon)** steps merge your log's quests for the same dungeon.
- Shortest Path Forever waypoint provider. It's used first when installed and takes the next steps as one held, multi-stop journey, sent again after combat. TomTom, then the map pin, are the fallbacks.
- Target button with a keybinding. It's a secure macro button that targets the nearest creature you still need for an objective, including droppers of quest items. It updates only out of combat.

## [0.3.0] - 2026-11-13

### Added
- Minimap button: left-click toggles the step guide, right-click opens the main window, and you can drag it around the minimap edge.
- Guide browser (Guides tab): every zone guide on your route, with level range and progress. Selecting a guide lists its quests with level, quest giver and your status. **Follow this guide** or **Automatic** picks what the step guide follows.
- Settings tab with checkboxes and buttons for every option: guide on or off, guide window, minimap button, announcements, waypoint arrow, bring back skipped quests, and reset positions.
- **Guides** button and an active-guide header in the step guide window.

### Changed
- The main window is now tabbed (Guides, Plan, Settings). Slash commands still work but aren't needed.
- XP updates only redraw the Plan tab. The guide browser redraws when quest state changes.

## [0.2.0] - 2026-11-13

### Added
- Step-by-step guide window that takes you from quest giver to quest giver: accept, complete and turn in, with live objective progress.
- QuestieDB integration through the documented `LibQuestieDB` API (contract 4). It finds quest givers, quest enders and objective locations, and checks race, class, faction, level and prerequisites. Questie's own availability check is used when the full Questie addon is loaded.
- Walking-route ordering: nearest step next, a small preference for hand-ins, a current step that stays put, and re-sorting after you've walked about 150 yards.
- New quests are limited to your current route band's zones plus the zone you're in.
- Class training steps every two levels, pointing to your nearest class trainer. Opening the trainer completes the step.
- Reminders for hearthstone, bags, talents, First Aid, Riding, dual spec and some class-specific steps.
- Waypoints through TomTom (which also drives TomTom-based path addons) or the built-in map pin: `/fp waypoints`.
- `/fp guide`, `/fp skip`, `/fp done` and `/fp unskip` commands.
- Tests for the planner, the QuestieDB adapter and the engine, using fake QuestieDB and TomTom.

### Changed
- Saved variables schema 2 adds guide settings. Existing settings are kept.
- Eligibility checks are cached between quest-state changes, so kills and loot don't trigger a full rescan.

## [0.1.0] - 2026-11-13

### Added
- Detects race, class, faction and level, including the Skyborne and the new Forever race/class combinations.
- Three leveling routes: Forever Frontier, Classic Questing and Dungeon Runner.
- Leveling spec, alternative spec, tier and tips for each class.
- Dungeon suggestions for your level, with the new Forever dungeons tagged.
- Rested XP and XP-to-level display.
- Chat announcements when you enter a new band or reach a milestone.
- `/fp` slash commands and an addon compartment entry.
- Unit tests with a mocked WoW API, luacheck configuration and GitHub Actions CI.
