# Goblin Flyout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW Forever addon whose seven action-bar buttons open flyouts of the player's professions, food, drink, potions, elixirs, bandages and scrolls, best item first, with the four combat kinds usable in combat.

**Architecture:** One generic bar engine (`Bar.lua`) driven by a data table of kinds (`Kinds.lua`). Pure modules (`Kinds`, `Professions`, `Items`, `Options`, `Macro`, pure halves of `Bar` and `MinimapButton`) are unit-tested on the desktop through `lupa`; `API.lua` is the only file that calls Blizzard game APIs. Plain bars open out of combat from an insecure toggle; secure bars open from a `SecureHandlerClickTemplate` snippet and are rebuilt only out of combat (on open and at `PLAYER_REGEN_DISABLED`).

**Tech Stack:** Lua 5.1 (WoW client, interface 16001), Blizzard FrameXML templates, Python `lupa` for tests, luacheck 1.2.0, lua-language-server.

**Spec:** `docs/superpowers/specs/2026-10-12-goblin-flyout-design.md`

## Global Constraints

- Client: WoW Forever, `## Interface: 16001`, game type `camelot`; Blizzard source of truth is `D:\wow-api\1.60.1.70291\Interface\AddOns`. `12.1.5.*` is Retail and never the authority.
- `API.lua` is the only file that calls Blizzard game APIs, each through `attempt()`. UI construction (`CreateFrame`, templates, `Settings`, `SecureHandlerWrapScript`) lives in the UI files that own it.
- Pure modules touch no Blizzard global at file load; `test/run.lua` loads them with `loadfile(path)("GoblinFlyout", ns)`.
- No libraries. Nothing secure is created, changed or shown by insecure code in combat.
- Every file starts `local _, ns = ...` and publishes `ns.<Name>`.
- TOC order: `API, Kinds, Professions, Items, Options, Macro, Bar, Window, MinimapButton, Core`.
- Names: toggle `GoblinFlyout<Label>` (e.g. `GoblinFlyoutPotions`), macro body `/click GoblinFlyout<Label>`, macro name = label, slash `/gf` and `/goblinflyout`, SavedVariable `GoblinFlyoutDB`, chat prefix `|cffffd100Goblin Flyout|r`.
- Sort: item level desc, required level desc, name A–Z (item ID last, for a stable order).
- Calendar version in the TOC only: `2026.10.12`.
- Zero luacheck and zero lua-language-server warnings.
- Commit after each task as `Area: plain sentence`, ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No remote, no push.

## Commands (PowerShell, from `D:\GoblinFlyout`)

Tests (whole suite, about a second; prints `N passed, M failed`, any `FAIL:` lines, then `0` or `1`):

```powershell
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Lint:

```powershell
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinFlyout test --no-color --no-cache
lua-language-server --check D:\GoblinFlyout --checklevel=Warning --check_out_path=$env:TEMP\gf-luals.json
```

luacheck must end `0 warnings / 0 errors`; lua-language-server must report no problems (if it writes the JSON, the file must be `[]` or `{}`).

## Review Focus

1. A snippet body containing `{`, `}` or the word `function` is refused by the restricted environment (`RestrictedExecution.lua` lines 62–70) only when clicked, silently in combat. Expected: snippet text is plain. Pinned by a Bar test (Task 7).
2. `/reload` or login while in combat. Expected: no "action blocked" error; setup waits for `PLAYER_REGEN_ENABLED`, then every button works. Pinned by Core's deferred setup (Task 9) and a checklist line.
3. The same macro in two slots, then combat starts. Expected: the secure bar stays on the slot it last opened from while that slot still holds the macro. Pinned by a `Bar.PickHost` "last host" test (Task 7).
4. One potion split over several stacks or bags. Expected: one entry with the total count. Pinned by an Items test (Task 3).
5. The client gives no Food/Drink spell names (API missing, odd locale). Expected: every subclass-5 item shows on both bars, nothing errors. Pinned by a Kinds test (Task 2).

---

### Task 1: Repo scaffold and Professions carried over

**Files:**
- Create: `CLAUDE.md`, `.luacheckrc`, `.luarc.json`, `test/harness.lua`, `test/run.lua`
- Create: `GoblinFlyout/Professions.lua` (copied from `D:\ProfessionFlyout\ProfessionFlyout\Professions.lua`)
- Test: `test/test_professions.lua` (copied from `D:\ProfessionFlyout\test\test_professions.lua`)
- Modify: `.gitignore` (already has `.remember/` and `.superpowers/`; unchanged)

**Interfaces:**
- Consumes: nothing.
- Produces: `ns.Professions.Pick(raw) -> spell|nil`, `ns.Professions.Entries(raws) -> { {spellID, name, icon, skill}, ... }`, `Professions.MINING = 186`, `Professions.SMELTING = 2656`. Test runner contract: a suite is `return function(h, loaded)` using `h.describe/it/eq/truthy/falsy`; `loaded.ns` is the shared namespace.

- [ ] **Step 1: Copy the harness, Professions and its tests**

```powershell
New-Item -ItemType Directory -Force GoblinFlyout, test | Out-Null
Copy-Item D:\ProfessionFlyout\test\harness.lua test\harness.lua
Copy-Item D:\ProfessionFlyout\test\test_professions.lua test\test_professions.lua
Copy-Item D:\ProfessionFlyout\ProfessionFlyout\Professions.lua GoblinFlyout\Professions.lua
(Get-Content GoblinFlyout\Professions.lua -Raw).Replace('(spec 2026-10-11-profession-flyout-design.md)', '(spec 2026-10-12-goblin-flyout-design.md; carried over from ProfessionFlyout)') | Set-Content GoblinFlyout\Professions.lua -NoNewline
Select-String GoblinFlyout\Professions.lua -Pattern 'spec 2026'
```

Expected: one line showing `spec 2026-10-12-goblin-flyout-design.md; carried over from ProfessionFlyout`.

- [ ] **Step 2: Write `test/run.lua`**

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua, Window.lua and Core.lua touch Blizzard globals, so they are not loaded here.
-- A missing module is a hard failure: a suite that silently skips proves nothing.
local modules = {
    { "Professions", "GoblinFlyout/Professions.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    loaded[name] = assert(loadfile(path))("GoblinFlyout", ns)
end

local suites = {
    "test/test_professions.lua",
}

for i = 1, #suites do
    dofile(suites[i])(harness, loaded)
end

os.exit(harness.run())
```

- [ ] **Step 3: Write `.luacheckrc`** (the full global list for the whole addon, set once)

```lua
std = "lua51"
max_line_length = 120
self = false
globals = {
    "GoblinFlyoutDB", "SLASH_GOBLINFLYOUT1", "SLASH_GOBLINFLYOUT2", "SlashCmdList",
}
read_globals = {
    "print", "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "InCombatLockdown",
    "GetProfessions", "GetProfessionInfo", "C_SpellBook", "C_TradeSkillUI", "Enum",
    "GetActionInfo", "ActionButtonUtil",
    "GetNumMacros", "GetMacroInfo", "CreateMacro", "PickupMacro", "Constants",
    "Settings", "SettingsPanel", "HideUIPanel",
    "C_Container", "C_Item", "C_Spell",
    "SecureHandlerExecute", "SecureHandlerWrapScript",
    "Minimap", "GetCursorPosition", "ButtonFrameTemplate_HidePortrait",
}
```

- [ ] **Step 4: Write `.luarc.json`** (same list)

```json
{
  "runtime.version": "Lua 5.1",
  "workspace.ignoreDir": [".remember", ".superpowers", "docs"],
  "diagnostics.globals": [
    "GoblinFlyoutDB", "SLASH_GOBLINFLYOUT1", "SLASH_GOBLINFLYOUT2", "SlashCmdList",
    "print", "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "InCombatLockdown",
    "GetProfessions", "GetProfessionInfo", "C_SpellBook", "C_TradeSkillUI", "Enum",
    "GetActionInfo", "ActionButtonUtil",
    "GetNumMacros", "GetMacroInfo", "CreateMacro", "PickupMacro", "Constants",
    "Settings", "SettingsPanel", "HideUIPanel",
    "C_Container", "C_Item", "C_Spell",
    "SecureHandlerExecute", "SecureHandlerWrapScript",
    "Minimap", "GetCursorPosition", "ButtonFrameTemplate_HidePortrait"
  ]
}
```

- [ ] **Step 5: Write `CLAUDE.md`**

````markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Goblin Flyout

WoW Forever addon (interface 16001: Classic data on the 12.x engine, game type `camelot`).
Seven macros on stock Blizzard action bars open bars of the player's professions, food, drink,
potions, elixirs, bandages and scrolls. Spec: `docs/superpowers/specs/2026-10-12-goblin-flyout-design.md`
(its Nomenclature section names kind, button, bar, entry, host, toggle, plain/secure, window).
Grown from `D:\ProfessionFlyout`, which stays as it is.

## Rules

- Blizzard source of truth: `D:\wow-api\1.60.1.70291\Interface\AddOns` (the `forever` branch).
  `12.1.5.*` is Retail and never the authority. Never guess an API, event or template name.
- "Verified in source" is not "verified in game". Only the owner runs the client; in-game
  checks live in `docs/manual-test-checklist.md` and every UI change adds an entry. Tick a box
  only for what the owner saw; `[-]` means skipped by choice, with the reason.
- `API.lua` is the only file that calls Blizzard game APIs, each through `attempt()`.
- Pure modules touch no Blizzard global at file load; test/run.lua loads them.
- No libraries. Nothing secure is created, changed or shown by insecure code in combat.
- Snippet text (`Bar.TOGGLE_SNIPPET`, `Bar.CLOSE_PRE`, `Bar.CLOSE_POST`) may not contain `{`, `}`
  or the word `function`: the restricted environment refuses them, silently in combat.
