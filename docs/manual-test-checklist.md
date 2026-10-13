# Manual test checklist

In-game checks for what unit tests cannot reach. Only the owner runs the client.
Mark each with the build and date when walked; `[-]` is skipped by choice, with the reason.

## Install

- [ ] After the junction and a **full client restart**, Goblin Flyout is listed and enabled in
      the AddOns list with its round GF icon; no Lua error on login.
- [ ] `/gf probe`: one line per profession ending `-> <spell> <id>` as ProfessionFlyout showed;
      food and drink spell names; every bag consumable with its subclass, spell and kinds
      (Minor Healing Potion -> potions, Tough Jerky -> food, Ice Cold Milk -> drink, Elixir of
      Minor Defense -> elixirs, Scroll of Protection -> scrolls); "secure snippets work"; no "threw:".
- [ ] A bandage and a flask (if one can be had) report subclass 7 and 3 and land in bandages and elixirs.

## Window and minimap

- [ ] A round minimap button sits on the rim: gold "GF" on an oxblood disc with a gold rim, no
      extra border ring, sharp (not blurry). Hovering says "Goblin Flyout / Click for options, drag
      to move. / Time is money, friend." (the last line gold).
- [ ] Dragging it slides it round the rim; `/reload`: it stays where it was put.
- [ ] Clicking it opens the window; clicking again, or Escape, closes it.
- [ ] `/gf` and `/gf options` open the window too.
- [ ] Esc > Options > AddOns lists "Goblin Flyout" with a gold flat "Open Goblin Flyout" button
      that closes the options and opens the window.
