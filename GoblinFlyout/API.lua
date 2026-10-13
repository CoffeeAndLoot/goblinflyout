local _, ns = ...

-- The ONLY file that calls Blizzard game APIs. Everything is defensive: a
-- missing API or an odd return means "no answer", never an error. Every
-- Blizzard call goes through attempt(), which pcalls it and remembers the
-- message under the call's name so /gf probe can say why a call went quiet.
local API = {}
ns.API = API

local errors = {}

local function finish(name, ok, ...)
    if ok then
        return ...
    end
    errors[name] = tostring((...))
    return nil
end

local function attempt(name, fn, ...)
    return finish(name, pcall(fn, ...))
end

-- name -> message for every call that has thrown since login.
function API.Errors()
    local copy = {}
    for name, message in pairs(errors) do
        copy[name] = message
    end
    return copy
end

function API.InCombat()
    if not InCombatLockdown then
        return false
    end
    return attempt("InCombatLockdown", InCombatLockdown) and true or false
end

-- ---- professions ----

local MAX_SPELLS = 10  -- a profession lists one to three spells; this only bounds a junk count

local function spellBank()
    return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
end

-- Enum.SpellBookItemType.Spell (1 in SpellBookConstantsDocumentation).
local function spellItemType()
    return Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
end

-- Whether casting the spell opens a crafting window: the check Blizzard's
-- Camelot profession tabs make (Blizzard_Professions\Camelot\
-- Blizzard_ProfessionsFrame.lua RefreshRightTab). nil when unknown.
local function opensCraftingUI(spellID)
    if not (C_TradeSkillUI and C_TradeSkillUI.CanTradeSkillShowCraftingUI) then
        return nil
    end
    local canShow = attempt("CanTradeSkillShowCraftingUI", C_TradeSkillUI.CanTradeSkillShowCraftingUI, spellID)
    if canShow == nil then
        return nil
    end
    return canShow and true or false
end

-- One profession as Professions.lua takes it, or nil.
local function rawProfession(index)
    local name, icon, rank, maxRank, numSpells, spellOffset, skillLine =
        attempt("GetProfessionInfo", GetProfessionInfo, index)
    if type(name) ~= "string" then
        return nil
    end
    local raw = { name = name, icon = icon, rank = rank, maxRank = maxRank, skillLine = skillLine,
        numSpells = numSpells, spells = {} }
    if type(numSpells) ~= "number" or type(spellOffset) ~= "number" then
        return raw
    end
    for i = 1, math.min(numSpells, MAX_SPELLS) do
        local info = attempt("GetSpellBookItemInfo", C_SpellBook.GetSpellBookItemInfo, spellOffset + i, spellBank())
        -- spellID only: actionID can be a flyout's ID (SpellBookDocumentation).
        if type(info) == "table" and type(info.spellID) == "number" then
            raw.spells[#raw.spells + 1] = {
                spellID = info.spellID, name = info.name, icon = info.iconID,
                isPassive = info.isPassive and true or false,
                isSpell = info.itemType == spellItemType(),
                craftingUI = opensCraftingUI(info.spellID),
            }
        end
    end
    return raw
end