- Adding a file to the TOC needs a full client restart, not `/reload`. Say so.
- Calendar versions (`2026.10.12`, `.2` for a second that day), written only in the TOC.
- Commit after each change: `Area: plain sentence`. Push only when the owner asks (no remote yet).

## How it fits together

TOC load order is `API, Kinds, Professions, Items, Options, Macro, Bar, Window, MinimapButton, Core`.

1. `Kinds.LIST` is the seven kinds as data: key, label, icon, source (`professions` / `bags`),
   `secure` (opens in combat), `accepts(item, names)` filter, plus derived `toggle` and `empty`.
2. `/gf <kind>` or dragging a kind's icon in the window → `Macro.PickUp(kind)` finds the macro
   **by body** (`/click GoblinFlyout<Label>`), creates it if missing, and puts it on the cursor.
3. Pressing the macro `/click`s the kind's toggle:
   - plain (professions, food, drink): an insecure Button → `Bar.TogglePlain`; refuses in combat.
   - secure (potions, elixirs, bandages, scrolls): a `SecureHandlerClickTemplate` Button.
     Its insecure `PreClick` (`Bar.BeforeSecureClick`) rebuilds out of combat; its `_onclick`
     snippet shows or hides the bar, in combat too.
4. Entries are rebuilt out of combat only: on open, at `PLAYER_REGEN_DISABLED` (secure bars, the
   last moment changes are allowed), and at `PLAYER_REGEN_ENABLED` (open bars). Counts and
   cooldowns are drawn only, so they update in combat on `BAG_UPDATE_DELAYED`/`BAG_UPDATE_COOLDOWN`.
5. Every bar is a `SecureHandlerBaseTemplate` frame; each entry's click is wrapped so a used entry
   hides its bar in or out of combat. Escape is on for every bar only out of combat.
6. Core says messages that Bar and Macro return; every handler runs behind `guard(label, ...)`,
   one error per label per session. Setup waits until out of combat.

## Client facts (verified in game, build 1.60.1.70338)

- Secure snippets work (the 69913 `loadstring_untainted` bug was fixed in 70009).
- Consumables (classID 0) carry modern subclasses: 1 Potion, 2 Elixir, 4 Scroll, 5 Food & Drink
  (3 Flask and 7 Bandage by the same table). Food vs drink is the item's spell: Food (433), Drink (430).
- Profession facts carried from ProfessionFlyout: `C_TradeSkillUI.CanTradeSkillShowCraftingUI`
  picks the crafting spell; Mining opens Smelting 2656; Skinning opens via Tanning; entry
  template order `"ActionButtonTemplate, SecureActionButtonTemplate"` with `useOnKeyDown = false`.
- `/gf probe` prints professions, every bag consumable with its subclass, spell and kinds, each
  kind's macro and slot count, whether snippets work, and `attempt()` errors. Ask the owner for
  its output before guessing about client behavior.

## Deploy

The addon folder is junctioned into the client:
`New-Item -ItemType Junction -Path "D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinFlyout" -Target "D:\GoblinFlyout\GoblinFlyout"`

## Commands (this Windows box)

Tests through `lupa` from the repo root; there is no per-test filter, always run it all:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

`test/run.lua` keeps two **hand-kept lists**: pure modules (TOC order) and suites. A new module or
`test/test_*.lua` must be added there or it silently does not run.

luacheck and lua-language-server:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinFlyout test --no-color --no-cache
lua-language-server --check D:\GoblinFlyout --checklevel=Warning --check_out_path=$env:TEMP\gf-luals.json
```

Keep both at zero warnings. A new WoW global goes in both `.luacheckrc` and `.luarc.json`.
````

- [ ] **Step 6: Run the tests**

Run the test command. Expected: `15 passed, 0 failed` then `0`.

- [ ] **Step 7: Run lint**

Run the lint commands. Expected: luacheck `0 warnings / 0 errors in 4 files`; lua-language-server no problems.

- [ ] **Step 8: Commit**

```powershell
git add CLAUDE.md .luacheckrc .luarc.json test GoblinFlyout
git commit -m "Repo: test harness, lint config and Professions carried over from ProfessionFlyout" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Kinds

**Files:**
- Create: `GoblinFlyout/Kinds.lua`
- Test: `test/test_kinds.lua`
- Modify: `test/run.lua` (module and suite lists)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Kinds.LIST`: ordered rows `{ key, label, icon, source = "professions"|"bags", secure = bool, accepts = function(item, names) -> bool | nil, toggle = "GoblinFlyout"..label, empty = string }`.
  - `Kinds.ByKey(key) -> kind|nil`, `Kinds.KEYS` (list of keys in order), `Kinds.Matching(item, names) -> { key, ... }`.
  - `Kinds.CONSUMABLE = 0`; subclass constants `POTION=1, ELIXIR=2, FLASK=3, SCROLL=4, FOOD_DRINK=5, BANDAGE=7`.
  - `names` is `{ food = string|nil, drink = string|nil }`; `accepts` must tolerate `{}` and any junk `item`.

- [ ] **Step 1: Write the failing test `test/test_kinds.lua`**

```lua
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
```

- [ ] **Step 2: Add the module and suite to `test/run.lua`**

In `modules`, before the Professions line, add `{ "Kinds", "GoblinFlyout/Kinds.lua" },`. In `suites`, add `"test/test_kinds.lua",` after `"test/test_professions.lua",`.

- [ ] **Step 3: Run the tests to verify they fail**

Run the test command. Expected: an error that `GoblinFlyout/Kinds.lua` cannot be opened (the `assert(loadfile(...))` fails).

- [ ] **Step 4: Write `GoblinFlyout/Kinds.lua`**

```lua
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the test command. Expected: `28 passed, 0 failed` then `0`.

- [ ] **Step 6: Run lint**

Expected: luacheck `0 warnings / 0 errors`; lua-language-server no problems.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Kinds.lua test/test_kinds.lua test/run.lua
git commit -m "Kinds: the seven flyouts as data, with subclass and food/drink filters" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Items

**Files:**
- Create: `GoblinFlyout/Items.lua`
- Test: `test/test_items.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Consumes: a kind row from Task 2 (`kind.accepts(item, names)`), `Kinds.ByKey`.
- Produces: `Items.Entries(raws, kind, names) -> { { itemID, name, icon, count, itemLevel, minLevel }, ... }` sorted best first, never nil; `Items.Better(a, b) -> bool` (the sort's comparator).

- [ ] **Step 1: Write the failing test `test/test_items.lua`**

```lua
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
```

- [ ] **Step 2: Add to `test/run.lua`**

In `modules`, after the Professions line, add `{ "Items", "GoblinFlyout/Items.lua" },`. In `suites`, add `"test/test_items.lua",`.

- [ ] **Step 3: Run the tests to verify they fail**

Expected: an error that `GoblinFlyout/Items.lua` cannot be opened.

- [ ] **Step 4: Write `GoblinFlyout/Items.lua`**

```lua
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Expected: `37 passed, 0 failed` then `0`.

- [ ] **Step 6: Run lint**

Expected: zero warnings from both.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Items.lua test/test_items.lua test/run.lua
git commit -m "Items: a kind's bag items, stacks merged, best item level first" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Options

**Files:**
- Create: `GoblinFlyout/Options.lua`
- Test: `test/test_options.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Consumes: `ns.Kinds.LIST` (read at call time, not at load).
- Produces:
  - `Options.NAME = "Goblin Flyout"`, `Options.LAYOUTS = { "horizontal", "vertical" }`, `Options.LABELS = { horizontal = "Horizontal", vertical = "Vertical" }`, `Options.DEFAULT_LAYOUT = "horizontal"`, `Options.DEFAULT_ANGLE = 225`.
  - `Options.Init(db) -> db` with `db.layouts[key]` valid for every kind (and only kinds), `db.minimap.angle` a number, `db.window` either `{ point, x, y }` or nil. Returns the same table it was given when that was a table.
  - `Options.Other(layout) -> layout`.
  - `Options.Register(openWindow) -> bool`: adds Esc > Options > AddOns > Goblin Flyout with one "Open Goblin Flyout" button.

- [ ] **Step 1: Write the failing test `test/test_options.lua`**

```lua
return function(h, loaded)
    local Options = loaded.ns.Options

    h.describe("Options.Init", function()
        h.it("no SavedVariable: every kind horizontal, minimap at 225, no saved window", function()
            local db = Options.Init(nil)
            for _, kind in ipairs(loaded.ns.Kinds.LIST) do
                h.eq(db.layouts[kind.key], "horizontal", kind.key)
            end
            h.eq(db.minimap.angle, 225)
            h.eq(db.window, nil)
        end)
        h.it("a saved vertical layout is kept, in the same table", function()
            local db = { layouts = { potions = "vertical" } }
            h.eq(Options.Init(db), db)
            h.eq(db.layouts.potions, "vertical")
            h.eq(db.layouts.food, "horizontal")
        end)
        h.it("junk layouts reset to horizontal; layouts for unknown kinds are dropped", function()
            local db = Options.Init({ layouts = { potions = "diagonal", food = 3, mounts = "vertical" } })
            h.eq(db.layouts.potions, "horizontal")
            h.eq(db.layouts.food, "horizontal")
            h.eq(db.layouts.mounts, nil)
            h.eq(Options.Init({ layouts = "junk" }).layouts.drink, "horizontal")
        end)
        h.it("a junk SavedVariable starts fresh", function()
            h.eq(Options.Init("junk").layouts.scrolls, "horizontal")
        end)
        h.it("the minimap angle is kept when it's a number, else 225", function()
            h.eq(Options.Init({ minimap = { angle = 90 } }).minimap.angle, 90)
            h.eq(Options.Init({ minimap = { angle = "north" } }).minimap.angle, 225)
            h.eq(Options.Init({ minimap = 5 }).minimap.angle, 225)
        end)
        h.it("a whole saved window position is kept; a partial one is dropped", function()
            h.eq(Options.Init({ window = { point = "TOPLEFT", x = 10, y = -20 } }).window.x, 10)
            h.eq(Options.Init({ window = { point = "TOPLEFT", x = 10 } }).window, nil)
            h.eq(Options.Init({ window = "junk" }).window, nil)
        end)
    end)

    h.describe("Options.Other", function()
        h.it("flips between the two layouts", function()
            h.eq(Options.Other("horizontal"), "vertical")
            h.eq(Options.Other("vertical"), "horizontal")
        end)
    end)
