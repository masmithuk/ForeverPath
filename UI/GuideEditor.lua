--[[
    ForeverPath - UI/GuideEditor.lua

    The guide editor. It works on a draft copy of a guide and has three
    tabs:

      Quests   the guide's quests in order. Select one and move it to the
               top, up, down or to the bottom, or remove it. Search
               QuestieDB by part of a quest's name (or its ID) and add
               results after the selected quest. "Add a step" puts a
               non-quest step (note, buy, train, set hearth, go to a spot)
               after the selected entry, optionally at your current location;
               select a step in the list to change it.
      Details  name, author, description and what it's based on.
      JSON     the whole guide as JSON: zones, rules, extra steps and
               anything else. Also used to export and import.

    Modes
      edit    one of your guides; Save overwrites it
      new     a new guide or a copy; Save creates it
      view    a built-in guide, read-only, with "Copy & edit"
      export  the JSON, read-only and selected, ready for Ctrl+C
      import  an empty JSON box to paste a shared guide into

    Saving always runs the full checks, so a broken guide is never stored.
    The list operations (Ops) are pure functions and are unit-tested.
]]

local _, ns = ...

local GuideEditor = {}
ns.GuideEditor = GuideEditor

local L = ns.L
local C = ns.Util.Color

local FRAME_NAME = "ForeverPathGuideEditor"
local WIDTH, HEIGHT = 780, 580 -- default size; resizable from MIN to MAX
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 700, 500, 1400, 1000
local PADDING = 12
local ROW_HEIGHT = 20
local COLUMN_WIDTH = 360 -- at the default size; GuideEditor.Layout recomputes it
local MAX_MESSAGES = 6
local SEARCH_LIMIT = 50

local frame
local state = {
    mode = nil,        -- see the modes above
    id = nil,          -- guide being edited / viewed / exported
    draft = nil,       -- guide table being edited
    tab = "quests",    -- "quests" | "details" | "json"
    selected = nil,    -- index in draft.quests
    results = {},      -- search results
    resultSelected = nil,
    jsonDirty = false, -- JSON box edited since it was filled
    viewList = nil,    -- read-only quest list shown for built-in guides
    stepForm = { kind = "NOTE", text = "" }, -- the "Add a step" form
}

---------------------------------------------------------------------------
-- Quest list operations (pure; tested)
---------------------------------------------------------------------------

local Ops = {}
GuideEditor.Ops = Ops

