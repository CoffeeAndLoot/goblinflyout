local _, ns = ...

-- The options window (spec 2026-10-12-goblin-flyout-design.md): one row per
-- kind: its icon (drag or click it to pick up the kind's button), its name,
-- and a button that flips its layout. Made on first open; position saved.
local Window = {}
ns.Window = Window

Window.WIDTH = 300
Window.ROW = 44
Window.TOP = -32  -- below ButtonFrameTemplate's title bar

local frame
local flips = {}  -- kind key -> its layout button

local function row(core, kind, i)
    local top = Window.TOP - (i - 1) * Window.ROW

    local icon = CreateFrame("Button", nil, frame)
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, top)
    icon:SetNormalTexture("Interface\\Icons\\" .. kind.icon)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function()
        core.PickUp(kind)
    end)
    icon:SetScript("OnClick", function()
        core.PickUp(kind)
    end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(kind.label)
        GameTooltip:AddLine("Drag to an action bar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local flip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    flip:SetSize(100, 22)
    flip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, top - 7)
    flip:SetScript("OnClick", function()
        core.SetLayout(kind.key, ns.Options.Other(core.Layout(kind.key)))
    end)
    flips[kind.key] = flip

    -- Two anchors bound the name between the icon and the button.
    local name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetPoint("RIGHT", flip, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(kind.label)
end

local function make(core)
    frame = CreateFrame("Frame", "GoblinFlyoutWindow", UIParent, "ButtonFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if frame.SetTitle then
        frame:SetTitle(ns.Options.NAME)
    end
    frame:SetSize(Window.WIDTH, -Window.TOP + #ns.Kinds.LIST * Window.ROW + 16)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)  -- our SavedVariable keeps the place, not layout-local.txt
        local point, _, _, x, y = self:GetPoint(1)
        core.SaveWindow(point, x, y)
    end)
    frame:ClearAllPoints()
    local saved = core.Window()
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
    frame:Hide()
    table.insert(UISpecialFrames, "GoblinFlyoutWindow")  -- Escape closes it
    for i, kind in ipairs(ns.Kinds.LIST) do
        row(core, kind, i)
    end
end

-- Shows each kind's current layout on its button.
function Window.Refresh(core)
    for key, flip in pairs(flips) do
        flip:SetText(ns.Options.LABELS[core.Layout(key)])
    end
end

function Window.Toggle(core)
    if not frame then
        make(core)
    end
    if frame:IsShown() then
        frame:Hide()
        return
    end
    Window.Refresh(core)
    frame:Show()
end

return Window
