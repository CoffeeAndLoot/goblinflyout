local _, ns = ...

-- The bar engine (spec 2026-10-12-goblin-flyout-design.md): one bar per kind,
-- Blizzard's own ActionButtonTemplate per entry, opened next to the slot that
-- holds the kind's button. Every bar is a secure handler, so a used entry can
-- hide it in combat too. The toggle sets the style: plain (an insecure
-- button, out of combat only) or secure (a click snippet that also opens it
-- in combat). Entries change only out of combat. Frames are made when Core
-- makes the toggles, so loading this file touches no Blizzard global and
-- test/run.lua can test the pure parts.
local Bar = {}
ns.Bar = Bar

Bar.PADDING = 2  -- gap when the host bar gives none: Blizzard's ActionBar minButtonPadding

-- Later templates win: ActionButtonTemplate brings FlyoutButtonTemplate's
-- OnClick (Blizzard_Flyout\Flyout.xml), so the secure one must come last.
Bar.ENTRY_TEMPLATES = "ActionButtonTemplate, SecureActionButtonTemplate"

-- useOnKeyDown false: an addon's click is treated as a key press, so with
-- ActionButtonUseKeyDown on, a mouse-up would do nothing
-- (SecureActionButton_OnClick in Blizzard_FrameXML\SecureTemplates.lua).
Bar.ENTRY_ATTRIBUTES = { useOnKeyDown = false }

-- The secure action type per kind source; the attribute it reads has the same name.
Bar.ENTRY_TYPE = { professions = "spell", bags = "item" }

-- The toggle's _onclick (SecureHandlerClickTemplate). Hides the bar if open;
-- else hides the other secure bars and shows this one when it has entries.
-- No braces and no "function": the restricted environment refuses them.
Bar.TOGGLE_SNIPPET = [[
local bar = self:GetFrameRef("bar")
if bar:IsShown() then
    bar:Hide()
    return
end
local i = 1
local other = self:GetFrameRef("other" .. i)
while other do
    other:Hide()
    i = i + 1
    other = self:GetFrameRef("other" .. i)
end
if (bar:GetAttribute("entries") or 0) > 0 then
    bar:Show()
end
]]

-- Wrapped round each entry's OnClick, with its bar as header (owner). The
-- post-snippet runs only when the pre-snippet returns a message
-- (Wrapped_Click in SecureHandlers.lua).
Bar.CLOSE_PRE = [[return nil, "close"]]
Bar.CLOSE_POST = [[owner:Hide()]]

-- Where each of n square buttons sits, from the bar's bottom-left, and the
-- bar's width and height. Vertical stacks up; anything else is a row.
function Bar.Positions(n, size, gap, layout)
    local points = {}
    for i = 1, n do
        local step = (i - 1) * (size + gap)
        if layout == "vertical" then
            points[i] = { x = 0, y = step }
        else
            points[i] = { x = step, y = 0 }
        end
    end
    local long = n > 0 and (n * size + (n - 1) * gap) or 0
    if layout == "vertical" then
        return points, size, long
    end
    return points, long, size
end

-- The slot to open from: the first prefer() likes, else the first; nil if none.
function Bar.PickHost(hosts, prefer)
    for _, candidate in ipairs(hosts) do
        if prefer(candidate) then
            return candidate
        end
    end
    return hosts[1]
end

-- The entry's secure action type: its own (a Travel entry is a spell or an
-- item), else its kind's.
function Bar.ActionType(kind, entry)
    return entry.type or Bar.ENTRY_TYPE[kind.source]
end

-- What the entry's secure action gets: a spell ID, or "item:<id>"
-- (SecureCmdItemParse hands it to C_Item.UseItemByName).
function Bar.ActionValue(kind, entry)
    if Bar.ActionType(kind, entry) == "spell" then
        return entry.spellID
    end
    return "item:" .. entry.itemID
end

function Bar.CountText(count)
    if type(count) ~= "number" then
        return ""
    end
    return tostring(count)