--- Move list[from] to position `to`. Returns the new index.
function Ops.Move(list, from, to)
    if not list[from] then return from end
    to = math.max(1, math.min(#list, to))
    local item = table.remove(list, from)
    table.insert(list, to, item)
    return to
end

function Ops.Remove(list, index)
    if not list[index] then return nil end
    table.remove(list, index)
    if #list == 0 then return nil end
    return math.min(index, #list)
end

--- Add a quest after position `after` (or at the end). Ignores duplicates.
-- @return index of the quest in the list, and whether it was added
function Ops.Add(list, quest, after)
    for i, q in ipairs(list) do
        if q.id == quest.id then return i, false end
    end
    local at = after and (after + 1) or (#list + 1)
    table.insert(list, at, { id = quest.id, name = quest.name })
    return at, true
end

--- Add a non-quest step after position `after` (or at the end).
-- @return its index
function Ops.AddStep(list, step, after)
    local at = after and (after + 1) or (#list + 1)
    table.insert(list, at, { step = step.kind, text = step.text, zone = step.zone, x = step.x, y = step.y })
    return at
end

--- Replace the step at `index` (only if that entry is a step).
function Ops.UpdateStep(list, index, step)
    local entry = list[index]
    if not entry or not entry.step then return false end
    list[index] = { step = step.kind, text = step.text, zone = step.zone, x = step.x, y = step.y }
    return true
end

--- Check a step form. @return nil when fine, or a locale key for the problem.
function Ops.StepProblem(step)
    if (step.kind == "NOTE" or step.kind == "BUY") and (step.text or "") == "" then
        return "EDITOR_STEP_NEEDS_TEXT"
    end
    if step.kind == "GOTO" and not step.zone then return "EDITOR_STEP_NEEDS_PLACE" end
    return nil
end

---------------------------------------------------------------------------
-- Text helpers (pure; tested)
---------------------------------------------------------------------------

--- Errors (red) and warnings (orange) as display text, capped in length.
function GuideEditor.FormatMessages(errors, warnings)
    local lines = {}
    local function add(list, color)
        for _, m in ipairs(list or {}) do
            if #lines >= MAX_MESSAGES then return end
            lines[#lines + 1] = C(color, ns.GuideFormat.Describe(m))
        end
    end
    add(errors, "ff4040")
    add(warnings, "warn")
    local total = #(errors or {}) + #(warnings or {})
    if total > MAX_MESSAGES then
        lines[#lines + 1] = C("muted", L.EDITOR_MORE_FMT:format(total - MAX_MESSAGES))
    end
    return table.concat(lines, "\n")
end

--- "12. [5] Vile Familiars - Durotar", or "3. <Buy> Buy bags - Durotar 52.0, 41.5"
function GuideEditor.QuestRowText(index, q)
    if q.step then
        local kind = L["STEP_KIND_" .. q.step] or q.step
        local where = ns.Sources.LocationText(q)
        return ("%d. %s %s%s"):format(index, C("accent", "<" .. kind .. ">"),
            q.text or C("muted", L.EDITOR_STEP_DEFAULT), where and C("muted", " - " .. where) or "")
    end
    local info = ns.QuestieData.Describe(q.id, q.name)
    local level = info.level > 0 and ("[%d] "):format(info.level) or ""
    local where = info.zone and C("muted", " - " .. info.zone) or ""
    return ("%d. %s%s%s"):format(index, level, info.name, where)
end

--- "[5] Vile Familiars - Durotar  #101" (+ "in guide" when already listed)
function GuideEditor.ResultRowText(r, inGuide)
    local level = r.level > 0 and ("[%d] "):format(r.level) or ""
    local where = r.zone and (" - " .. r.zone) or ""
    local text = ("%s%s%s"):format(level, r.name, C("muted", where .. "  #" .. r.id))
    if inGuide then text = C("muted", text .. "  " .. L.EDITOR_IN_GUIDE) end
    return text
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function readOnly()
    return state.mode == "view" or state.mode == "export"
end

local function setStatus(text) frame.status:SetText(text or "") end

local function newButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function newLabel(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function newEditBox(parent, width)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 22)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

--- A scrolling list of clickable rows.
local function newList(parent, width, onClick)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - 24, 1)
    scroll:SetScrollChild(child)
    scroll.rows = {}

    --- Follow a new column width (the editor was resized).
    function scroll.SetListWidth(_, w)
        width = w
        scroll:SetWidth(w)
        child:SetWidth(w - 24)
        for _, row in ipairs(scroll.rows) do row:SetWidth(w - 24) end
    end

    function scroll.SetItems(_, texts, selectedIndex)
        for i, text in ipairs(texts) do
            local row = scroll.rows[i]
            if not row then
                row = CreateFrame("Button", nil, child)
                row:SetSize(width - 24, ROW_HEIGHT)
                row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.selected = row:CreateTexture(nil, "BACKGROUND")
                row.selected:SetAllPoints()
                row.selected:SetColorTexture(1, 0.82, 0, 0.18)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text:SetJustifyH("LEFT")
                row:SetScript("OnClick", function(self) onClick(self.index) end)
                scroll.rows[i] = row
            end
            row.index = i
            row.text:SetText(text)
            if i == selectedIndex then row.selected:Show() else row.selected:Hide() end
            row:Show()
        end
        for i = #texts + 1, #scroll.rows do scroll.rows[i]:Hide() end
        child:SetHeight(math.max(1, #texts * ROW_HEIGHT))
    end
    return scroll
end

---------------------------------------------------------------------------
-- Quests tab
---------------------------------------------------------------------------

local function questList()
    if state.mode == "view" then return state.viewList or {} end
    return state.draft.quests
end

local function inGuide(id)
    for _, q in ipairs(questList()) do if q.id == id then return true end end
    return false
end

local refreshQuests -- forward

local function moveSelected(to)
    if readOnly() or not state.selected then return end
    state.selected = Ops.Move(state.draft.quests, state.selected, to)
    refreshQuests()
end

local function createQuestsTab(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -60)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING + 24 + 60)

    -- Left: the guide's quests.
    p.listLabel = newLabel(p)
    p.listLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.list = newList(p, COLUMN_WIDTH, function(index)
        state.selected = index
        GuideEditor.LoadStepForm(index)
        refreshQuests()
    end)
    p.list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -18)
    p.list:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 28)
    p.list:SetWidth(COLUMN_WIDTH)

    p.moveButtons = {}
    local moves = {
        { "EDITOR_TOP", function() moveSelected(1) end },
        { "EDITOR_UP", function() moveSelected((state.selected or 1) - 1) end },
        { "EDITOR_DOWN", function() moveSelected((state.selected or 0) + 1) end },
        { "EDITOR_BOTTOM", function() moveSelected(#state.draft.quests) end },
        { "EDITOR_REMOVE", function()
            if readOnly() or not state.selected then return end
            state.selected = Ops.Remove(state.draft.quests, state.selected)
            refreshQuests()
        end },
    }
    for i, m in ipairs(moves) do
        local b = newButton(p, L[m[1]], 68, m[2])
        b:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", (i - 1) * 72, 0)
        p.moveButtons[i] = b
    end

    -- Right: search and add.
    local right = COLUMN_WIDTH + 20
    p.searchLabel = newLabel(p, L.EDITOR_ADD_QUESTS)
    p.searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", right, 0)
    p.search = newEditBox(p, COLUMN_WIDTH - 10)
    p.search:SetPoint("TOPLEFT", p, "TOPLEFT", right + 6, -18)
    p.search:SetScript("OnTextChanged", function(self)
        GuideEditor.Search(self:GetText())
    end)
    p.results = newList(p, COLUMN_WIDTH, function(index)
        state.resultSelected = index
        refreshQuests()
    end)
    p.results:SetPoint("TOPLEFT", p, "TOPLEFT", right, -46)
    p.results:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 140)
    p.resultsHint = newLabel(p, "", "GameFontHighlightSmall")
    p.resultsHint:SetPoint("TOPLEFT", p.results, "TOPLEFT", 4, -4)
    p.resultsHint:SetWidth(COLUMN_WIDTH - 30)

    p.add = newButton(p, L.EDITOR_ADD, 140, function() GuideEditor.AddSelectedResult() end)
    p.add:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, 112)

    -- "Add a step": [kind] [text............]
    --               [Use my location] [Clear]  Durotar 52.0, 41.5
    --               [Add step] [Update step]
    p.stepLabel = newLabel(p, L.EDITOR_ADD_STEP)
    p.stepLabel:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, 84)
    p.stepKind = newButton(p, "", 70, function() GuideEditor.CycleStepKind() end)
    p.stepKind:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, 56)
    p.stepText = newEditBox(p, COLUMN_WIDTH - 86)
    p.stepText:SetPoint("LEFT", p.stepKind, "RIGHT", 10, 0)
    p.stepText:SetScript("OnTextChanged", function(self, userInput)
        if userInput then state.stepForm.text = self:GetText() end
    end)
    p.stepHere = newButton(p, L.EDITOR_STEP_HERE, 120, function() GuideEditor.UseMyLocation() end)
    p.stepHere:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, 28)
    p.stepClear = newButton(p, L.EDITOR_STEP_CLEAR, 60, function()
        local form = state.stepForm
        form.zone, form.x, form.y = nil, nil, nil
        refreshQuests()
    end)
    p.stepClear:SetPoint("LEFT", p.stepHere, "RIGHT", 4, 0)
    p.stepWhere = newLabel(p, "", "GameFontHighlightSmall")
    p.stepWhere:SetPoint("LEFT", p.stepClear, "RIGHT", 8, 0)
    p.stepAdd = newButton(p, L.EDITOR_STEP_ADD, 120, function() GuideEditor.AddStep() end)
    p.stepAdd:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, 0)
    p.stepUpdate = newButton(p, L.EDITOR_STEP_UPDATE, 120, function() GuideEditor.UpdateStep() end)
    p.stepUpdate:SetPoint("LEFT", p.stepAdd, "RIGHT", 4, 0)

    f.questsTab = p
end

refreshQuests = function()
    local p = frame.questsTab
    local list = questList()
    local texts = {}
    for i, q in ipairs(list) do texts[i] = GuideEditor.QuestRowText(i, q) end
    p.list:SetItems(texts, state.selected)

    local label = state.mode == "view" and L.EDITOR_GENERATED_FMT or L.EDITOR_QUESTS_FMT
    p.listLabel:SetText(label:format(#list))

    local rtexts = {}
    for i, r in ipairs(state.results) do rtexts[i] = GuideEditor.ResultRowText(r, inGuide(r.id)) end
    p.results:SetItems(rtexts, state.resultSelected)

    local hint = ""
    if ns.QuestieData.Status() == "missing" then
        hint = L.EDITOR_SEARCH_NO_DB
    elseif #state.results == 0 then
        hint = (p.search:GetText() or "") == "" and L.EDITOR_SEARCH_HINT or L.EDITOR_SEARCH_NONE
    end
    p.resultsHint:SetText(C("muted", hint))

    for _, b in ipairs(p.moveButtons) do
        if readOnly() or not state.selected then b:Disable() else b:Enable() end
    end
    local r = state.results[state.resultSelected or 0]
    if readOnly() or not r or inGuide(r.id) then p.add:Disable() else p.add:Enable() end
    if readOnly() then p.search:Hide(); p.searchLabel:Hide() else p.search:Show(); p.searchLabel:Show() end

    local form = state.stepForm
    p.stepKind:SetText(L["STEP_KIND_" .. form.kind])
    if p.stepText:GetText() ~= (form.text or "") then p.stepText:SetText(form.text or "") end
    p.stepWhere:SetText(C("muted", ns.Sources.LocationText(form) or L.EDITOR_STEP_NOWHERE))
    local selectedEntry = list[state.selected or 0]
    local stepWidgets = { p.stepKind, p.stepHere, p.stepClear, p.stepAdd }
    for _, w in ipairs(stepWidgets) do
        if readOnly() then w:Disable() else w:Enable() end
    end
    if readOnly() then p.stepText:Disable() else p.stepText:Enable() end
    if readOnly() or not (selectedEntry and selectedEntry.step) then p.stepUpdate:Disable() else p.stepUpdate:Enable() end
end

---------------------------------------------------------------------------
-- Step form actions
---------------------------------------------------------------------------

--- Fill the step form from the selected entry, if it's a step.
function GuideEditor.LoadStepForm(index)
    local entry = questList()[index]
    if not entry or not entry.step then return end
    state.stepForm = { kind = entry.step, text = entry.text or "", zone = entry.zone, x = entry.x, y = entry.y }
end

function GuideEditor.CycleStepKind()
    local order = ns.GuideFormat.LIST_STEP_ORDER
    local form = state.stepForm
    for i, k in ipairs(order) do
        if k == form.kind then form.kind = order[i % #order + 1]; break end
    end
    refreshQuests()
end

--- Put your current map position into the step form.
function GuideEditor.UseMyLocation()
    local pos = ns.GameApi.GetPlayerPosition()
    local zone = pos and ns.GameApi.GetMapName(pos.mapID)
    if not zone then
        setStatus(C("warn", L.EDITOR_STEP_NO_POSITION))
        return false
    end
    local form = state.stepForm
    form.zone = zone
    form.x = math.floor(pos.x * 1000 + 0.5) / 10
    form.y = math.floor(pos.y * 1000 + 0.5) / 10
    refreshQuests()
    return true
end

local function formStep()
    local f = state.stepForm
    local text = f.text and f.text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    return { kind = f.kind, text = text ~= "" and text or nil, zone = f.zone, x = f.x, y = f.y }
end

local function stepFormOk(step)
    local problem = Ops.StepProblem(step)
    if problem then setStatus(C("warn", L[problem])) end
    return problem == nil
end

--- Add the step in the form after the selected entry.
function GuideEditor.AddStep()
    if readOnly() then return false end
    local step = formStep()
    if not stepFormOk(step) then return false end
    state.selected = Ops.AddStep(state.draft.quests, step, state.selected)
    setStatus("")
    refreshQuests()
    return true
end

--- Save the form into the selected step.
function GuideEditor.UpdateStep()
    if readOnly() then return false end
    local step = formStep()
    if not stepFormOk(step) then return false end
    if not Ops.UpdateStep(state.draft.quests, state.selected, step) then return false end
    setStatus("")
    refreshQuests()
    return true
end

--- For tests: fill the step form.
function GuideEditor.SetStepForm(kind, text)
    state.stepForm.kind = kind
    state.stepForm.text = text or ""
    refreshQuests()
end

function GuideEditor.GetStepForm() return state.stepForm end

---------------------------------------------------------------------------
-- Details tab
---------------------------------------------------------------------------

local function createDetailsTab(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -60)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING + 24 + 60)

    local y = 0
    p.fields = {}
    for _, field in ipairs({ { "name", "EDITOR_NAME", 300 }, { "author", "EDITOR_AUTHOR", 300 },
                             { "description", "EDITOR_DESCRIPTION", 600 } }) do
        local label = newLabel(p, L[field[2]])
        label:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
        local box = newEditBox(p, field[3])
        box:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y - 18)
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput and not readOnly() then
                local text = self:GetText()
                state.draft[field[1]] = text ~= "" and text or nil
            end
        end)
        p.fields[field[1]] = box
        y = y - 50
    end

    local baseLabel = newLabel(p, L.EDITOR_BASED_ON)
    baseLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
    p.baseButtons = {}
    for i, base in ipairs({ "story", "efficient" }) do
        local b = newButton(p, L["LIB_BASE_" .. base:upper()], 240, function()
            if readOnly() then return end
            -- Switching base resets the rules to that base's defaults.
            state.draft.base = base
            state.draft.rules = {}
            for k, v in pairs(ns.GuideFormat.BASES[base]) do state.draft.rules[k] = v end
            GuideEditor.Refresh()
        end)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 246, y - 18)
        b.base = base
        p.baseButtons[i] = b
    end

    p.help = newLabel(p, L.EDITOR_DETAILS_HELP, "GameFontHighlightSmall")
    p.help:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y - 60)
    p.help:SetWidth(WIDTH - PADDING * 2 - 20)
    f.detailsTab = p