-- The known professions in Blizzard's tab order (Professions.Indices): on
-- Camelot GetProfessions() returns prof1, prof2, firstAid, fishing, cooking.
-- Which of them get an entry is Professions.Pick's call, as it is the tabs'.
function API.RawProfessions()
    if not (GetProfessions and GetProfessionInfo and C_SpellBook and C_SpellBook.GetSpellBookItemInfo) then
        return {}
    end
    local raws = {}
    for _, index in ipairs(ns.Professions.Indices(attempt("GetProfessions", GetProfessions))) do
        local raw = rawProfession(index)
        if raw then
            raws[#raws + 1] = raw
        end
    end
    return raws
end

-- ---- action slots ----

-- Blizzard's own list (Blizzard_ActionBar\Shared\ActionButtonUtil.lua), copied
-- in case the table is missing.
local BAR_BUTTON_NAMES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
    "MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local BUTTONS_PER_BAR = 12

-- Every visible stock action button whose slot holds the macro at macroIndex.
function API.MacroButtons(macroIndex)
    local found = {}
    if type(macroIndex) ~= "number" or not GetActionInfo then
        return found
    end
    local names = BAR_BUTTON_NAMES
    if ActionButtonUtil and type(ActionButtonUtil.ActionBarButtonNames) == "table" then
        names = ActionButtonUtil.ActionBarButtonNames
    end
    for _, prefix in ipairs(names) do
        for i = 1, BUTTONS_PER_BAR do
            local button = _G[prefix .. i]
            if button and type(button.action) == "number" and button:IsVisible() then
                local kind, id = attempt("GetActionInfo", GetActionInfo, button.action)
                if kind == "macro" and id == macroIndex then
                    found[#found + 1] = button
                end
            end
        end
    end
    return found
end

-- ---- macros ----

-- The first account macro whose body passes test(body), or nil.
function API.FindMacro(test)
    if not (GetNumMacros and GetMacroInfo) then
        return nil
    end
    local numAccount = attempt("GetNumMacros", GetNumMacros)
    if type(numAccount) ~= "number" then
        return nil
    end
    for i = 1, numAccount do
        local _, _, body = attempt("GetMacroInfo", GetMacroInfo, i)
        if test(body) then
            return i
        end
    end
    return nil
end

local ACCOUNT_MACRO_LIMIT = 120  -- MacroConstantsDocumentation's value, if the table is missing

-- The account macro cap: Constants.MacroConsts, as Blizzard's macro UI reads it.
local function accountMacroLimit()
    local consts = Constants and Constants.MacroConsts
    local limit = consts and consts.MAX_ACCOUNT_MACROS
    return type(limit) == "number" and limit or ACCOUNT_MACRO_LIMIT
end

function API.AccountMacrosFull()
    local numAccount = GetNumMacros and attempt("GetNumMacros", GetNumMacros)
    if type(numAccount) ~= "number" then
        return false
    end
    return numAccount >= accountMacroLimit()
end

-- Makes an account-wide macro; its index, or nil.
function API.CreateMacro(name, icon, body)
    if not CreateMacro then
        return nil
    end
    local index = attempt("CreateMacro", CreateMacro, name, icon, body, false)
    return type(index) == "number" and index or nil
end

function API.PickupMacro(index)
    if PickupMacro then
        attempt("PickupMacro", PickupMacro, index)
    end
end

-- The name of the account macro at index, or nil.
function API.MacroName(index)
    if not GetMacroInfo then
        return nil
    end
    local name = attempt("GetMacroInfo", GetMacroInfo, index)
    return type(name) == "string" and name or nil
end

-- The icon (a file ID or a path) of the account macro at index, or nil.
function API.MacroIcon(index)
    if not GetMacroInfo then
        return nil
    end
    local _, icon = attempt("GetMacroInfo", GetMacroInfo, index)
    if type(icon) == "number" or type(icon) == "string" then
        return icon
    end
    return nil
end

-- Opens Blizzard's macro window (Esc > Macros) on the account macro at index,
-- with its "Change Name/Icon" picker open, as if the player had clicked it:
-- the General tab (macroBase 0, so the index is the macro's own), the macro
-- selected, then the Edit button (Blizzard_MacroUI.lua). Not protected.
function API.OpenMacroEditor(index)
    if not ShowMacroFrame then
        return
    end
    attempt("ShowMacroFrame", ShowMacroFrame)
    if not (MacroFrame and MacroFrame.ChangeTab and MacroFrame.SelectMacro) then
        return
    end
    attempt("MacroFrame:ChangeTab", MacroFrame.ChangeTab, MacroFrame, 1)
    attempt("MacroFrame:SelectMacro", MacroFrame.SelectMacro, MacroFrame, index, true)
    if MacroEditButton_OnClick and MacroEditButton then
        attempt("MacroEditButton_OnClick", MacroEditButton_OnClick, MacroEditButton)
    end
end

-- Renames a macro. A nil icon and body keep theirs, as Blizzard's macro UI
-- relies on (Blizzard_MacroUI.lua EditMacro(actualIndex, nil, nil, body)).
function API.RenameMacro(index, name)
    if EditMacro then
        attempt("EditMacro", EditMacro, index, name, nil, nil)
    end
end

-- ---- bags and items ----

-- The backpack and the four bags: Enum.BagIndex.Backpack (0) to Bag_4 (4).
local BAGS = { 0, 1, 2, 3, 4 }

-- One raw item per occupied bag slot, as Kinds.lua and Items.lua take them:
-- { itemID, name, icon, count, classID, subclassID, itemLevel, minLevel, spellName }.
-- An item the client hasn't cached yet comes back without a name.
function API.BagItems()
    local items = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo
        and C_Item and C_Item.GetItemInfo) then
        return items
    end
    for _, bag in ipairs(BAGS) do
        local slots = attempt("GetContainerNumSlots", C_Container.GetContainerNumSlots, bag)
        for slot = 1, type(slots) == "number" and slots or 0 do
            local info = attempt("GetContainerItemInfo", C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and type(info.itemID) == "number" then
                local name, _, _, itemLevel, minLevel, _, _, _, _, icon, _, classID, subclassID =
                    attempt("GetItemInfo", C_Item.GetItemInfo, info.itemID)
                local spellName
                if C_Item.GetItemSpell then
                    spellName = attempt("GetItemSpell", C_Item.GetItemSpell, info.itemID)
                end
                items[#items + 1] = {
                    itemID = info.itemID, name = name, icon = icon or info.iconFileID, count = info.stackCount,
                    classID = classID, subclassID = subclassID, itemLevel = itemLevel, minLevel = minLevel,
                    spellName = spellName,
                }
            end
        end
    end
    return items
end

local FOOD_SPELL, DRINK_SPELL = 433, 430  -- the spells food and drink cast (seen in game 2026-10-12)

-- The client's own names for the Food and Drink spells, so food and drink are
-- told apart in any locale. {} when the client can't say.
function API.FoodDrinkNames()
    if not (C_Spell and C_Spell.GetSpellName) then
        return {}
    end
    return {
        food = attempt("GetSpellName", C_Spell.GetSpellName, FOOD_SPELL),
        drink = attempt("GetSpellName", C_Spell.GetSpellName, DRINK_SPELL),
    }
end

-- How many of the item are in the bags; 0 when unknown.
function API.ItemCount(itemID)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    local count = attempt("GetItemCount", C_Item.GetItemCount, itemID)
    return type(count) == "number" and count or 0
end

-- start, duration, enable for the item's cooldown, or nil.
function API.ItemCooldown(itemID)
    if not (C_Container and C_Container.GetItemCooldown) then
        return nil
    end
    return attempt("GetItemCooldown", C_Container.GetItemCooldown, itemID)
end

-- start, duration, enable for a spell's cooldown (C_Spell.GetSpellCooldown's
-- SpellCooldownInfo), or nil.
function API.SpellCooldown(spellID)
    if not (C_Spell and C_Spell.GetSpellCooldown) then
        return nil
    end
    local info = attempt("GetSpellCooldown", C_Spell.GetSpellCooldown, spellID)
    if type(info) ~= "table" then
        return nil
    end
    return info.startTime, info.duration, info.isEnabled
end

-- { [spellID] = { name, icon } } for the spells in ids the player knows.
function API.KnownSpells(ids)
    local known = {}
    if not (C_SpellBook and C_SpellBook.IsSpellKnown and C_Spell and C_Spell.GetSpellName) then
        return known
    end
    for _, id in ipairs(ids) do
        if attempt("IsSpellKnown", C_SpellBook.IsSpellKnown, id) then
            local icon = C_Spell.GetSpellTexture and attempt("GetSpellTexture", C_Spell.GetSpellTexture, id)
            known[id] = { name = attempt("GetSpellName", C_Spell.GetSpellName, id), icon = icon }
        end
    end
    return known
end

-- { [itemID] = { name, icon, count } } for the items in ids in the bags. An
-- item the client hasn't cached yet comes back without a name.
function API.Carried(ids)
    local carried = {}
    if not (C_Item and C_Item.GetItemInfo) then
        return carried
    end
    for _, id in ipairs(ids) do
        local count = API.ItemCount(id)
        if count > 0 then
            local name, _, _, _, _, _, _, _, _, icon = attempt("GetItemInfo", C_Item.GetItemInfo, id)
            carried[id] = { name = name, icon = icon, count = count }
        end
    end
    return carried
end

-- Whether secure snippets run on this build (the 69913 bug left
-- loadstring_untainted nil and broke them all). Out of combat only; called
-- once, at setup.
function API.SnippetsWork()
    if not (CreateFrame and SecureHandlerExecute) then
        return false
    end
    local frame = attempt("CreateFrame", CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    if not frame then
        return false
    end
    attempt("SecureHandlerExecute", SecureHandlerExecute, frame, "self:SetAttribute('goblinflyout', 1)")
    return frame:GetAttribute("goblinflyout") == 1
end

-- ---- screen ----

-- Physical pixels per UI unit at scale 1 (the UI is 768 units tall), so a
-- glyph picks a copy that is sharp from 1080p to 4K; nil when unknown.
function API.ScreenPixelsPerUnit()
    if not GetPhysicalScreenSize then
        return nil
    end
    local _, height = attempt("GetPhysicalScreenSize", GetPhysicalScreenSize)
    if type(height) ~= "number" or height <= 0 then
        return nil
    end
    return height / 768
end

-- The cursor's x, y in screen units at scale 1, or nil.
function API.CursorPosition()
    if not GetCursorPosition then
        return nil
    end
    return attempt("GetCursorPosition", GetCursorPosition)
end

-- ---- events ----

local eventFrame
local handlers = {}

-- fn(event, ...) for each name. An unknown name is a hard error in the
-- client, so each registration is pcalled and a failure is kept for the probe.
function API.OnEvents(names, fn)
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            for _, handler in ipairs(handlers[event] or {}) do
                handler(event, ...)
            end
        end)
    end
    for _, name in ipairs(names) do
        local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, name)
        if ok then
            handlers[name] = handlers[name] or {}
            table.insert(handlers[name], fn)
        else
            errors["RegisterEvent " .. name] = tostring(err)
        end
    end
end

return API
