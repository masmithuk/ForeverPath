--[[
    ForeverPath - UI/GuideEditor.lua

    One window for working with guide text, in five modes:

      edit    one of your guides; Save overwrites it
      new     a template (or a copy of another guide); Save creates a guide
      import  an empty box to paste a shared guide into; Import creates it
      export  the guide text, read-only and selected, ready for Ctrl+C
      view    a built-in guide, read-only, with a "Copy & edit" button

    "Check" validates without saving and lists problems with line numbers.
    Saving runs the same checks, so a broken guide is never stored.
]]

local _, ns = ...

local GuideEditor = {}
ns.GuideEditor = GuideEditor

local L = ns.L
local C = ns.Util.Color

local FRAME_NAME = "ForeverPathGuideEditor"
local WIDTH, HEIGHT = 640, 520
local PADDING = 12
local MAX_MESSAGES = 6

local frame
local state = { mode = nil, id = nil, original = "" }

local TITLES = {
    edit = "EDITOR_TITLE_EDIT", new = "EDITOR_TITLE_NEW", import = "EDITOR_TITLE_IMPORT",
    export = "EDITOR_TITLE_EXPORT", view = "EDITOR_TITLE_VIEW",
}

---------------------------------------------------------------------------
-- Messages (pure; tested)
---------------------------------------------------------------------------

--- Errors (red) and warnings (orange) as display text, capped in length.
function GuideEditor.FormatMessages(errors, warnings)
    local lines = {}
    local function add(list, color)
        for _, m in ipairs(list or {}) do
            if #lines >= MAX_MESSAGES then return end
            local text = m.line and L.EDITOR_LINE_FMT:format(m.line, m.message) or m.message
            lines[#lines + 1] = C(color, text)
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

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function readOnly()
    return state.mode == "export" or state.mode == "view"
end

local function setStatus(text)
    frame.status:SetText(text or "")
end

local function createTextArea(f)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -32)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING - 22, PADDING + 24 + 70)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(WIDTH - PADDING * 2 - 30)
    edit:SetMaxLetters(ns.GuideFormat.MAX_TEXT)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Keep the cursor in view while typing (Blizzard helpers, if present).
    edit:SetScript("OnCursorChanged", function(self, ...)
        if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, ...) end
    end)
    edit:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, scroll) end
    end)
    -- Read-only modes: undo any typing and keep everything selected.
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and readOnly() then
            self:SetText(state.original)
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

    f.scroll, f.edit = scroll, edit
end

local function newButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(110, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

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

    createTextArea(f)

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", f.scroll, "BOTTOMLEFT", 0, -8)
    f.status:SetWidth(WIDTH - PADDING * 2)
    f.status:SetJustifyH("LEFT")
    f.status:SetJustifyV("TOP")

    f.close = newButton(f, L.EDITOR_CLOSE, function() GuideEditor.Close() end)
    f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    f.save = newButton(f, L.EDITOR_SAVE, function() GuideEditor.Save() end)
    f.save:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    f.check = newButton(f, L.EDITOR_CHECK, function() GuideEditor.Check() end)
    f.check:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
    f.selectAll = newButton(f, L.EDITOR_SELECT_ALL, function()
        f.edit:SetFocus()
        f.edit:HighlightText()
    end)
    f.selectAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, PADDING)
    f.copyEdit = newButton(f, L.EDITOR_COPY_EDIT, function()
        GuideEditor.Open("new", nil, ns.Library.CopyText(state.id))
    end)
    f.copyEdit:SetPoint("RIGHT", f.close, "LEFT", -6, 0)

    table.insert(UISpecialFrames, FRAME_NAME) -- close with Escape
    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

local function show(widget, shown)
    if shown then widget:Show() else widget:Hide() end
end

--- Open the editor.
-- @param mode "edit" | "new" | "import" | "export" | "view"
-- @param id   guide id (edit, export, view)
-- @param text optional starting text (new: a template or a copy)
function GuideEditor.Open(mode, id, text)
    if not frame then frame = create() end
    state.mode, state.id = mode, id

    if mode == "edit" or mode == "export" or mode == "view" then
        text = ns.Library.Text(id)
    elseif mode == "new" then
        text = text or ns.GuideFormat.Template()
    else -- import
        text = ""
    end
    state.original = text or ""

    frame.title:SetText(L[TITLES[mode]])
    frame.edit:SetText(state.original)

    show(frame.check, not readOnly())
    show(frame.save, not readOnly())
    show(frame.copyEdit, mode == "view")
    show(frame.selectAll, readOnly())
    frame.save:SetText(mode == "import" and L.EDITOR_IMPORT or L.EDITOR_SAVE)

    local hints = {
        export = L.EDITOR_EXPORT_HINT, import = L.EDITOR_IMPORT_HINT,
        view = L.EDITOR_VIEW_HINT,
    }
    setStatus(C("muted", hints[mode] or L.EDITOR_HELP))

    frame:Show()
    frame.edit:SetFocus()
    if mode == "export" then frame.edit:HighlightText() end
end

--- Validate the text without saving.
function GuideEditor.Check()
    local guide, errors, warnings = ns.GuideFormat.Parse(frame.edit:GetText())
    if guide and #warnings == 0 then
        setStatus(C("good", L.EDITOR_OK))
    else
        setStatus(GuideEditor.FormatMessages(errors, warnings))
    end
    return guide ~= nil
end

--- Save (edit/new) or import, then show the result in the Guides tab.
function GuideEditor.Save()
    if readOnly() then return end
    local text = frame.edit:GetText()
    local id, errors, warnings
    if state.mode == "edit" then
        id, errors, warnings = ns.Library.Save(text, state.id)
    else
        id, errors, warnings = ns.Library.Save(text, nil)
    end

    if not id then
        setStatus(GuideEditor.FormatMessages(errors, warnings))
        return nil
    end

    local guide = ns.Library.Get(id)
    local wasImport = state.mode == "import"
    -- Later saves go to the same guide.
    state.mode, state.id = "edit", id
    state.original = ns.Library.Text(id)
    frame.title:SetText(L.EDITOR_TITLE_EDIT)
    frame.save:SetText(L.EDITOR_SAVE)

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

--- For tests.
function GuideEditor.SetText(text) frame.edit:SetText(text) end
function GuideEditor.GetText() return frame.edit:GetText() end
function GuideEditor.GetStatus() return frame.status:GetText() end
function GuideEditor.GetMode() return state.mode end
