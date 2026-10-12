local _, ns = ...

-- The options window (spec 2026-10-12-goblin-flyout-design.md) in the Goblin
-- look (Look.lua, from GoblinQuest): a dark window with a gold top edge, a
-- header to drag it by, and one row per kind in an inset well: its icon (drag
-- or click it to pick up the kind's button), its name, and a Horizontal |
-- Vertical switch. Plain frames, no Blizzard templates. Made on first open.
local Window = {}
ns.Window = Window

Window.NAME = "GoblinFlyoutWindow"  -- UISpecialFrames closes frames by name on Escape
Window.WIDTH = 400  -- room for "Food & Drink" between its icon and its switch
Window.HOME = { "CENTER", "CENTER", 0, 40 }  -- where it opens until dragged
Window.LAYOUT = {
    TOP_EDGE = 2, HEADER = 56, PAD = 16, CLOSE = 28,
    ROW = 44, ICON = 32, ICON_X = 24, WELL_PAD = 4, SWITCH_W = 82, SWITCH_H = 24, FOOT = 30,
    BRACE_X = 12, BRACE = 2,  -- the gold bracket in the gutter left of the icons
}
local L = Window.LAYOUT
Window.HEIGHT = L.TOP_EDGE + L.HEADER + L.PAD + #ns.Kinds.LIST * L.ROW + 2 * L.WELL_PAD + L.FOOT

local frame
local switches = {}  -- kind key -> { horizontal = button, vertical = button }

local function buildHeader(core)
    local Look = ns.Look
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -L.TOP_EDGE)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -L.TOP_EDGE)
    head:SetHeight(L.HEADER)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() frame:StartMoving() end)
    head:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        -- Re-anchor TOPLEFT by where the window sits, and keep both points.
        local x, y = frame:GetLeft(), frame:GetTop()
        if x and y then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            core.SaveWindow("TOPLEFT", "BOTTOMLEFT", x, y)
        end
    end)
    local rule = Look.Texture(head, "BORDER", Look.COLOUR.divider)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT")

    local close = Look.IconButton(head, "close", L.CLOSE, function() frame:Hide() end, "X")
    close:SetPoint("RIGHT", head, "RIGHT", -12, 0)
    local name = Look.Text(head, Look.WORDS, 17, "gold")
    name:SetPoint("TOPLEFT", head, "TOPLEFT", L.PAD, -12)
    name:SetPoint("RIGHT", close, "LEFT", -12, 0)
    name:SetText(ns.Options.NAME)
    local tagline = Look.Text(head, Look.WORDS, 10, "dim")
    tagline:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    tagline:SetPoint("RIGHT", close, "LEFT", -12, 0)
    tagline:SetText("Time is money, friend.")
end