end

local function refreshDetails()
    local p, d = frame.detailsTab, state.draft
    for key, box in pairs(p.fields) do
        box:SetText(d[key] or "")
        if readOnly() then box:Disable() else box:Enable() end
    end
    for _, b in ipairs(p.baseButtons) do
        if b.base == d.base then b:LockHighlight() else b:UnlockHighlight() end
    end
end

---------------------------------------------------------------------------
-- JSON tab
---------------------------------------------------------------------------

local function createJsonTab(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -60)
    p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING + 24 + 60)

    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -22, 0)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(WIDTH - PADDING * 2 - 30)
    edit:SetMaxLetters(ns.Json.MAX_LENGTH)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(self, ...)
        if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, ...) end
    end)
    edit:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, scroll) end
    end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        if readOnly() then
            self:SetText(state.jsonText or "")
            self:HighlightText()
        else
            state.jsonDirty = true
        end
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    p.edit = edit
    f.jsonTab = p
end

local function fillJson()
    if state.mode == "import" then
        state.jsonText = state.jsonText or ""
    else
        state.jsonText = ns.GuideFormat.ToJson(state.draft)
    end
    frame.jsonTab.edit:SetText(state.jsonText)
    state.jsonDirty = false
end

--- Read the JSON box back into the draft. Returns false (and shows the
--- problems) if it doesn't parse.
local function applyJson()
    if not state.jsonDirty or readOnly() then return true end
    local guide, errors, warnings = ns.GuideFormat.FromJson(frame.jsonTab.edit:GetText())
    if not guide then
        setStatus(GuideEditor.FormatMessages(errors, warnings))
        return false
    end
    state.draft = guide
    state.jsonDirty = false
    state.selected = nil
    return true
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local TABS = {
    { id = "quests", label = "EDITOR_TAB_QUESTS" },
    { id = "details", label = "EDITOR_TAB_DETAILS" },
    { id = "json", label = "EDITOR_TAB_JSON" },
}

