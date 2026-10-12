return function(h, loaded)
    local Kinds = loaded.ns.Kinds
    local names = { food = "Food", drink = "Drink" }

    local function item(subclassID, spellName)
        return { itemID = 1, name = "x", classID = 0, subclassID = subclassID, spellName = spellName }
    end

    local function matching(it, given)
        if given == nil then
            given = names
        end
        return table.concat(Kinds.Matching(it, given), ",")
    end

    h.describe("Kinds.LIST", function()
        h.it("seven kinds in the window's order", function()
            h.eq(table.concat(Kinds.KEYS, ","), "professions,food,drink,potions,elixirs,bandages,scrolls")
            h.eq(#Kinds.LIST, 7)
        end)
        h.it("each toggle is GoblinFlyout plus the label, and every toggle is unique", function()
            h.eq(Kinds.ByKey("potions").toggle, "GoblinFlyoutPotions")
            h.eq(Kinds.ByKey("professions").toggle, "GoblinFlyoutProfessions")
            local seen = {}
            for _, kind in ipairs(Kinds.LIST) do
                h.falsy(seen[kind.toggle], "duplicate toggle " .. kind.toggle)
                seen[kind.toggle] = true
            end
        end)
        h.it("potions, elixirs, bandages and scrolls open in combat; the rest don't", function()
            local secure = {}
            for _, kind in ipairs(Kinds.LIST) do
                if kind.secure then
                    secure[#secure + 1] = kind.key
                end
            end
            h.eq(table.concat(secure, ","), "potions,elixirs,bandages,scrolls")
        end)
        h.it("every bag kind has a filter; professions has none", function()
            for _, kind in ipairs(Kinds.LIST) do
                if kind.source == "bags" then
                    h.eq(type(kind.accepts), "function", kind.key)
                else
                    h.eq(kind.accepts, nil, kind.key)
                end
            end
            h.eq(Kinds.ByKey("professions").source, "professions")
        end)
        h.it("each kind says what's missing in plain words", function()
            h.eq(Kinds.ByKey("potions").empty, "No potions in your bags.")
            h.eq(Kinds.ByKey("food").empty, "No food in your bags.")
            h.eq(Kinds.ByKey("professions").empty, "No crafting professions known.")
        end)
        h.it("an unknown or missing key is no kind", function()
            h.eq(Kinds.ByKey("mounts"), nil)
            h.eq(Kinds.ByKey(nil), nil)
        end)
    end)

    h.describe("Kinds filters", function()
        h.it("potions take subclass 1", function()
            h.eq(matching(item(1, "Healing Potion")), "potions")
        end)
        h.it("elixirs take elixirs and flasks", function()
            h.eq(matching(item(2, "Elixir of Minor Defense")), "elixirs")
            h.eq(matching(item(3, "Flask of the Titans")), "elixirs")
        end)
        h.it("bandages take 7, scrolls take 4", function()
            h.eq(matching(item(7, "First Aid")), "bandages")
            h.eq(matching(item(4, "Armor")), "scrolls")
        end)
        h.it("a Food spell is food only; a Drink spell is drink only", function()
            h.eq(matching(item(5, "Food")), "food")
            h.eq(matching(item(5, "Drink")), "drink")
        end)
        h.it("neither (Refreshment, or no spell) goes on both", function()
            h.eq(matching(item(5, "Refreshment")), "food,drink")
            h.eq(matching(item(5, nil)), "food,drink")
        end)
        h.it("with no spell names from the client, every food and drink goes on both", function()
            h.eq(matching(item(5, "Food"), {}), "food,drink")
            h.eq(table.concat(Kinds.Matching(item(5, "Drink"), nil), ","), "food,drink")
        end)
        h.it("non-consumables, other subclasses and junk match nothing", function()
            h.eq(matching({ itemID = 1, name = "x", classID = 2, subclassID = 1 }), "")
            h.eq(matching(item(6, "Sharpen Blade")), "")
            h.eq(matching(item(0, "Use")), "")
            h.eq(matching("junk"), "")
            h.eq(matching(nil), "")
        end)
    end)
end
