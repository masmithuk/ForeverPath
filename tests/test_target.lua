-- Target button: cycling nearest to furthest, one step per press, Shift.

local fixtures = require("fixtures")

-- Three quests whose creatures are 20, ~141 and ~636 yards away.
local function setup(T)
    local ns, mock = T.fresh()
    local db = fixtures.durotar(mock)
    db.Npc[2002] = { name = "Distant Boar", spawns = { [14] = { { 95, 95 } } } }
    db.Npc[2003] = { name = "Near Scorpid", spawns = { [14] = { { 52, 50 } } } }
    db.Quest[112] = { name = "Boars", startedBy = { { 1002 } }, objectives = { { { 2002 } } } }
    db.Quest[113] = { name = "Scorpids", startedBy = { { 1002 } }, objectives = { { { 2003 } } } }
    fixtures.addToLog(mock, 101, "Vile Familiars", false, { "Vile Familiar slain: 2/8" })
    fixtures.addToLog(mock, 112, "Boars", false, { "Distant Boar slain: 0/5" })
    fixtures.addToLog(mock, 113, "Scorpids", false, { "Near Scorpid slain: 1/6" })
    fixtures.login(ns)
    return ns, mock, ForeverPathTargetButton
end

local function target(name) return "/targetexact " .. name end

return {
    { "creatures are listed nearest first", function(T)
        local ns = setup(T)
        local names = ns.TargetButton.GetNames()
        T.eq(table.concat(names, ","), "Near Scorpid,Vile Familiar,Distant Boar")
    end },

    { "each press steps to the next creature, then wraps around", function(T)
        local _, mock, button = setup(T)
        local order = {}
        for i = 1, 4 do order[i] = mock.click(button)[1] end
        T.eq(order[1], target("Near Scorpid"))
        T.eq(order[2], target("Vile Familiar"))
        T.eq(order[3], target("Distant Boar"))
        T.eq(order[4], target("Near Scorpid"), "back to the nearest")
    end },

    { "one press = one step, whichever key-down setting you use", function(T)
        local _, mock, button = setup(T)
        T.eq(#mock.click(button), 1, "mouse down + up targets once (key-up mode)")
        -- A fresh character with "cast on key down" switched on.
        local ns2, mock2, button2 = setup(T)
        mock2.useKeyDown = true
        ns2.TargetButton.SetEnabled(true)
        local ran = mock2.click(button2)
        T.eq(#ran, 1, "key-down mode also targets once")
        T.eq(ran[1], target("Near Scorpid"))
    end },

    { "the label shows what the next press targets", function(T)
        local _, mock, button = setup(T)
        T.eq(button:GetText(), "Target: Near Scorpid (1/3)")
        mock.click(button)
        T.eq(button:GetText(), "Target: Vile Familiar (2/3)")
    end },

    { "Shift-click doesn't target (Shift is for dragging)", function(T)
        local _, mock, button = setup(T)
        mock.keys.shift = true
        T.eq(#mock.click(button), 0)
        mock.keys.shift = false
        T.eq(mock.click(button)[1], target("Near Scorpid"), "cycle didn't move")
    end },

    { "Shift + left-drag moves the button, but not in combat", function(T)
        local _, mock, button = setup(T)
        local moved = 0
        button.StartMoving = function() moved = moved + 1 end
        button:GetScript("OnDragStart")(button)
        T.eq(moved, 0, "plain drag does nothing")
        mock.keys.shift = true
        button:GetScript("OnDragStart")(button)
        T.eq(moved, 1, "Shift-drag moves")
        mock.inCombat = true
        button:GetScript("OnDragStart")(button)
        T.eq(moved, 1, "secure frames can't move in combat")
        mock.inCombat = false
        button:GetScript("OnDragStop")(button)
        T.eq(ForeverPathDB.target.x, 10, "position saved")
    end },

    { "cycling keeps working in combat", function(T)
        local _, mock, button = setup(T)
        mock.inCombat = true
        T.eq(mock.click(button)[1], target("Near Scorpid"))
        T.eq(mock.click(button)[1], target("Vile Familiar"))
    end },

    { "a new list starts again from the nearest", function(T)
        local ns, mock, button = setup(T)
        mock.click(button)
        mock.click(button)
        fixtures.removeFromLog(mock, 113) -- scorpids done and handed in
        ns:FireEvent("QUEST_REMOVED", 113)
        T.eq(table.concat(ns.TargetButton.GetNames(), ","), "Vile Familiar,Distant Boar")
        T.eq(mock.click(button)[1], target("Vile Familiar"))
    end },

    { "the same creature for two quests is listed once", function(T)
        local ns, mock = setup(T)
        mock.db.Quest[114] = { name = "More Familiars", startedBy = { { 1001 } }, objectives = { { { 2001 } } } }
        fixtures.addToLog(mock, 114, "More Familiars", false, { "Vile Familiar slain: 0/3" })
        ns:FireEvent("QUEST_ACCEPTED", 114)
        T.eq(#ns.TargetButton.GetNames(), 3)
    end },
}
