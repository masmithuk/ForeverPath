--[[
    Questwalker - UI/GuideFrame.lua

    The compact step-by-step window:

      [icon] Turn in to Grull Hawkwind        84 yd
             Rite of Strength
             [Skip]
      Then:  Talk to Brave Windfeather - Accept: ...
             Complete: Break the Quilboar ...

    It only displays Engine state; all decisions live in Guide/Engine.lua.
]]

local _, ns = ...

local GuideFrame = {}
ns.GuideFrame = GuideFrame

local L = ns.L
local Util = ns.Util

local WIDTH = 320 -- default width; the window can be resized from 260 to 640
local MIN_WIDTH, MAX_WIDTH = 260, 640

local function savedWidth()
    local w = ns.Settings.account.guide.width or WIDTH
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, w))
end
local PADDING = 10

local ICONS = {
    ACCEPT   = "Interface\\GossipFrame\\AvailableQuestIcon",
    TURNIN   = "Interface\\GossipFrame\\ActiveQuestIcon",
    COMPLETE = "Interface\\Icons\\INV_Misc_Note_01",
    TRAIN    = "Interface\\GossipFrame\\TrainerGossipIcon",
    BUY      = "Interface\\GossipFrame\\VendorGossipIcon",
    HEARTH   = "Interface\\Icons\\INV_Misc_Rune_01",
    NOTE     = "Interface\\GossipFrame\\GossipGossipIcon",
    GOTO     = "Interface\\Icons\\INV_Misc_Map_01",
}

local frame

---------------------------------------------------------------------------
-- Text helpers (pure; tested)
---------------------------------------------------------------------------

--- Human-friendly distance, or nil when unknown.
function GuideFrame.FormatDistance(origin, step)
    local to = step and step.target and step.target.world
    if not origin or not to or origin.continent ~= to.continent then return nil end
    local yards = Util.Distance(origin, to)
    if yards >= 1000 then
        return ("%.1fk yd"):format(yards / 1000)
    end
    return ("%d yd"):format(math.floor(yards + 0.5))
end