end
```

- [ ] **Step 2: Add to `test/run.lua`**

In `modules`, after the Items line, add `{ "Options", "GoblinFlyout/Options.lua" },`. In `suites`, add `"test/test_options.lua",`.

- [ ] **Step 3: Run the tests to verify they fail**

Expected: an error that `GoblinFlyout/Options.lua` cannot be opened.

- [ ] **Step 4: Write `GoblinFlyout/Options.lua`**

```lua
local _, ns = ...

-- The settings (spec 2026-10-12-goblin-flyout-design.md): the SavedVariable's
-- shape, and a stub page in Blizzard's options (Esc > Options > AddOns >
-- Goblin Flyout) that opens our own window. Init and Other are pure; Register
-- uses Blizzard's Settings UI only when called, so test/run.lua loads this file.
local Options = {}
ns.Options = Options

Options.NAME = "Goblin Flyout"
Options.LAYOUTS = { "horizontal", "vertical" }
Options.LABELS = { horizontal = "Horizontal", vertical = "Vertical" }
Options.DEFAULT_LAYOUT = "horizontal"
Options.DEFAULT_ANGLE = 225  -- degrees round the minimap: bottom-left

-- The SavedVariable with every field valid:
-- { layouts = { <kind key> = layout }, minimap = { angle }, window = { point, x, y } | nil }.
-- Keeps the given table, so writes to it are saved.
function Options.Init(db)
    if type(db) ~= "table" then
        db = {}
    end
    local saved = type(db.layouts) == "table" and db.layouts or {}
    local layouts = {}
    for _, kind in ipairs(ns.Kinds.LIST) do
        local layout = saved[kind.key]
        layouts[kind.key] = (layout ~= nil and Options.LABELS[layout]) and layout or Options.DEFAULT_LAYOUT
    end
    db.layouts = layouts
    if type(db.minimap) ~= "table" or type(db.minimap.angle) ~= "number" then
        db.minimap = { angle = Options.DEFAULT_ANGLE }
    end
    local window = db.window
    if not (type(window) == "table" and type(window.point) == "string"
        and type(window.x) == "number" and type(window.y) == "number") then
        db.window = nil
    end
    return db
end

function Options.Other(layout)
    return layout == "vertical" and "horizontal" or "vertical"
end

local category

-- Adds the page; false when this client's Settings UI lacks a piece.
-- openWindow() shows Goblin Flyout's own window.
function Options.Register(openWindow)
    if category then
        return true
    end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return false
    end
    local panel = CreateFrame("Frame")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    open:SetText("Open " .. Options.NAME)
    open:SetScript("OnClick", function()
        if SettingsPanel and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        openWindow()
    end)
    category = Settings.RegisterCanvasLayoutCategory(panel, Options.NAME)
    Settings.RegisterAddOnCategory(category)
    return true
end

return Options
```

- [ ] **Step 5: Run the tests to verify they pass**

Expected: `44 passed, 0 failed` then `0`.

- [ ] **Step 6: Run lint**

Expected: zero warnings from both.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Options.lua test/test_options.lua test/run.lua
git commit -m "Options: per-kind layouts, minimap angle and window position, repaired on load" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Macro

**Files:**
- Create: `GoblinFlyout/Macro.lua`
- Test: `test/test_macro.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Consumes: a kind row (`kind.toggle`, `kind.label`, `kind.icon`); at call time `ns.API.FindMacro(test)`, `ns.API.AccountMacrosFull()`, `ns.API.CreateMacro(name, icon, body)`, `ns.API.PickupMacro(index)`, `ns.API.InCombat()` (Task 6).
- Produces: `Macro.Body(kind) -> string`, `Macro.IsOurs(kind, body) -> bool`, `Macro.Index(kind) -> index|nil`, `Macro.Ensure(kind) -> index | nil, "full"|"failed"`, `Macro.PickUp(kind) -> message|nil` (nil means the macro is on the cursor).

- [ ] **Step 1: Write the failing test `test/test_macro.lua`**

```lua
return function(h, loaded)
    local Macro, Kinds = loaded.ns.Macro, loaded.ns.Kinds
    local potions, professions = Kinds.ByKey("potions"), Kinds.ByKey("professions")

    h.describe("Macro.Body", function()
        h.it("a kind's body clicks its toggle", function()
            h.eq(Macro.Body(potions), "/click GoblinFlyoutPotions")
            h.eq(Macro.Body(professions), "/click GoblinFlyoutProfessions")
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
end
```

- [ ] **Step 2: Add to `test/run.lua`**

In `modules`, after the Options line, add `{ "Macro", "GoblinFlyout/Macro.lua" },`. In `suites`, add `"test/test_macro.lua",`.

- [ ] **Step 3: Run the tests to verify they fail**

Expected: an error that `GoblinFlyout/Macro.lua` cannot be opened.

- [ ] **Step 4: Write `GoblinFlyout/Macro.lua`**

```lua
local _, ns = ...

-- A kind's button (spec 2026-10-12-goblin-flyout-design.md): an account-wide
-- macro whose only line clicks the kind's toggle. Ours is found by its body,
-- never its name, so a player's own "Potions" macro is never touched. Body and
-- IsOurs are pure; the rest goes through ns.API when called.
local Macro = {}
ns.Macro = Macro

function Macro.Body(kind)
    return "/click " .. kind.toggle
end

function Macro.IsOurs(kind, body)
    if type(kind) ~= "table" or type(body) ~= "string" then
        return false
    end
    return string.match(body, "^%s*(.-)%s*$") == Macro.Body(kind)
end

function Macro.Index(kind)
    return ns.API.FindMacro(function(body)
        return Macro.IsOurs(kind, body)
    end)
end

-- The kind's macro index, made if missing; or nil and "full" / "failed".
function Macro.Ensure(kind)
    local index = Macro.Index(kind)
    if index then
        return index
    end
    if ns.API.AccountMacrosFull() then
        return nil, "full"
    end
    index = ns.API.CreateMacro(kind.label, kind.icon, Macro.Body(kind))
    if not index then
        return nil, "failed"
    end
    return index
end

-- Puts the kind's button on the cursor. nil when it did; else what went wrong.
-- Out of combat only: the macro may have to be made first.
function Macro.PickUp(kind)
    if ns.API.InCombat() then
        return "Can't do that in combat."
    end
    local index, problem = Macro.Ensure(kind)
    if problem == "full" then
        return "Your account macros are full. Delete one and try again."
    end
    if not index then
        return "Couldn't make the " .. kind.label .. " macro."
    end
    ns.API.PickupMacro(index)
    return nil
end

return Macro
```

- [ ] **Step 5: Run the tests to verify they pass**

Expected: `49 passed, 0 failed` then `0`.

- [ ] **Step 6: Run lint**

Expected: zero warnings from both.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Macro.lua test/test_macro.lua test/run.lua
git commit -m "Macro: one account macro per kind, found by its body" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: API

**Files:**
- Create: `GoblinFlyout/API.lua` (starts from `D:\ProfessionFlyout\ProfessionFlyout\API.lua`)

No unit tests: this file is the Blizzard boundary. It is checked by lint here and by `/gf probe` in game (Task 9).

**Interfaces:**
- Consumes: Blizzard globals only, verified in `D:\wow-api\1.60.1.70291`: `C_Container.GetContainerNumSlots(bag)`, `C_Container.GetContainerItemInfo(bag, slot) -> { itemID, stackCount, iconFileID, ... }`, `C_Container.GetItemCooldown(itemID) -> start, duration, enable`, `C_Item.GetItemInfo(id)` (13th return subclassID, 12th classID, 10th texture, 5th minLevel, 4th itemLevel), `C_Item.GetItemSpell(id) -> spellName, spellID`, `C_Item.GetItemCount(id) -> count`, `C_Spell.GetSpellName(id)`, `SecureHandlerExecute(frame, body)`.
- Produces (carried over unchanged): `API.Errors()`, `API.InCombat()`, `API.RawProfessions()`, `API.MacroButtons(macroIndex)`, `API.FindMacro(test)`, `API.AccountMacrosFull()`, `API.CreateMacro(name, icon, body)`, `API.PickupMacro(index)`, `API.OnEvents(names, fn)`.
- Produces (new): `API.BagItems() -> { raw item, ... }`, `API.FoodDrinkNames() -> { food, drink }`, `API.ItemCount(itemID) -> number`, `API.ItemCooldown(itemID) -> start, duration, enable` (or nil), `API.SnippetsWork() -> bool`.

- [ ] **Step 1: Copy ProfessionFlyout's API and fix its header**

