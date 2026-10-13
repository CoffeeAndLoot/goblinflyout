local _, ns = ...

-- Turns the raw professions API.RawProfessions reads into the profession
-- bar's entries (spec 2026-10-12-goblin-flyout-design.md; carried over from ProfessionFlyout). Pure: no
-- Blizzard globals, so test/run.lua loads it.
--
-- A raw profession: { name, icon, rank, maxRank, skillLine, numSpells,
--   spells = { { spellID, name, icon, isPassive, isSpell, craftingUI }, ... } }.
-- An entry: { spellID, name, icon, skill }: the spell its button casts, shown
-- with the profession's name, icon and skill level ("122/150").
local Professions = {}
ns.Professions = Professions

Professions.MINING = 186     -- skillLine: Mining has no window of its own, so it opens Smelting
Professions.SMELTING = 2656  -- spellID of Smelting

-- The spell a profession's entry casts, or nil when it has none. It is the
-- first spell the client says opens a crafting window (craftingUI, from
-- C_TradeSkillUI.CanTradeSkillShowCraftingUI: the check Blizzard's Camelot
-- profession tabs use before casting it). Skinning's window opens from
-- Tanning, not from its own spell, which skins a corpse. Only when the client
-- gives no answer (craftingUI nil) does the name decide: the crafting spell
-- carries the profession's own name in every locale.
function Professions.Pick(raw)
    if type(raw) ~= "table" or type(raw.spells) ~= "table" then
        return nil
    end
    for _, spell in ipairs(raw.spells) do
        -- A passive (Skinning's own spell) or a non-spell item can't be cast.
        if type(spell) == "table" and type(spell.spellID) == "number"
            and not spell.isPassive and spell.isSpell ~= false then
            if raw.skillLine == Professions.MINING then
                if spell.spellID == Professions.SMELTING then
                    return spell
                end
            elseif spell.craftingUI == true then
                return spell
            elseif spell.craftingUI == nil and spell.name ~= nil and spell.name == raw.name then
                return spell
            end
        end
    end
    return nil
end

-- The profession indices GetProfessions() returned, in Blizzard's tab order
-- (Blizzard_Professions\Camelot\Blizzard_ProfessionsFrame.lua RefreshRightTabs:
-- prof1, prof2, then every secondary: First Aid, Fishing, Cooking on Camelot),
-- skipping the ones not learned. Fishing is kept: WoW Forever gives it a
-- crafting window, opened by Bait and Tackle (seen in game 2026-10-12).
function Professions.Indices(...)
    local indices = {}
    for i = 1, select("#", ...) do
        local index = select(i, ...)
        if index ~= nil then
            indices[#indices + 1] = index
        end
    end
    return indices
end

-- "122/150", as the profession book's skill bar reads, or nil without a rank.
local function skillText(rank, maxRank)
    if type(rank) ~= "number" or type(maxRank) ~= "number" then
        return nil
    end
    return rank .. "/" .. maxRank
end

-- Entries for the raw professions, in their order; never nil.
function Professions.Entries(raws)
    local entries = {}
    if type(raws) ~= "table" then
        return entries
    end
    for _, raw in ipairs(raws) do
        local spell = Professions.Pick(raw)
        if spell then
            -- Named and drawn as the profession, as Blizzard's profession tabs are:
            -- Skinning shows as Skinning though it casts Tanning to open its window.
            entries[#entries + 1] = { spellID = spell.spellID, name = raw.name, icon = raw.icon or spell.icon,
                skill = skillText(raw.rank, raw.maxRank) }
        end
    end
    return entries
end

return Professions
