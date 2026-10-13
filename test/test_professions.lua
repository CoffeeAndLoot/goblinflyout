return function(h, loaded)
    local Professions = loaded.ns.Professions

    local function spell(id, name)
        return { spellID = id, name = name, icon = id * 10 }
    end

    h.describe("Professions.Indices", function()
        h.it("Blizzard's tab order: both primaries, then every secondary, Fishing included", function()
            -- GetProfessions() on Camelot: prof1, prof2, firstAid, fishing, cooking (and two more slots).
            h.eq(table.concat(Professions.Indices(7, 9, 5, 4, 3), ","), "7,9,5,4,3")
        end)
        h.it("skips the professions the player hasn't learned, keeping the rest in order", function()
            h.eq(table.concat(Professions.Indices(nil, 9, nil, 4, 3, nil, nil), ","), "9,4,3")
            h.eq(#Professions.Indices(), 0)
        end)
    end)

    h.describe("Professions.Pick", function()
        h.it("Fishing opens its window through Bait and Tackle, never the cast (seen in game)", function()
            local pick = Professions.Pick({ name = "Fishing", skillLine = 356, spells = {
                { spellID = 7620, name = "Fishing", craftingUI = false },
                { spellID = 1278067, name = "Bait and Tackle", craftingUI = true } } })
            h.eq(pick.spellID, 1278067)
        end)
        h.it("picks the spell named after the profession, not Disenchant", function()
            local pick = Professions.Pick({ name = "Enchanting", skillLine = 333,
                spells = { spell(13262, "Disenchant"), spell(7411, "Enchanting") } })
            h.eq(pick.spellID, 7411)
        end)
        h.it("Mining picks Smelting by ID, not Find Minerals", function()
            local pick = Professions.Pick({ name = "Mining", skillLine = 186,
                spells = { spell(2580, "Find Minerals"), spell(2656, "Smelting") } })
            h.eq(pick.spellID, 2656)
        end)
        h.it("Mining without Smelting gives no entry", function()
            h.eq(Professions.Pick({ name = "Mining", skillLine = 186,
                spells = { spell(2580, "Find Minerals") } }), nil)
        end)
        h.it("a passive or non-spell item named after the profession gives no entry (Skinning)", function()
            h.eq(Professions.Pick({ name = "Skinning", skillLine = 393,
                spells = { { spellID = 8613, name = "Skinning", isPassive = true } } }), nil)
            h.eq(Professions.Pick({ name = "Tailoring", skillLine = 197,
                spells = { { spellID = 3908, name = "Tailoring", isSpell = false } } }), nil)
        end)
        h.it("the client's crafting-window answer decides over the name (Skinning opens via Tanning)", function()
            local pick = Professions.Pick({ name = "Skinning", skillLine = 393, spells = {
                { spellID = 1278068, name = "Tanning", craftingUI = true },
                { spellID = 8617, name = "Skinning", craftingUI = false } } })
            h.eq(pick.spellID, 1278068)
            pick = Professions.Pick({ name = "Enchanting", skillLine = 333, spells = {
                { spellID = 13262, name = "Disenchant", craftingUI = false },
                { spellID = 7411, name = "Enchanting", craftingUI = true } } })
            h.eq(pick.spellID, 7411)
        end)
        h.it("a profession whose spells all say no window gets no entry", function()
            h.eq(Professions.Pick({ name = "Herbalism", skillLine = 182, spells = {
                { spellID = 2383, name = "Herbalism", craftingUI = false } } }), nil)
        end)
        h.it("a gathering profession with only a tracking spell gives no entry", function()
            h.eq(Professions.Pick({ name = "Herbalism", skillLine = 182,
                spells = { spell(2383, "Find Herbs") } }), nil)
        end)
        h.it("no spells, missing spells, junk spells and nil give no entry and no error", function()
            h.eq(Professions.Pick({ name = "Tailoring", skillLine = 197, spells = {} }), nil)
            h.eq(Professions.Pick({ name = "Tailoring", skillLine = 197 }), nil)
            h.eq(Professions.Pick({ name = "Tailoring", skillLine = 197,
                spells = { "junk", { name = "Tailoring" }, { spellID = 3908 } } }), nil)
            h.eq(Professions.Pick(nil), nil)
        end)
    end)

    h.describe("Professions.Entries", function()
        h.it("keeps order and skips professions without an entry", function()
            local entries = Professions.Entries({
                { name = "Herbalism", skillLine = 182, spells = { spell(2383, "Find Herbs") } },
                { name = "Mining", skillLine = 186,
                  spells = { spell(2580, "Find Minerals"), spell(2656, "Smelting") } },
                { name = "Cooking", skillLine = 185, spells = { spell(2550, "Cooking") } },
                { name = "First Aid", skillLine = 129, spells = { spell(3273, "First Aid") } },
            })
            h.eq(#entries, 3)
            h.eq(entries[1].spellID, 2656)
            h.eq(entries[2].name, "Cooking")
            h.eq(entries[3].name, "First Aid")
        end)
        h.it("an entry wears its profession's name and icon, and casts the window's spell", function()
            local entries = Professions.Entries({
                { name = "Skinning", skillLine = 393, icon = 134366, spells = {
                    { spellID = 1278068, name = "Tanning", icon = 7000, craftingUI = true },
                    { spellID = 8617, name = "Skinning", icon = 8000, craftingUI = false } } },
                { name = "Mining", skillLine = 186, icon = 136248,
                  spells = { spell(2656, "Smelting") } },
            })
            h.eq(entries[1].name, "Skinning")
            h.eq(entries[1].icon, 134366)
            h.eq(entries[1].spellID, 1278068)
            h.eq(entries[2].name, "Mining")
            h.eq(entries[2].icon, 136248)
            h.eq(entries[2].spellID, 2656)
        end)
        h.it("an entry carries the skill level as rank/max for its tooltip", function()
            local entries = Professions.Entries({
                { name = "Skinning", skillLine = 393, rank = 122, maxRank = 150,
                  spells = { { spellID = 1278068, name = "Tanning", craftingUI = true } } },
            })
            h.eq(entries[1].skill, "122/150")
        end)
        h.it("no skill line when the client gives no rank", function()
            local entries = Professions.Entries({
                { name = "Cooking", skillLine = 185, rank = "junk",
                  spells = { spell(2550, "Cooking") } },
            })
            h.eq(entries[1].skill, nil)
        end)
        h.it("with no profession icon, the spell's icon stands in", function()
            local entries = Professions.Entries({
                { name = "Cooking", skillLine = 185, spells = { spell(2550, "Cooking") } },
            })
            h.eq(entries[1].icon, 25500)
        end)
        h.it("a character with only gathering professions gets no entries", function()
            local entries = Professions.Entries({
                { name = "Herbalism", skillLine = 182, spells = { spell(2383, "Find Herbs") } },
                { name = "Skinning", skillLine = 393, spells = {} },
            })
            h.eq(#entries, 0)
        end)
        h.it("nil or junk gives an empty list", function()
            h.eq(#Professions.Entries(nil), 0)
            h.eq(#Professions.Entries("junk"), 0)
        end)
    end)
end
