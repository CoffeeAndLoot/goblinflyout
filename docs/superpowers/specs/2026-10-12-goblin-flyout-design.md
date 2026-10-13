# Goblin Flyout — Design

Date: 2026-10-12
Client: WoW Forever, interface 16001 (Classic data on the 12.x engine, game type `camelot`),
build 1.60.1.70338 in game. Source reference: `D:\wow-api\1.60.1.70291\Interface\AddOns`.
Base: `D:\ProfessionFlyout` (left as it is; Goblin Flyout is a new addon that grows from it).

## Goal

Nine buttons on stock Blizzard action bars, each opening a small bar ("flyout") of things to
use: the player's crafting professions, and the food, drink, potions, elixirs, bandages and
scrolls in their bags. Consumables are listed best first. Potions, elixirs, bandages and scrolls
open and work in combat. It looks and feels like stock Blizzard UI.

## Nomenclature

- **Kind**: one of the nine flyouts (professions, food, drink, food & drink, potions, elixirs, bandages, scrolls, travel).
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
- The nine kinds below, each its own button, macro and bar.
- Per-kind layout: Horizontal (default) or Vertical.
- Own options window with each kind's icon (drag or click it to pick up the button), name and
  a Horizontal | Vertical switch. A hand-made minimap button opens it. Both wear the Goblin look
  (amended 2026-10-12, see Look.lua below).
- Potions, elixirs, bandages and scrolls open and are usable in combat.
- Stack counts and cooldown sweeps on item entries.

