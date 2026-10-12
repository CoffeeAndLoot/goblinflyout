# Goblin Flyout — Design

Date: 2026-10-12
Client: WoW Forever, interface 16001 (Classic data on the 12.x engine, game type `camelot`),
build 1.60.1.70338 in game. Source reference: `D:\wow-api\1.60.1.70291\Interface\AddOns`.
Base: `D:\ProfessionFlyout` (left as it is; Goblin Flyout is a new addon that grows from it).

## Goal

Seven buttons on stock Blizzard action bars, each opening a small bar ("flyout") of things to
use: the player's crafting professions, and the food, drink, potions, elixirs, bandages and
scrolls in their bags. Consumables are listed best first. Potions, elixirs, bandages and scrolls
open and work in combat. It looks and feels like stock Blizzard UI.

## Nomenclature

- **Kind**: one of the seven flyouts (professions, food, drink, potions, elixirs, bandages, scrolls).
- **Button**: a kind's macro, placed by the player in a stock Blizzard action slot.
- **Bar**: our flyout of entries that opens next to the button.
- **Entry**: one profession or one item on a bar.
- **Host**: the stock action button the bar opened from.
- **Toggle**: the hidden frame a button's macro clicks (`GoblinFlyout<Key>`).
- **Plain** / **secure**: the two bar styles (see Bar.lua).
- **Window**: Goblin Flyout's own options window.

## Facts settled in game (2026-10-12, build 70338)

- **Secure snippets work.** `SecureHandlerExecute` on a `SecureHandlerBaseTemplate` frame ran
  and set an attribute. The 69913 bug (`loadstring_untainted` nil) came from
  `Blizzard_EnvironmentCleanup.toc` listing its dependency on `Blizzard_RestrictedAddOnEnvironment`
  for `classic, standard` only, so on `camelot` the cleanup could load first and nil the
  function before `RestrictedExecution.lua` captured it. Build 70009 made it an unconditional
  `OptionalDep`; 70291 source and 70338 in game both work.
- **Consumables carry modern subclasses** (`C_Item.GetItemInfo` classID 0):
  1 Potion, 2 Elixir, 4 Scroll, 5 Food & Drink (seen in bags). 3 Flask and 7 Bandage follow
  the same table (not yet seen in game; `/gf probe` reports them).
- **Food vs drink is the item's spell**: `C_Item.GetItemSpell` gives `Food` (433) or `Drink`
  (430, 431) on subclass 5.

## Scope

In:
- The seven kinds below, each its own button, macro and bar.
- Per-kind layout: Horizontal (default) or Vertical.
- Own options window with each kind's icon (drag or click it to pick up the button), name and
  a layout button that flips Horizontal/Vertical. A hand-made minimap button opens it.
- Potions, elixirs, bandages and scrolls open and are usable in combat.
- Stack counts and cooldown sweeps on item entries.

Out (YAGNI):
- An on/off switch per kind: a kind costs nothing until its button is on a bar.
- Bartender, Dominos, or any bar addon. Libraries (LibDBIcon, LibStub).
- Changing which entries a bar holds during combat (the client forbids it).
- Player-editable entries, favourites, hiding single items.

## Kinds

| key | Macro name | Source | Filter (classID 0) | In combat |
|---|---|---|---|---|
| professions | Professions | professions | — (Professions.lua rules) | no |
| food | Food | bags | subclass 5 and spell is Food or neither | no |
| drink | Drink | bags | subclass 5 and spell is Drink or neither | no |
| potions | Potions | bags | subclass 1 | yes |
| elixirs | Elixirs | bags | subclass 2 or 3 | yes |
| bandages | Bandages | bags | subclass 7 | yes |
| scrolls | Scrolls | bags | subclass 4 | yes |

"Neither" means a subclass-5 item whose spell is neither Food nor Drink (Refreshment-style, or
no spell): it shows on both bars. Food and Drink are compared with the client's own names for
spells 433 and 430 (`C_Spell.GetSpellName`), so this works in any locale.