local TITLES = {
    edit = "EDITOR_TITLE_EDIT", new = "EDITOR_TITLE_NEW", import = "EDITOR_TITLE_IMPORT",
    export = "EDITOR_TITLE_EXPORT", view = "EDITOR_TITLE_VIEW",
}

local function create()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)

    f.tabButtons = {}
    for i, tab in ipairs(TABS) do
        local b = newButton(f, L[tab.label], 110, function() GuideEditor.ShowTab(tab.id) end)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + (i - 1) * 114, -28)
        b.tabId = tab.id
        f.tabButtons[i] = b
    end

    createQuestsTab(f)
    createDetailsTab(f)
    createJsonTab(f)

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, PADDING + 30)
    f.status:SetWidth(WIDTH - PADDING * 2)
    f.status:SetJustifyH("LEFT")
    f.status:SetJustifyV("BOTTOM")

    f.close = newButton(f, L.EDITOR_CLOSE, 110, function() GuideEditor.Close() end)
    f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    f.save = newButton(f, L.EDITOR_SAVE, 110, function() GuideEditor.Save() end)
    f.save:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    f.check = newButton(f, L.EDITOR_CHECK, 110, function() GuideEditor.Check() end)
    f.check:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
    f.copyEdit = newButton(f, L.EDITOR_COPY_EDIT, 130, function()
        GuideEditor.Open("new", nil, ns.Library.CopyDraft(state.id, ns.Engine.BuildContext()))
    end)
    f.copyEdit:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    f.selectAll = newButton(f, L.EDITOR_SELECT_ALL, 110, function()
        f.jsonTab.edit:SetFocus()
        f.jsonTab.edit:HighlightText()
    end)
    f.selectAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, PADDING)

    -- Resizable: the two Quests columns share the width.
    local saved = ns.Settings.account.editor
    f:SetSize(math.max(MIN_WIDTH, math.min(MAX_WIDTH, saved.width or WIDTH)),
              math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, saved.height or HEIGHT)))
    ns.MainFrame.AddResizeGrip(f, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT, function(self)
        saved.width, saved.height = math.floor(self:GetWidth() + 0.5), math.floor(self:GetHeight() + 0.5)
    end)
    f:SetScript("OnSizeChanged", function(self) GuideEditor.Layout(self) end)
    GuideEditor.Layout(f)

    table.insert(UISpecialFrames, FRAME_NAME) -- close with Escape
    f:Hide()
    return f
