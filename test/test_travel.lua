return function(h, loaded)
    local Travel = loaded.ns.Travel

    local function kinds(entries)
        local out = {}
        for i, entry in ipairs(entries) do
            out[i] = entry.type .. ":" .. tostring(entry.spellID or entry.itemID)
        end
        return table.concat(out, ",")
    end

    local function spell(name)
        return { name = name, icon = 1 }
    end

    h.describe("Travel.Entries", function()
        h.it("a druid with a hearthstone: Hearthstone, then Teleport: Moonglade (as seen in game)", function()
            local entries = Travel.Entries(
                { [18960] = spell("Teleport: Moonglade") },
                { [6948] = { name = "Hearthstone", icon = 134414, count = 1 } })
            h.eq(kinds(entries), "item:6948,spell:18960")
            h.eq(entries[1].name, "Hearthstone")
            h.eq(entries[1].count, 1)
            h.eq(entries[2].name, "Teleport: Moonglade")
        end)
        h.it("a mage: hearthstone, the teleports in city order, then the portals in the same order", function()
            local known = {}
            for _, id in ipairs({ 11420, 3567, 3563, 3566, 11417, 11418 }) do  -- a Horde mage, any order
                known[id] = spell("x")
            end
            h.eq(kinds(Travel.Entries(known, { [6948] = { name = "Hearthstone", count = 1 } })),
                "item:6948,spell:3567,spell:3563,spell:3566,spell:11417,spell:11418,spell:11420")
        end)
        h.it("a shaman's Astral Recall sits with Moonglade, before any teleport", function()
            h.eq(kinds(Travel.Entries({ [556] = spell("Astral Recall"), [3561] = spell("x") }, {})),
                "spell:556,spell:3561")
        end)
        h.it("no hearthstone in the bags, no hearthstone entry; nothing known, an empty bar", function()
            h.eq(kinds(Travel.Entries({ [18960] = spell("Teleport: Moonglade") }, {})), "spell:18960")
            h.eq(#Travel.Entries({}, {}), 0)
        end)
        h.it("an uncached item (no name) and junk input are skipped, never an error", function()
            h.eq(#Travel.Entries({}, { [6948] = { count = 1 } }), 0)
            h.eq(#Travel.Entries(nil, nil), 0)
            h.eq(#Travel.Entries("junk", "junk"), 0)
        end)
    end)

    h.describe("Travel lists", function()
        h.it("asks the client about every spell and item on the list, once each", function()
            h.eq(#Travel.SpellIDs(), 14)
            h.eq(table.concat(Travel.ItemIDs(), ","), "6948")
        end)
    end)
end