local function row(core, well, kind, i)
    local Look = ns.Look
    local r = CreateFrame("Frame", nil, well)
    r:SetHeight(L.ROW)
    r:SetPoint("TOPLEFT", well, "TOPLEFT", L.WELL_PAD, -(L.WELL_PAD + (i - 1) * L.ROW))
    r:SetPoint("TOPRIGHT", well, "TOPRIGHT", -L.WELL_PAD, -(L.WELL_PAD + (i - 1) * L.ROW))

    local icon = CreateFrame("Button", nil, r)
    icon:SetSize(L.ICON, L.ICON)
    icon:SetPoint("LEFT", r, "LEFT", L.ICON_X, 0)
    local art = icon:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    art:SetTexture("Interface\\Icons\\" .. kind.icon)
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Look.Outline(icon, Look.COLOUR.line)
    local hover = Look.Texture(icon, "HIGHLIGHT", Look.COLOUR.gold, 0.25)
    hover:SetAllPoints(art)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function() core.PickUp(kind) end)
    icon:SetScript("OnClick", function() core.PickUp(kind) end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(kind.label)
        GameTooltip:AddLine("Drag to an action bar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function choose(layout)
        return function() core.SetLayout(kind.key, layout) end
    end
    local vertical = Look.Button(r, ns.Options.LABELS.vertical, L.SWITCH_W, L.SWITCH_H, choose("vertical"))
    vertical:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    local horizontal = Look.Button(r, ns.Options.LABELS.horizontal, L.SWITCH_W, L.SWITCH_H, choose("horizontal"))
    horizontal:SetPoint("RIGHT", vertical, "LEFT", 1, 0)  -- the borders overlap: one switch
    switches[kind.key] = { horizontal = horizontal, vertical = vertical }

    -- Two anchors bound the name between the icon and the switch.
    local name = Look.Text(r, Look.WORDS, 13, "text")
    name:SetPoint("LEFT", icon, "RIGHT", 12, 0)
    name:SetPoint("RIGHT", horizontal, "LEFT", -8, 0)
    name:SetText(kind.label)

    if i > 1 then
        local rule = Look.Texture(r, "BORDER", Look.COLOUR.divider)
        rule:SetHeight(1)
        rule:SetPoint("TOPLEFT", r, "TOPLEFT", L.ICON_X, 0)  -- clear of the bracket's gutter
        rule:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, 0)
    end
end

-- A gold bracket down the gutter joining a kind's row to the rows it combines
-- (Food & Drink to Food and Drink): a spine from the first row's middle to the
-- last's, and a tick into each row's icon. Plain colour textures, sharp at any size.
local function bracket(well, kind, at)
    local Look = ns.Look
    local rows = { at }
    for _, key in ipairs(kind.joins) do
        for i, other in ipairs(ns.Kinds.LIST) do
            if other.key == key then
                rows[#rows + 1] = i
            end
        end
    end
    local function middle(i)
        return -(L.WELL_PAD + (i - 1) * L.ROW + L.ROW / 2)
    end
    local top, bottom = math.min(unpack(rows)), math.max(unpack(rows))
    local spine = Look.Texture(well, "ARTWORK", Look.COLOUR.gold)
    spine:SetWidth(L.BRACE)
    spine:SetPoint("TOPLEFT", well, "TOPLEFT", L.BRACE_X, middle(top) + L.BRACE / 2)
    spine:SetPoint("BOTTOMLEFT", well, "TOPLEFT", L.BRACE_X, middle(bottom) - L.BRACE / 2)
    for _, i in ipairs(rows) do
        local tick = Look.Texture(well, "ARTWORK", Look.COLOUR.gold)
        tick:SetHeight(L.BRACE)
        tick:SetPoint("LEFT", well, "TOPLEFT", L.BRACE_X, middle(i))
        tick:SetWidth(L.WELL_PAD + L.ICON_X - L.BRACE_X - 3)  -- stops just short of the icon
    end
end

local function make(core)
    local Look = ns.Look
    frame = CreateFrame("Frame", Window.NAME, UIParent)
    frame:SetSize(Window.WIDTH, Window.HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    Look.Texture(frame, "BACKGROUND", Look.COLOUR.window):SetAllPoints(frame)
    Look.Outline(frame, Look.COLOUR.line)
    local topEdge = Look.Texture(frame, "ARTWORK", Look.COLOUR.gold)
    topEdge:SetPoint("TOPLEFT", frame, "TOPLEFT")
    topEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    topEdge:SetHeight(L.TOP_EDGE)
    buildHeader(core)

    local well = CreateFrame("Frame", nil, frame)
    well:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -(L.TOP_EDGE + L.HEADER + L.PAD))
    well:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, -(L.TOP_EDGE + L.HEADER + L.PAD))
    well:SetHeight(#ns.Kinds.LIST * L.ROW + 2 * L.WELL_PAD)
    Look.Texture(well, "BACKGROUND", Look.COLOUR.inset):SetAllPoints(well)
    Look.Outline(well, Look.COLOUR.line)
    for i, kind in ipairs(ns.Kinds.LIST) do
        row(core, well, kind, i)
        if kind.joins then
            bracket(well, kind, i)
        end
    end

    local hint = Look.Text(frame, Look.WORDS, 10, "dim")
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", L.PAD, 11)
    hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.PAD, 11)
    hint:SetText("Drag an icon onto an action bar to place its button.")

    frame:ClearAllPoints()
    local saved = core.Window()
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        frame:SetPoint(Window.HOME[1], UIParent, Window.HOME[2], Window.HOME[3], Window.HOME[4])
    end
    frame:Hide()
    table.insert(UISpecialFrames, Window.NAME)  -- Escape closes it
end

-- Lights each kind's current layout gold on its switch.
function Window.Refresh(core)
    for key, switch in pairs(switches) do
        local layout = core.Layout(key)
        ns.Look.Style(switch.horizontal, layout == "horizontal" and "gold" or "quiet")
        ns.Look.Style(switch.vertical, layout == "vertical" and "gold" or "quiet")
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
