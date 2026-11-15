--[[
    ForeverPath - UI/LibraryTab.lua

    "Guides" tab: every guide you can follow.

      Left   the built-in guides, then your own. The one this character
             follows is marked "in use".
      Right  the selected guide's details, and buttons to:
               Use this guide      follow it on this character
               Edit / View         change your guide, or read a built-in one
               Copy                make your own editable copy
               New guide           start from a template
               Delete              remove your guide (click twice)
               Export / Import     share guides as text
]]

local _, ns = ...

local LibraryTab = {}
ns.LibraryTab = LibraryTab

local L = ns.L
local C = ns.Util.Color

local LIST_WIDTH = 250
local ROW_HEIGHT = 22

local panel
local selectedId
local deleteArmedFor -- guide id whose Delete button has been clicked once

---------------------------------------------------------------------------
-- Text (pure; tested)
---------------------------------------------------------------------------

local function currentId()
    local profile = ns.Character.Detect()
    return ns.Advisor.ResolveRouteId(profile, ns.Settings.char.routeId)
end

function LibraryTab.RowText(guide, inUse)
    local name = inUse and C("good", "> " .. guide.name) or guide.name
    local tag = guide.builtin and C("muted", "  " .. L.LIB_BUILTIN) or ""
    return name .. tag
end

local function zoneCount(guide)
    local seen, n = {}, 0
    for _, b in ipairs(guide.bands) do
        for _, faction in ipairs({ "Alliance", "Horde" }) do
            for _, z in ipairs(b[faction]) do
                if not seen[z] then seen[z] = true; n = n + 1 end
            end
        end
    end
    return n
end