```powershell
Copy-Item D:\ProfessionFlyout\ProfessionFlyout\API.lua GoblinFlyout\API.lua
(Get-Content GoblinFlyout\API.lua -Raw).Replace("so /pf probe can say why a call went quiet.", "so /gf probe can say why a call went quiet.") | Set-Content GoblinFlyout\API.lua -NoNewline
Select-String GoblinFlyout\API.lua -Pattern '/pf|/gf'
```

Expected: one line, containing `/gf probe`.

- [ ] **Step 2: Insert the bag, item and snippet calls**

In `GoblinFlyout/API.lua`, insert this block directly above the line `-- ---- events ----`:

```lua
-- ---- bags and items ----

-- The backpack and the four bags: Enum.BagIndex.Backpack (0) to Bag_4 (4).
local BAGS = { 0, 1, 2, 3, 4 }

-- One raw item per occupied bag slot, as Kinds.lua and Items.lua take them:
-- { itemID, name, icon, count, classID, subclassID, itemLevel, minLevel, spellName }.
-- An item the client hasn't cached yet comes back without a name.
function API.BagItems()
    local items = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo
        and C_Item and C_Item.GetItemInfo) then
        return items
    end
    for _, bag in ipairs(BAGS) do
        local slots = attempt("GetContainerNumSlots", C_Container.GetContainerNumSlots, bag)
        for slot = 1, type(slots) == "number" and slots or 0 do
            local info = attempt("GetContainerItemInfo", C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and type(info.itemID) == "number" then
                local name, _, _, itemLevel, minLevel, _, _, _, _, icon, _, classID, subclassID =
                    attempt("GetItemInfo", C_Item.GetItemInfo, info.itemID)
                local spellName
                if C_Item.GetItemSpell then
                    spellName = attempt("GetItemSpell", C_Item.GetItemSpell, info.itemID)
                end
                items[#items + 1] = {
                    itemID = info.itemID, name = name, icon = icon or info.iconFileID, count = info.stackCount,
                    classID = classID, subclassID = subclassID, itemLevel = itemLevel, minLevel = minLevel,
                    spellName = spellName,
                }
            end
        end
    end
    return items
end

local FOOD_SPELL, DRINK_SPELL = 433, 430  -- the spells food and drink cast (seen in game 2026-10-12)

-- The client's own names for the Food and Drink spells, so food and drink are
-- told apart in any locale. {} when the client can't say.
function API.FoodDrinkNames()
    if not (C_Spell and C_Spell.GetSpellName) then
        return {}
    end
    return {
        food = attempt("GetSpellName", C_Spell.GetSpellName, FOOD_SPELL),
        drink = attempt("GetSpellName", C_Spell.GetSpellName, DRINK_SPELL),
    }
end

-- How many of the item are in the bags; 0 when unknown.
function API.ItemCount(itemID)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    local count = attempt("GetItemCount", C_Item.GetItemCount, itemID)
    return type(count) == "number" and count or 0
end

-- start, duration, enable for the item's cooldown, or nil.
function API.ItemCooldown(itemID)
    if not (C_Container and C_Container.GetItemCooldown) then
        return nil
    end
    return attempt("GetItemCooldown", C_Container.GetItemCooldown, itemID)
end

-- Whether secure snippets run on this build (the 69913 bug left
-- loadstring_untainted nil and broke them all). Out of combat only; called
-- once, at setup.
function API.SnippetsWork()
    if not (CreateFrame and SecureHandlerExecute) then
        return false
    end
    local frame = attempt("CreateFrame", CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    if not frame then
        return false
    end
    attempt("SecureHandlerExecute", SecureHandlerExecute, frame, "self:SetAttribute('goblinflyout', 1)")
    return frame:GetAttribute("goblinflyout") == 1
end

```

- [ ] **Step 3: Run lint**

Expected: zero warnings from both. (`API.lua` is not loaded by the tests; the test command still prints `49 passed, 0 failed`.)

- [ ] **Step 4: Run the tests**

Expected: `49 passed, 0 failed` then `0`.

- [ ] **Step 5: Commit**

```powershell
git add GoblinFlyout/API.lua
git commit -m "API: bag items, food and drink spell names, counts, cooldowns and a snippet check" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Bar

**Files:**
- Create: `GoblinFlyout/Bar.lua`
- Test: `test/test_bar.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Consumes: kind rows (Task 2); at call time `ns.API.InCombat/MacroButtons/RawProfessions/BagItems/FoodDrinkNames/ItemCount/ItemCooldown` (Task 6), `ns.Macro.Index(kind)` (Task 5), `ns.Professions.Entries` (Task 1), `ns.Items.Entries` (Task 3).
- Produces:
  - Pure: `Bar.PADDING = 2`, `Bar.ENTRY_TEMPLATES`, `Bar.ENTRY_ATTRIBUTES = { useOnKeyDown = false }`, `Bar.ENTRY_TYPE = { professions = "spell", bags = "item" }`, `Bar.Positions(n, size, gap, layout) -> points, width, height`, `Bar.PickHost(hosts, prefer) -> host|nil`, `Bar.ActionValue(kind, entry) -> spellID | "item:<id>"`, `Bar.CountText(count) -> string`, `Bar.TOGGLE_SNIPPET`, `Bar.CLOSE_PRE`, `Bar.CLOSE_POST`.
  - Runtime (each returns a message string for Core to say, or nil): `Bar.TogglePlain(kind, layout)`, `Bar.BeforeSecureClick(kind, layout)`.
  - Runtime (no return): `Bar.MakePlainToggle(kind, onClick)`, `Bar.MakeSecureToggle(kind, onPreClick)`, `Bar.LinkSecure()`, `Bar.SetEscape(on)`, `Bar.Close(kind)`, `Bar.CloseAll()`, `Bar.CloseUnlessMouseOver()`, `Bar.Refresh()`, `Bar.EnterCombat(layoutOf)`, `Bar.LeaveCombat(layoutOf)` where `layoutOf(key) -> layout`.

- [ ] **Step 1: Write the failing test `test/test_bar.lua`**

```lua
return function(h, loaded)
    local Bar, Kinds = loaded.ns.Bar, loaded.ns.Kinds

    h.describe("Bar.Positions", function()
        h.it("horizontal: a row going right, the bar one button tall", function()
            local points, width, height = Bar.Positions(3, 45, 2, "horizontal")
            h.eq(#points, 3)
            h.eq(points[1].x, 0)
            h.eq(points[2].x, 47)
            h.eq(points[3].x, 94)
            h.eq(points[3].y, 0)
            h.eq(width, 139)
            h.eq(height, 45)
        end)
        h.it("vertical: a column going up, the bar one button wide", function()
            local points, width, height = Bar.Positions(3, 45, 2, "vertical")
            h.eq(points[2].x, 0)
            h.eq(points[2].y, 47)
            h.eq(points[3].y, 94)
            h.eq(width, 45)
            h.eq(height, 139)
        end)
        h.it("one button is exactly one button; an unknown layout is horizontal", function()
            local points, width, height = Bar.Positions(1, 45, 2, "sideways")
            h.eq(#points, 1)
            h.eq(width, 45)
            h.eq(height, 45)
        end)
    end)

    h.describe("Bar.PickHost", function()
        local a, b = { id = "a" }, { id = "b" }
        h.it("the preferred slot wins (the one under the mouse)", function()
            h.eq(Bar.PickHost({ a, b }, function(host) return host == b end), b)
        end)
        h.it("in combat prep the last host wins while it still holds the macro", function()
            local last = b
            h.eq(Bar.PickHost({ a, b }, function(host) return host == last end), b)
        end)
        h.it("else the first", function()
            h.eq(Bar.PickHost({ a, b }, function() return false end), a)
        end)
        h.it("no slots, no host", function()
            h.eq(Bar.PickHost({}, function() return true end), nil)
        end)
    end)

    h.describe("Bar entries", function()
        h.it("the secure template comes last, so its OnClick beats the flyout template's", function()
            h.eq(Bar.ENTRY_TEMPLATES, "ActionButtonTemplate, SecureActionButtonTemplate")
        end)
        h.it("entries act on mouse-up, whatever ActionButtonUseKeyDown says", function()
            h.eq(Bar.ENTRY_ATTRIBUTES.useOnKeyDown, false)
        end)
        h.it("professions cast a spell; bag kinds use an item by ID", function()
            h.eq(Bar.ENTRY_TYPE.professions, "spell")
            h.eq(Bar.ENTRY_TYPE.bags, "item")
            h.eq(Bar.ActionValue(Kinds.ByKey("professions"), { spellID = 2656 }), 2656)
            h.eq(Bar.ActionValue(Kinds.ByKey("potions"), { itemID = 118 }), "item:118")
        end)
        h.it("the count reads as a number, zero included; nothing for no count", function()
            h.eq(Bar.CountText(3), "3")
            h.eq(Bar.CountText(0), "0")
            h.eq(Bar.CountText(nil), "")
        end)
    end)

    h.describe("Bar snippets", function()
        -- RestrictedExecution.lua refuses a body with { } or the word function, only when it runs.
        local snippets = { toggle = Bar.TOGGLE_SNIPPET, pre = Bar.CLOSE_PRE, post = Bar.CLOSE_POST }
        for name, body in pairs(snippets) do
            h.it(name .. " snippet is text the restricted environment accepts", function()
                h.eq(type(body), "string", name)
                h.falsy(string.find(body, "[{}]"), name .. " has a brace")
                h.falsy(string.find(body, "function", 1, true), name .. " says function")
            end)
        end
        h.it("a used entry closes its bar: the pre-snippet passes a message, so the post-snippet runs", function()
            h.truthy(string.find(Bar.CLOSE_PRE, "return nil, \"close\"", 1, true))
            h.truthy(string.find(Bar.CLOSE_POST, "owner:Hide()", 1, true))
        end)
    end)
end
```