Out (YAGNI):
- An on/off switch per kind: a kind costs nothing until its button is on a bar.
- Deleting a macro when its button leaves the bars (owner's ruling 2026-10-12). Account macros
  are shared by every character but only this character's bars are visible, a button being
  moved is briefly on no slot, and a deleted macro loses the player's picked icon. Blizzard keeps
  macros off-bar too. A macro the player deletes by hand is remade on the next drag.
- Bartender, Dominos, or any bar addon. Libraries (LibDBIcon, LibStub).
- Changing which entries a bar holds during combat (the client forbids it).
- Player-editable entries, favourites, hiding single items.

## Kinds

| key | Label (macro name) | Source | Filter (classID 0) | In combat |
|---|---|---|---|---|
| professions | Professions (Prof) | professions | — (Professions.lua rules) | no |
| food | Food (Food) | bags | subclass 5 and spell is Food or neither | no |
| drink | Drink (Drink) | bags | subclass 5 and spell is Drink or neither | no |
| fooddrink | Food & Drink (Meals) | bags | anything food or drink takes; food (and neither) first, then drink | no |
| potions | Potions (Potion) | bags | subclass 1 | yes |
| elixirs | Elixirs (Elixir) | bags | subclass 2 or 3 | yes |
| bandages | Bandages (Aid) | bags | subclass 7 | yes |
| scrolls | Scrolls (Scroll) | bags | subclass 4 | yes |
| travel | Travel (Travel) | travel | Travel.lua's list: what the player knows or carries | no |

The label is what the window and chat say. The macro name (amended 2026-10-12) is what the action bar shows under the button, which cuts off past about 6 characters; so it is short. Setup renames a macro an earlier build made under its label (`Macro.Tidy`, by body, out of combat).

"Neither" means a subclass-5 item whose spell is neither Food nor Drink (Refreshment-style, or
no spell): it shows on both bars. Food and Drink are compared with the client's own names for
spells 433 and 430 (`C_Spell.GetSpellName`), so this works in any locale.

Food & Drink (amended 2026-10-12, the owner's ask) is Food and Drink on one bar: food and
"neither" items first, then drink, each half best first; an item that is both shows once. Its
empty message is "No food or drink in your bags." There is no link setting: like every kind it
costs nothing until its button is placed. The window joins its row to Food and Drink with a gold
bracket (the row's `joins`).

Toggle frame `GoblinFlyout<Label>` with only letters and digits kept (`GoblinFlyoutPotions`,
`GoblinFlyoutFoodDrink`), macro body `/click` plus that name.
Macro icons: Professions `INV_Misc_Book_09`, Food `INV_Misc_Food_15`, Drink `INV_Drink_07`,
Food & Drink `INV_Misc_Fork&Knife`, Potions `INV_Potion_51`, Elixirs `INV_Potion_45`, Bandages
`INV_Misc_Bandage_15`, Scrolls `INV_Scroll_03`. Each is confirmed by the manual checklist; one
that does not draw is swapped for another stock icon.

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
    Kinds.lua          pure: the nine kinds as data, in window order
    Professions.lua    pure: copied from ProfessionFlyout, unchanged in behaviour
    Items.lua          pure: raw bag items -> one kind's sorted entries
    Travel.lua         pure: the Hearthstone and travel spells -> the Travel bar's entries
    Look.lua           the Goblin look: palette, fonts, flat pieces (from GoblinQuest)
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

`Kinds.LIST`: the nine rows in the order above, each
`{ key, label, macroName, icon, source = "professions" | "bags", secure = bool, accepts = function(item, names) }`.
`Kinds.ByKey(key)` returns a row or nil. `accepts` gets a raw item and the localized
`{ food, drink }` spell names; Professions has no `accepts`.

### Professions.lua (pure)

Copied from ProfessionFlyout: `Pick(raw)` and `Entries(raws)` as there (Mining opens Smelting
2656; otherwise the first non-passive spell where `CanTradeSkillShowCraftingUI` is true; name
match only when the client gives no answer). Its unit tests come over too.

Amended 2026-10-12: `Professions.Indices(...)` keeps every profession `GetProfessions()` returns,
in Blizzard's tab order (prof1, prof2, First Aid, Fishing, Cooking on Camelot), as the Camelot
Professions frame's `RefreshRightTabs` does. Fishing is no longer dropped: WoW Forever gives it a
crafting window, opened by Bait and Tackle (1278067, `CanTradeSkillShowCraftingUI` true); its own
spell Fishing (7620) casts a line and says false (both seen in game), so `Pick` takes Bait and
Tackle, as it takes Tanning for Skinning.

### Items.lua (pure)

Input: raw bag items `{ itemID, name, icon, count, classID, subclassID, itemLevel, minLevel, spellName }`.
`Items.Entries(raws, kind, names)`:
1. Skip anything that is not a table, has no numeric `itemID`, or has no `name` (uncached).
2. Keep items `kind.accepts(item, names)` passes.
3. Merge by `itemID`, summing `count`.
4. Sort: `itemLevel` desc, `minLevel` desc, `name` asc (missing numbers count as 0).

Output: `{ itemID, name, icon, count }`, never nil.

### Travel.lua (pure; amended 2026-10-12, the owner's ask)

`Travel.ORDER`, then `Travel.Entries(known, carried)` keeps only what the player has, in this
order: the Hearthstone (item 6948); Teleport: Moonglade (18960, druid) and Astral Recall (556,
shaman); the mage teleports (3561, 3562, 3565, 3567, 3563, 3566) and then the portals (10059,
11416, 11419, 11417, 11418, 11420), both in the city order Stormwind, Ironforge, Darnassus,
Orgrimmar, Undercity, Thunder Bluff. Classic IDs: WoW Forever kept Moonglade's 18960 (seen in game
2026-10-12); the mage IDs are unwalked until a mage is played. Known spells come from
`C_SpellBook.IsSpellKnown`, the Hearthstone from the bag count; names and icons from the client.
Entries carry their own `type` (`item` or `spell`): the bar sets each entry's secure type on
every rebuild (`Bar.ActionType`). Spell entries show the spell tooltip and its cooldown sweep
(`C_Spell.GetSpellCooldown`, refreshed on `SPELL_UPDATE_COOLDOWN`). Out of combat only.

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

`GoblinFlyoutDB = { layouts = { <key> = "horizontal" | "vertical" }, minimap = { angle = 225, hide = false }, window = { point, relativePoint, x, y } }`.
`Options.Init(db)` fills and repairs every field in place (unknown keys/values reset; default
layout Horizontal for every kind). `Options.Other(layout)`. `Options.Register(openWindow)` adds
Esc > Options > AddOns > Goblin Flyout with one button, "Open Goblin Flyout"; false when the
client's Settings UI lacks a piece.

### Look.lua (amended 2026-10-12: the GoblinQuest design)

GoblinQuest's `Look.lua`, trimmed to what this addon draws: its clean-look palette (window,
inset, raised, divider, line, dim, text, gold, ink), the game's two fonts (`FRIZQT__`, `ARIALN`),
1-pixel outlines, flat buttons (raised / quiet / gold) and an outlined glyph button. Plain frames
and colour textures, **no Blizzard frame templates**, so a template renamed by a beta patch
cannot break the window. Pure: `Look.RGB(name)` and `Look.File(name, pixels)`, which picks the
smallest of the 32/64/128 px copies at least as big as the glyph is drawn (sharp 1080p to 4K;
64 when the client gives no screen size). Glyphs: `Media\icons\close-*.tga`, copied from
GoblinQuest. The flyout bars are not restyled: they stay Blizzard action buttons so they match
the bar they open from.

### Window.lua

`GoblinFlyoutWindow`: GoblinQuest's window chrome. A `window` fill, a `line` outline, a 2 px gold
top edge, and a header (drag handle) with "Goblin Flyout" in gold Friz 17, the tagline "Time is
money, friend." in dim Friz 10, and a close glyph button. Below it an inset well of nine rows
in `Kinds.LIST` order:
- the kind's macro icon (`Macro.Icon`: the player's pick, else the default; redrawn on
  `UPDATE_MACROS`) as a button: `OnDragStart` and left-click call `Macro.PickUp(kind)`;
  right-click (amended 2026-10-12) calls `Macro.Edit(kind)`, which makes the macro if missing and
  opens Blizzard's macro window on it with "Change Name/Icon" open. No picker or search of our
  own: the client lists icons only as file IDs (27,715 on 70338), so search would need a shipped
  name list, and the owner chose Blizzard's window. Its tooltip says "Drag to an action bar." /
  "Right-click to change its icon.";