Toggle frame `GoblinFlyout<Key>` (`GoblinFlyoutPotions`), macro body `/click GoblinFlyout<Key>`.
Macro icons: Professions `INV_Misc_Book_09`, Food `INV_Misc_Food_15`, Drink `INV_Drink_07`,
Potions `INV_Potion_51`, Elixirs `INV_Potion_45`, Bandages `INV_Misc_Bandage_15`,
Scrolls `INV_Scroll_03`. Each is confirmed by the manual checklist; one that does not draw is
swapped for another stock icon.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Structure | One generic bar engine plus a kinds table (data) | DRY: one bar, one set of bugs; a new kind is a row plus a filter. |
| Button in a slot | Account macro per kind, found by its **body** | Slots hold macros; keeps keybinds, paging, `/reload`. A player's own "Potions" macro is never touched. |
| Combat | Secure style (snippet toggle) for potions, elixirs, bandages, scrolls; plain style (out of combat only) for the rest | Snippets work on 70338. Food, drink and crafting can't be used in combat anyway. |
| Sort | Item level desc, then required level desc, then name A–Z | In game, item level rises with tier; required level sits at 1 or 5 across tiers. |
| Stacks | One entry per item ID, count summed over bags | One click uses one; the count shows how many are left. |
| Options UI | Own movable window; Settings page holds one "Open Goblin Flyout" button | Sits beside the bars while dragging icons; the big Settings panel covers the screen. |
| Minimap | Hand-made button | No libraries; Blizzard's addon compartment is Mainline-only (`Blizzard_Minimap\Mainline\AddonCompartment.xml`). |

## Layout

```
D:\GoblinFlyout\
  GoblinFlyout\
    GoblinFlyout.toc   ## Interface: 16001, SavedVariables: GoblinFlyoutDB
    API.lua            the only Blizzard caller; every call through attempt(); owns the event frame
    Kinds.lua          pure: the seven kinds as data, in window order
    Professions.lua    pure: copied from ProfessionFlyout, unchanged in behaviour
    Items.lua          pure: raw bag items -> one kind's sorted entries
    Options.lua        SavedVariable shape; stub Settings page
    Macro.lua          find / create / pick up a kind's macro
    Bar.lua            the bar engine, plain and secure styles
    Window.lua         the options window
    MinimapButton.lua  the minimap button (not Minimap.lua: Minimap is Blizzard's global frame)
    Core.lua           glue: events, /gf
  docs\  test\  CLAUDE.md  README.md  .luacheckrc  .luarc.json  .gitignore
```

Conventions carry over from ProfessionFlyout: `local _, ns = ...` in every file, each file
publishes `ns.<Name>`; pure modules touch no Blizzard global at file load; no libraries; zero
luacheck and lua-language-server warnings; calendar versions in the TOC only. Deploy is a
junction into `D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinFlyout`.

## Components

### Kinds.lua (pure)

`Kinds.LIST`: the seven rows in the order above, each
`{ key, label, macroName, icon, source = "professions" | "bags", secure = bool, accepts = function(item, names) }`.
`Kinds.ByKey(key)` returns a row or nil. `accepts` gets a raw item and the localized
`{ food, drink }` spell names; Professions has no `accepts`.

### Professions.lua (pure)

Copied from ProfessionFlyout: `Pick(raw)` and `Entries(raws)` as there (Mining opens Smelting
2656; otherwise the first non-passive spell where `CanTradeSkillShowCraftingUI` is true; name
match only when the client gives no answer). Its unit tests come over too.

### Items.lua (pure)

Input: raw bag items `{ itemID, name, icon, count, classID, subclassID, itemLevel, minLevel, spellName }`.
`Items.Entries(raws, kind, names)`:
1. Skip anything that is not a table, has no numeric `itemID`, or has no `name` (uncached).
2. Keep items `kind.accepts(item, names)` passes.
3. Merge by `itemID`, summing `count`.
4. Sort: `itemLevel` desc, `minLevel` desc, `name` asc (missing numbers count as 0).

Output: `{ itemID, name, icon, count }`, never nil.

### API.lua

The only file touching Blizzard globals; every call through `attempt()` (pcall, error kept per
call name for the probe). Carries over ProfessionFlyout's `InCombat`, `RawProfessions`,
`MacroButtons`, `FindMacro`, `AccountMacrosFull`, `CreateMacro`, `PickupMacro`, `OnEvents`,
`Errors`, and adds:
- `BagItems()`: bags 0..4 (`C_Container.GetContainerNumSlots`, `GetContainerItemInfo` for
  itemID and stack count), each item enriched with `C_Item.GetItemInfo` (name, icon, itemLevel,
  minLevel, classID, subclassID) and `C_Item.GetItemSpell` (spellName). Uncached items come
  back without a name.