end

--- Place the editor's widgets for its current size.
function GuideEditor.Layout(f)
    f = f or frame
    if not f or not f.questsTab then return end
    local width = f:GetWidth()
    if not width or width <= 0 then width = WIDTH end
    local column = math.floor((width - PADDING * 2 - 20) / 2)
    local right = column + 20
    local p = f.questsTab

    p.list:SetListWidth(column)
    p.searchLabel:ClearAllPoints()
    p.searchLabel:SetPoint("TOPLEFT", p, "TOPLEFT", right, 0)
    p.search:ClearAllPoints()
    p.search:SetPoint("TOPLEFT", p, "TOPLEFT", right + 6, -18)
    p.search:SetWidth(column - 10)
    p.results:SetListWidth(column)
    p.results:ClearAllPoints()
    p.results:SetPoint("TOPLEFT", p, "TOPLEFT", right, -46)
    p.results:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 140)
    p.resultsHint:SetWidth(column - 30)
    for _, pair in ipairs({ { p.add, 112 }, { p.stepLabel, 84 }, { p.stepKind, 56 },
                            { p.stepHere, 28 }, { p.stepAdd, 0 } }) do
        pair[1]:ClearAllPoints()
        pair[1]:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", right, pair[2])
    end
    p.stepText:SetWidth(column - 86)

    f.detailsTab.help:SetWidth(width - PADDING * 2 - 20)
    f.jsonTab.edit:SetWidth(width - PADDING * 2 - 30)
    f.status:SetWidth(width - PADDING * 2)
    f.columnWidth = column
