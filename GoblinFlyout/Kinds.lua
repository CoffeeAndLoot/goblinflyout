local _, ns = ...

-- The seven kinds (spec 2026-10-12-goblin-flyout-design.md) as data, in the
-- window's order. Pure: no Blizzard globals, so test/run.lua loads it.
--
-- A raw bag item (API.BagItems): { itemID, name, icon, count, classID,
--   subclassID, itemLevel, minLevel, spellName }.
-- names: the client's own names for the Food and Drink spells,
--   { food = "Food", drink = "Drink" } in English; {} when unknown.
local Kinds = {}
ns.Kinds = Kinds

Kinds.CONSUMABLE = 0  -- classID: Enum.ItemClass.Consumable
-- Consumable subclasses as WoW Forever reports them (1, 2, 4 and 5 seen in game 2026-10-12).
Kinds.POTION, Kinds.ELIXIR, Kinds.FLASK, Kinds.SCROLL, Kinds.FOOD_DRINK, Kinds.BANDAGE = 1, 2, 3, 4, 5, 7

local function consumable(item, subclass, other)
    if type(item) ~= "table" or item.classID ~= Kinds.CONSUMABLE then
        return false
    end
    return item.subclassID == subclass or (other ~= nil and item.subclassID == other)
end

-- Food and drink share a subclass; the item's spell tells them apart. An item
-- whose spell is neither (Refreshment, none, or names unknown) goes on both bars.
local function eats(item, mine, theirs)
    if not consumable(item, Kinds.FOOD_DRINK) then
        return false
    end
    local spell = item.spellName
    if spell ~= nil and spell == mine then
        return true
    end
    return not (spell ~= nil and spell == theirs)
end

Kinds.LIST = {
    { key = "professions", label = "Professions", icon = "INV_Misc_Book_09", source = "professions",
      secure = false },
    { key = "food", label = "Food", icon = "INV_Misc_Food_15", source = "bags", secure = false,
      accepts = function(item, names) return eats(item, names.food, names.drink) end },
    { key = "drink", label = "Drink", icon = "INV_Drink_07", source = "bags", secure = false,
      accepts = function(item, names) return eats(item, names.drink, names.food) end },
    { key = "potions", label = "Potions", icon = "INV_Potion_51", source = "bags", secure = true,
      accepts = function(item) return consumable(item, Kinds.POTION) end },
    { key = "elixirs", label = "Elixirs", icon = "INV_Potion_45", source = "bags", secure = true,
      accepts = function(item) return consumable(item, Kinds.ELIXIR, Kinds.FLASK) end },
    { key = "bandages", label = "Bandages", icon = "INV_Misc_Bandage_15", source = "bags", secure = true,
      accepts = function(item) return consumable(item, Kinds.BANDAGE) end },
    { key = "scrolls", label = "Scrolls", icon = "INV_Scroll_03", source = "bags", secure = true,
      accepts = function(item) return consumable(item, Kinds.SCROLL) end },
}

Kinds.KEYS = {}
local byKey = {}
for _, kind in ipairs(Kinds.LIST) do
    kind.toggle = "GoblinFlyout" .. kind.label
    if kind.source == "professions" then
        kind.empty = "No crafting professions known."
    else
        kind.empty = "No " .. string.lower(kind.label) .. " in your bags."
    end
    Kinds.KEYS[#Kinds.KEYS + 1] = kind.key
    byKey[kind.key] = kind
end

function Kinds.ByKey(key)
    if key == nil then
        return nil
    end
    return byKey[key]
end

-- The keys of every bag kind the item lands in, in window order.
function Kinds.Matching(item, names)
    if type(names) ~= "table" then
        names = {}
    end
    local keys = {}
    for _, kind in ipairs(Kinds.LIST) do
        if kind.accepts and kind.accepts(item, names) then
            keys[#keys + 1] = kind.key
        end
    end
    return keys
end

return Kinds
