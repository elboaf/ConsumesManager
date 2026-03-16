# ConsumesManager

A consumables tracking and buff bar addon for World of Warcraft 1.12 (Vanilla), built on SuperWoW.

Forked from [Cinecom/ConsumesManager](https://github.com/Cinecom/ConsumesManager).

---

## Features

### Consumables Tracker
- Tracks consumables, food buffs, flasks, elixirs, poisons, and more across your inventory, bank, and mail
- Supports multiple characters and accounts
- Includes updated concoction recipes and an expanded item list with spell IDs for accurate buff detection

### Buff Bar
A dynamic action bar that displays your tracked consumables as clickable icons. Click an icon to use the item directly from your bags.

- **Multiple bars** — create as many bars as you need, each independently positioned and configured
- **Horizontal or vertical orientation** — toggle per bar in edit mode
- **Buff tracking** — icons show your current buff status using SuperWoW's updated `UnitBuff()` (spell ID based) and `GetWeaponEnchantInfo()` for weapon enchants
- **Cooldown display** — item cooldown sweeps shown directly on each icon
- **Buff timer** — remaining buff duration shown on buffed icons
- **Item count** — current bag count displayed on each icon
- **Glow reminder** — animated glow on icons where your buff is missing or expired (powered by bundled DoiteGlow)
- **Mouseover mode** — bars fade out and only appear when you mouse over them
- **Scalable** — resize all bars globally with `/cmbarscale`
- **Icon reordering** — drag icons left/right (or up/down in vertical mode) within a bar using swap buttons in edit mode
- **Per-bar show/hide** — hide individual bars without deleting them
- **Settings UI** — manage bars, mouseover mode, and scale from the Consumes Manager settings panel

---

## Requirements

- [SuperWoW](https://github.com/balakethelock/SuperWoW) — required for buff tracking via spell ID

---

## Installation

1. Download and extract to your `Interface/AddOns/` folder as `ConsumesManager`
2. The `Textures` folder must be present inside the addon folder (included)
3. Reload UI or log in

---

## Slash Commands

| Command | Description |
|---|---|
| `/cmbar` | Show or hide all bars |
| `/cmbaredit` | Toggle edit mode |
| `/cmbarscale <0.5–2.0>` | Set bar scale (e.g. `/cmbarscale 1.2`) |
| `/cmbarmouseover` | Toggle mouseover mode |
| `/cmbarreset` | Reset all bar positions to default |
| `/cmbarresetorder` | Reset all custom icon ordering |
| `/cmbarresetglow` | Reset all custom glow reminder settings |

---

## Edit Mode

Enter edit mode with `/cmbaredit` or via the Settings panel.

In edit mode:
- **Right-click** an icon to assign it to a different bar
- **`<>` swap buttons** appear between icons to reorder them
- **`^>` orientation button** appears on each bar to toggle horizontal/vertical layout
- Bar name labels are shown below each bar
- Bars with the hidden flag still appear so they can be managed

---

## Credits

- Original addon by [Cinecom](https://github.com/Cinecom/ConsumesManager)
- Glow effect by DoiteGlow :)
- Built for use with [SuperWoW](https://github.com/balakethelock/SuperWoW)


# Changelog

## 2.3.0

### Added: Auction House Shopping List

A new panel appears automatically below the aux auction house window whenever you open the AH, listing all your selected consumes and their crafting reagents.

#### Panel behaviour
- Anchors flush below the aux frame (or to the right of the vanilla AH frame as a fallback)
- A **[-] / [+]** button in the panel header collapses the panel down to a slim title bar when you need it out of the way — collapsed state persists while the AH is open
- Mousewheel and up/down arrow buttons scroll the list; a scrollbar provides drag-to-scroll
- Panel background is fully opaque for readability

#### Consume rows
- All selected consumes are listed, sorted by category order
- **White name + green count** — you have this consume somewhere across your tracked characters
- **Red name + red [0]** — you are missing this consume entirely
- **Left-click** — searches the AH for that consume
- **Right-click** — expands or collapses the crafting reagent list for that consume
- **[+] / [-]** indicator on the right shows whether a consume has reagents and whether they are expanded

#### Reagent sub-rows
- Expand per-consume to see each crafting mat indented below it, with quantity and item quality colour
- **Left-click** a reagent row to search the AH for that reagent

#### BOP / non-auctionable items (`bop = true`)
Items that cannot be purchased on the AH (e.g. Jujus, Blasted Lands turn-ins) are flagged with `bop = true` in the itemlist. The shopping list handles them specially:
- **Single-mat BOP** (e.g. Juju Flurry): left-click directly searches the one reagent (e.g. Frostsaber E'ko) rather than the item itself
- **Multi-mat BOP** (e.g. R.O.I.D.S.): left-click expands the reagent list; tooltip shows `Not on AH`
- Right-click expand/collapse works normally on all BOP items

#### aux integration
- Uses aux's internal `CLICK_LINK` API with a proper `item_info` object for item-link searches
- Falls back to walking the aux frame hierarchy to set the search box text and programmatically click the Search button for name-based searches (used for sentinels and uncached items)
- Vanilla AH (`BrowseName` + `AuctionFrameBrowse_Search`) as final fallback

#### MatIDs.lua (new file)
A lookup table mapping reagent names to item IDs, used to construct item links for the aux search API. Covers all crafting mats present in the itemlist including Turtle WoW custom items. Supports a `"search"` sentinel value for items with no single canonical ID (e.g. `["Bijou"] = "search"`), which triggers a plain name search instead of an item link lookup.

#### Concoction elixirs (edge case)
Concoctions use other tracked elixirs as reagents (e.g. Elixir of the Mongoose, Dreamshard Elixir). Rather than duplicating IDs in MatIDs, the shopping list resolves these at runtime by looking up the reagent name in `consumablesCategories` directly.

#### New files
- `AuctionShoppingList.lua` — the shopping list feature
- `MatIDs.lua` — reagent name → item ID lookup table




# Original readme below:

# Consumes Manager
Easily track and manage your consumables, food buffs, and more across your inventory, bank, and mail, while supporting multiple characters and accounts.
Created with ♥ by Horyoshi for World of Warcraft 1.12 **Turtle WoW**

[![Consumes Manager Video Tutorial](https://i.ibb.co/Dfkc7VK/Consumes-Manager-video.jpg)](https://www.youtube.com/watch?v=GMo-7vIHxl0)

## How To

Unzip the file and place the 'ConsumesManager' folder in your /Interface/AddOns folder. Remove '-master' from the folder name!

Click the mini-map icon to open/close the Tracker. For a detailled overview watch the tutorial video on top.

## Changelog
**2.1.0**
```
- Added a new feature which makes the addon crossfaction compatible
```

**2.0.4**
```
- Fixed a bug where the count of the consumes in your bank would reset
- Added magic resistance and invisibility potions
```

**2.0.3**
```
- Fixed a bug where multi-account characters where not selected by default
```

**2.0.2**
```
- Fixed a compatibility issue with other addons where the bank would not scan
- Added a delay to the scanning functions to avoid performance issues or client crashes
- Fixed a UI bug in the syncing progress bar
- Added compatibility with SuperWoW for consumables that have charges
```

**2.0.1**
```
- Fixed a compatibility issue with Onebag
- Added some food buffs to the item list
```

**2.0**
```
- Added a new feature which allows syncing between multiple accounts (in beta)
- Added new consumes to the itemlist
- Added materials or objectives needed to make the consumes in the tooltips
- Fixed some wrong ID's in the itemlist
- Increased Performance in item scanning
- Added class color codes to the preset lists and ordered the items better
```

**1.8**
```
- Added new consumables and fixed some mismatched icons
- Added a new feature that shows a list of must-have consumables per class per raid
- Fixed an issue where settings did not save
- Disables the Items and Presets window if the character has not been scanned yet
- Fixed an issue where disabled characters corrupted the Data table
```

**1.7**
```
- Added a reset button to wipe all settings and caches
- Added buttons to order by name or amount in the tracker window
```

**V1.6**
```
- Added more items to the consumables list
- UI changes to the tabs
- Added an option to show/hide a 'use'
- Added an option to show/hide categories
- Small UI fixes
```


**V1.5**
```
- Can now be updated via the Turtle WoW launcher
- Changed Addon name to: Consumes Manager
- Fixed general styling issues
- Added a 'Use' button for tracked consumables
- Added a select/deselect all button to the options
- Changed scanning to global instead of selected items only
```

<img width="680" alt="image" src="https://github.com/user-attachments/assets/07fbaeb2-fb67-463f-a743-a28db6d82adc">

**V1.4**
```
- Updated consumables list
- Fixed icons and ID's for all consumables
- Fixed an issue where the consumables counting could be a negative value
- Added a search filter in the options window
- Fixed general styling issues
- You can now close the addon window by pressing 'Esc'
```
