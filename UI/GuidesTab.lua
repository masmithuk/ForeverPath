--[[
    ForeverPath - UI/GuidesTab.lua

    "Guides" tab: the guide browser.

      Left   every zone guide on the selected route, with its level range
             and progress (quests done / total). Guides for your level are
             gold; the one you're following is marked with an arrow.
      Right  the selected guide's quests with level, quest giver and your
             status, plus "Follow this guide" and "Automatic" buttons.
]]

local _, ns = ...

local GuidesTab = {}
ns.GuidesTab = GuidesTab

local L = ns.L
local Util = ns.Util
local C = Util.Color

local LIST_WIDTH = 250
local ROW_HEIGHT = 22

local panel
local selectedId -- guide shown on the right; defaults to the active/recommended one

local STATUS_TEXT = {
    done      = { "muted", "QUEST_DONE" },
    ready     = { "good",  "QUEST_READY" },
    active    = { "ffffff", "QUEST_ACTIVE" },
    available = { "accent", "QUEST_AVAILABLE" },
    level     = { "warn",  "QUEST_LEVEL_FMT" },
    locked    = { "muted", "QUEST_LOCKED" },
}

---------------------------------------------------------------------------
-- Text (pure; tested)
---------------------------------------------------------------------------

function GuidesTab.RowText(guide, overview)
    local marker = guide.active and C("good", "> ") or ""
    local name = guide.recommended and C("accent", guide.name) or guide.name
    local progress = ""
    if overview and overview.total > 0 then
        progress = C("muted", (" %d/%d"):format(overview.done, overview.total))
    end
    return ("%s%s  %s%s"):format(marker, name, C("muted", guide.min .. "-" .. guide.max), progress)
end

function GuidesTab.StatusLabel(q)
    local entry = STATUS_TEXT[q.status]
    local label = L[entry[2]]
    if q.status == "level" then label = label:format(q.requiredLevel) end
    return C(entry[1], label)
end

function GuidesTab.DetailText(guide, overview)
    local lines = {}
    lines[#lines + 1] = C("accent", ("%s  (%d-%d)"):format(guide.name, guide.min, guide.max))

    if overview.dataStatus ~= "ready" then
        lines[#lines + 1] = C("warn", L.GUIDES_NEED_QUESTIE)
        return table.concat(lines, "\n")
    end
    if overview.total == 0 then
        lines[#lines + 1] = C("muted", L.GUIDES_NO_QUESTS)
        return table.concat(lines, "\n")
    end

    lines[#lines + 1] = L.GUIDES_PROGRESS_FMT:format(overview.done, overview.total)
    lines[#lines + 1] = " "
    for _, q in ipairs(overview.quests) do
        lines[#lines + 1] = ("[%d] %s  %s  %s"):format(
            q.level, q.name, C("muted", "- " .. q.giver), GuidesTab.StatusLabel(q))
    end
    return table.concat(lines, "\n")
end

function GuidesTab.FollowingText()
    local guideId = ns.Settings.char.guideId
    if guideId then return L.GUIDES_FOLLOWING_FMT:format(guideId) end
    return L.GUIDES_FOLLOWING_AUTO
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

local function createListRow(parent, index)
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
        selectedId = self.guideId
        GuidesTab.Refresh()
    end)
    return row
end

function GuidesTab.Create(parent)
    local MF = ns.MainFrame
    panel = MF.NewPanel(parent)

    -- Left: list of guides.
    panel.listScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.listScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.listScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    panel.listScroll:SetWidth(LIST_WIDTH)
    panel.listChild = CreateFrame("Frame", nil, panel.listScroll)
    panel.listChild:SetSize(LIST_WIDTH - 24, 1)
    panel.listScroll:SetScrollChild(panel.listChild)
    panel.rows = {}

    -- Right: details.
    local detailLeft = LIST_WIDTH + 12
    panel.following = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.following:SetPoint("TOPLEFT", panel, "TOPLEFT", detailLeft, 0)

    panel.follow = MF.NewButton(panel, L.GUIDES_FOLLOW, 150, function()
        if selectedId then ns.Engine.SetGuide(selectedId) end
        GuidesTab.Refresh()
    end)
    panel.follow:SetPoint("TOPLEFT", panel.following, "BOTTOMLEFT", 0, -6)

    panel.auto = MF.NewButton(panel, L.GUIDES_AUTO, 150, function()
        ns.Engine.SetGuide(nil)
        GuidesTab.Refresh()
    end)
    panel.auto:SetPoint("LEFT", panel.follow, "RIGHT", 6, 0)

    local detailWidth = MF.WIDTH - MF.PADDING * 2 - detailLeft - 30
    panel.detail = MF.NewScrollText(panel, detailWidth)
    panel.detail:SetPoint("TOPLEFT", panel.follow, "BOTTOMLEFT", 0, -10)
    panel.detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 0)
    return panel
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function pickDefault(guides)
    local chosen = ns.Settings.char.guideId
    local fallback = guides[1]
    for _, g in ipairs(guides) do
        if g.id == chosen then return g end
        if g.recommended and not fallback.recommended then fallback = g end
    end
    return fallback
end

function GuidesTab.Refresh()
    if not panel then return end
    local ctx = ns.Engine.BuildContext()
    local guides = ns.Catalog.List(ctx.profile, ns.Settings.char.routeId)

    local selected
    for _, g in ipairs(guides) do
        if g.id == selectedId then selected = g end
    end
    if not selected then
        selected = pickDefault(guides)
        selectedId = selected and selected.id
    end

    for i, guide in ipairs(guides) do
        local row = panel.rows[i] or createListRow(panel.listChild, i)
        panel.rows[i] = row
        row.guideId = guide.id
        row.text:SetText(GuidesTab.RowText(guide, ns.Catalog.Overview(guide.id, ctx)))
        if guide.id == selectedId then row.selected:Show() else row.selected:Hide() end
        row:Show()
    end
    for i = #guides + 1, #panel.rows do panel.rows[i]:Hide() end
    panel.listChild:SetHeight(#guides * ROW_HEIGHT)

    panel.following:SetText(GuidesTab.FollowingText())
    if selected then
        panel.detail:SetContent(GuidesTab.DetailText(selected, ns.Catalog.Overview(selected.id, ctx)))
        if selected.active then panel.follow:Disable() else panel.follow:Enable() end
    else
        panel.detail:SetContent("")
        panel.follow:Disable()
    end
    if ns.Settings.char.guideId then panel.auto:Enable() else panel.auto:Disable() end
end

--- For tests: select a guide as if its row were clicked.
function GuidesTab.Select(guideId)
    selectedId = guideId
    GuidesTab.Refresh()
end

function GuidesTab.GetDetailText()
    return panel and panel.detail.text:GetText()
end

function GuidesTab.GetRows()
    return panel and panel.rows or {}
end
