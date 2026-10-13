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
        h.it("nine kinds in the window's order, Food & Drink under Drink, Travel last", function()
            h.eq(table.concat(Kinds.KEYS, ","),
                "professions,food,drink,fooddrink,potions,elixirs,bandages,scrolls,travel")
            h.eq(#Kinds.LIST, 9)
        end)
        h.it("Travel opens out of combat only and says so when there's nothing to take", function()
            local travel = Kinds.ByKey("travel")
            h.eq(travel.source, "travel")
            h.falsy(travel.secure)
            h.eq(travel.toggle, "GoblinFlyoutTravel")
            h.eq(travel.empty, "No hearthstone or travel spells.")
        end)
        h.it("each toggle is GoblinFlyout plus the label, and every toggle is unique", function()
            h.eq(Kinds.ByKey("potions").toggle, "GoblinFlyoutPotions")
            h.eq(Kinds.ByKey("professions").toggle, "GoblinFlyoutProfessions")
            h.eq(Kinds.ByKey("fooddrink").toggle, "GoblinFlyoutFoodDrink", "only letters and digits")
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
            h.eq(Kinds.ByKey("fooddrink").empty, "No food or drink in your bags.")
        end)
        h.it("each macro has a short name that fits under an action button, and no two match", function()
            local macros, seen = {}, {}
            for _, kind in ipairs(Kinds.LIST) do
                h.truthy(#kind.macro <= 6, kind.macro .. " is longer than 6")
                h.falsy(seen[kind.macro], "duplicate macro name " .. kind.macro)
                seen[kind.macro] = true
                macros[#macros + 1] = kind.macro
            end
            h.eq(table.concat(macros, ","), "Prof,Food,Drink,Meals,Potion,Elixir,Aid,Scroll,Travel")
        end)
        h.it("Food & Drink joins Food and Drink (the window draws the bracket from this)", function()
            h.eq(table.concat(Kinds.ByKey("fooddrink").joins, ","), "food,drink")
            h.eq(Kinds.ByKey("food").joins, nil)
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
        h.it("a Food spell is food only; a Drink spell is drink only; Food & Drink takes both", function()
            h.eq(matching(item(5, "Food")), "food,fooddrink")
            h.eq(matching(item(5, "Drink")), "drink,fooddrink")
        end)
        h.it("neither (Refreshment, or no spell) goes on both", function()
            h.eq(matching(item(5, "Refreshment")), "food,drink,fooddrink")
            h.eq(matching(item(5, nil)), "food,drink,fooddrink")
        end)
        h.it("with no spell names from the client, every food and drink goes on both", function()
            h.eq(matching(item(5, "Food"), {}), "food,drink,fooddrink")
            h.eq(table.concat(Kinds.Matching(item(5, "Drink"), nil), ","), "food,drink,fooddrink")
        end)
        h.it("on Food & Drink, drink is the second group; food and both-items the first", function()
            local fooddrink = Kinds.ByKey("fooddrink")
            h.eq(fooddrink.group(item(5, "Drink"), names), 2)
            h.eq(fooddrink.group(item(5, "Food"), names), 1)
            h.eq(fooddrink.group(item(5, "Refreshment"), names), 1)
            h.eq(fooddrink.group(item(5, "Drink"), {}), 1, "names unknown: all one group")
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