end

local function show(widget, on)
    if on then widget:Show() else widget:Hide() end
end

--- Redraw everything for the current state.
function GuideEditor.Refresh()
    local f = frame
    f.title:SetText(L[TITLES[state.mode]] .. (state.draft and state.draft.name and (": " .. state.draft.name) or ""))

    -- Export and import only make sense as JSON.
    local jsonOnly = state.mode == "export" or state.mode == "import"
    if jsonOnly then state.tab = "json" end
    for _, b in ipairs(f.tabButtons) do
        show(b, not jsonOnly)
        if b.tabId == state.tab then b:LockHighlight() else b:UnlockHighlight() end
    end
    show(f.questsTab, state.tab == "quests")
    show(f.detailsTab, state.tab == "details")
    show(f.jsonTab, state.tab == "json")
    if state.tab == "quests" then refreshQuests() end
    if state.tab == "details" then refreshDetails() end

    show(f.check, not readOnly())
    show(f.save, not readOnly())
    show(f.copyEdit, state.mode == "view")
    show(f.selectAll, state.tab == "json")
    f.save:SetText(state.mode == "import" and L.EDITOR_IMPORT or L.EDITOR_SAVE)
end

function GuideEditor.ShowTab(tabId)
    if state.tab == "json" and tabId ~= "json" and not applyJson() then
        return -- stay on the JSON tab until it parses
    end
    state.tab = tabId
    if tabId == "json" then fillJson() end
    GuideEditor.Refresh()
