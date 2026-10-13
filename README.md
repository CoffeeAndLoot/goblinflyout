# Goblin Flyout

*Time is money, friend.*

One button on your action bar, a whole bar of choices. Goblin Flyout gives you nine buttons for
your stock Blizzard action bars. Click one and a small bar flies out above it with everything of
that kind you have: your professions, your food, your potions, your ways home. Click what you
want and the bar folds away.

Made for **WoW Forever** (interface 16001).

![The Goblin Flyout window: nine flyouts, each with its icon and a Horizontal or Vertical switch](https://raw.githubusercontent.com/CoffeeAndLoot/goblinflyout/master/images/gallery/1-window.png)

## Features

- **Nine flyouts:** Professions, Food, Drink, Food & Drink, Potions, Elixirs, Bandages, Scrolls
  and Travel.
- **Potions, elixirs, bandages and scrolls work in combat.** Open the bar and drink mid-fight.
- **Best first.** Consumables are sorted by item level, so your strongest potion leads the bar.
  Split stacks show as one entry with the total count.
- **Looks like it belongs.** Every entry is Blizzard's own action button, matched to the size,
  scale and spacing of the bar it opens from, with stack counts and cooldown sweeps.
- **Finds everything on its own.** No dragging items in or out: the bars rebuild from your bags,
  spellbook and professions every time they open.
- **Horizontal or vertical,** chosen per button.
- **Your icons.** Right-click a button's icon in the Goblin Flyout window to pick any icon from
  Blizzard's macro window.
- **A minimap button** to open the window, which you can hide.

## The buttons

| Button | What its bar holds | In combat |
|---|---|---|
| Professions | Every profession with a crafting window, in the order of Blizzard's profession tabs. Mining opens Smelting; Skinning, Herbalism and Fishing open their WoW Forever windows. | No |
| Food | The food in your bags. | No |
| Drink | The drinks in your bags. | No |
| Food & Drink | Food first, then drinks, on one bar. | No |
| Potions | Your potions. | **Yes** |
| Elixirs | Your elixirs and flasks. | **Yes** |
| Bandages | Your bandages. | **Yes** |
| Scrolls | Your scrolls. | **Yes** |
| Travel | Your Hearthstone, Teleport: Moonglade, Astral Recall, and a mage's teleports and portals. | No |

![The Food & Drink bar open above its Meals button: food first, then drinks, with stack counts](https://raw.githubusercontent.com/CoffeeAndLoot/goblinflyout/master/images/gallery/2-food-and-drink.png)

![The Professions bar open above its Prof button, its tooltip showing Skinning 144/225](https://raw.githubusercontent.com/CoffeeAndLoot/goblinflyout/master/images/gallery/3-professions.png)

## Getting started

1. Click the round **GF** button on the minimap, or type `/gf`.
2. Drag any icon from the Goblin Flyout window onto an action bar slot.
3. Click that slot (or press its keybind) to open its bar. Click an entry to use it.

Each button is an ordinary account macro with a short name (Prof, Food, Drink, Meals, Potion,
Elixir, Aid, Scroll, Travel), so it keeps its keybind, works on every bar page and survives a
`/reload`. Only the buttons you place are made.

## The window

- **Icon:** drag it to an action bar to place the button; right-click it to change its icon.
- **Horizontal | Vertical:** which way that button's bar opens.
- **Show minimap button:** untick to hide it. `/gf` still opens the window, and so does
  Esc > Options > AddOns > Goblin Flyout.

![Blizzard's macro icon picker, opened by right-clicking a button's icon in the Goblin Flyout window](https://raw.githubusercontent.com/CoffeeAndLoot/goblinflyout/master/images/gallery/4-your-icons.png)

## In combat

The game only lets an addon change what is on a bar out of combat. So in a fight, a bar shows
what you had when the fight began. A potion you drink to the last greys out at 0 and drops off
when the fight ends; one you loot mid-fight joins the bar afterwards. Professions, food, drink
and travel open out of combat only, since you can't use them in a fight anyway.

## Commands

| Command | Does |
|---|---|
| `/gf` | Opens the Goblin Flyout window |
| `/gf <kind>` | Puts that button on your cursor, e.g. `/gf potions` |
| `/gf layout <kind>` | Flips that button between Horizontal and Vertical |
| `/gf minimap` | Hides or shows the minimap button |
| `/gf probe` | Prints what the addon detects; include it in bug reports |

Kinds: `professions`, `food`, `drink`, `fooddrink`, `potions`, `elixirs`, `bandages`,
`scrolls`, `travel`.

## Good to know

- Stock Blizzard action bars only. Bartender, Dominos and other bar addons are not supported.
- Deleting one of the macros does no harm; drag its icon from the window again and it comes back.
- Taking a button off your bars leaves its macro in place, since your other characters may still
  use it.

## Install

Install with the Wago app, or copy the `GoblinFlyout` folder into
`World of Warcraft\_classic_beta_\Interface\AddOns\` and restart the game.

## For developers

See `CLAUDE.md` for the rules, architecture, tests and lint commands, and `docs/` for the design
spec and the in-game test checklist.
