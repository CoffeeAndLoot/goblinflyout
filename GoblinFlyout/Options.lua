local _, ns = ...

-- The settings (spec 2026-10-12-goblin-flyout-design.md): the SavedVariable's
-- shape, and a stub page in Blizzard's options (Esc > Options > AddOns >
-- Goblin Flyout) that opens our own window. Init and Other are pure; Register
-- uses Blizzard's Settings UI only when called, so test/run.lua loads this file.
local Options = {}
ns.Options = Options

Options.NAME = "Goblin Flyout"
Options.LAYOUTS = { "horizontal", "vertical" }
Options.LABELS = { horizontal = "Horizontal", vertical = "Vertical" }
Options.DEFAULT_LAYOUT = "horizontal"
Options.DEFAULT_ANGLE = 225  -- degrees round the minimap: bottom-left

-- The SavedVariable with every field valid:
-- { layouts = { <kind key> = layout }, minimap = { angle }, window = { point, x, y } | nil }.
-- Keeps the given table, so writes to it are saved.
function Options.Init(db)
    if type(db) ~= "table" then
        db = {}
    end
    local saved = type(db.layouts) == "table" and db.layouts or {}
    local layouts = {}
    for _, kind in ipairs(ns.Kinds.LIST) do
        local layout = saved[kind.key]
        layouts[kind.key] = (layout ~= nil and Options.LABELS[layout]) and layout or Options.DEFAULT_LAYOUT
    end
    db.layouts = layouts
    if type(db.minimap) ~= "table" or type(db.minimap.angle) ~= "number" then
        db.minimap = { angle = Options.DEFAULT_ANGLE }
    end
    local window = db.window
    if not (type(window) == "table" and type(window.point) == "string"
        and type(window.x) == "number" and type(window.y) == "number") then
        db.window = nil
    end
    return db
end

function Options.Other(layout)
    return layout == "vertical" and "horizontal" or "vertical"
end

local category

-- Adds the page; false when this client's Settings UI lacks a piece.
-- openWindow() shows Goblin Flyout's own window.
function Options.Register(openWindow)
    if category then
        return true
    end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return false
    end
    local panel = CreateFrame("Frame")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    open:SetText("Open " .. Options.NAME)
    open:SetScript("OnClick", function()
        if SettingsPanel and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        openWindow()
    end)
    category = Settings.RegisterCanvasLayoutCategory(panel, Options.NAME)
    Settings.RegisterAddOnCategory(category)
    return true
end

return Options
