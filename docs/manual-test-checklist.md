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