- `FoodDrinkNames()`: `{ food = C_Spell.GetSpellName(433), drink = C_Spell.GetSpellName(430) }`.
- `ItemCount(itemID)`, `ItemCooldown(itemID)` for the drawn count and sweep.
- `SnippetsWork()`: runs one `SecureHandlerExecute` on a scratch frame, true if it set its attribute.

### Macro.lua

As ProfessionFlyout's, keyed by kind: `Macro.Body(kind)`, `Macro.IsOurs(kind, body)`,
`Macro.Index(kind)`, `Macro.Ensure(kind)` (create if missing, or nil and `"full"` / `"failed"`),
`Macro.PickUp(kind)` (out of combat only: Ensure then `PickupMacro`; returns a message on
refusal). Matching is by body only.

### Bar.lua

One bar frame per kind, made on first use (`GoblinFlyout<Key>Bar`); only one bar is open at a
time. Pure parts: `Bar.Positions(n, size, gap, layout)`, `Bar.PickHost(hosts, isUnderMouse)`,
`Bar.ENTRY_TEMPLATES` (`"ActionButtonTemplate, SecureActionButtonTemplate"`, secure last),
`Bar.ENTRY_ATTRIBUTES` (`useOnKeyDown = false`; plus `type = "spell"` / `type = "item"`).

**Plain style** (professions, food, drink): as ProfessionFlyout. Hidden insecure toggle;
`OnClick` refuses in combat, closes if open, picks the host (`MacroButtons` + `PickHost`),
rebuilds entries, sizes/scales/spaces them from the host, anchors and shows. Closes on entry
`PostClick`, toggle click, Escape (`UISpecialFrames`), `GLOBAL_MOUSE_DOWN` outside bar and host,
`PLAYER_REGEN_DISABLED`, `ACTIONBAR_PAGE_CHANGED`. Food and drink entries are `type = "item"`,
`item = "item:<id>"`.

**Secure style** (potions, elixirs, bandages, scrolls):
- Toggle: `SecureHandlerClickTemplate` button; the bar is a `SecureHandlerBaseTemplate` frame
  passed in with `SetFrameRef`. `_onclick` hides the bar if shown; otherwise hides the other
  secure bars (frame refs) and shows its own when its `entries` attribute is above 0.
- Rebuild (insecure, out of combat only), at two moments:
  1. Toggle `PreClick` when not in combat and the bar is closed: host by mouse, rebuild entries,
     layout, anchor, set `entries`. The snippet then shows it.
  2. `PLAYER_REGEN_DISABLED` (lockdown begins after it): every secure bar is rebuilt from the
     bags and anchored to its last host, or the first visible host if it has none.
- Entries: `type = "item"`, `item = "item:<id>"`. Each entry's click is wrapped with
  `SecureHandlerWrapScript` so a post-snippet hides the bar (in or out of combat).
- Drawn, never secure, so it updates in combat: stack count on `BAG_UPDATE_DELAYED`, cooldown
  sweep on `BAG_UPDATE_COOLDOWN`; count 0 desaturates the icon.
- Out of combat it also closes on Escape, a click outside, and `ACTIONBAR_PAGE_CHANGED`. Its name
  is added to `UISpecialFrames` on `PLAYER_REGEN_ENABLED` and removed on `PLAYER_REGEN_DISABLED`,
  so Escape never tries to hide a protected frame in combat.
- If `API.SnippetsWork()` is false at login, secure kinds run in plain style and Core says so
  once.

**Both styles:** entry tooltips are the real item (`GameTooltip:SetItemByID`) or the profession
name and `rank/maxRank`. Bars are clamped to the screen; Horizontal is a row above the host,
Vertical a column up from it. Toggle returns a message string for Core to say, never prints.

