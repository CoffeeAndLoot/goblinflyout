# Goblin Flyout

A World of Warcraft addon for **WoW Forever** (interface 16001). Nine buttons for your stock
Blizzard action bars, each opening a small bar built from Blizzard's own action button:

| Button | Opens | In combat |
|---|---|---|
| Professions | your crafting professions | no |
| Food | the food in your bags | no |
| Drink | the drinks in your bags | no |
| Food & Drink | your food, then your drinks, on one bar | no |
| Potions | your potions | yes |
| Elixirs | your elixirs and flasks | yes |
| Bandages | your bandages | yes |
| Scrolls | your scrolls | yes |
| Travel | your Hearthstone, Teleport: Moonglade, Astral Recall, mage teleports and portals | no |

Items are listed best first (highest item level), one entry per item with its count. In combat
a bar shows what you had when the fight began; used-up items grey out until it ends.

## Install

Copy the `GoblinFlyout` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\` and
restart the game.

## Use

Click the round GF button on the minimap (or type `/gf`) and drag a kind's icon onto an action bar. Each
kind has its own Horizontal/Vertical button in that window. Right-click a kind's icon to pick
a different icon in Blizzard's macro window; the button and the window follow it.

| Command | Does |
|---|---|
| `/gf` | Opens the Goblin Flyout window |
| `/gf <kind>` | Puts that kind's button on your cursor (`/gf potions`) |
| `/gf layout <kind>` | Flips that kind between Horizontal and Vertical |
| `/gf minimap` | Hides or shows the minimap button (also a check box in the window) |
| `/gf probe` | Prints what the addon detects, for bug reports |

Stock Blizzard bars only; Bartender, Dominos and other bar addons are not supported.

## Development

See `CLAUDE.md` for the rules, test and lint commands, and `docs/` for the design spec, plan and
in-game test checklist.
