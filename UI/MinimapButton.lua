--[[
    ForeverPath - UI/MinimapButton.lua

    A round button on the edge of the minimap, written without libraries.

      Left-click    show or hide the step guide window
      Right-click   open or close the main window (Guides, Plan, Settings)
      Drag          move it around the minimap edge (position is saved)

    It can be hidden from the Settings tab. The minimap's addon compartment
    entry (declared in the .toc) stays available either way.
]]

local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local L = ns.L
local button

--- x, y offset from the minimap centre for an angle in degrees.
function MinimapButton.Offset(angle, radius)
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

local function radius()
    local width = Minimap:GetWidth() or 140
    return width / 2 + 10
end

function MinimapButton.UpdatePosition()
    if not button then return end
    local x, y = MinimapButton.Offset(ns.Settings.account.minimap.angle, radius())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Angle of the cursor around the minimap centre, in degrees.
local function cursorAngle()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    return math.deg(math.atan2(py / scale - my, px / scale - mx))
end

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.MainFrame.Toggle()
    else
        ns.GuideFrame.Toggle()
    end
end

local function showTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE)
    GameTooltip:AddLine(L.MINIMAP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function create()
    local b = CreateFrame("Button", "ForeverPathMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            ns.Settings.account.minimap.angle = cursorAngle()
            MinimapButton.UpdatePosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    return b
end

--- Create the button (once) and apply the saved visibility.
function MinimapButton.Init()
    if not Minimap then return end
    if not button then button = create() end
    MinimapButton.UpdatePosition()
    if ns.Settings.account.minimap.hide then button:Hide() else button:Show() end
end

function MinimapButton.SetShown(shown)
    ns.Settings.account.minimap.hide = not shown
    MinimapButton.Init()
end

--- For tests: simulate a click.
function MinimapButton.Click(mouseButton)
    onClick(button, mouseButton)
end
