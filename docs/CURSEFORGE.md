# Questwalker

**A step-by-step levelling guide for World of Warcraft: Forever.** It tells you which quest to do next, takes you
from quest giver to quest giver with an arrow, and moves you on to the next zone when you've out-levelled the one
you're in. Pick up, do, hand in, repeat, all the way to 60.

## What it does

- **Tells you what to do next.** A small guide window shows your current step ("Talk to Gornek", "Complete:
  Cutting Teeth", "Turn in to Zureetha") and the few after it. It updates by itself as you pick up, finish and hand
  in quests.
- **Guides for every race, levels 1 to 60.** Orc & Troll, Tauren, Undead, Human, Dwarf & Gnome, Night Elf and
  Skyborne each have two guides:
  - **Speedrun** (the default) is the quickest quest path to 60. It favours quests that give good XP for the time
    they take, and skips long detours.
  - **Story** is a slower, relaxed route through the important quests of each zone. Quest chains come first, and
    side quests only when they're on your way.
- **New or old characters.** A brand new character starts on its first quest. An existing character is picked up
  wherever it is, with the best quests for its level and location.
- **Moves you on to the next zone** when you've out-levelled the one you're in, and tells you why.
- **Fills the gaps.** If you run out of quests for your level, it tells you where to grind and roughly how many
  kills you need (it counts your rested XP).
- **Handy stops along the way:** visit your class trainer when new spells are due and you're nearby, set your
  hearthstone at the inn closest to your quests, and train your professions when you're ready for the next rank.
- **Target button.** One click targets the next creature you need for your current quest, nearest first. With
  several creatures, there's a button for each.
- **Elite tips:** when a quest needs an elite, it tells you if there are guards close enough to pull it to, or to
  find a group.
- **Class quests come first.** Quests for your class (new spells, totems, forms and pets) are never skipped,
  whatever your level or guide.
- **Dungeon suggestions** for your level.
- **Auto accept and hand in** when you talk to quest givers. Grey, repeatable and too-difficult quests are skipped
  (all optional).
- **Steps list:** see every quest in your guide, where you are, what you've done, skipped or missed, and jump to
  any step. Lost? Press **Best step**.
- **Make your own guides.** Copy a built-in guide and tweak it, or build one from scratch. Search for quests to add,
  reorder them, and add your own steps such as "Buy bags" or "Go to the cave entrance". Share guides with friends
  by export and import.
- **Abandon unrelated quests** in one click, to tidy your quest log.

## What you need

- **[Questie](https://www.curseforge.com/wow/addons/questie)** with **QuestieDB**: this is where Questwalker gets
  its quest information.
- **An arrow addon:** **Shortest Path Forever** (recommended) or **[TomTom](https://www.curseforge.com/wow/addons/tomtom)**.
  Without one, Questwalker puts a pin on your map instead, and reminds you to install one.

## Getting started

1. Install Questwalker along with Questie and an arrow addon, then log in.
2. The guide window appears with your first step. Follow the arrow.
3. Click the **minimap button** to show or hide the guide window. Right-click it to open the main window.
4. The main window's **Home** tab explains every part. **Steps** shows your whole guide, **Guides** lets you switch
   between Speedrun and Story (or your own), and **Settings** has the options.

Shift-drag the Target button to move it, and drag the corner of any window to resize it.

## Make and edit your own guides

Open the main window (right-click the minimap button) and go to the **Guides** tab.

- **Copy** a built-in guide to make your own version of it. Built-in guides can't be changed, but you can press
  **View** to look inside one.
- **New guide** starts an empty one.
- **Edit** opens one of your guides in the guide editor. **Use this guide** makes it the one you follow.
- **Export** gives you the guide as text to copy (Ctrl+C) and share. **Import** lets you paste (Ctrl+V) a guide
  someone shared with you.

The guide editor has three tabs:

- **Quests:** your quests in the order you want to do them. Pick one and press **Top**, **Up**, **Down**,
  **Bottom** or **Remove**. To add quests, type part of a quest's name (or its ID) in the search box and press
  **Add after selected**.
  - **Add a step** puts in something that isn't a quest: a note, buying something, training, setting your
    hearthstone, or going to a spot. **Use my location** saves where you're standing, so the arrow can take you
    back there.
- **Details:** the guide's name, author and description, and what it's **based on**. Base it on Speedrun or Story
  to choose how it fills the gaps.
- **JSON:** the whole guide as text, for the extra options below.

Press **Check** to find mistakes, then **Save**. A guide with problems is never saved, and the editor tells you
which line to fix.

How a guide is followed: your quest list comes first, in order. When nothing on it is available (too high level,
not unlocked yet, or done), Questwalker picks good quests from the guide's zones for your level instead. So a short
list of your favourite quests still works all the way to 60.

### The guide file (JSON)

Exported guides, and the editor's JSON tab, use this layout. Every part except `format`, `version` and `name` is
optional.

```json
{
  "format": "Questwalker guide",
  "version": 2,
  "name": "My Barrens Rush",
  "author": "Mike",
  "description": "My fastest Horde route.",
  "basedOn": "efficient",
  "rules": { "greyGap": 2, "levelsAbove": 2, "maxDetour": 350 },
  "quests": [
    { "id": 788, "name": "Your Place In The World" },
    { "step": "buy", "text": "Buy 6-slot bags.", "zone": "Durotar", "x": 52.0, "y": 41.5 },
    { "id": 789, "name": "Cutting Teeth" },
    { "step": "goto", "text": "Go to the cave entrance.", "zone": "Durotar", "x": 51.8, "y": 9.6 }
  ],
  "bands": [
    { "levels": [1, 10], "zones": ["START"], "notes": ["Talents open at 10."] },
    { "levels": [11, 20], "alliance": ["Westfall"], "horde": ["The Barrens"] }
  ],
  "skipQuests": [123, 456],
  "steps": [ { "level": 12, "kind": "buy", "text": "Buy bags." } ]
}
```

- **basedOn:** `"efficient"` (Speedrun) or `"story"`. This sets the default rules.
- **quests:** the order to do things in. Quests are `{ "id": … }`. The name is only for people reading the file,
  and the ID is what counts. Find IDs with the editor's search or on a quest database site. Steps that aren't
  quests use `"step"`, which is one of `note`, `buy`, `train`, `hearth` or `goto`, plus a `"text"`. `zone`, `x`
  and `y` (map coordinates from 0 to 100) are optional, except for `goto`. A step comes up once every quest before
  it is done, taken or unavailable.
- **bands:** which zones to quest in for each level range. `"zones"` applies to both factions. Use `"alliance"`
  and `"horde"` to set them separately. `"START"` means your race's starting area. `"notes"` are shown for that
  level range. If your bands stop short of 60, the last one is used for the levels after it.
- **skipQuests:** IDs of quests the guide never picks up.
- **steps:** reminders that appear from a level. `kind` is `train`, `buy`, `note` or `hearth`.
- **rules** (all optional, and they override the base):

  | Rule | What it does | Speedrun | Story |
  |---|---|---|---|
  | `greyGap` | How many levels below you a quest can be and still be picked | 2 | 3 |
  | `levelsAbove` | How many levels above you a quest can be | 2 | 3 |
  | `maxAccept` | How many quests to pick up in one go | 10 | 30 |
  | `turninBonus` | How strongly hand-ins are put first | 120 | 60 |
  | `chainBonus` | Preference for following on in a quest chain | 0 | 250 |
  | `sidePenalty` | How much side quests are pushed back | 0 | 350 |
  | `maxDetour` | Skip quests whose giver is more than this many yards out of the way (0 = no limit) | 350 | 0 |
  | `minRate` | Drop quests giving less than this % of the usual XP for the time they take | 50 | 0 |
  | `rateBonus` | Preference for quests with good XP for the time they take | 250 | 0 |

The `|` character isn't allowed in text, and it's replaced with `/`. Imported guides are only data and never run
as code, so they're safe to share.

## Feedback and bug reports

Found a problem, or have an idea? Please raise an issue on GitHub:
**<https://github.com/masmithuk/Questwalker/issues>**

It helps to say which character (race, class and level), which guide, and what the guide asked you to do. Typing
`/qw debug` in game prints a few lines you can paste into the issue.
