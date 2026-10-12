return function(h, loaded)
    local Items, Kinds = loaded.ns.Items, loaded.ns.Kinds
    local potions, food = Kinds.ByKey("potions"), Kinds.ByKey("food")
    local names = { food = "Food", drink = "Drink" }

    local function raw(itemID, name, itemLevel, minLevel, count, subclassID, spellName)
        return { itemID = itemID, name = name, icon = itemID * 10, itemLevel = itemLevel, minLevel = minLevel,
            count = count, classID = 0, subclassID = subclassID or 1, spellName = spellName }
    end

    local function ids(entries)
        local out = {}
        for i, entry in ipairs(entries) do
            out[i] = tostring(entry.itemID)
        end
        return table.concat(out, ",")
    end

    h.describe("Items.Entries", function()
        h.it("best first: the higher tier potion leads (bags as seen in game)", function()
            local entries = Items.Entries({
                raw(118, "Minor Healing Potion", 5, 1, 3),
                raw(858, "Lesser Healing Potion", 13, 3, 2),
                raw(2456, "Minor Rejuvenation Potion", 15, 5, 1),
            }, potions, names)
            h.eq(ids(entries), "2456,858,118")
        end)
        h.it("equal item level falls to required level, then name A to Z", function()
            local entries = Items.Entries({
                raw(1, "Beta", 10, 5, 1), raw(2, "Alpha", 10, 5, 1), raw(3, "Gamma", 10, 7, 1),
            }, potions, names)
            h.eq(ids(entries), "3,2,1")
        end)
        h.it("one potion split over several stacks is one entry with the total", function()
            local entries = Items.Entries({
                raw(118, "Minor Healing Potion", 5, 1, 3), raw(858, "Lesser Healing Potion", 13, 3, 1),
                raw(118, "Minor Healing Potion", 5, 1, 2),
            }, potions, names)
            h.eq(#entries, 2)
            h.eq(entries[2].itemID, 118)
            h.eq(entries[2].count, 5)
        end)
        h.it("keeps only the kind's items", function()
            local bags = { raw(117, "Tough Jerky", 5, 1, 4, 5, "Food"), raw(118, "Minor Healing Potion", 5, 1, 1) }
            h.eq(ids(Items.Entries(bags, potions, names)), "118")
            h.eq(ids(Items.Entries(bags, food, names)), "117")
        end)
        h.it("an entry carries the item's name and icon", function()
            local entry = Items.Entries({ raw(118, "Minor Healing Potion", 5, 1, 1) }, potions, names)[1]
            h.eq(entry.name, "Minor Healing Potion")
            h.eq(entry.icon, 1180)
        end)
        h.it("uncached items (no name) and junk are skipped", function()
            local entries = Items.Entries({
                { itemID = 5, classID = 0, subclassID = 1 }, "junk", { name = "x", classID = 0, subclassID = 1 },
                raw(118, "Minor Healing Potion", 5, 1, 1),
            }, potions, names)
            h.eq(ids(entries), "118")
        end)
        h.it("a missing count counts as one; missing levels count as zero", function()
            local entries = Items.Entries({
                { itemID = 7, name = "Odd Potion", classID = 0, subclassID = 1 },
                raw(118, "Minor Healing Potion", 5, 1, 2),
            }, potions, names)
            h.eq(ids(entries), "118,7")
            h.eq(entries[2].count, 1)
        end)
        h.it("works without spell names", function()
            h.eq(#Items.Entries({ raw(117, "Tough Jerky", 5, 1, 1, 5, "Food") }, food, nil), 1)
        end)
        h.it("nil raws, a kind without a filter, or no kind give an empty list", function()
            h.eq(#Items.Entries(nil, potions, names), 0)
            h.eq(#Items.Entries({ raw(118, "Minor Healing Potion", 5, 1, 1) }, Kinds.ByKey("professions"), names), 0)
            h.eq(#Items.Entries({ raw(118, "Minor Healing Potion", 5, 1, 1) }, nil, names), 0)
        end)
    end)
end