- the label;
- a Horizontal | Vertical switch (two flat buttons, the current one gold) bound to
  `GoblinFlyoutDB.layouts[key]`; a change closes that kind's bar if open (out of combat).
A dim footer reads "Drag an icon onto an action bar to place its button." Added to
`UISpecialFrames`. On drag stop it re-anchors TOPLEFT to UIParent's BOTTOMLEFT where it sits and
saves `{ point, relativePoint, x, y }` in `GoblinFlyoutDB.window`. Pickup refuses in combat
(CreateMacro may be needed); the window says why in chat. The Settings page's "Open Goblin
Flyout" is a gold `Look.Button`.

### MinimapButton.lua

`GoblinFlyoutMinimapButton`, parented to `Minimap`, wearing `Media\icon.tga` (also the TOC's
`IconTexture`): GoblinQuest's icon recipe (`tools/make_icon.py`, Cinzel, SIL OFL) with "GF" on an
oxblood disc, picked by the owner 2026-10-12. The icon has its own gold rim, so no border art.
Left-click toggles the window; drag moves it round the rim and saves `minimap.angle`. Hidden when `minimap.hide` (the window's "Show minimap button" check box, or `/gf minimap`); `/gf` and the Settings page still open the window. Tooltip:
"Goblin Flyout" / "Click for options, drag to move." / "Time is money, friend." (gold). Pure:
`MinimapButton.Position(angle, radius)` → x, y offset from the centre, and
`MinimapButton.Angle(dx, dy)` → degrees 0..360.

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
| `/gf minimap` | Hides or shows the minimap button (amended 2026-10-12; also the window's check box) |
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
  (nine rows, unique keys and toggle names, every filter), `Items` (filters, Food/Drink/neither,
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