- [ ] **Step 2: Add to `test/run.lua`**

In `modules`, after the Macro line, add `{ "Bar", "GoblinFlyout/Bar.lua" },`. In `suites`, add `"test/test_bar.lua",`.

- [ ] **Step 3: Run the tests to verify they fail**

Expected: an error that `GoblinFlyout/Bar.lua` cannot be opened.

- [ ] **Step 4: Write `GoblinFlyout/Bar.lua`**

```lua
local _, ns = ...

-- The bar engine (spec 2026-10-12-goblin-flyout-design.md): one bar per kind,
-- Blizzard's own ActionButtonTemplate per entry, opened next to the slot that
-- holds the kind's button. Every bar is a secure handler, so a used entry can
-- hide it in combat too. The toggle sets the style: plain (an insecure
-- button, out of combat only) or secure (a click snippet that also opens it
-- in combat). Entries change only out of combat. Frames are made when Core
-- makes the toggles, so loading this file touches no Blizzard global and
-- test/run.lua can test the pure parts.
local Bar = {}
ns.Bar = Bar

Bar.PADDING = 2  -- gap when the host bar gives none: Blizzard's ActionBar minButtonPadding

-- Later templates win: ActionButtonTemplate brings FlyoutButtonTemplate's
-- OnClick (Blizzard_Flyout\Flyout.xml), so the secure one must come last.
Bar.ENTRY_TEMPLATES = "ActionButtonTemplate, SecureActionButtonTemplate"

-- useOnKeyDown false: an addon's click is treated as a key press, so with
-- ActionButtonUseKeyDown on, a mouse-up would do nothing
-- (SecureActionButton_OnClick in Blizzard_FrameXML\SecureTemplates.lua).
Bar.ENTRY_ATTRIBUTES = { useOnKeyDown = false }

-- The secure action type per kind source; the attribute it reads has the same name.
Bar.ENTRY_TYPE = { professions = "spell", bags = "item" }

-- The toggle's _onclick (SecureHandlerClickTemplate). Hides the bar if open;
-- else hides the other secure bars and shows this one when it has entries.
-- No braces and no "function": the restricted environment refuses them.
Bar.TOGGLE_SNIPPET = [[
local bar = self:GetFrameRef("bar")
if bar:IsShown() then
    bar:Hide()
    return
end
local i = 1
local other = self:GetFrameRef("other" .. i)
while other do
    other:Hide()
    i = i + 1
    other = self:GetFrameRef("other" .. i)
end
if (bar:GetAttribute("entries") or 0) > 0 then
    bar:Show()
end
]]

-- Wrapped round each entry's OnClick, with its bar as header (owner). The
-- post-snippet runs only when the pre-snippet returns a message
-- (Wrapped_Click in SecureHandlers.lua).
Bar.CLOSE_PRE = [[return nil, "close"]]
Bar.CLOSE_POST = [[owner:Hide()]]

-- Where each of n square buttons sits, from the bar's bottom-left, and the
-- bar's width and height. Vertical stacks up; anything else is a row.
function Bar.Positions(n, size, gap, layout)
    local points = {}
    for i = 1, n do
        local step = (i - 1) * (size + gap)
        if layout == "vertical" then
            points[i] = { x = 0, y = step }
        else
            points[i] = { x = step, y = 0 }
        end
    end
    local long = n > 0 and (n * size + (n - 1) * gap) or 0
    if layout == "vertical" then
        return points, size, long
    end
    return points, long, size
end

-- The slot to open from: the first prefer() likes, else the first; nil if none.
function Bar.PickHost(hosts, prefer)
    for _, candidate in ipairs(hosts) do
        if prefer(candidate) then
            return candidate
        end
    end
    return hosts[1]
end

-- What the entry's secure action gets: a spell ID, or "item:<id>"
-- (SecureCmdItemParse hands it to C_Item.UseItemByName).
function Bar.ActionValue(kind, entry)
    if kind.source == "professions" then
        return entry.spellID
    end
    return "item:" .. entry.itemID
end

function Bar.CountText(count)
    if type(count) ~= "number" then
        return ""
    end
    return tostring(count)
end

-- ---- runtime ----

local bars = {}   -- kind key -> { kind, frame, entries, host, secure, toggle }
local order = {}  -- the same bars, in the order they were made

local function inCombat()
    return ns.API.InCombat()
end

local function underMouse(button)
    return button:IsMouseOver()
end

local GOLD = { 1, 0.82, 0 }  -- NORMAL_FONT_COLOR, the tooltip's body color

-- An item shows its own tooltip; a profession its name and skill level, as
-- Blizzard's profession tabs show it.
local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.itemID then
        GameTooltip:SetItemByID(self.itemID)
    else
        GameTooltip:SetText(self.label)
        if self.skill then
            GameTooltip:AddLine(self.skill, GOLD[1], GOLD[2], GOLD[3])
        end
    end
    GameTooltip:Show()
end

local function onLeave()
    GameTooltip:Hide()
end

-- The Count font string sits in TextOverlayContainer
-- (Blizzard_ActionBar\Mainline\ActionButtonTemplate.xml).
local function countString(button)
    return button.Count or (button.TextOverlayContainer and button.TextOverlayContainer.Count)
end

-- Count, grey-out at 0, and cooldown sweep: drawn only, so allowed in combat.
local function refresh(bar)
    for _, button in ipairs(bar.entries) do
        if button:IsShown() and button.itemID then
            local count = ns.API.ItemCount(button.itemID)
            local text = countString(button)
            if text then
                text:SetText(Bar.CountText(count))
            end
            button.icon:SetDesaturated(count == 0)
            if button.cooldown then
                local start, duration, enable = ns.API.ItemCooldown(button.itemID)
                if (enable == 1 or enable == true) and type(duration) == "number" and duration > 0 then
                    button.cooldown:SetCooldown(start, duration)
                else
                    button.cooldown:Clear()
                end
            end
        end
    end
end

local function barFor(kind)
    local bar = bars[kind.key]
    if bar then
        return bar
    end
    local frame = CreateFrame("Frame", kind.toggle .. "Bar", UIParent, "SecureHandlerBaseTemplate")
    frame:Hide()
    frame:SetFrameStrata("DIALOG")  -- the strata Blizzard's SpellFlyout uses
    frame:SetClampedToScreen(true)
    frame:SetAttribute("entries", 0)
    bar = { kind = kind, frame = frame, entries = {} }
    frame:HookScript("OnShow", function()
        refresh(bar)
    end)
    bars[kind.key] = bar
    order[#order + 1] = bar
    return bar
end

local function entry(bar, i)
    if bar.entries[i] then
        return bar.entries[i]
    end
    local button = CreateFrame("CheckButton", bar.frame:GetName() .. "Entry" .. i, bar.frame, Bar.ENTRY_TEMPLATES)
    button:RegisterForClicks("AnyUp")
    for name, value in pairs(Bar.ENTRY_ATTRIBUTES) do
        button:SetAttribute(name, value)
    end
    button:SetAttribute("type", Bar.ENTRY_TYPE[bar.kind.source])
    button:HookScript("OnEnter", onEnter)
    button:HookScript("OnLeave", onLeave)
    button:SetScript("PostClick", function(self)
        self:SetChecked(false)
    end)
    SecureHandlerWrapScript(button, "OnClick", bar.frame, Bar.CLOSE_PRE, Bar.CLOSE_POST)
    bar.entries[i] = button
    return button
end

local function entriesFor(kind)
    if kind.source == "professions" then
        return ns.Professions.Entries(ns.API.RawProfessions())
    end
    return ns.Items.Entries(ns.API.BagItems(), kind, ns.API.FoodDrinkNames())
end

-- Fills, sizes and anchors the bar on bar.host. Out of combat only.
local function fill(bar, list, layout)
    local actionType = Bar.ENTRY_TYPE[bar.kind.source]
    for i, item in ipairs(list) do
        local button = entry(bar, i)
        button:SetAttribute(actionType, Bar.ActionValue(bar.kind, item))
        button.icon:SetTexture(item.icon)
        button.label = item.name
        button.skill = item.skill
        button.itemID = item.itemID
        local text = countString(button)
        if text then
            text:SetText("")
        end
        button:Show()
    end
    for i = #list + 1, #bar.entries do
        bar.entries[i]:Hide()
    end
    local host = bar.host
    local gap = Bar.PADDING
    if host.bar and type(host.bar.buttonPadding) == "number" then
        gap = host.bar.buttonPadding
    end
    local points, width, height = Bar.Positions(#list, bar.entries[1]:GetWidth(), gap, layout)
    for i, point in ipairs(points) do
        bar.entries[i]:ClearAllPoints()
        bar.entries[i]:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", point.x, point.y)
    end
    bar.frame:SetSize(width, height)
    -- Same on-screen size as the host, whatever scale Edit Mode gave its bar.
    bar.frame:SetScale(host:GetEffectiveScale() / UIParent:GetEffectiveScale())
    bar.frame:ClearAllPoints()
    bar.frame:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, gap)
    if bar.frame:IsShown() then
        refresh(bar)
    end
end

-- Rebuilds the bar out of combat on the host prefer() picks. Sets its entries
-- attribute (0 when it can't), which the toggle snippet reads. Returns a
-- message when there is nothing to show.
local function prepare(bar, layout, prefer)
    local kind = bar.kind
    bar.frame:SetAttribute("entries", 0)
    local index = ns.Macro.Index(kind)
    local host = index and Bar.PickHost(ns.API.MacroButtons(index), prefer)
    if not host then
        return "Put the " .. kind.label .. " button on an action bar (/gf " .. kind.key .. ")."
    end
    local list = entriesFor(kind)
    if #list == 0 then
        return kind.empty
    end
    bar.host = host
    fill(bar, list, layout)
    bar.frame:SetAttribute("entries", #list)
    return nil
end

local function lastHost(bar)
    local last = bar.host
    return function(button)
        return button == last
    end
end

-- Hides the kind's bar. Never in combat: it is a protected frame.
function Bar.Close(kind)
    local bar = bars[kind.key]
    if bar and bar.frame:IsShown() and not inCombat() then
        bar.frame:Hide()
    end
end

function Bar.CloseAll()
    if inCombat() then
        return
    end
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() then
            bar.frame:Hide()
        end
    end
end

-- A click anywhere but an open bar or its host closes it, out of combat. The
-- host is spared so its own click toggles the bar closed instead of reopening it.
function Bar.CloseUnlessMouseOver()
    if inCombat() then
        return
    end
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() and not bar.frame:IsMouseOver()
            and not (bar.host and bar.host:IsMouseOver()) then
            bar.frame:Hide()
        end
    end
end

-- Redraws counts and cooldowns on every open bar; fine in combat.
function Bar.Refresh()
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() then
            refresh(bar)
        end
    end
end

-- Escape closes bars only out of combat: Blizzard's Escape handler hiding a
-- protected frame in combat would be blocked.
function Bar.SetEscape(on)
    for _, bar in ipairs(order) do
        local name = bar.frame:GetName()
        local at
        for i, listed in ipairs(UISpecialFrames) do
            if listed == name then
                at = i
            end
        end
        if on and not at then
            table.insert(UISpecialFrames, name)
        elseif not on and at then
            table.remove(UISpecialFrames, at)
        end
    end
end

-- A plain toggle's click: opens or closes the bar, out of combat only.
function Bar.TogglePlain(kind, layout)
    if inCombat() then
        return "Can't open " .. string.lower(kind.label) .. " in combat."
    end
    local bar = barFor(kind)
    if bar.frame:IsShown() then
        bar.frame:Hide()
        return nil
    end
    Bar.CloseAll()
    local message = prepare(bar, layout, underMouse)
    if message then
        return message
    end
    bar.frame:Show()
    return nil
end

-- A secure toggle's PreClick: out of combat, rebuild a closed bar so the
-- snippet that runs next can show it. In combat the snippet works alone.
function Bar.BeforeSecureClick(kind, layout)
    if inCombat() then
        return nil
    end
    local bar = barFor(kind)
    if bar.frame:IsShown() then
        return nil
    end
    Bar.CloseAll()
    return prepare(bar, layout, underMouse)
end

-- PLAYER_REGEN_DISABLED fires just before lockdown, the last moment secure
-- frames may change: plain bars close, every secure bar is rebuilt from the
-- bags on its last host, so it opens in combat with what was there at the pull.
function Bar.EnterCombat(layoutOf)
    Bar.SetEscape(false)
    for _, bar in ipairs(order) do
        if bar.secure then
            if prepare(bar, layoutOf(bar.kind.key), lastHost(bar)) and bar.frame:IsShown() then
                bar.frame:Hide()
            end
        elseif bar.frame:IsShown() then
            bar.frame:Hide()
        end
    end
end

-- PLAYER_REGEN_ENABLED: Escape back on; an open bar drops what was used up.
function Bar.LeaveCombat(layoutOf)
    Bar.SetEscape(true)
    for _, bar in ipairs(order) do
        if bar.frame:IsShown() and prepare(bar, layoutOf(bar.kind.key), lastHost(bar)) then
            bar.frame:Hide()
        end
    end
end

-- The hidden button a plain kind's macro /clicks. Up and down are both
-- registered so it answers however the action bar runs the macro.
function Bar.MakePlainToggle(kind, onClick)
    barFor(kind)
    local toggle = CreateFrame("Button", kind.toggle, UIParent)
    toggle:Hide()
    toggle:RegisterForClicks("AnyUp", "AnyDown")
    toggle:SetScript("OnClick", onClick)
end

-- The hidden secure button a combat kind's macro /clicks.
function Bar.MakeSecureToggle(kind, onPreClick)
    local bar = barFor(kind)
    bar.secure = true
    local toggle = CreateFrame("Button", kind.toggle, UIParent, "SecureHandlerClickTemplate")
    toggle:Hide()
    toggle:RegisterForClicks("AnyUp", "AnyDown")
    toggle:SetFrameRef("bar", bar.frame)
    toggle:SetAttribute("_onclick", Bar.TOGGLE_SNIPPET)
    toggle:SetScript("PreClick", onPreClick)
    bar.toggle = toggle
end

-- Lets each secure toggle's snippet hide the other secure bars. Once, after
-- every toggle is made, out of combat.
function Bar.LinkSecure()
    for _, bar in ipairs(order) do
        if bar.toggle then
            local n = 0
            for _, other in ipairs(order) do
                if other.secure and other ~= bar then
                    n = n + 1
                    bar.toggle:SetFrameRef("other" .. n, other.frame)
                end
            end
        end
    end
end

return Bar
```

