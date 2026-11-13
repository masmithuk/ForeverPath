--[[
    ForeverPath - Data/Suggestions.lua

    Non-quest steps the guide slots into your route: visiting the trainer,
    buying things, setting your hearthstone.

    Fields
      id        unique key, used to remember that a step is done
      level     first level the step appears at
      kind      "TRAIN" | "BUY" | "NOTE" | "HEARTH"
      text      what to do
      classes   optional set of classFile tokens the step applies to
      detect    how the step completes on its own:
                  "trainer"  opening your class trainer's window
                  "hearth"   binding your hearthstone at an innkeeper
                  nil        click Done (or /fp done) when you've done it

    Class training is generated separately (see TRAINING below) because it
    repeats throughout leveling.
]]

local _, ns = ...

ns.Data.Suggestions = {
    { id = "hearth-start", level = 5, kind = "HEARTH", detect = "hearth",
      text = "Set your hearthstone at the nearest inn." },
    { id = "bags-1", level = 8, kind = "BUY",
      text = "Buy bags from a general goods vendor when you can spare the silver." },
    { id = "talents-10", level = 10, kind = "NOTE",
      text = "Talents are open - spend your first point." },
    { id = "pet-10", level = 10, kind = "TRAIN", classes = { HUNTER = true },
      text = "Learn Tame Beast from your trainer and tame your first pet." },
    { id = "fury-10", level = 10, kind = "TRAIN", detect = "trainer", classes = { PALADIN = true },
      text = "Learn Righteous Fury from your trainer if you want to tank dungeons." },
    { id = "firstaid-12", level = 12, kind = "TRAIN",
      text = "Learn First Aid - bandages cut downtime for every class." },
    { id = "riding-40", level = 40, kind = "BUY",
      text = "Learn Riding and buy your first mount." },
    { id = "dualspec-40", level = 40, kind = "TRAIN", detect = "trainer",
      text = "Buy Dual Talent Specialization from your class trainer." },
}

--- Class training reminders: every `every` levels starting at `from`.
--- Forever, like Classic, makes you buy new ranks from your class trainer.
ns.Data.Training = {
    from = 4,
    every = 2,
    text = "Visit your class trainer for new abilities.",
}
