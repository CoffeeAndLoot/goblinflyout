local _, ns = ...

-- The Travel bar's entries (spec 2026-10-12-goblin-flyout-design.md): the
-- Hearthstone, the trips home a class learns, then the mage's teleports and
-- portals, in a fixed order, keeping only what the player has. Pure: no
-- Blizzard globals, so test/run.lua loads it.
--
-- known:   { [spellID] = { name, icon } } for the spells the player knows (API.KnownSpells)
-- carried: { [itemID] = { name, icon, count } } for the items in the bags (API.Carried)
-- An entry: { type = "item", itemID, name, icon, count } or { type = "spell", spellID, name, icon }.
local Travel = {}
ns.Travel = Travel

-- Classic IDs; WoW Forever kept them (Teleport: Moonglade is 18960, seen in game 2026-10-12).
-- Cities in one order for both rows: Stormwind, Ironforge, Darnassus, Orgrimmar, Undercity, Thunder Bluff.
Travel.ORDER = {
    { item = 6948 },    -- Hearthstone
    { spell = 18960 },  -- Teleport: Moonglade (druid)
    { spell = 556 },    -- Astral Recall (shaman)
    { spell = 3561 }, { spell = 3562 }, { spell = 3565 },     -- mage teleports, self
    { spell = 3567 }, { spell = 3563 }, { spell = 3566 },
    { spell = 10059 }, { spell = 11416 }, { spell = 11419 },  -- mage portals, the group
    { spell = 11417 }, { spell = 11418 }, { spell = 11420 },
}

local function ids(field)
    local out = {}
    for _, step in ipairs(Travel.ORDER) do
        if step[field] then
            out[#out + 1] = step[field]
        end
    end
    return out
end

function Travel.SpellIDs()
    return ids("spell")
end

function Travel.ItemIDs()
    return ids("item")
end

-- The bar's entries, in ORDER; never nil. An item without a name is not cached
-- yet and is skipped until the next rebuild.
function Travel.Entries(known, carried)
    known = type(known) == "table" and known or {}
    carried = type(carried) == "table" and carried or {}
    local entries = {}
    for _, step in ipairs(Travel.ORDER) do
        if step.item then
            local item = carried[step.item]
            if type(item) == "table" and type(item.name) == "string" then
                entries[#entries + 1] = { type = "item", itemID = step.item, name = item.name, icon = item.icon,
                    count = item.count }
            end
        else
            local spell = known[step.spell]
            if type(spell) == "table" then
                entries[#entries + 1] = { type = "spell", spellID = step.spell, name = spell.name, icon = spell.icon }
            end
        end
    end
    return entries
end

return Travel
