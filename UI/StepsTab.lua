--[[
    ForeverPath - UI/StepsTab.lua

    "Steps" tab: every quest in the guide you're following, in order.

      Header   guide name, where you are (quest n of N), and how many quests
               are done, skipped and missed
      Filters  All · To do · Skipped & missed · Done
      List     one row per quest: number, level, name, quest giver, status.
               The step the guide is showing now is marked with an arrow.
               Click a row to select it.
      Buttons  Go to this step   make the selected quest the current step
               Skip / Unskip     skip it, or bring a skipped quest back
               Undo last skip    undo your most recent skip or tick

    The rows come from Guide/StepList.lua (pure; tested there).
]]

local _, ns = ...

local StepsTab = {}
ns.StepsTab = StepsTab

local L = ns.L
local Util = ns.Util
local C = Util.Color

local ROW_HEIGHT = 18
local FILTER_ORDER = { "all", "todo", "missed", "done" }
local FILTER_LABEL = {
    all = "STEPS_FILTER_ALL", todo = "STEPS_FILTER_TODO",
    missed = "STEPS_FILTER_MISSED", done = "STEPS_FILTER_DONE",
}

local STATUS = {
    done     = { "muted",  "QUEST_DONE" },
    ready    = { "good",   "QUEST_READY" },
    active   = { "ffffff", "QUEST_ACTIVE" },
    skipped  = { "warn",   "STEPS_SKIPPED" },
    missed   = { "warn",   "STEPS_MISSED" },
    upcoming = { "accent", "QUEST_AVAILABLE" },
    level    = { "muted",  "QUEST_LEVEL_FMT" },
    locked   = { "muted",  "QUEST_LOCKED" },
}

local panel
local filter = "all"
local selectedId -- quest ID of the selected row
local lastList   -- last StepList.Build result, for tests and buttons

---------------------------------------------------------------------------
-- Text (pure; tested)
---------------------------------------------------------------------------

function StepsTab.StatusLabel(row)
    local entry = STATUS[row.status] or STATUS.locked
    local label = L[entry[2]]
    if row.status == "level" then label = label:format(row.requiredLevel or 0) end
    return C(entry[1], label)
end

function StepsTab.RowText(row)
    local marker = row.isCurrent and C("good", "> ") or "   "
    local name = row.name
    if row.status == "done" then name = C("muted", name) end
    local giver = row.giver and C("muted", "  - " .. row.giver) or ""
    return ("%s%d. [%d] %s%s   %s"):format(
        marker, row.index, row.level or 0, name, giver, StepsTab.StatusLabel(row))
end

function StepsTab.HeaderText(guideName, list)
    if list.total == 0 then return C("accent", guideName) .. "  " .. C("muted", L.STEPS_EMPTY) end
    return ("%s   %s   %s"):format(
        C("accent", guideName),
        L.STEPS_POSITION_FMT:format(list.position, list.total),
        C("muted", L.STEPS_COUNTS_FMT:format(list.done, list.skipped, list.missed)))
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local REASONS = { done = "STEPS_CANT_DONE", level = "STEPS_CANT_LEVEL_FMT", locked = "STEPS_CANT_LOCKED" }

local function selectedRow()
    for _, r in ipairs(lastList and lastList.rows or {}) do
        if r.id == selectedId then return r end
    end
    return nil
end

--- Make the selected quest the current step.
function StepsTab.GoTo()
    local row = selectedRow()
    if not row then return false end
    local ok, reason, level = ns.Engine.FocusQuest(row.id)
    if ok then
        Util.Print(L.STEPS_GOING_FMT:format(row.name))
    else
        Util.Print(L[REASONS[reason] or "STEPS_CANT_LOCKED"]:format(level or 0))
    end
    StepsTab.Refresh()
    return ok
end

function StepsTab.ToggleSkip()
    local row = selectedRow()
    if not row then return end
    if row.status == "skipped" then
        ns.Engine.UnskipQuest(row.id)
    else
        ns.Engine.SkipQuest(row.id, row.name)
    end
    StepsTab.Refresh()
end