end

--- Open the editor.
-- @param mode  "edit" | "new" | "view" | "export" | "import"
-- @param id    guide id (edit, view, export)
-- @param draft optional starting guide for "new" (e.g. a copy)
function GuideEditor.Open(mode, id, draft)
    if not frame then frame = create() end
    state.mode, state.id = mode, id
    state.selected, state.results, state.resultSelected = nil, {}, nil
    state.jsonText, state.viewList = nil, nil

    if mode == "edit" or mode == "view" or mode == "export" then
        state.draft = ns.Library.Draft(id)
    elseif mode == "new" then
        state.draft = draft or ns.GuideFormat.NewGuide()
    else
        state.draft = ns.GuideFormat.NewGuide()
        state.jsonText = ""
    end
    if mode == "view" then
        -- Built-in guides have no list of their own: show the quests they
        -- would pick for this character.
        state.viewList = ns.Library.QuestList(ns.Library.Get(id), ns.Engine.BuildContext())
    end

    frame.questsTab.search:SetText("")
    state.tab = (mode == "export" or mode == "import") and "json" or "quests"
    if state.tab == "json" then fillJson() end

    local hints = {
        export = L.EDITOR_EXPORT_HINT, import = L.EDITOR_IMPORT_HINT, view = L.EDITOR_VIEW_HINT,
    }
    setStatus(C("muted", hints[mode] or L.EDITOR_HELP))

    GuideEditor.Refresh()
    frame:Show()
    if mode == "export" then
        frame.jsonTab.edit:SetFocus()
        frame.jsonTab.edit:HighlightText()
    elseif mode == "import" then
        frame.jsonTab.edit:SetFocus()
    end
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