end

-- ---- runtime ----

local bars = {}   -- kind key -> { kind, frame, entries, host, secure, toggle }
local order = {}  -- the same bars, in the order they were made

local function inCombat()
    return ns.API.InCombat()
end

local function underMouse(button)
    return button:IsMouseOver()
end

local GOLD = { 1, 0.82, 0 }  -- NORMAL_FONT_COLOR, the tooltip's body color

-- An item or a travel spell shows its own tooltip; a profession its name and
-- skill level, as Blizzard's profession tabs show it.
local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.itemID then
        GameTooltip:SetItemByID(self.itemID)
    elseif self.spellTooltip then
        GameTooltip:SetSpellByID(self.spellTooltip)
    else
        GameTooltip:SetText(self.label)
        if self.skill then
            GameTooltip:AddLine(self.skill, GOLD[1], GOLD[2], GOLD[3])
        end
    end
    GameTooltip:Show()
end

local function onLeave()
    GameTooltip:Hide()
end

-- The Count font string sits in TextOverlayContainer
-- (Blizzard_ActionBar\Mainline\ActionButtonTemplate.xml).
local function countString(button)
    return button.Count or (button.TextOverlayContainer and button.TextOverlayContainer.Count)
end

-- The item's or spell's cooldown sweep (Astral Recall, the Hearthstone).
local function sweep(button)
    if not button.cooldown then
        return
    end
    local start, duration, enable
    if button.itemID then
        start, duration, enable = ns.API.ItemCooldown(button.itemID)
    elseif button.spellID then
        start, duration, enable = ns.API.SpellCooldown(button.spellID)
    end
    if (enable == 1 or enable == true) and type(duration) == "number" and duration > 0 then
        button.cooldown:SetCooldown(start, duration)
    else
        button.cooldown:Clear()
    end
end

-- Count, grey-out at 0, and cooldown sweep: drawn only, so allowed in combat.
local function refresh(bar)
    for _, button in ipairs(bar.entries) do
        if button:IsShown() then
            if button.itemID then
                local count = ns.API.ItemCount(button.itemID)
                local text = countString(button)
                if text then
                    text:SetText(Bar.CountText(count))
                end
                button.icon:SetDesaturated(count == 0)
            end
            sweep(button)
        end
    end
end

