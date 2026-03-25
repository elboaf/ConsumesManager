# ConsumesManager

A consumables tracking, buff bar, and inventory management addon for World of Warcraft 1.12 (Vanilla), built on SuperWoW.

Forked from [Cinecom/ConsumesManager](https://github.com/Cinecom/ConsumesManager).

---

## Requirements

- [SuperWoW](https://github.com/balakethelock/SuperWoW) — required for buff tracking via spell ID

---

## Installation

1. Download and extract to your `Interface/AddOns/` folder as `ConsumesManager`
2. The `Textures` folder must be present inside the addon folder (included)
3. Log in or `/reload`

---

## Features

### Consumables Tracker
Tracks consumables across your inventory, bank, and mail. Supports elixirs, flasks, food buffs, poisons, weapon enchants, and more — including Turtle WoW custom items and concoction elixirs.

- Per-character tracking — each character has their own selected items and settings
- Bank scanning when the bank is open; mail scanning when the mailbox is open
- Tooltips show per-character breakdown of where items are located

### Buff Bar
A dynamic action bar displaying your tracked consumables as clickable icons. Click an icon to use the item directly from your bags.

- **Multiple bars** — create as many named bars as you need, each independently positioned
- **Buff tracking** — icons reflect your current buff status using SuperWoW's spell ID based `UnitBuff()` and `GetWeaponEnchantInfo()`
- **Cooldown sweep** — item cooldown displayed directly on each icon
- **Buff timer** — remaining duration shown on active buff icons
- **Item count** — current bag count shown on each icon
- **Glow reminder** — animated glow on icons where your buff is missing or expired (powered by DoiteGlow)
- **Mouseover mode** — bars fade out and reappear only on hover
- **Scalable** — resize all bars globally via settings or `/cmbarscale`
- **Icon reordering** — swap icons left/right (or up/down in vertical mode) in edit mode
- **Per-bar show/hide** — hide individual bars without removing them
- **Horizontal or vertical layout** — toggle per bar in edit mode

### Auction House Shopping List
A panel that appears automatically below the aux AH window when you open the auction house, showing your consumes and their crafting reagents.

- **Left-click** a consume row to search the AH for that item
- **Right-click** a consume row to expand its crafting reagent list
- **Left-click** a reagent row to search the AH for that reagent
- Sorted by quantity ascending — missing items at the top
- Reagent item links use `MatIDs.lua` for accurate aux item ID searches, with name-search fallback
- Supports `"search"` sentinel values for items with no single canonical ID (e.g. Bijou — searches all colours)
- **BOP items** (e.g. Jujus, Blasted Lands turn-ins) are handled specially:
  - Single-mat BOP: left-click searches the reagent directly
  - Multi-mat BOP: left-click expands the reagent list
- Panel collapses to a slim header bar via the `[-]/[+]` toggle button
- Mousewheel, arrow buttons, and a scrollbar for navigation

### Multi-Character Manager
A file-based cross-character inventory system powered by SuperWoW's `ImportFile`/`ExportFile` API. No simultaneous login required — each character writes a snapshot file independently.

#### How it works
- Every character automatically exports their full consumables inventory (bags + bank) to `imports/CM_CharName.txt` on `BAG_UPDATE` and when the bank closes
- A manifest file (`imports/CM_manifest.txt`) tracks all known characters
- Manager characters read all character files on login and on demand via the **Sync** button

#### Manager Mode
Enable **Manager Mode** on a character via the **Network** tab in the Consumes Manager window. Manager characters get access to:

**Stock Overview** (right-click the minimap icon, or via the Network tab):
- Floating grid window showing all configured consumes across all characters
- Rows = consumes (only items at least one character uses), columns = characters
- Sorted by non-BOP items first, then BOP items; within each group by total count ascending
- Manager character columns appear on the left in gold; non-manager columns on the right in grey
- Per-character tabs to view a single character's inventory in isolation
- Zebra-striped rows for readability
- Tooltips on hover; scrollable with mousewheel and scrollbar
- **Refresh** button to re-read all character files

**Manager AH Shopping List** (replaces the standard shopping list when manager mode is on):
- Flat list of all configured consumes across all characters, total count shown
- BOP items shown below non-BOP items, with per-character breakdown (so you know how many reagents each toon needs)
- Sorted by quantity ascending within each group

#### Network Tab
The Network tab in the Consumes Manager window provides per-character sync settings:

- **Manager Mode** checkbox — enables the stock overview and manager shopping list
- **Sync** button — exports your inventory immediately; managers also import all character files
- **Stock Overview** button — opens/closes the manager grid window (managers only)
- **Tracked Characters** list (managers only) — uncheck any character to hide them from the overview and shopping list without affecting their file exports

#### Character Exclusion
Any character can be hidden from the manager overview by unchecking them in the manager's **Tracked Characters** list. Their inventory data continues to be exported — they are simply filtered out of the manager's view.

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

Enter edit mode with `/cmbaredit` or via the Settings tab.

In edit mode:
- **Right-click** an icon to assign it to a different bar
- **`<>` swap buttons** appear between icons to reorder them
- **`^>` orientation button** appears on each bar to toggle horizontal/vertical layout
- Bar name labels are shown below each bar
- Hidden bars still appear so they can be managed

---

## New Files (2.3.x)

| File | Purpose |
|---|---|
| `AuctionShoppingList.lua` | AH shopping list panel |
| `MatIDs.lua` | Reagent name → item ID lookup table |
| `CM_FileSync.lua` | Per-character file export/import system |
| `CM_ManagerView.lua` | Stock overview grid window |

---

## Credits

- Original addon by [Horyoshi / Cinecom](https://github.com/Cinecom/ConsumesManager)
- Glow effect by DoiteGlow
- Built for [Turtle WoW](https://turtle-wow.org) with [SuperWoW](https://github.com/balakethelock/SuperWoW)

---

## Changelog

### 2.3.2
- All settings and selected items are now **per-character** — configuring consumables on one character no longer affects others
- Manager mode and exclude flags moved to a dedicated per-character saved variable (`ConsumesManager_CharOptions`)
- Stock overview column headers now distinguish managers (gold, left columns) from non-managers (grey, right columns)
- Stock overview and shopping list sorted by non-BOP items first, then BOP; within each group by quantity ascending
- Stock overview clickable column headers — click any character or Total column to sort by that column
- Stock overview character tabs now show manager columns alongside the character's own count for deficit tracking
- Stock overview minimize button collapses the window to a slim draggable title bar
- Stock overview Total column moved to leftmost position
- Manager AH shopping list BOP items show per-character inline rows (e.g. `Juju Power [0] (Rels)`) instead of section headers
- Shopping list right-click mat expansion fixed for non-manager characters
- Shopping list now shows all mats including non-auctionable ones; non-auctionable mats are display-only (clicking does nothing)
- Network tab is now scrollable
- Minimap right-click now toggles bar edit mode for all characters
- Edit mode exit now correctly hides orientation, drag, and swap handles for hidden bars
- Added Dragonbreath Chili to itemlist (id 12217, spellId 15852)
- Fixed `string.gmatch` and `string.match` calls replaced with Lua 5.0 compatible `string.gfind` and `string.find`
- Fixed modulo operator (`%`) replaced with `math.mod` for Lua 5.0 compatibility

### 2.3.0
- Added AH Shopping List panel (aux integration)
- Added Multi-Character Manager with file-based sync
- Added Stock Overview window
- Added Network tab to main window
- Added `MatIDs.lua` reagent lookup table
- Added `CM_FileSync.lua` and `CM_ManagerView.lua`
- Added BOP item handling in shopping list and itemlist (`bop = true` flag)
- Removed "Made by Horyoshi" footer attribution
- Footer now shows addon name and version only

### 2.2.x and earlier
See original changelog below.

---

## Original Changelog

**2.2.x**
- Cross-faction support
- Various bug fixes and item list updates

**2.1.0**
- Added cross-faction compatibility

**2.0.4**
- Fixed bank count reset bug
- Added magic resistance and invisibility potions

**2.0.3**
- Fixed multi-account characters not selected by default

**2.0.2**
- Fixed bank scanning compatibility issue
- Added scanning delay to prevent performance issues
- Fixed syncing progress bar UI bug
- Added SuperWoW compatibility for consumables with charges

**2.0.1**
- Fixed OneBag compatibility
- Added food buffs to item list

**2.0**
- Multi-account syncing (beta)
- New consumes added to item list
- Materials shown in tooltips
- Performance improvements

**1.8**
- New consumables and icon fixes
- Per-class per-raid preset lists
- Various bug fixes

**1.7**
- Reset button added
- Sort by name or amount in tracker

**1.6**
- More consumables
- UI improvements
- Show/hide use button option
- Show/hide categories option

**1.5**
- Turtle WoW launcher support
- Renamed to Consumes Manager
- Added Use button
- Select/deselect all button
- Global scanning

**1.4**
- Updated consumables list
- Icon and ID fixes
- Search filter in options
- Esc to close window
