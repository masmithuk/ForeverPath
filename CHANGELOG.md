# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

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