- [ ] **Step 5: Run the tests to verify they pass**

Expected: `64 passed, 0 failed` then `0`.

- [ ] **Step 6: Run lint**

Expected: zero warnings from both. Fix any real warning; never silence one.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Bar.lua test/test_bar.lua test/run.lua
git commit -m "Bar: one engine for plain and combat-ready secure flyouts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Window and minimap button

**Files:**
- Create: `GoblinFlyout/Window.lua`, `GoblinFlyout/MinimapButton.lua`
- Test: `test/test_minimap.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Consumes: `ns.Kinds.LIST`, `ns.Options.NAME/LABELS/Other`; a `core` table (made in Task 9) with `core.Layout(key)`, `core.SetLayout(key, layout)`, `core.PickUp(kind) -> bool`, `core.Window() -> { point, x, y }|nil`, `core.SaveWindow(point, x, y)`, `core.Angle() -> number`, `core.SetAngle(angle)`, `core.ToggleWindow()`.
- Produces: `Window.Toggle(core)`, `Window.Refresh(core)` (no-op before first open); `MinimapButton.ICON`, `MinimapButton.Position(angle, radius) -> x, y`, `MinimapButton.Angle(dx, dy) -> degrees 0..360`, `MinimapButton.Create(core)`.

- [ ] **Step 1: Write the failing test `test/test_minimap.lua`**

```lua
return function(h, loaded)
    local MinimapButton = loaded.ns.MinimapButton

    local function near(actual, expected, label)
        h.truthy(math.abs(actual - expected) < 1e-9, (label or "") .. " " .. actual .. " ~= " .. expected)
    end

    h.describe("MinimapButton.Position", function()
        h.it("0 degrees is straight right, 90 straight up", function()
            local x, y = MinimapButton.Position(0, 80)
            near(x, 80, "x")
            near(y, 0, "y")
            x, y = MinimapButton.Position(90, 80)
            near(x, 0, "x")
            near(y, 80, "y")
        end)
    end)

    h.describe("MinimapButton.Angle", function()
        h.it("reads the four directions as 0..360", function()
            near(MinimapButton.Angle(1, 0), 0)
            near(MinimapButton.Angle(0, 1), 90)
            near(MinimapButton.Angle(-1, 0), 180)
            near(MinimapButton.Angle(0, -1), 270)
        end)
        h.it("round-trips with Position", function()
            near(MinimapButton.Angle(MinimapButton.Position(225, 80)), 225)
        end)
    end)
end
```

- [ ] **Step 2: Add to `test/run.lua`**

In `modules`, after the Bar line, add `{ "MinimapButton", "GoblinFlyout/MinimapButton.lua" },`. In `suites`, add `"test/test_minimap.lua",`. (`Window.lua` is not loaded: it has no pure parts.)

- [ ] **Step 3: Run the tests to verify they fail**

Expected: an error that `GoblinFlyout/MinimapButton.lua` cannot be opened.

- [ ] **Step 4: Write `GoblinFlyout/MinimapButton.lua`**

```lua
local _, ns = ...

-- The minimap button (spec 2026-10-12-goblin-flyout-design.md), hand-made:
-- no libraries, and Blizzard's addon compartment is Mainline-only. Click
-- opens the window; drag slides it round the rim. Not "Minimap": that name
-- is Blizzard's own frame. Position and Angle are pure; Create builds frames
-- only when called, so test/run.lua loads this file.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

MinimapButton.ICON = "Interface\\Icons\\INV_Misc_Bomb_04"

-- Offset from the minimap's centre for an angle in degrees (0 = right, 90 = up).
function MinimapButton.Position(angle, radius)
    local r = math.rad(angle)
    return math.cos(r) * radius, math.sin(r) * radius
end

-- The angle, 0..360, of an offset from the minimap's centre.
function MinimapButton.Angle(dx, dy)
    return math.deg(math.atan2(dy, dx)) % 360
end

local button

local function place(angle)
    local x, y = MinimapButton.Position(angle, Minimap:GetWidth() / 2 + 10)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function follow()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    button.angle = MinimapButton.Angle(cx / scale - mx, cy / scale - my)
    place(button.angle)
end

