--[[
    ForeverPath - Data/Milestones.lua

    Level milestones worth announcing. `classes` restricts a milestone to
    specific classes; omit it for milestones that apply to everyone.
]]

local _, ns = ...

ns.Data.Milestones = {
    { level = 10, text = "Talents open - spend your first point." },
    { level = 10, text = "Tame Beast - get your first pet.", classes = { HUNTER = true } },
    { level = 10, text = "Righteous Fury - you can tank dungeons.", classes = { PALADIN = true } },
    { level = 13, text = "First dungeons open (Ragefire Chasm, Hall of Thanes)." },
    { level = 25, text = "The Legacy system usually unlocks around now." },
    { level = 40, text = "Riding - your first mount." },
    { level = 40, text = "Dual Talent Specialization from your class trainer." },
    { level = 60, text = "Level cap. Faster riding, Mount Hyjal and the endgame." },
}
