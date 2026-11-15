-- Target button: cycling nearest to furthest, one step per press, Shift,
-- and only the current step's creatures.

local fixtures = require("fixtures")

-- The current step is "Vile Familiars", which needs three creatures that are
-- 20, ~141 and ~636 yards away. Another quest in the log ("Boars") has its
-- own creature in another area, which the button should leave alone.
local function setup(T)
    local ns, mock = T.fresh()
    local db = fixtures.durotar(mock)
    db.Npc[2002] = { name = "Distant Boar", spawns = { [14] = { { 95, 95 } } } }
    db.Npc[2003] = { name = "Near Scorpid", spawns = { [14] = { { 52, 50 } } } }
    db.Npc[2004] = { name = "Other Quest Raptor", spawns = { [14] = { { 95, 5 } } } } -- another area
    db.Quest[101].objectives = { { { 2001 }, { 2002 }, { 2003 } } }
    db.Quest[112] = { name = "Boars", startedBy = { { 1002 } }, objectives = { { { 2004 } } } }
    fixtures.addToLog(mock, 101, "Vile Familiars", false,
        { "Vile Familiar slain: 2/8", "Distant Boar slain: 0/5", "Near Scorpid slain: 1/6" })
    fixtures.addToLog(mock, 112, "Boars", false, { "Other Quest Raptor slain: 0/5" })
    ForeverPathCharDB = ForeverPathCharDB or {}
    fixtures.login(ns)
    ForeverPathCharDB.guide.trainedLevel = 60
    T.truthy(ns.Engine.FocusQuest(101), "focus the Vile Familiars step")
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
        -- All the scorpids are dead now.
        mock.questLog[1].objectives[3] = { text = "Near Scorpid slain: 6/6", finished = true }
        ns:FireEvent("QUEST_LOG_UPDATE")
        T.eq(table.concat(ns.TargetButton.GetNames(), ","), "Vile Familiar,Distant Boar")
        T.eq(mock.click(button)[1], target("Vile Familiar"))
    end },

    { "other quests' creatures aren't listed", function(T)
        local ns = setup(T)
        for _, name in ipairs(ns.TargetButton.GetNames()) do
            T.truthy(name ~= "Other Quest Raptor", "only the current step's creatures")
        end
    end },

    { "hidden when the current step isn't about objectives", function(T)
        local ns, _, button = setup(T)
        T.truthy(button:IsShown())
        -- Focus a quest that still has to be picked up.
        T.truthy(ns.Engine.FocusQuest(102))
        T.eq(ns.Engine.state.steps[1].kind, "ACCEPT")
        T.eq(#ns.TargetButton.GetNames(), 0)
        T.truthy(not button:IsShown())
    end },
}