local function barFor(kind)
    local bar = bars[kind.key]
    if bar then
        return bar
    end
    local frame = CreateFrame("Frame", kind.toggle .. "Bar", UIParent, "SecureHandlerBaseTemplate")
    frame:Hide()
    frame:SetFrameStrata("DIALOG")  -- the strata Blizzard's SpellFlyout uses
    frame:SetClampedToScreen(true)
    frame:SetAttribute("entries", 0)
    bar = { kind = kind, frame = frame, entries = {} }
    frame:HookScript("OnShow", function()
        refresh(bar)
    end)
    bars[kind.key] = bar
    order[#order + 1] = bar
    return bar
end

local function entry(bar, i)
    if bar.entries[i] then
        return bar.entries[i]
    end
    local button = CreateFrame("CheckButton", bar.frame:GetName() .. "Entry" .. i, bar.frame, Bar.ENTRY_TEMPLATES)
    button:RegisterForClicks("AnyUp")
    for name, value in pairs(Bar.ENTRY_ATTRIBUTES) do
        button:SetAttribute(name, value)
    end
    button:HookScript("OnEnter", onEnter)
    button:HookScript("OnLeave", onLeave)
    button:SetScript("PostClick", function(self)
        self:SetChecked(false)
    end)
    SecureHandlerWrapScript(button, "OnClick", bar.frame, Bar.CLOSE_PRE, Bar.CLOSE_POST)
    bar.entries[i] = button
    return button
end

local function entriesFor(kind)
    if kind.source == "professions" then
        return ns.Professions.Entries(ns.API.RawProfessions())
    elseif kind.source == "travel" then
        local Travel = ns.Travel
        return Travel.Entries(ns.API.KnownSpells(Travel.SpellIDs()), ns.API.Carried(Travel.ItemIDs()))
    end
    return ns.Items.Entries(ns.API.BagItems(), kind, ns.API.FoodDrinkNames())
end

local OTHER = { spell = "item", item = "spell" }

-- Fills, sizes and anchors the bar on bar.host. Out of combat only. The action
-- type is set per entry: a Travel bar mixes the Hearthstone and spells.
local function fill(bar, list, layout)
    for i, item in ipairs(list) do
        local button = entry(bar, i)
        local actionType = Bar.ActionType(bar.kind, item)
        button:SetAttribute("type", actionType)
        button:SetAttribute(actionType, Bar.ActionValue(bar.kind, item))
        button:SetAttribute(OTHER[actionType], nil)
        button.icon:SetTexture(item.icon)
        button.label = item.name
        button.skill = item.skill
        button.itemID = item.itemID
        button.spellID = item.spellID
        -- A profession keeps its own tooltip (Skinning casts Tanning); a travel spell shows the spell's.
        button.spellTooltip = bar.kind.source ~= "professions" and item.spellID or nil
        local text = countString(button)
        if text then
            text:SetText("")
        end
        button:Show()
    end
    for i = #list + 1, #bar.entries do
        bar.entries[i]:Hide()
    end
    local host = bar.host
    local gap = Bar.PADDING
    if host.bar and type(host.bar.buttonPadding) == "number" then
        gap = host.bar.buttonPadding
    end
    local points, width, height = Bar.Positions(#list, bar.entries[1]:GetWidth(), gap, layout)
    for i, point in ipairs(points) do
        bar.entries[i]:ClearAllPoints()
        bar.entries[i]:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", point.x, point.y)
    end
    bar.frame:SetSize(width, height)
    -- Same on-screen size as the host, whatever scale Edit Mode gave its bar.
    bar.frame:SetScale(host:GetEffectiveScale() / UIParent:GetEffectiveScale())
    bar.frame:ClearAllPoints()
    bar.frame:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, gap)
    if bar.frame:IsShown() then
        refresh(bar)
    end
end

-- Rebuilds the bar out of combat on the host prefer() picks. Sets its entries
-- attribute (0 when it can't), which the toggle snippet reads. Returns a
-- message when there is nothing to show.
local function prepare(bar, layout, prefer)
    local kind = bar.kind
    bar.frame:SetAttribute("entries", 0)
    local index = ns.Macro.Index(kind)
    local host = index and Bar.PickHost(ns.API.MacroButtons(index), prefer)
    if not host then
        return "Put the " .. kind.label .. " button on an action bar (/gf " .. kind.key .. ")."
    end
    local list = entriesFor(kind)
    if #list == 0 then
        return kind.empty
    end
    bar.host = host
    fill(bar, list, layout)
    bar.frame:SetAttribute("entries", #list)
    return nil
end

local function lastHost(bar)
    local last = bar.host
    return function(button)
        return button == last
    end
end

-- Hides the kind's bar. Never in combat: it is a protected frame.
function Bar.Close(kind)
    local bar = bars[kind.key]
    if bar and bar.frame:IsShown() and not inCombat() then
        bar.frame:Hide()
    end
end

function Bar.CloseAll()
    if inCombat() then
        return
    end
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() then
            bar.frame:Hide()
        end
    end
end

-- A click anywhere but an open bar or its host closes it, out of combat. The
-- host is spared so its own click toggles the bar closed instead of reopening it.
function Bar.CloseUnlessMouseOver()
    if inCombat() then
        return
    end
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() and not bar.frame:IsMouseOver()
            and not (bar.host and bar.host:IsMouseOver()) then
            bar.frame:Hide()
        end
    end
end

-- Redraws counts and cooldowns on every open bar; fine in combat.
function Bar.Refresh()
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() then
            refresh(bar)
        end
    end
end

-- Escape closes bars only out of combat: Blizzard's Escape handler hiding a
-- protected frame in combat would be blocked.
function Bar.SetEscape(on)
    for _, bar in ipairs(order) do
        local name = bar.frame:GetName()
        local at
        for i, listed in ipairs(UISpecialFrames) do
            if listed == name then
                at = i
            end
        end
        if on and not at then
            table.insert(UISpecialFrames, name)
        elseif not on and at then
            table.remove(UISpecialFrames, at)
        end
    end
end

-- A plain toggle's click: opens or closes the bar, out of combat only.
function Bar.TogglePlain(kind, layout)
    if inCombat() then
        return "Can't open " .. string.lower(kind.label) .. " in combat."
    end
    local bar = barFor(kind)
    if bar.frame:IsShown() then
        bar.frame:Hide()
        return nil
    end
    Bar.CloseAll()
    local message = prepare(bar, layout, underMouse)
    if message then
        return message
    end
    bar.frame:Show()
    return nil
end

-- A secure toggle's PreClick: out of combat, rebuild a closed bar so the
-- snippet that runs next can show it. In combat the snippet works alone.
function Bar.BeforeSecureClick(kind, layout)
    if inCombat() then
        return nil
    end
    local bar = barFor(kind)
    if bar.frame:IsShown() then
        return nil
    end
    Bar.CloseAll()
    return prepare(bar, layout, underMouse)
end

-- PLAYER_REGEN_DISABLED fires just before lockdown, the last moment secure
-- frames may change: plain bars close, every secure bar is rebuilt from the
-- bags on its last host, so it opens in combat with what was there at the pull.
function Bar.EnterCombat(layoutOf)
    Bar.SetEscape(false)
    -- Defensive: if lockdown has already begun, touching secure frames would be
    -- blocked; the bars keep what they had.
    if inCombat() then
        return
    end
    for _, bar in ipairs(order) do
        if bar.secure then
            if prepare(bar, layoutOf(bar.kind.key), lastHost(bar)) and bar.frame:IsShown() then
                bar.frame:Hide()
            end
        elseif bar.frame:IsShown() then
            bar.frame:Hide()
        end
    end
end

-- PLAYER_REGEN_ENABLED: Escape back on; an open bar drops what was used up.
function Bar.LeaveCombat(layoutOf)
    Bar.SetEscape(true)
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() and prepare(bar, layoutOf(bar.kind.key), lastHost(bar)) then
            bar.frame:Hide()
        end
    end
end

-- The hidden button a plain kind's macro /clicks. Up and down are both
-- registered so it answers however the action bar runs the macro.
function Bar.MakePlainToggle(kind, onClick)
    barFor(kind)
    local toggle = CreateFrame("Button", kind.toggle, UIParent)
    toggle:Hide()
    toggle:RegisterForClicks("AnyUp", "AnyDown")
    toggle:SetScript("OnClick", onClick)
end

-- The hidden secure button a combat kind's macro /clicks.
function Bar.MakeSecureToggle(kind, onPreClick)
    local bar = barFor(kind)
    bar.secure = true
    local toggle = CreateFrame("Button", kind.toggle, UIParent, "SecureHandlerClickTemplate")
    toggle:Hide()
    toggle:RegisterForClicks("AnyUp", "AnyDown")
    toggle:SetFrameRef("bar", bar.frame)
    toggle:SetAttribute("_onclick", Bar.TOGGLE_SNIPPET)
    toggle:SetScript("PreClick", onPreClick)
    bar.toggle = toggle
end

-- Lets each secure toggle's snippet hide the other secure bars. Once, after
-- every toggle is made, out of combat.
function Bar.LinkSecure()
    for _, bar in ipairs(order) do
        if bar.toggle then
            local n = 0
            for _, other in ipairs(order) do
                if other.secure and other ~= bar then
                    n = n + 1
                    bar.toggle:SetFrameRef("other" .. n, other.frame)
                end
            end
        end
    end
end

return Bar