Messages: "Can't open professions in combat.", "Put the Potions button on an action bar (/gf).",
"No potions in your bags." (each with the kind's label), "No crafting professions known."

### Options.lua

`GoblinFlyoutDB = { layouts = { <key> = "horizontal" | "vertical" }, minimap = { angle = 225 }, window = { point, x, y } }`.
`Options.Init(db)` fills and repairs every field in place (unknown keys/values reset; default
layout Horizontal for every kind). `Options.Other(layout)`. `Options.Register(openWindow)` adds
Esc > Options > AddOns > Goblin Flyout with one button, "Open Goblin Flyout"; false when the
client's Settings UI lacks a piece.

### Window.lua

`GoblinFlyoutWindow`: a movable `ButtonFrameTemplate` window (`Blizzard_SharedXML\Mainline\
SharedUIPanelTemplates.xml`, which camelot loads through `[Family]`), title "Goblin Flyout", added to
`UISpecialFrames`, position saved in `GoblinFlyoutDB.window`. Seven rows in `Kinds.LIST` order:
- the kind's icon as a button: `OnDragStart` and `OnClick` call `Macro.PickUp(kind)`; its
  tooltip says "Drag to an action bar";
- the label;
- a `UIPanelButtonTemplate` button reading "Horizontal" or "Vertical" that flips
  `GoblinFlyoutDB.layouts[key]` on click; a change closes that kind's bar if open (out of combat).
Pickup refuses in combat (CreateMacro may be needed); the window says why in chat.

### MinimapButton.lua

`GoblinFlyoutMinimapButton`, parented to `Minimap`, stock minimap-button art
(`MiniMap-TrackingBorder` ring, icon `INV_Misc_Bomb_04`, confirmed by the checklist). Left-click toggles the window;
drag moves it round the rim and saves `minimap.angle`. Tooltip: "Goblin Flyout" / "Click for
options, drag to move". Pure: `MinimapButton.Position(angle, radius)` → x, y offset from the centre, and `MinimapButton.Angle(dx, dy)` → degrees 0..360.

### Core.lua

SavedVariable via `Options.Init`; registers the Settings page, window and minimap button on
`PLAYER_LOGIN`; makes every kind's toggle; wires events to `Bar`. Every handler runs behind
`guard(label, ...)`: one chat line per label per session. Messages print as
`|cffffd100Goblin Flyout|r ...`.

Slash `/gf` and `/goblinflyout`:

| Command | Does |
|---|---|
| `/gf`, `/gf options` | Toggles the window |
| `/gf <kind>` | Puts that kind's button on the cursor (makes the macro if needed); out of combat |
| `/gf layout <kind>` | Flips that kind's layout |
| `/gf probe` | Professions as `/pf probe` did; every bag consumable with subclass, spell and the kinds it lands in; each kind's macro and visible slot count; snippets working or not; `attempt()` errors |

## Error handling

- Every Blizzard call through `attempt()`; a throw or missing API is "no answer", never an error.
- Every Core handler behind `guard()`.
- An uncached item is skipped until the next rebuild.
- Nothing secure is created, changed or shown by insecure code in combat; secure changes happen
  out of combat or at `PLAYER_REGEN_DISABLED`.
- Snippets broken on a future build: secure kinds fall back to plain style, said once.

## Testing

- Unit tests through Python `lupa` (`test/run.lua`, the ProfessionFlyout harness): `Kinds`
  (seven rows, unique keys and toggle names, every filter), `Items` (filters, Food/Drink/neither,
  stack merge, sort and ties, junk input), `Professions` (carried over), `Macro.IsOurs`,
  `Bar.Positions/PickHost/ENTRY_*`, snippet text the restricted environment accepts, `Options.Init/Other`, `MinimapButton.Position/Angle`.
- `docs/manual-test-checklist.md`: an in-game entry for every UI path: each kind opens and uses
  an entry; potions/elixirs/bandages/scrolls open and use in combat; count drops and greys at 0;
  cooldown sweep; Escape in and out of combat; click outside; page change; per-kind layout; the
  window, dragging and clicking each icon to a slot; the minimap button and its drag; each
  macro icon draws; `/gf probe`.
- luacheck and lua-language-server at zero warnings.

## Repo

`git init` in `D:\GoblinFlyout`; commit after each change as `Area: plain sentence`; no remote
and no push until the owner asks.
