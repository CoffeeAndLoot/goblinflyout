local _, ns = ...

-- Turns the raw bag items API.BagItems reads into one kind's entries, best
-- first (spec 2026-10-12-goblin-flyout-design.md). Pure: no Blizzard globals,
-- so test/run.lua loads it.
--
-- An entry: { itemID, name, icon, count, itemLevel, minLevel }: one per item
-- ID, its count summed over every stack in the bags.
local Items = {}
ns.Items = Items

local function number(value)
    return type(value) == "number" and value or 0
end

-- Best first: higher item level, then higher required level, then name A to Z.
-- The item ID last, so the order never depends on which bag a stack sits in.
function Items.Better(a, b)
    if a.itemLevel ~= b.itemLevel then
        return a.itemLevel > b.itemLevel
    end
    if a.minLevel ~= b.minLevel then
        return a.minLevel > b.minLevel
    end
    if a.name ~= b.name then
        return a.name < b.name
    end
    return a.itemID < b.itemID
end

-- The kind's entries; never nil. An item without a name is not cached yet and
-- is skipped until the next rebuild.
function Items.Entries(raws, kind, names)
    local entries, byID = {}, {}
    if type(raws) ~= "table" or type(kind) ~= "table" or type(kind.accepts) ~= "function" then
        return entries
    end
    if type(names) ~= "table" then
        names = {}
    end
    for _, raw in ipairs(raws) do
        if type(raw) == "table" and type(raw.itemID) == "number" and type(raw.name) == "string"
            and kind.accepts(raw, names) then
            local count = type(raw.count) == "number" and raw.count or 1
            local entry = byID[raw.itemID]
            if entry then
                entry.count = entry.count + count
            else
                entry = { itemID = raw.itemID, name = raw.name, icon = raw.icon, count = count,
                    itemLevel = number(raw.itemLevel), minLevel = number(raw.minLevel) }
                byID[raw.itemID] = entry
                entries[#entries + 1] = entry
            end
        end
    end
    table.sort(entries, Items.Better)
    return entries
end

return Items