function LibraryTab.DetailText(guide, inUse)
    local lines = { C("accent", guide.name) }
    local meta = {}
    if guide.author and guide.author ~= "" then meta[#meta + 1] = L.LIB_BY_FMT:format(guide.author) end
    if guide.builtin then meta[#meta + 1] = L.LIB_BUILTIN end
    if inUse then meta[#meta + 1] = C("good", L.LIB_IN_USE) end
    if #meta > 0 then lines[#lines + 1] = C("muted", table.concat(meta, " - ")) end
    if guide.description and guide.description ~= "" then
        lines[#lines + 1] = " "
        lines[#lines + 1] = guide.description
    end

    local r = guide.rules
    local base = guide.base == "story" and L.LIB_BASE_STORY or L.LIB_BASE_EFFICIENT
    local detour = (r.maxDetour or 0) > 0 and L.LIB_YARDS_FMT:format(r.maxDetour) or L.LIB_NO_LIMIT
    lines[#lines + 1] = " "
    lines[#lines + 1] = L.LIB_BASED_ON_FMT:format(base)
    lines[#lines + 1] = L.LIB_RULES_FMT:format(r.greyGap, r.levelsAbove, detour)
    lines[#lines + 1] = L.LIB_ZONES_FMT:format(zoneCount(guide))
    lines[#lines + 1] = L.LIB_EXTRAS_FMT:format(#guide.quests, #guide.skipQuests, #guide.steps)

    if guide.builtin then
        lines[#lines + 1] = " "
        lines[#lines + 1] = C("muted", L.LIB_BUILTIN_NOTE)
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function selected()
    return selectedId and ns.Library.Get(selectedId)
end

local actions = {}

function actions.use()
    local guide = selected()
    if not guide then return end
    ns.MainFrame.SetRoute(guide.id)
    ns.Util.Print(L.LIB_USING_FMT:format(guide.name))
end

function actions.edit()
    local guide = selected()
    if not guide then return end
    ns.GuideEditor.Open(guide.builtin and "view" or "edit", guide.id)
end

function actions.copy()
    local guide = selected()
    if guide then
        ns.GuideEditor.Open("new", nil, ns.Library.CopyDraft(guide.id, ns.Engine.BuildContext()))
    end
end

function actions.new()
    ns.GuideEditor.Open("new")
end

function actions.delete()
    local guide = selected()
    if not guide or guide.builtin then return end
    if deleteArmedFor ~= guide.id then
        deleteArmedFor = guide.id -- first click: ask for a second
        LibraryTab.Refresh()
        return
    end
    deleteArmedFor = nil
    ns.Library.Delete(guide.id)
    ns.Util.Print(L.LIB_DELETED_FMT:format(guide.name))
    selectedId = nil
    if ns.Settings.char.routeId == guide.id then
        -- This character followed it: fall back to the class's default.
        ns.Settings.char.routeId = nil
        ns.Engine.OnModeChanged()
    end
    ns.MainFrame.Refresh()
end

function actions.export()
    local guide = selected()
    if guide then ns.GuideEditor.Open("export", guide.id) end
end

function actions.import()
    ns.GuideEditor.Open("import")
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local BUTTONS = {
    -- { action, label, column, row }
    { "use", "LIB_USE", 1, 1 },     { "edit", "LIB_EDIT", 2, 1 },     { "copy", "LIB_COPY", 3, 1 },
    { "new", "LIB_NEW", 1, 2 },     { "delete", "LIB_DELETE", 2, 2 },
    { "export", "LIB_EXPORT", 1, 3 }, { "import", "LIB_IMPORT", 2, 3 },
}

local function createRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_WIDTH - 24, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.15)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
        LibraryTab.Select(self.guideId)
    end)
    return row
end

function LibraryTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)

    panel.listScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.listScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.listScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    panel.listScroll:SetWidth(LIST_WIDTH)
    panel.listChild = CreateFrame("Frame", nil, panel.listScroll)
    panel.listChild:SetSize(LIST_WIDTH - 24, 1)
    panel.listScroll:SetScrollChild(panel.listChild)
    panel.rows = {}

    local left = LIST_WIDTH + 12
    panel.buttons = {}
    for _, def in ipairs(BUTTONS) do
        local action, label, column, row = def[1], def[2], def[3], def[4]
        local b = MF.NewButton(panel, L[label], 132, function() actions[action]() end)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", left + (column - 1) * 136, -(row - 1) * 26)
        panel.buttons[action] = b
    end

    local detailWidth = MF.WIDTH - MF.PADDING * 2 - left - 30
    panel.detail = MF.NewScrollText(panel, detailWidth)
    panel.detail:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -3 * 26 - 8)
    panel.detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 0)
    return panel
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function enable(button, on)
    if on then button:Enable() else button:Disable() end
end

function LibraryTab.Refresh()
    if not panel then return end
    local guides = ns.Library.List()
    local inUseId = currentId()
    if not selectedId or not ns.Library.Get(selectedId) then selectedId = inUseId end
    if deleteArmedFor ~= selectedId then deleteArmedFor = nil end

    for i, guide in ipairs(guides) do
        local row = panel.rows[i] or createRow(panel.listChild, i)
        panel.rows[i] = row
        row.guideId = guide.id
        row.text:SetText(LibraryTab.RowText(guide, guide.id == inUseId))
        if guide.id == selectedId then row.selected:Show() else row.selected:Hide() end
        row:Show()
    end
    for i = #guides + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.listChild:SetHeight(#guides * ROW_HEIGHT)

    local guide = selected()
    panel.detail:SetContent(guide and LibraryTab.DetailText(guide, guide.id == inUseId) or "")

    local b = panel.buttons
    local isMine = guide and not guide.builtin
    b.use:SetText(guide and guide.id == inUseId and L.LIB_USING or L.LIB_USE)
    enable(b.use, guide and guide.id ~= inUseId)
    b.edit:SetText(isMine and L.LIB_EDIT or L.LIB_VIEW)
    enable(b.edit, guide ~= nil)
    enable(b.copy, guide ~= nil)
    enable(b.export, guide ~= nil)
    enable(b.delete, isMine)
    b.delete:SetText(deleteArmedFor and L.LIB_DELETE_CONFIRM or L.LIB_DELETE)
end

function LibraryTab.Select(id)
    selectedId = id
    LibraryTab.Refresh()
end

--- Called by the editor after a save or import: select the guide and, if
--- this character follows it, re-plan with the new version.
function LibraryTab.OnGuideSaved(id)
    selectedId = id
    if ns.Settings.char.routeId == id then
        ns.Engine.OnGuideEdited()
    end
    ns.MainFrame.Refresh()
end

--- For tests: press a button by its action name.
function LibraryTab.Press(action)
    actions[action]()
end

function LibraryTab.GetDetailText()
    return panel and panel.detail.text:GetText()
end

function LibraryTab.GetRows()
    return panel and panel.rows or {}
end

function LibraryTab.GetButton(action)
    return panel and panel.buttons[action]
end
