# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.8.1] - 2026-11-17

### Fixed
- **Quests too hard for your level** were still sent your way once they were in your log (e.g. "The Totem of Infliction", level 25, at level 22). A quest whose level, or whose creatures' level, is too far above yours now waits "on hold" until you're close enough: the guide window lists what's on hold and from which level, and the Steps tab marks it. Picking one with Go to this step overrides the hold.
- New quests are checked against their creatures' levels too, not just the quest's own level.

### Added
- Auto accept setting **Skip quests that are too hard for my level** (on by default).

## [0.8.0] - 2026-11-16

### Renamed
- **ForeverPath is now Questwalker** (the old name is taken on CurseForge). The addon folder is `Questwalker`, the slash commands are `/qw` and `/questwalker`, and the windows, key bindings and saved settings use the new name. Settings and your own guides saved under ForeverPath don't carry over automatically: export your guides from ForeverPath first, then import them into Questwalker. Guides exported from ForeverPath import fine.
- Releases are built and uploaded to CurseForge from GitHub when a version tag is pushed.

### Fixed
- **Hearthstone:** the guide suggested setting it at whatever inn you were near, even far from your quests. It now picks the inn nearest the middle of your current quest steps, and only suggests it while you're there.
- **Quests the NPC doesn't actually offer** (e.g. "Friend of the Library", which needs books first): when you talk to the quest giver and a quest the guide expected isn't in its list, the guide says so in chat, marks it "Not offered" in the Steps tab and moves on. It's checked again when you level up, or when you pick it with Go to this step.
- **Auto accept** could silently turn quests down: "only quests my guide would pick" was on by default and Speedrun's filters rejected many quests. It's now off by default (and turned off once on upgrade), so every offered quest is taken unless it's grey, repeatable or skipped.
- Auto accept no longer relies on Blizzard's gossip and quest windows to tell when a conversation ends, so dialog replacements such as DialogueUI don't stop it.
- `/qw debug` reports the auto accept settings and whether Questie's own automation is in charge.

### Removed
- **Hold to pause** for quest automation.

### Added
- **A Target button per creature:** when the current step needs several creatures, one extra button for each appears under the main Target button (up to 6 creatures in all), each with its own optional key binding. The main button still cycles through all of them.
- **Abandon unrelated quests** in Settings > Tools: abandons log quests that aren't on your guide's list or in its zones for your level and the next. Hand-ins, class quests and quests QuestieDB doesn't know are kept. Two clicks: the first lists them in chat.

### Changed (getting you from quest to quest)
- **Every class starts on Speedrun** for its race (Rogues used to start on Story).
- **Out-levelled your zone?** The step that takes you on says "You've out-levelled Durotar - head to The Barrens", and chat announces the move once.
- **No arrow addon?** The guide window, Home, Settings and a login tip tell you to install Shortest Path Forever or TomTom; a map pin marks the next stop until then.
- The Steps tab for the built-in guides lists the quests of your zones for this level and the next, so it stays short and quick.

### Changed (interface overhaul)
- **Home tab**, the new first tab: your character and guide, where you're levelling now and next, your current step, rested XP, class tips, dungeons for your level, and what every part of Questwalker does.
- **Guides per race:** a Speedrun and a Story guide, levels 1-60, for each starting area (Orc & Troll, Tauren, Undead, Human, Dwarf & Gnome, Night Elf, Skyborne). The Guides tab shows yours plus your own guides. Choices saved as "Efficient" or "Story" now mean your race's version.
- **Speedrun** is the quickest quest path to 60 for your race. **Story** now covers the important quests of each zone: quest chains first, no grey quests, and stand-alone side quests only when they're on the way (new `sidePenalty` rule).
- Main window tabs are now Home · Steps · Guides · Settings. The **Zones** and **Plan** tabs, following a single zone, and the **Change guide** button are gone.
- The guide window's buttons are Steps · Skip · Done. **Best step** lives on the Steps tab.
- **Settings:** the waypoint arrow and the pause key are dropdowns (they no longer overlap), the redundant "guide me step by step" switch is gone, and the columns stack when the window is narrow.
- **Resizable windows:** the main window, guide window and guide editor can be resized from the corner, everything inside adjusts, and the sizes are remembered.

### Fixed
- A brand-new character could see "No steps right now" instead of its first quest. Questie finishes starting up a few seconds after login, and until then its quest-availability and zone answers are empty. Questwalker used those answers and remembered them. Now it uses its own checks until Questie has started, doesn't remember failed zone lookups made in the meantime, and plans again the moment Questie is ready.
- Quest givers listed under a starting sub-zone (Valley of Trials, Echo Isles, Northshire, ...) are placed on their zone's map.
- `/qw debug` prints what the guide sees (guide, QuestieDB state, your map, quests available) for bug reports.

### Added
- **Steps that aren't quests in your own guides**: note, buy, train, set hearth and go to a spot, placed anywhere in the quest list. Add them in the editor's Quests tab (with **Use my location**) or in JSON as `{ "step": "goto", "text": "...", "zone": "Durotar", "x": 52.0, "y": 41.5 }`. They come up in order once the quests before them are dealt with. Train and hearth clear themselves at the trainer or innkeeper, go to clears when you arrive, and the rest are ticked off with Done. They're listed in the Steps tab too.
- **Best step** button in the guide window and the Steps tab (and `/qw best` or `/qw lost`): if you're lost, it drops any chosen or held step and picks the best one from where you're standing.
- **Steps tab**, the first tab of the main window: every quest in your guide in order, with where you are, what's done, skipped and missed (available quests you've moved past). Filter by All, To do, Skipped & missed or Done.
- **Go to this step** (or double-click) makes any quest in the list the current step until it's done, and says why if you can't do it yet. Skip, Unskip and Undo last skip work from the list.
- **Service steps** in the route, only when they're due and you're within about 400 yards:
  - Train at your class trainer.
  - Set your hearthstone at a nearby innkeeper when it's bound elsewhere.
  - Train a profession you've learned when you're near its skill cap and old enough for the next rank.

### Changed
- Quests whose objectives are in the **same area** are now one step ("Complete: Cutting Teeth & Wayward Weapons"), listing every quest's objectives. The arrow points at the nearest part, and the Target button cycles through all of their creatures.
- The **Target button** only shows the current step's creatures and hides on steps without any.
- The guide window's Back button is now **Steps**, which opens the list. Undo last skip lives in the Steps tab.
- A guide's `note`, `buy` and `hearth` steps are now steps in the route that you tick off with Done. Its `train` steps make class training due from that level.

### Removed
- The reminders list and the built-in reminders (bags, talents, First Aid, Riding, dual spec). Level milestones are still announced in chat.

## [0.7.0] - 2026-11-15

### Added
- **Back** button in the step guide window, plus `/qw back`. It undoes the most recent skip, or a hand-ticked reminder, and makes that step current again. Press it repeatedly to keep going back. Undoing a skipped training step restores your training level. The last 50 actions are kept per character.

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
- `/qw route` accepts any guide's id or name.

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
- Waypoints through TomTom (which also drives TomTom-based path addons) or the built-in map pin: `/qw waypoints`.
- `/qw guide`, `/qw skip`, `/qw done` and `/qw unskip` commands.
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
- `/qw` slash commands and an addon compartment entry.
- Unit tests with a mocked WoW API, luacheck configuration and GitHub Actions CI.