- [x] The window looks like GoblinQuest's Main Menu: dark, a thin gold edge along the top, a 1 px
      border; "Goblin Flyout" in gold with "Time is money, friend." under it; a square close button
      with an X glyph (not the letter X) at the right of the header; no Blizzard window art.
      (Owner's screenshot 2026-10-12, the seven-row build: all seven stock icons drew.)
- [x] Below, an inset list of eight rows: Professions, Food, Drink, Food & Drink, Potions,
      Elixirs, Bandages, Scrolls, each with its icon (book, food, drink, fork and knife, potion,
      elixir, bandage, scroll; no red question mark) in a thin outline, its name, and a
      Horizontal | Vertical switch with Horizontal gold. Thin rules between rows; names, "Food &
      Drink" too, don't run into the switch. A dim hint at the bottom: "Drag an icon onto an
      action bar to place its button."
- [x] A thin gold bracket in the left gutter joins the Food, Drink and Food & Drink rows: one line
      down from Food's middle to Food & Drink's, with a short tick into each of the three icons.
- [ ] Hovering an icon tints it gold and shows "<Kind> / Drag to an action bar. / Right-click to
      change its icon."
- [x] Right-clicking a row's icon opens Esc > Macros on that kind's macro (General tab, it
      selected) with the "Change Name/Icon" picker open; a kind with no macro yet gets one first.
- [ ] Picking an icon there and pressing Okay changes the button on the action bar, and the
      Goblin Flyout row shows the new icon at once (window left open) and after `/reload`.
- [ ] Renaming the macro there too: the button keeps working; after `/reload` it is back to its
      short name, with the picked icon kept.
- [ ] Right-clicking an icon in combat: "Can't do that in combat."
- [ ] The close button closes it.
- [ ] The window drags by its header (not by the list); `/reload`: it reopens exactly where it
      was left, not clamped to an edge.
- [ ] Dragging an icon onto an action slot places that kind's button; Esc > Macros > General shows
      the macro with the same icon and its short name: Prof, Food, Drink, Meals, Potion, Elixir,
      Aid or Scroll. Each label fits under its button, uncut.
- [x] Macros made by the first build (named "Professions", "Food & Drink" ...) are renamed to the
      short names at login; the buttons already placed keep working and show the short label.
- [ ] Clicking an icon puts the button on the cursor; clicking a slot places it.
- [ ] Doing either again makes no second macro.
- [ ] Clicking Vertical lights Vertical gold and Horizontal quiet, and the next open is a column;
      clicking Horizontal turns it back. `/reload` keeps the choice.
- [ ] `/gf layout potions` flips Potions and says so; an open window's switch agrees.
- [ ] In combat: dragging or clicking an icon says "Can't do that in combat."
- [ ] `/gf potions` puts the Potions button on the cursor and says to click a slot.
- [ ] The window's footer has a "Show minimap button" check box, gold inside while shown.
      Clicking it hides the minimap button and empties the box; again brings it back. `/reload`
      keeps the choice. `/gf minimap` does the same and says so; an open window's box agrees.
- [ ] With the minimap button hidden, `/gf` and Esc > Options > AddOns > Goblin Flyout still open
      the window.

## Plain bars (Professions, Food, Drink, Food & Drink)

- [ ] Professions opens exactly as ProfessionFlyout's did (same entries, tooltips, windows).
- [ ] Food opens a row of the food in the bags, best item level first; each entry shows its
      stack count and the item's own tooltip; clicking one eats it and closes the bar.
- [ ] Drink likewise for drinks.
- [ ] Dragging Food & Drink's icon to a slot makes a "Meals" macro with the fork-and-knife
      icon. Its bar shows every food first (best item level first), then every drink (best
      first); with Tough Jerky, Forest Mushroom Cap, Ice Cold Milk and Crisp Spring Water in the
      bags: Forest Mushroom Cap, Tough Jerky, Ice Cold Milk, Crisp Spring Water. An item that is
      both food and drink shows once, among the food.
- [ ] With Food, Drink and Food & Drink all placed, each opens its own bar; opening one closes
      the others. Its layout switch works on its own.
- [ ] No food or drink in the bags: "No food or drink in your bags." In combat: "Can't open food &
      drink in combat."
- [ ] With a stack split across two bags, one entry shows the total.
- [ ] Opening Food while Drink is open closes Drink.
- [ ] Escape, a click elsewhere, and paging the main bar each close it.
- [ ] Entering combat with it open closes it, with no "action blocked" error.
- [ ] Clicking the button in combat: "Can't open food in combat." (and "professions", "drink").
- [ ] No food in the bags: "No food in your bags."
- [ ] `/click GoblinFlyoutFood` with the macro on no bar: "Put the Food button on an action bar (/gf food)."

## Travel

- [x] After a **full client restart** (Travel.lua is new), the window has a ninth row, Travel,
      under Scrolls, with the Hearthstone icon; dragging it places a "Travel" macro.
- [x] On the druid, Travel opens above its button: Hearthstone first (count 1), then Teleport:
      Moonglade; the button's label reads "Travel", uncut. (Owner's screenshot 2026-10-12.)
- [ ] Hovering each shows its own tooltip (the Hearthstone says where it is set).
- [x] After a hearth, the Hearthstone entry shows its cooldown sweep and time left (13m seen).
- [ ] Clicking the Hearthstone starts the hearth cast and closes the bar.
- [ ] Clicking Teleport: Moonglade casts it and closes the bar.
- [ ] Clicking the Travel button in combat: "Can't open travel in combat."
- [ ] `/gf probe` ends with "Probe: travel -> 6948 Hearthstone, 18960 Teleport: Moonglade".
- [-] A mage: teleports, then portals, each in city order. (Not walked: no mage of that level yet.)
- [-] A shaman: Astral Recall after the Hearthstone, with its cooldown sweep after a cast. (Not
      walked: no shaman yet.)

## Secure bars (Potions, Elixirs, Bandages, Scrolls)

Out of combat:
- [ ] Potions opens above its slot, best potion first (Minor Rejuvenation before Minor Healing),
      sized and spaced like the bar; each entry has its count and the item's tooltip.
- [ ] Clicking a potion drinks it and closes the bar; the count drops next time.
- [ ] Vertical layout: a column straight up from the slot.
- [ ] Escape, a click elsewhere, and paging the main bar close it.
- [ ] Opening Elixirs while Potions is open closes Potions.
- [x] No bandages: "No bandages in your bags."

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