--- Body text for the current step.
function GuideFrame.CurrentText(step)
    local lines = { Util.Color("accent", step.title) }
    for _, line in ipairs(step.lines or {}) do
        lines[#lines + 1] = line
    end
    if not step.target then
        lines[#lines + 1] = Util.Color("muted", L.GUIDE_NO_LOCATION)
    end
    return table.concat(lines, "\n")
end

--- One-line summaries of the steps after the current one.
function GuideFrame.UpcomingText(steps)
    local lines = {}
    for i = 2, #steps do
        local s = steps[i]
        local summary = s.title
        if s.kind == "ACCEPT" or s.kind == "TURNIN" then
            summary = summary .. " (" .. #s.questIDs .. ")"
        end
        lines[#lines + 1] = Util.Color("muted", ("%d. %s"):format(i, summary))
    end
    return table.concat(lines, "\n")
end

--- "Questwalker - Orc & Troll Speedrun (1-60)"
function GuideFrame.HeaderText()
    local guide = ns.Engine.CurrentGuide()
    return L.GUIDE_TITLE .. (guide and (" - " .. guide.name) or "")
end

--- Status line explaining missing data, or nil when all is well.
--- "On hold until you're stronger: The Totem of Infliction (level 23)"
function GuideFrame.OnHoldText(onHold)
    if not onHold or #onHold == 0 then return nil end
    table.sort(onHold, function(a, b) return a.level < b.level end)
    local parts = {}
    for i = 1, math.min(3, #onHold) do
        parts[i] = L.ONHOLD_ITEM_FMT:format(onHold[i].title, onHold[i].level)
    end
    if #onHold > 3 then parts[#parts + 1] = L.ONHOLD_MORE_FMT:format(#onHold - 3) end
    return Util.Color("muted", L.ONHOLD_FMT:format(table.concat(parts, ", ")))
end

--- "Too low to be worth it: Gnome Engineering (level 8) - abandon them ..."
function GuideFrame.TooLowText(tooLow)
    if not tooLow or #tooLow == 0 then return nil end
    table.sort(tooLow, function(a, b) return a.level < b.level end)
    local parts = {}
    for i = 1, math.min(3, #tooLow) do
        parts[i] = L.ONHOLD_ITEM_FMT:format(tooLow[i].title, tooLow[i].level)
    end
    if #tooLow > 3 then parts[#parts + 1] = L.ONHOLD_MORE_FMT:format(#tooLow - 3) end
    return Util.Color("muted", L.TOOLOW_FMT:format(table.concat(parts, ", ")))
end

--- "Dungeons for your level: Wailing Caverns (17-24), Shadowfang Keep (22-30)"
function GuideFrame.DungeonText(dungeons)
    if not dungeons or #dungeons == 0 then return nil end
    local parts = {}
    for i = 1, math.min(3, #dungeons) do
        local d = dungeons[i]
        parts[i] = ("%s (%d-%d)"):format(d.name, d.min, d.max)
    end
    return Util.Color("accent", L.GUIDE_DUNGEONS_FMT:format(table.concat(parts, ", ")))
end

--- "Group quests left out: The Defias Brotherhood (turn on in Settings)"
function GuideFrame.GroupHiddenText(hidden)
    if not hidden or #hidden == 0 then return nil end
    local names = {}
    for i = 1, math.min(3, #hidden) do names[i] = hidden[i].title end
    if #hidden > 3 then names[#names + 1] = L.ONHOLD_MORE_FMT:format(#hidden - 3) end
    return Util.Color("muted", L.GROUP_HIDDEN_FMT:format(table.concat(names, ", ")))
end

function GuideFrame.StatusText(dataStatus, providerSetting)
    local parts = {}
    if dataStatus == "missing" then
        parts[#parts + 1] = L.GUIDE_NEEDS_QUESTIE
    elseif dataStatus == "incompatible" then
        parts[#parts + 1] = L.GUIDE_QUESTIE_INCOMPATIBLE
    elseif dataStatus == "indexing" then
        parts[#parts + 1] = L.GUIDE_INDEXING
    end
    if ns.Waypoints.NeedsArrowAddon(providerSetting) then
        parts[#parts + 1] = L.GUIDE_NEEDS_ARROW
    elseif ns.Waypoints.Resolve(providerSetting) == "off" and providerSetting ~= "off" then
        parts[#parts + 1] = L.GUIDE_NO_WAYPOINTS
    end
    if #parts == 0 then return nil end
    return Util.Color("warn", table.concat(parts, "\n"))
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function savePosition(f)
    local point, _, relativePoint, x, y = f:GetPoint(1)
    local saved = ns.Settings.account.guide.frame
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function restorePosition(f)
    local saved = ns.Settings.account.guide.frame
    f:ClearAllPoints()
    f:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end

local function newText(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWidth(savedWidth() - PADDING * 2 - 26)
    return fs
end

local function newButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(70, 20)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function create()
    local f = CreateFrame("Frame", "QuestwalkerGuideFrame", UIParent, "BackdropTemplate")
    f:SetSize(savedWidth(), 120)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
    end)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.75)
    end

    f.header = newText(f, "GameFontNormalSmall")
    f.header:SetPoint("TOPLEFT", PADDING, -PADDING)
    f.header:SetText(L.GUIDE_TITLE)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f.close:SetScript("OnClick", function() GuideFrame.Hide() end)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -6)

    f.distance = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.distance:SetPoint("TOPRIGHT", -PADDING, -PADDING - 2)

    f.current = newText(f, "GameFontHighlight")
    f.current:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, 0)

    -- Button row: [Steps] [Skip] [Done]. Steps opens the full list (and Best
    -- step, if you're lost). Done only shows on steps you tick off yourself.
    f.list = newButton(f, L.GUIDE_LIST, function() ns.MainFrame.ShowTab("steps") end)
    f.list:SetPoint("TOPLEFT", f.current, "BOTTOMLEFT", 0, -6)

    f.skip = newButton(f, L.GUIDE_SKIP, function()
        local skipped = ns.Engine.SkipCurrent()
        if skipped then Util.Print(L.GUIDE_SKIPPED_FMT:format(skipped.title)) end
    end)

    f.done = newButton(f, L.GUIDE_DONE, function()
        local step = ns.Engine.state.steps[1]
        if step then ns.Engine.MarkDone(step.key) end
    end)

    f.upcoming = newText(f, "GameFontHighlightSmall")
    f.upcoming:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 0, -8)

    f.status = newText(f, "GameFontHighlightSmall")

    -- Drag the corner to make the window wider or narrower; the text wraps
    -- to fit and the height follows the text.
    ns.MainFrame.AddResizeGrip(f, MIN_WIDTH, 80, MAX_WIDTH, 2000, function(self)
        ns.Settings.account.guide.width = math.floor(self:GetWidth() + 0.5)
        GuideFrame.Update(ns.Engine.state)
    end)
    f:SetScript("OnSizeChanged", function(self, w)
        local textWidth = (w or savedWidth()) - PADDING * 2 - 26
        for _, fs in ipairs({ self.header, self.current, self.upcoming, self.status }) do
            fs:SetWidth(textWidth)
        end
    end)

    restorePosition(f)
    return f
end

local function getFrame()
    if not frame then frame = create() end
    return frame
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function layoutBelow(anchor, widgets)
    local last = anchor
    for _, w in ipairs(widgets) do
        if w:IsShown() then
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
            last = w
        end
    end
    return last
end

local function setShown(widget, shown)
    if shown then widget:Show() else widget:Hide() end
end

--- Lay out the button row left to right, skipping hidden buttons.
local function layoutButtons(f)
    local prev = f.list
    for _, b in ipairs({ f.skip, f.done }) do
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            prev = b
        end
    end
end

--- "I'm lost": jump to the best step from where you're standing.
function GuideFrame.BestStep()
    local step = ns.Engine.BestStep()
    if step then
        Util.Print(L.GUIDE_BEST_FMT:format(step.title))
    else
        Util.Print(L.GUIDE_NOTHING)
    end
    return step
end

--- Redraw from Engine state.
function GuideFrame.Update(state)
    if not ns.Settings.account.guide.shown then return end
    local f = getFrame()
    local step = state.steps[1]
    f.header:SetText(GuideFrame.HeaderText())

    if step then
        f.icon:SetTexture(ICONS[step.kind] or ICONS.NOTE)
        f.icon:Show()
        f.current:SetText(GuideFrame.CurrentText(step))
        f.skip:Show()
        setShown(f.done, step.manual)
    else
        f.icon:Hide()
        f.current:SetText(L.GUIDE_NOTHING)
        f.skip:Hide()
        f.done:Hide()
    end

    f.upcoming:SetText(GuideFrame.UpcomingText(state.steps))
    setShown(f.upcoming, #state.steps > 1)

    local status = GuideFrame.StatusText(state.dataStatus, ns.Settings.account.guide.waypoints)
    local hold = GuideFrame.OnHoldText(state.onHold)
    if hold then status = status and (hold .. "\n" .. status) or hold end
    local low = GuideFrame.TooLowText(state.tooLow)
    if low then status = status and (low .. "\n" .. status) or low end
    local group = GuideFrame.GroupHiddenText(state.groupHidden)
    if group then status = status and (group .. "\n" .. status) or group end
    local dungeons = ns.Settings.account.guide.suggestDungeons ~= false and GuideFrame.DungeonText(state.dungeons)
    if dungeons then status = status and (dungeons .. "\n" .. status) or dungeons end
    f.status:SetText(status or "")
    setShown(f.status, status ~= nil)

    layoutButtons(f)
    local last = layoutBelow(f.list, { f.upcoming, f.status })

    local top = f:GetTop()
    local bottom = last:GetBottom()
    if top and bottom then
        f:SetHeight(math.max(80, top - bottom + PADDING))
    end

    GuideFrame.UpdateDistance(state.origin)
    f:Show()
end

--- Refresh just the distance readout (called every few seconds).
function GuideFrame.UpdateDistance(origin)
    if not frame then return end
    local step = ns.Engine.state.steps[1]
    frame.distance:SetText(GuideFrame.FormatDistance(origin, step) or "")
end

function GuideFrame.Show()
    ns.Settings.account.guide.shown = true
    GuideFrame.Update(ns.Engine.state)
end

function GuideFrame.Hide()
    ns.Settings.account.guide.shown = false
    if frame then frame:Hide() end
end

function GuideFrame.Toggle()
    if frame and frame:IsShown() then GuideFrame.Hide() else GuideFrame.Show() end
end

function GuideFrame.ResetPosition()
    if frame then restorePosition(frame) end
end