--- Update the search results for `text`.
function GuideEditor.Search(text)
    state.results = ns.QuestieData.Search(text, SEARCH_LIMIT)
    -- Without QuestieDB a quest ID can still be added by number.
    local asNumber = tonumber(text)
    if #state.results == 0 and asNumber and asNumber > 0 and asNumber == math.floor(asNumber) then
        state.results = { ns.QuestieData.Describe(asNumber) }
    end
    state.resultSelected = #state.results > 0 and 1 or nil
    refreshQuests()
end

--- Add the selected search result after the selected quest (or at the end).
function GuideEditor.AddSelectedResult()
    if readOnly() then return end
    local r = state.results[state.resultSelected or 0]
    if not r then return end
    local index, added = Ops.Add(state.draft.quests, r, state.selected)
    state.selected = index
    if not added then setStatus(C("warn", L.EDITOR_ALREADY_FMT:format(r.name))) end
    refreshQuests()
end

--- Validate without saving.
function GuideEditor.Check()
    if state.tab == "json" and not applyJson() then return false end
    local guide, errors, warnings = ns.GuideFormat.Check(state.draft)
    if guide and #warnings == 0 then
        setStatus(C("good", L.EDITOR_OK))
    else
        setStatus(GuideEditor.FormatMessages(errors, warnings))
    end
    return guide ~= nil
end

--- Save (edit/new) or import, then show the result in the Guides tab.
function GuideEditor.Save()
    if readOnly() then return nil end
    local id, errors, warnings
    local wasImport = state.mode == "import"

    if wasImport then
        id, errors, warnings = ns.Library.Import(frame.jsonTab.edit:GetText())
    else
        if state.tab == "json" and not applyJson() then return nil end
        id, errors, warnings = ns.Library.Save(state.draft, state.mode == "edit" and state.id or nil)
    end
    if not id then
        setStatus(GuideEditor.FormatMessages(errors, warnings))
        return nil
    end

    -- Keep editing the saved guide; later saves update it.
    state.mode, state.id = "edit", id
    state.draft = ns.Library.Draft(id)
    state.jsonText = nil
    if state.tab == "json" then fillJson() end
    GuideEditor.Refresh()

    local guide = ns.Library.Get(id)
    local done = wasImport and L.EDITOR_IMPORTED_FMT:format(guide.name) or L.EDITOR_SAVED
    local extra = GuideEditor.FormatMessages(nil, warnings)
    setStatus(C("good", done) .. (extra ~= "" and ("\n" .. extra) or ""))

    ns.LibraryTab.OnGuideSaved(id)
    return id
end

function GuideEditor.Close()
    if frame then frame:Hide() end
end

function GuideEditor.IsShown()
    return frame ~= nil and frame:IsShown()
end

---------------------------------------------------------------------------
-- For tests
---------------------------------------------------------------------------

function GuideEditor.GetState() return state end
function GuideEditor.GetStatus() return frame.status:GetText() end
function GuideEditor.GetMode() return state.mode end
function GuideEditor.GetJson() return frame.jsonTab.edit:GetText() end
function GuideEditor.SetJson(text)
    frame.jsonTab.edit:SetText(text)
    state.jsonDirty = true
    state.jsonText = text
end
function GuideEditor.SelectQuest(index)
    state.selected = index
    GuideEditor.LoadStepForm(index)
    refreshQuests()
end
function GuideEditor.SelectResult(index) state.resultSelected = index; refreshQuests() end
function GuideEditor.PressMove(i) frame.questsTab.moveButtons[i]:GetScript("OnClick")() end
function GuideEditor.SetField(key, text)
    local box = frame.detailsTab.fields[key]
    box:SetText(text)
    box:GetScript("OnTextChanged")(box, true)
end
function GuideEditor.QuestRows()
    local out = {}
    for _, r in ipairs(frame.questsTab.list.rows) do
        if r:IsShown() then out[#out + 1] = r.text:GetText() end
    end
    return out
end
function GuideEditor.ResultRows()
    local out = {}
    for _, r in ipairs(frame.questsTab.results.rows) do
        if r:IsShown() then out[#out + 1] = r.text:GetText() end
    end
    return out
end
