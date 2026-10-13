return function(h, loaded)
    local Macro, Kinds = loaded.ns.Macro, loaded.ns.Kinds
    local potions, professions = Kinds.ByKey("potions"), Kinds.ByKey("professions")

    h.describe("Macro.Body", function()
        h.it("a kind's body clicks its toggle", function()
            h.eq(Macro.Body(potions), "/click GoblinFlyoutPotions")
            h.eq(Macro.Body(professions), "/click GoblinFlyoutProfessions")
            h.eq(Macro.Body(Kinds.ByKey("fooddrink")), "/click GoblinFlyoutFoodDrink")
        end)
    end)

    h.describe("Macro.IsOurs", function()
        h.it("our body is ours, even with stray whitespace", function()
            h.truthy(Macro.IsOurs(potions, "/click GoblinFlyoutPotions"))
            h.truthy(Macro.IsOurs(potions, "/click GoblinFlyoutPotions\n"))
            h.truthy(Macro.IsOurs(potions, "  /click GoblinFlyoutPotions  "))
        end)
        h.it("another kind's body is not this kind's", function()
            h.falsy(Macro.IsOurs(potions, "/click GoblinFlyoutElixirs"))
        end)
        h.it("ProfessionFlyout's own macro is never ours", function()
            h.falsy(Macro.IsOurs(professions, "/click ProfessionFlyoutToggle"))
        end)
        h.it("a player's macro, even one with extra lines, is never ours", function()
            h.falsy(Macro.IsOurs(potions, "/use Minor Healing Potion"))
            h.falsy(Macro.IsOurs(potions, "/click GoblinFlyoutPotions\n/say hi"))
            h.falsy(Macro.IsOurs(potions, ""))
            h.falsy(Macro.IsOurs(potions, nil))
            h.falsy(Macro.IsOurs(nil, "/click GoblinFlyoutPotions"))
        end)
    end)

    -- A fake macro book behind ns.API, so Ensure and Tidy run without the client.
    local function book(macros)
        local api = {}
        function api.FindMacro(test)
            for i, m in ipairs(macros) do
                if test(m.body) then
                    return i
                end
            end
        end
        function api.AccountMacrosFull() return false end
        function api.CreateMacro(name, icon, body)
            macros[#macros + 1] = { name = name, icon = icon, body = body }
            return #macros
        end
        function api.MacroName(index) return macros[index] and macros[index].name end
        function api.MacroIcon(index) return macros[index] and macros[index].icon end
        function api.RenameMacro(index, name) macros[index].name = name end
        function api.InCombat() return false end
        function api.OpenMacroEditor(index) api.opened = index end
        return api
    end

    local function with(api, fn)
        local saved = loaded.ns.API
        loaded.ns.API = api
        local ok, err = pcall(fn)
        loaded.ns.API = saved
        assert(ok, err)
    end

    h.describe("Macro.Ensure", function()
        h.it("a new macro gets the kind's short name, so its label fits under the button", function()
            local macros = {}
            with(book(macros), function()
                h.eq(Macro.Ensure(Kinds.ByKey("fooddrink")), 1)
            end)
            h.eq(macros[1].name, "Meals")
            h.eq(macros[1].body, "/click GoblinFlyoutFoodDrink")
        end)
    end)

    h.describe("Macro.Icon", function()
        h.it("shows the icon the player picked in Blizzard's macro window", function()
            local macros = { { name = "Potion", icon = 134400, body = "/click GoblinFlyoutPotions" } }
            with(book(macros), function()
                h.eq(Macro.Icon(potions), 134400)
            end)
        end)
        h.it("a kind with no macro yet, or a macro that won't say, shows its default icon", function()
            local macros = { { name = "Elixir", body = "/click GoblinFlyoutElixirs" } }
            with(book(macros), function()
                h.eq(Macro.Icon(potions), "Interface\\Icons\\INV_Potion_51")
                h.eq(Macro.Icon(Kinds.ByKey("elixirs")), "Interface\\Icons\\INV_Potion_45")
            end)
        end)
    end)

    h.describe("Macro.Edit", function()
        h.it("opens Blizzard's macro window on our macro, making it first if missing", function()
            local macros = { { name = "Mine", body = "/cast Cooking" } }
            local api = book(macros)
            with(api, function()
                h.eq(Macro.Edit(potions), nil)
            end)
            h.eq(api.opened, 2)
            h.eq(macros[2].body, "/click GoblinFlyoutPotions")
        end)
        h.it("refuses in combat and opens nothing", function()
            local api = book({})
            api.InCombat = function() return true end
            with(api, function()
                h.eq(Macro.Edit(potions), "Can't do that in combat.")
            end)
            h.eq(api.opened, nil)
        end)
    end)

    h.describe("Macro.Tidy", function()
        h.it("an older macro named after the label is renamed to the short name, body untouched", function()
            local macros = { { name = "My Macro", body = "/cast Cooking" },
                { name = "Food & Drink", body = "/click GoblinFlyoutFoodDrink" } }
            with(book(macros), function()
                Macro.Tidy(Kinds.ByKey("fooddrink"))
            end)
            h.eq(macros[2].name, "Meals")
            h.eq(macros[2].body, "/click GoblinFlyoutFoodDrink")
            h.eq(macros[2].icon, nil, "renaming never touches the icon the player picked")
            h.eq(macros[1].name, "My Macro", "a player's macro is never touched")
        end)
        h.it("a macro already short, or none made, is left alone", function()
            local renamed = false
            local macros = { { name = "Potion", body = "/click GoblinFlyoutPotions" } }
            local api = book(macros)
            api.RenameMacro = function() renamed = true end
            with(api, function()
                Macro.Tidy(potions)
                Macro.Tidy(Kinds.ByKey("scrolls"))
            end)
            h.falsy(renamed)
        end)
    end)
end