function StepsTab.Undo()
    local entry = ns.Engine.Back()
    if entry then Util.Print(L.GUIDE_RESTORED_FMT:format(entry.title)) end
    StepsTab.Refresh()
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function createRow(parent, index, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.15)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(self)
        selectedId = self.questID
        StepsTab.Refresh()
    end)
    row:SetScript("OnDoubleClick", function(self)
        selectedId = self.questID
        StepsTab.GoTo()
    end)
    return row
end

function StepsTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)
    local width = MF.WIDTH - MF.PADDING * 2

    panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.header:SetWidth(width)
    panel.header:SetJustifyH("LEFT")

    panel.filters = {}
    local prev
    for _, id in ipairs(FILTER_ORDER) do
        local b = MF.NewButton(panel, L[FILTER_LABEL[id]], id == "missed" and 140 or 90, function()
            filter = id
            StepsTab.Refresh()
        end)
        b.filterId = id
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else b:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT", 0, -6) end
        panel.filters[#panel.filters + 1] = b
        prev = b
    end

    -- Action buttons along the bottom.
    panel.go = MF.NewButton(panel, L.STEPS_GO, 140, StepsTab.GoTo)
    panel.go:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    panel.skip = MF.NewButton(panel, L.STEPS_SKIP, 90, StepsTab.ToggleSkip)
    panel.skip:SetPoint("LEFT", panel.go, "RIGHT", 6, 0)
    panel.undo = MF.NewButton(panel, L.GUIDE_BACK, 130, StepsTab.Undo)
    panel.undo:SetPoint("LEFT", panel.skip, "RIGHT", 6, 0)
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.hint:SetPoint("LEFT", panel.undo, "RIGHT", 10, 0)
    panel.hint:SetText(L.STEPS_HINT)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", panel.filters[1], "BOTTOMLEFT", 0, -8)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, MF.BUTTON_HEIGHT + 8)
    panel.child = CreateFrame("Frame", nil, panel.scroll)
    panel.child:SetSize(width - 28, 1)
    panel.scroll:SetScrollChild(panel.child)
    panel.rowWidth = width - 28
    panel.rows = {}
    return panel
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

function StepsTab.Refresh()
    if not panel then return end
    local ctx = ns.Engine.BuildContext()
    lastList = ns.StepList.Build(ctx, ns.Engine.state.steps[1])
    panel.header:SetText(StepsTab.HeaderText(ctx.guide.name or "", lastList))

    for _, b in ipairs(panel.filters) do
        if b.filterId == filter then b:LockHighlight() else b:UnlockHighlight() end
    end

    local rows = ns.StepList.Filter(lastList.rows, filter)
    -- Select the current step by default.
    if not selectedRow() then
        selectedId = nil
        for _, r in ipairs(lastList.rows) do
            if r.isCurrent then selectedId = r.id; break end
        end
    end

    for i, r in ipairs(rows) do
        local widget = panel.rows[i] or createRow(panel.child, i, panel.rowWidth)
        panel.rows[i] = widget
        widget.questID = r.id
        widget.text:SetText(StepsTab.RowText(r))
        if r.id == selectedId then widget.selected:Show() else widget.selected:Hide() end
        widget:Show()
    end
    for i = #rows + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.child:SetHeight(math.max(1, #rows * ROW_HEIGHT))

    local sel = selectedRow()
    local canAct = sel and sel.status ~= "done"
    if canAct then panel.go:Enable(); panel.skip:Enable() else panel.go:Disable(); panel.skip:Disable() end
    panel.skip:SetText(sel and sel.status == "skipped" and L.STEPS_UNSKIP or L.STEPS_SKIP)
    if ns.Engine.LastSkipped() then panel.undo:Enable() else panel.undo:Disable() end
end

---------------------------------------------------------------------------
-- For tests
---------------------------------------------------------------------------

function StepsTab.Select(questID)
    selectedId = questID
    StepsTab.Refresh()
end

function StepsTab.SetFilter(id)
    filter = id
    StepsTab.Refresh()
end

function StepsTab.GetList() return lastList end

function StepsTab.GetVisibleRows()
    local out = {}
    for _, r in ipairs(panel and panel.rows or {}) do
        if r:IsShown() then out[#out + 1] = r end
    end
    return out
end

function StepsTab.GetPanel() return panel end
