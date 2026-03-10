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
- Glow effect by DoiteGlow (bundled with permission)
- Built for use with [SuperWoW](https://github.com/balakethelock/SuperWoW)

original readme below:

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
