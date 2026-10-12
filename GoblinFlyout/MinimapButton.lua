local _, ns = ...

-- The minimap button (spec 2026-10-12-goblin-flyout-design.md), hand-made:
-- no libraries, and Blizzard's addon compartment is Mainline-only. Click
-- opens the window; drag slides it round the rim. Not "Minimap": that name
-- is Blizzard's own frame. Position and Angle are pure; Create builds frames
-- only when called, so test/run.lua loads this file.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

MinimapButton.ICON = "Interface\\Icons\\INV_Misc_Bomb_04"

-- Offset from the minimap's centre for an angle in degrees (0 = right, 90 = up).
function MinimapButton.Position(angle, radius)
    local r = math.rad(angle)
    return math.cos(r) * radius, math.sin(r) * radius
end

-- The angle, 0..360, of an offset from the minimap's centre.
function MinimapButton.Angle(dx, dy)
    return math.deg(math.atan2(dy, dx)) % 360
end

local button

local function place(angle)
    local x, y = MinimapButton.Position(angle, Minimap:GetWidth() / 2 + 10)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function follow()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    button.angle = MinimapButton.Angle(cx / scale - mx, cy / scale - my)
    place(button.angle)
end

function MinimapButton.Create(core)
    if button or not Minimap then
        return
    end
    button = CreateFrame("Button", "GoblinFlyoutMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
    icon:SetTexture(MinimapButton.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function()
        core.ToggleWindow()
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", follow)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        core.SetAngle(self.angle)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.Options.NAME)
        GameTooltip:AddLine("Click for options, drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button.angle = core.Angle()
    place(button.angle)
end

return MinimapButton