function MinimapButton.Create(core)
    if button or not Minimap then
        return
    end
    button = CreateFrame("Button", "GoblinFlyoutMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
    icon:SetTexture(MinimapButton.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function()
        core.ToggleWindow()
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", follow)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        core.SetAngle(self.angle)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.Options.NAME)
        GameTooltip:AddLine("Click for options, drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button.angle = core.Angle()
    place(button.angle)
end

return MinimapButton
```

- [ ] **Step 5: Write `GoblinFlyout/Window.lua`**

```lua
local _, ns = ...

-- The options window (spec 2026-10-12-goblin-flyout-design.md): one row per
-- kind: its icon (drag or click it to pick up the kind's button), its name,
-- and a button that flips its layout. Made on first open; position saved.
local Window = {}
ns.Window = Window

Window.WIDTH = 300
Window.ROW = 44
Window.TOP = -32  -- below ButtonFrameTemplate's title bar

local frame
local flips = {}  -- kind key -> its layout button

local function row(core, kind, i)
    local top = Window.TOP - (i - 1) * Window.ROW

    local icon = CreateFrame("Button", nil, frame)
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, top)
    icon:SetNormalTexture("Interface\\Icons\\" .. kind.icon)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function()
        core.PickUp(kind)
    end)
    icon:SetScript("OnClick", function()
        core.PickUp(kind)
    end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(kind.label)
        GameTooltip:AddLine("Drag to an action bar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local flip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    flip:SetSize(100, 22)
    flip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, top - 7)
    flip:SetScript("OnClick", function()
        core.SetLayout(kind.key, ns.Options.Other(core.Layout(kind.key)))
    end)
    flips[kind.key] = flip

    -- Two anchors bound the name between the icon and the button.
    local name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetPoint("RIGHT", flip, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(kind.label)
end

local function make(core)
    frame = CreateFrame("Frame", "GoblinFlyoutWindow", UIParent, "ButtonFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if frame.SetTitle then
        frame:SetTitle(ns.Options.NAME)
    end
    frame:SetSize(Window.WIDTH, -Window.TOP + #ns.Kinds.LIST * Window.ROW + 16)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)  -- our SavedVariable keeps the place, not layout-local.txt
        local point, _, _, x, y = self:GetPoint(1)
        core.SaveWindow(point, x, y)
    end)
    frame:ClearAllPoints()
    local saved = core.Window()
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
    frame:Hide()
    table.insert(UISpecialFrames, "GoblinFlyoutWindow")  -- Escape closes it
    for i, kind in ipairs(ns.Kinds.LIST) do
        row(core, kind, i)
    end
end

-- Shows each kind's current layout on its button.
function Window.Refresh(core)
    for key, flip in pairs(flips) do
        flip:SetText(ns.Options.LABELS[core.Layout(key)])
    end
end

function Window.Toggle(core)
    if not frame then
        make(core)
    end
    if frame:IsShown() then
        frame:Hide()
        return
    end
    Window.Refresh(core)
    frame:Show()
end

return Window
```

- [ ] **Step 6: Run the tests to verify they pass**

Expected: `67 passed, 0 failed` then `0`.

- [ ] **Step 7: Run lint**

Expected: zero warnings from both.

- [ ] **Step 8: Commit**

```powershell
git add GoblinFlyout/Window.lua GoblinFlyout/MinimapButton.lua test/test_minimap.lua test/run.lua
git commit -m "Window: each kind's icon to drag onto a bar and its layout; minimap button opens it" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Core, TOC, deploy, docs

**Files:**
- Create: `GoblinFlyout/Core.lua`, `GoblinFlyout/GoblinFlyout.toc`, `docs/manual-test-checklist.md`, `README.md`

**Interfaces:**
- Consumes: everything above. `core` for Window and MinimapButton is `Core` itself, with exactly the functions listed in Task 8's Consumes.
- Produces: the working addon; `Core.Say(text)`.

- [ ] **Step 1: Write `GoblinFlyout/Core.lua`**

```lua
local _, ns = ...

-- Glue (spec 2026-10-12-goblin-flyout-design.md): the SavedVariable, setup,
-- events and /gf. Every handler runs behind guard(), so an error is one chat
-- line, said once per label, never a raise.
local API, Bar, Kinds, Macro, MinimapButton, Options, Professions, Window =
    ns.API, ns.Bar, ns.Kinds, ns.Macro, ns.MinimapButton, ns.Options, ns.Professions, ns.Window
local Core = {}
ns.Core = Core

local function say(text)
    print("|cffffd100Goblin Flyout|r " .. text)
end
Core.Say = say

local said = {}
local function guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not said[label] then
        said[label] = true
        say(label .. " error: " .. tostring(err) .. " (said once; tell Claude).")
    end
    return ok
end

-- Looked up lazily: SavedVariables load after this file runs.
local function db()
    GoblinFlyoutDB = Options.Init(GoblinFlyoutDB)
    return GoblinFlyoutDB
end

function Core.Layout(key)
    return db().layouts[key] or Options.DEFAULT_LAYOUT
end

function Core.SetLayout(key, layout)
    local kind = Kinds.ByKey(key)
    if kind and Options.LABELS[layout] then
        db().layouts[key] = layout
        Bar.Close(kind)
        Window.Refresh(Core)
    end
end

function Core.Angle()
    return db().minimap.angle
end

function Core.SetAngle(angle)
    if type(angle) == "number" then
        db().minimap.angle = angle
    end
end

function Core.Window()
    return db().window
end

function Core.SaveWindow(point, x, y)
    if type(point) == "string" and type(x) == "number" and type(y) == "number" then
        db().window = { point = point, x = x, y = y }
    end
end

function Core.ToggleWindow()
    guard("Window", Window.Toggle, Core)
end

-- Puts the kind's button on the cursor; says why when it can't. True when it's there.
function Core.PickUp(kind)
    local placed = false
    guard("Pick up", function()
        local message = Macro.PickUp(kind)
        if message then
            say(message)
        else
            placed = true
        end
    end)
    return placed
end

local snippets  -- whether secure snippets ran at setup; nil until then

-- /gf <word> [rest] -> handler(rest)
local commands = {}
local HELP = "Commands: /gf, /gf <kind>, /gf layout <kind>, /gf probe. Kinds: "
    .. table.concat(Kinds.KEYS, ", ") .. "."

commands[""] = function()
    Core.ToggleWindow()
end
commands.options = commands[""]

function commands.layout(rest)
    local kind = Kinds.ByKey(rest)
    if not kind then
        say("Which one? /gf layout <" .. table.concat(Kinds.KEYS, "|") .. ">")
        return
    end
    Core.SetLayout(kind.key, Options.Other(Core.Layout(kind.key)))
    say(kind.label .. " layout: " .. Options.LABELS[Core.Layout(kind.key)] .. ".")
end

-- What detection sees, to settle in-game unknowns.
function commands.probe()
    for _, raw in ipairs(API.RawProfessions()) do
        local spells = {}
        for _, spell in ipairs(raw.spells) do
            spells[#spells + 1] = string.format("%d %s [window:%s passive:%s]", spell.spellID,
                tostring(spell.name), tostring(spell.craftingUI), tostring(spell.isPassive))
        end
        local pick = Professions.Pick(raw)
        say(string.format("Probe: %s (skillLine %s): %s -> %s", raw.name, tostring(raw.skillLine),
            #spells > 0 and table.concat(spells, ", ") or "no spells",
            pick and (tostring(pick.name) .. " " .. pick.spellID) or "no entry"))
    end
    local names = API.FoodDrinkNames()
    say("Probe: food spell " .. tostring(names.food) .. ", drink spell " .. tostring(names.drink) .. ".")
    for _, item in ipairs(API.BagItems()) do
        if item.classID == Kinds.CONSUMABLE then
            local keys = Kinds.Matching(item, names)
            say(string.format("Probe: %d %s ilvl %s req %s sub %s spell %s -> %s", item.itemID,
                tostring(item.name), tostring(item.itemLevel), tostring(item.minLevel), tostring(item.subclassID),
                tostring(item.spellName), #keys > 0 and table.concat(keys, ", ") or "none"))
        end
    end
    for _, kind in ipairs(Kinds.LIST) do
        local index = Macro.Index(kind)
        if index then
            say("Probe: " .. kind.label .. " macro #" .. index .. " is in " .. #API.MacroButtons(index)
                .. " visible slot(s).")
        else
            say("Probe: " .. kind.label .. " macro isn't made yet.")
        end
    end
    local state = snippets == nil and "not checked yet" or (snippets and "work" or "don't work")
    say("Probe: secure snippets " .. state .. ".")
    for name, message in pairs(API.Errors()) do
        say("Probe: " .. name .. " threw: " .. message)
    end
end

for _, kind in ipairs(Kinds.LIST) do
    commands[kind.key] = function()
        if Core.PickUp(kind) then
            say("Click an action bar slot to place the " .. kind.label .. " button.")
        end
    end
end

local function slash(msg)
    local word, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    local command = commands[string.lower(word or "")]
    if command then
        command(string.lower(rest or ""))
    else
        say(HELP)
    end
end

-- Makes every toggle, the options page and the minimap button. Secure frames
-- can't be made in combat, so after a /reload in combat this waits for the
-- fight to end.
local function setup()
    snippets = API.SnippetsWork()
    for _, kind in ipairs(Kinds.LIST) do
        if kind.secure and snippets then
            Bar.MakeSecureToggle(kind, function()
                guard("Open", function()
                    local message = Bar.BeforeSecureClick(kind, Core.Layout(kind.key))
                    if message then
                        say(message)
                    end
                end)
            end)
        else
            Bar.MakePlainToggle(kind, function()
                guard("Open", function()
                    local message = Bar.TogglePlain(kind, Core.Layout(kind.key))
                    if message then
                        say(message)
                    end
                end)
            end)
        end
    end
    Bar.LinkSecure()
    Bar.SetEscape(true)
    if not snippets then
        say("Secure snippets don't work on this client build, so potions, elixirs, bandages and scrolls "
            .. "open out of combat only.")
    end
    if not Options.Register(Core.ToggleWindow) then
        say("Couldn't add the options page; /gf still opens the window.")
    end
    MinimapButton.Create(Core)
end

local ready = false
local function trySetup()
    if ready or API.InCombat() then
        return
    end
    ready = true
    guard("Setup", setup)
end

API.OnEvents({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }, trySetup)

API.OnEvents({ "GLOBAL_MOUSE_DOWN" }, function()
    guard("Close on click", Bar.CloseUnlessMouseOver)
end)

API.OnEvents({ "ACTIONBAR_PAGE_CHANGED" }, function()
    guard("Close", Bar.CloseAll)
end)

API.OnEvents({ "PLAYER_REGEN_DISABLED" }, function()
    guard("Combat", Bar.EnterCombat, Core.Layout)
end)

API.OnEvents({ "PLAYER_REGEN_ENABLED" }, function()
    guard("Combat", Bar.LeaveCombat, Core.Layout)
end)

API.OnEvents({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" }, function()
    guard("Counts", Bar.Refresh)
end)

SLASH_GOBLINFLYOUT1 = "/gf"
SLASH_GOBLINFLYOUT2 = "/goblinflyout"
SlashCmdList.GOBLINFLYOUT = function(msg) guard("Slash", slash, msg) end

return Core
```

- [ ] **Step 2: Write `GoblinFlyout/GoblinFlyout.toc`**

```
## Interface: 16001
## Title: Goblin Flyout
## Notes: Action bar buttons that open bars of your professions, food, drink, potions, elixirs, bandages and scrolls.
## Author: CoffeeAndLoot
## Version: 2026.10.12
## SavedVariables: GoblinFlyoutDB

API.lua
Kinds.lua
Professions.lua
Items.lua
Options.lua
Macro.lua
Bar.lua
Window.lua
MinimapButton.lua
Core.lua
```

- [ ] **Step 3: Run tests and lint**

Expected: tests `67 passed, 0 failed` then `0`; luacheck `0 warnings / 0 errors in 19 files`; lua-language-server no problems.

- [ ] **Step 4: Write `docs/manual-test-checklist.md`**

```markdown
# Manual test checklist

In-game checks for what unit tests cannot reach. Only the owner runs the client.
Mark each with the build and date when walked; `[-]` is skipped by choice, with the reason.

## Install

- [ ] After the junction and a **full client restart**, Goblin Flyout is listed and enabled in
      the AddOns list; no Lua error on login.
- [ ] `/gf probe`: one line per profession ending `-> <spell> <id>` as ProfessionFlyout showed;
      food and drink spell names; every bag consumable with its subclass, spell and kinds
      (Minor Healing Potion -> potions, Tough Jerky -> food, Ice Cold Milk -> drink, Elixir of
      Minor Defense -> elixirs, Scroll of Protection -> scrolls); "secure snippets work"; no "threw:".
- [ ] A bandage and a flask (if one can be had) report subclass 7 and 3 and land in bandages and elixirs.

## Window and minimap

- [ ] A minimap button with a bomb icon sits on the rim; hovering says "Goblin Flyout / Click for
      options, drag to move."
- [ ] Dragging it slides it round the rim; `/reload`: it stays where it was put.
- [ ] Clicking it opens the window; clicking again, or Escape, closes it.
- [ ] `/gf` and `/gf options` open the window too.
- [ ] Esc > Options > AddOns lists "Goblin Flyout" with an "Open Goblin Flyout" button that closes
      the options and opens the window.
- [ ] The window shows seven rows: Professions, Food, Drink, Potions, Elixirs, Bandages, Scrolls,
      each with its icon (book, food, drink, potion, elixir, bandage, scroll; no red question mark),
      name and a "Horizontal" button. Names don't run into the buttons.
- [ ] The window can be dragged; `/reload`: it reopens where it was left.
- [ ] Dragging an icon onto an action slot places that kind's button; Esc > Macros > General shows
      the macro with the same icon, named after the kind.
- [ ] Clicking an icon puts the button on the cursor; clicking a slot places it.
- [ ] Doing either again makes no second macro.
- [ ] Clicking a layout button flips it to "Vertical" and back; `/reload` keeps the choice.
- [ ] `/gf layout potions` flips Potions and says so; an open window's button agrees.
- [ ] In combat: dragging or clicking an icon says "Can't do that in combat."
- [ ] `/gf potions` puts the Potions button on the cursor and says to click a slot.

## Plain bars (Professions, Food, Drink)

- [ ] Professions opens exactly as ProfessionFlyout's did (same entries, tooltips, windows).
- [ ] Food opens a row of the food in the bags, best item level first; each entry shows its
      stack count and the item's own tooltip; clicking one eats it and closes the bar.
- [ ] Drink likewise for drinks.
- [ ] With a stack split across two bags, one entry shows the total.
- [ ] Opening Food while Drink is open closes Drink.
- [ ] Escape, a click elsewhere, and paging the main bar each close it.
- [ ] Entering combat with it open closes it, with no "action blocked" error.
- [ ] Clicking the button in combat: "Can't open food in combat." (and "professions", "drink").
- [ ] No food in the bags: "No food in your bags."
- [ ] `/click GoblinFlyoutFood` with the macro on no bar: "Put the Food button on an action bar (/gf food)."

## Secure bars (Potions, Elixirs, Bandages, Scrolls)

Out of combat:
- [ ] Potions opens above its slot, best potion first (Minor Rejuvenation before Minor Healing),
      sized and spaced like the bar; each entry has its count and the item's tooltip.
- [ ] Clicking a potion drinks it and closes the bar; the count drops next time.
- [ ] Vertical layout: a column straight up from the slot.
- [ ] Escape, a click elsewhere, and paging the main bar close it.
- [ ] Opening Elixirs while Potions is open closes Potions.
- [ ] No bandages: "No bandages in your bags."

In combat (fight a mob):
- [ ] The Potions button opens the bar in combat; clicking a potion drinks it and closes the bar.
- [ ] The button again closes an open bar in combat.
- [ ] Opening Elixirs in combat closes Potions.
- [ ] After drinking the last of a stack in combat, its entry stays, reads 0 and is grey; when the
      fight ends and the bar is opened, that entry is gone.
- [ ] Drinking a potion starts the cooldown sweep on every potion entry that shares it.
- [ ] A bar left open when combat ends drops the used-up entries.
- [ ] Escape in combat does not try to close a bar (no "action blocked" error).
- [ ] Bandages and Scrolls also open and work in combat.
- [ ] The Potions macro on two bars: opened from the second out of combat, then combat starts, it
      opens on the second in combat too.
- [ ] Same with "Cast action keybinds on key press" both on and off: one press opens once.

## Combat edge cases

- [ ] `/reload` while in combat: no Lua error; once the fight ends, every button works.
- [ ] Learning a potion mid-fight (loot one): it is not on the bar until combat ends (expected).
```

- [ ] **Step 5: Write `README.md`**

```markdown
# Goblin Flyout

A World of Warcraft addon for **WoW Forever** (interface 16001). Seven buttons for your stock
Blizzard action bars, each opening a small bar built from Blizzard's own action button:

| Button | Opens | In combat |
|---|---|---|
| Professions | your crafting professions | no |
| Food | the food in your bags | no |
| Drink | the drinks in your bags | no |
| Potions | your potions | yes |
| Elixirs | your elixirs and flasks | yes |
| Bandages | your bandages | yes |
| Scrolls | your scrolls | yes |

Items are listed best first (highest item level), one entry per item with its count. In combat
a bar shows what you had when the fight began; used-up items grey out until it ends.

## Install

Copy the `GoblinFlyout` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\` and
restart the game.

## Use

Click the bomb on the minimap (or type `/gf`) and drag a kind's icon onto an action bar. Each
kind has its own Horizontal/Vertical button in that window.

| Command | Does |
|---|---|
| `/gf` | Opens the Goblin Flyout window |
| `/gf <kind>` | Puts that kind's button on your cursor (`/gf potions`) |
| `/gf layout <kind>` | Flips that kind between Horizontal and Vertical |
| `/gf probe` | Prints what the addon detects, for bug reports |

Stock Blizzard bars only; Bartender, Dominos and other bar addons are not supported.

## Development

See `CLAUDE.md` for the rules, test and lint commands, and `docs/` for the design spec, plan and
in-game test checklist.
```

- [ ] **Step 6: Make the deploy junction**

```powershell
New-Item -ItemType Junction -Path "D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinFlyout" -Target "D:\GoblinFlyout\GoblinFlyout"
Get-ChildItem "D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinFlyout" | Select-Object Name
```

Expected: the ten `.lua` files and `GoblinFlyout.toc` listed. Tell the owner: a new addon needs a **full client restart**, not `/reload`.

- [ ] **Step 7: Commit**

```powershell
git add GoblinFlyout/Core.lua GoblinFlyout/GoblinFlyout.toc docs/manual-test-checklist.md README.md
git commit -m "Core: setup, events and /gf; TOC, README and the in-game checklist" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Hand over to the owner**

Ask the owner to restart the client, run `/gf probe`, and walk `docs/manual-test-checklist.md`. Fix what they report one item at a time (systematic-debugging), adding what they confirm to `CLAUDE.md`'s client facts.
