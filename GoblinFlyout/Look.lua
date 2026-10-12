local _, ns = ...

-- The Goblin look, from GoblinQuest's Look.lua (its clean-look palette, one
-- colour per job; the game's two fonts; plain pieces). Used by the window,
-- the options page and the minimap button. No Blizzard templates, so a
-- template renamed by a beta patch can't break them. RGB and File are pure;
-- the rest makes textures and frames only when called.
local Look = {}
ns.Look = Look

local function hex(r, g, b) return { r / 255, g / 255, b / 255 } end

Look.COLOUR = {
    inset = hex(0x0F, 0x10, 0x12),     -- wells: the list of kinds
    window = hex(0x16, 0x17, 0x1A),    -- every window
    raised = hex(0x22, 0x25, 0x2A),    -- buttons, a hovered row
    divider = hex(0x26, 0x29, 0x2E),   -- rules inside a window
    line = hex(0x33, 0x36, 0x3C),      -- window and control borders
    dim = hex(0x9A, 0x94, 0x88),       -- labels, the tagline
    text = hex(0xEC, 0xE6, 0xD8),      -- everything you read
    gold = hex(0xD6, 0xAA, 0x4E),      -- the accent
    ink = hex(0x17, 0x14, 0x0D),       -- words on gold
}
Look.WORDS = "Fonts\\FRIZQT__.TTF"
Look.NUMBERS = "Fonts\\ARIALN.TTF"
Look.BORDER = 1
Look.ICONS = "Interface\\AddOns\\GoblinFlyout\\Media\\icons\\"
Look.COPIES = { 32, 64, 128 }  -- every glyph, in pixels
Look.FALLBACK = 64             -- no screen size from the client

function Look.RGB(name)
    local c = Look.COLOUR[name] or Look.COLOUR.dim
    return c[1], c[2], c[3]
end

-- The copy of a glyph drawn `pixels` wide: the smallest at least that big, so
-- the game only ever shrinks one (by less than 2x), or the largest there is.
function Look.File(name, pixels)
    local pick = Look.FALLBACK
    if type(pixels) == "number" and pixels == pixels and pixels > 0 then
        pick = Look.COPIES[#Look.COPIES]
        for _, size in ipairs(Look.COPIES) do
            if size >= pixels then
                pick = size
                break
            end
        end
    end
    return Look.ICONS .. name .. "-" .. pick
end

-- How many physical pixels `units` UI units take in this frame; nil when the
-- client gives no screen size.
function Look.Pixels(frame, units)
    local perUnit = ns.API.ScreenPixelsPerUnit()
    if not perUnit then
        return nil
    end
    return units * frame:GetEffectiveScale() * perUnit
end

function Look.Texture(parent, layer, colour, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(colour[1], colour[2], colour[3], a or 1)
    return t
end

-- A one-line, left-justified FontString in a face, size and palette colour.
-- A face that will not load falls back to the client's small font: a missing
-- file costs looks, never words. The flags are required by the client.
function Look.Text(parent, face, size, colour)
    local s = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s:SetJustifyH("LEFT")
    s:SetWordWrap(false)
    if not s:SetFont(face, size, "") then
        s:SetFontObject("GameFontHighlightSmall")
    end
    s:SetTextColor(Look.RGB(colour))
    return s
end

-- A one-pixel outline drawn as four strips inside the frame.
function Look.Outline(frame, colour, layer)
    local sides = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
    local strips = {}
    for i, side in ipairs(sides) do
        local t = Look.Texture(frame, layer or "BORDER", colour)
        t:SetPoint(side[1], frame, side[1])
        t:SetPoint(side[2], frame, side[2])
        if i <= 2 then
            t:SetHeight(Look.BORDER)
        else
            t:SetWidth(Look.BORDER)
        end
        strips[i] = t
    end
    return strips
end

-- Button styles: fill, border and words.
Look.BUTTON = {
    raised = { fill = "raised", edge = "line", text = "text" },
    quiet = { fill = "window", edge = "line", text = "dim" },
    gold = { fill = "gold", edge = "gold", text = "ink" },
}

function Look.Style(b, style)
    local s = Look.BUTTON[style] or Look.BUTTON.raised
    b.fill:SetColorTexture(Look.RGB(s.fill))
    for _, t in ipairs(b.edges) do
        t:SetColorTexture(Look.RGB(s.edge))
    end
    b.label:SetTextColor(Look.RGB(s.text))
end

-- A flat button: a fill, an outline and one centred label.
function Look.Button(parent, text, width, height, onClick, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.fill = Look.Texture(b, "BACKGROUND", Look.COLOUR.raised)
    b.fill:SetAllPoints(b)
    b.edges = Look.Outline(b, Look.COLOUR.line)
    b.label = Look.Text(b, Look.WORDS, 11, "text")
    b.label:SetJustifyH("CENTER")
    b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.label:SetText(text)
    Look.Style(b, style)
    b:SetScript("OnClick", onClick)
    return b
end

-- A square outlined button holding a white glyph tinted dim, or fallbackText
-- when the file will not load (a new file before a full client restart).
function Look.IconButton(parent, name, size, onClick, fallbackText)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    Look.Outline(b, Look.COLOUR.line)
    local glyph = math.floor(size / 2)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(glyph, glyph)
    icon:SetPoint("CENTER", b, "CENTER")
    if icon:SetTexture(Look.File(name, Look.Pixels(b, glyph))) then
        icon:SetVertexColor(Look.RGB("dim"))
    else
        icon:Hide()
        local t = Look.Text(b, Look.WORDS, 11, "dim")
        t:SetJustifyH("CENTER")
        t:SetPoint("LEFT", b, "LEFT")
        t:SetPoint("RIGHT", b, "RIGHT")
        t:SetText(fallbackText or "")
    end
    b:SetScript("OnClick", onClick)
    return b
end

return Look
