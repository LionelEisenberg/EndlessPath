# Inventory System

## Overview

The inventory holds what the player owns and what they have equipped:

- equipment instances in a paged grid
- stacked materials
- stacked consumables
- quest items
- six gear slots and a four-slot consumable hotbar

`InventoryManager` (autoload) owns every mutation and emits a single `inventory_changed` signal. The state lives in `InventoryData` inside the save file.

The UI is a book (`InventoryView`), the red one of the four menu books that share `BookFrame` (see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#menu-books)). Its four tabs are pressed paper ([design](../superpowers/specs/2026-10-23-inventory-pressed-pages-design.md)): slots, panels and the gear figure are pressed into the page and the labels printed in ink, at screen resolution. Each tab's left page holds what the player has, and its right page what they use and the details of what they last pointed at:

| Tab | Left page | Right page |
|---|---|---|
| Equipment | A 6 × 6 page of the bag, a category filter, the page slots and a discard slot | The gear figure with its six slots, and the item's details |
| Consumables | The stacks, in a list | The four-slot hotbar, and the consumable's details |
| Materials | A 6 × 6 page of stacks | The material's details and where it is gathered |
| Journal | The quest items, in a list | The item's details and its quest |

Items arrive from three sources: foraging loot tables, adventure encounter effects and quest completion effects. Equipped gear feeds attribute bonuses into `CharacterManager`. Quest items gate content through the `ITEM_OWNED` unlock condition.

Related docs:
- [ITEMS.md](ITEMS.md) — equipment catalog. The headless generator turns it into `.tres` files. Other item types are hand-authored `.tres`.
- [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md) — equipment design intent and tier guidelines.
- [resources/loot_tables/README.md](../../resources/loot_tables/README.md) — loot table authoring.

## Player Experience

1. **Open.** In the zone view, press `I` or click INVENTORY in the zone's SystemMenu. The book plays its open animation and lands on the Equipment tab. The inventory can't be opened from the adventure view.
2. **Switch tabs.** Four tab buttons sit on the left edge: Equipment, Consumables, Materials and Journal. The page-turn animation plays forwards when you move to a later tab and backwards when you move to an earlier one.
3. **Equipment tab — left page.** The Equipment tab is pressed into the paper: its slots, panel and gear figure are cut into the page, and its labels are printed in ink.
   - **Layout:** the title "Equipment", the filter words (`ALL` / `WEAPONS` / `ARMOR` / `ACCESSORIES`) printed under it, then a 6 × 6 page of 72 px slots. A slot holding an item is pressed deep and an empty one shallow. The footer holds `PAGE` with one small pressed slot per page (the page shown pressed deep), the count of equipment in the bag against its capacity (`11 / 72`; worn gear isn't counted), and the discard slot.
   - **Hover:** hovering or pressing a slot that holds an item shows it in the details on the right page and puts printer's marks (red corner marks) round the slot. Hovering an empty slot changes nothing, so the details keep the last item.
   - **Drag:** left-drag works in these ways:
     - between grid slots: move or swap
     - onto a matching gear slot: equip, and the slot's previous item goes back where the dragged item came from
     - from a gear slot onto the grid: unequip
     - between the two accessory slots: swap them
     - hovering a page slot mid-drag flips to that page

     The item is held by its centre at full size. While dragging, printer's marks sit on the slot the item would land in: the slot under the cursor, or for an item taken out of the discard slot, the bag's first free slot when the one under the cursor is taken. A slot that would refuse the item, and the slot it came from, get none.
   - **Right-click:** on a grid item, it equips. An accessory goes to the first free accessory slot, or to slot 0 if both are full. On an equipped item, it unequips to the first free grid slot.
   - **Filter:** clicking a word filters the page. The word in use is printed in dark ink in a pressed lozenge. Items outside it are faded into the paper (an opaque fade, never transparency) in shallow slots, and stay draggable. Empty slots count as outside it.
   - **Discard:** drop an item on the discard slot to hold it there; drag it back out to restore it. Empty, the discard slot is shallow with a printed ×; holding an item, it is deep and shows the item. Dropping a second item destroys the held one permanently and logs "Discarded <name>". Closing the book returns any held item to the inventory.
4. **Equipment tab — right page.** The title "Gear", then the cultivator figure pressed into the page, with six gear slots round it mirrored to the figure:
   - left column: Head, Main hand, Accessory 1
   - right column: Body, Off hand, Accessory 2

   Each slot's name is printed under it, and an empty gear slot is a shallow slot. The details panel sits under the figure: the item in a deep slot beside its name and slot, its bonuses two to a row, its description, and a hint at the foot (`Right-click to wear it`, or `Right-click to take it off` for a worn piece). The panel has a fixed height laid out for the longest item, the Dreadbeast Tooth Necklace; shorter items flow up from the same gaps. The hint is the first thing to give way: it hides when an item's text would end lower than the necklace's.

   On opening, the details show the first item on the grid page, else the first worn piece (Head, Main hand, Accessory 1, Body, Off hand, Accessory 2); with neither, they hide. While the bag changes (foraging, a purchase), they and the marks stay on the item the player picked. When that item is discarded, they move to the first item.
5. **Consumables tab.** Pressed into the paper like the Equipment tab.
   - **Left page:** the title "Consumables", then the stacks in inventory order, one row every 80 px. Each row shows the item in a deep slot, its name, and what it does in muted ink under the name (`+20 Madra · 10 s cooldown`, the Madra amount in Madra ink). How many you have (`×7`) sits at the right. A pressed rule runs under every row but the last.
     - Seven rows fit. With more, the list scrolls, and a pressed groove with an ink thumb appears beside it.
     - A long name wraps and its row grows.
     - With no consumables, the page prints "No consumables yet." and the details hide.
   - **Right page:** the title "Hotbar", four slots with their keys `1`–`4` printed under them, a printed hint, then the details panel. A filled slot is pressed deep and shows its stack count on a paper tag; an empty one is shallow.
     - Drag a row onto a slot to equip it. A consumable can sit in only one slot. The dragged item's icon follows the cursor at full size, and printer's marks sit round the slot under it.
     - Drag between slots to move or swap.
     - Click an equipped slot to clear it.
   - **Details:** hovering or clicking a row, or hovering a filled hotbar slot, shows that consumable in the details and puts printer's marks round what you pointed at.
     - The panel shows the item in a deep slot, its name, and `CONSUMABLE` (`CONSUMABLE · IN SLOT n` while it is on the hotbar).
     - Under them, a table of what it does (`RESTORES` → `+20 Madra`, `COOLDOWN` → `10 s`), then the description and the hint `Drag it onto the hotbar`.
     - It grows downward with long text.

     On opening, the details show the first stack. While the stacks change (a purchase), they and the marks stay on the consumable you picked; when it is used up, they move to the first stack. When the hotbar slot you pointed at loses its consumable, the marks move to its row.
   - **Current limits:** the Merchant's Crude Scale is the only consumable a player can get, and nothing on `main` reads the hotbar.
6. **Materials tab.** Pressed into the paper like the Equipment tab.
   - **Left page:** the title "Materials", the caption `N KINDS` (`1 KIND` for one), then the same 6 × 6 page of 72 px slots as Equipment. Each material sits in a deep slot, in inventory order, with its full count on a paper tag at the slot's bottom right (`×4600`); the rest of the page is shallow empty slots. There is no filter, no discard slot and no dragging.
     - Past 36 kinds the page scrolls, and a pressed groove appears beside it.
     - With nothing gathered, the page prints "Nothing gathered yet." where the grid would be, and the right page stays blank.
   - **Right page:** the material's name as the title, then the details panel under its last line: the material in a deep slot beside `MATERIAL` and `You have 4,600`, its description, then a table of where it is gathered, one block per source: `GATHERED BY` (the activity), `IN` (its zone) and `YIELD` (`2–6 every 5 s`). Only sources the player can already see are listed; with none, the table is left out. The panel grows downward with long text.
   - **Details:** hovering or clicking a slot shows its material and puts printer's marks round the slot. Hovering an empty slot changes nothing. On opening, the details show the first material. While the stacks change (a foraging roll every 5 s), they and the marks stay on the material the player picked, and its amount follows its stack.
7. **Journal tab.** Pressed into the paper like the Equipment tab.
   - **Left page:** the title "Journal", the caption `ITEMS OF CONSEQUENCE`, then the quest items in inventory order, one row every 80 px. Each row shows the item in a deep slot, its name, and in muted ink under it the name of the quest it belongs to. At the right sits a vermilion `DONE` seal once that quest is finished, or the step the player is on (`Step 2 of 3`) while it is under way. An item that belongs to no quest shows where it came from under its name, and nothing at the right. A pressed rule runs under every row but the last.
     - Six rows fit. With more, the list scrolls, and a pressed groove appears beside it.
     - A long name wraps and its row grows.
     - With no quest items, the page prints "No quest items yet." and the right page stays blank.
   - **Right page:** the item's name as the title, then two panels under its last line:
     - the item's panel: the item in a deep slot beside `QUEST ITEM` and where it came from (`From Old Vesh, in the broken shrine`), then its description, opening with a two-line drop cap in vermilion;
     - the quest's panel, which shows the quest the way the Goals board does: `QUEST`, with the `DONE` seal at its top right once the quest is finished, the quest's name, its description as flavour text, a pressed rule, then the steps reached so far in tick boxes. Finished steps are ticked. The current step is unticked, with its progress figure (`7 / 10`) at the right when it has one. Later steps are not shown. An item that belongs to no quest has no quest panel.

     Both panels grow downward with long text.
   - **The item's quest** is the started quest that needs it, else the started quest that gave it ([QUESTS.md](../progression/QUESTS.md#public-api)), so the page never names a quest the player has not met.
   - **Details:** hovering or clicking a row shows its item and puts printer's marks round the row. On opening, the details show the first item. While the bag changes (foraging, a reward), they and the marks stay on the item the player picked; when it leaves the bag, they move to the first item.
8. **Close.** Press `I` or `Escape`, click the close tab standing up from the top-right of the book, or click anywhere outside the book. The backdrop fades out while the book closes. On close, every trash slot flushes back into the inventory.

## Architecture

```
MainView
  MainViewStateMachine/InventoryViewState        — inventory_view_state.gd (BookViewState: close on I/Escape/close tab/backdrop click)
  InventoryView (Control, full screen, mouse ignored, theme book_theme.tres)
                                                 — inventory_view.gd (MenuBookView; page_content = [BookContent, PageLayer])
    BookLayer (centred, scale 2, mouse ignored)
      BookFrame                                  — scenes/ui/book_frame/book_frame.tscn, style inventory_book_style.tres
                                                   (book art + open/close and page-turn animations, close tab, bookmark)
      BookContent (Control, mouse ignored)       — shown only while the book lies open
        TabSwitcher (mouse ignored)              — tab_switcher.gd: collects its child tab buttons, signal tab_changed(index)
          EquipmentTabButton / ConsumablesTabButton / MaterialsTabButton / QuestItemsTabButton
                                                 — tab_button.tscn/.gd (icon_texture export, "TabButtonAnimation", set_locked())
    PageLayer (centred, screen pixels, mouse ignored) — shown only while the book lies open
      EquipmentTab                               — equipment_tab.tscn/.gd
      ConsumablesTab                             — consumables_tab.tscn/.gd
      MaterialsTab                               — materials_tab.tscn/.gd
      QuestItemsTab                              — quest_items_tab.tscn/.gd (the Journal)
```

The book's art and side tabs are drawn at 2x on `BookLayer` and the pages at screen resolution on `PageLayer`, as in the other menu books, so the pages' text renders at its own size. Each tab covers the book, 1400 × 900 from screen (260, 90), the book's top-left, and ignores the mouse, so a click outside the book reaches the backdrop. Positions inside a tab are tab-local: screen − (260, 90).

`InventoryView` calls the shown tab's `open_page()` before the book opens. A tab button turns the page through `BookFrame.turn_page()`; on `page_turned` the view calls the new tab's `open_page()`, then shows the tab. Once the book has closed, it flushes the trash slots.

### Equipment tab

```
EquipmentTab (Control, 1400×900, mouse ignored) — equipment_tab.gd: drag/drop, quick-equip, category filter,
                                           trash routing, the shown item and the marks
  LeftTitle (PageTitle)                    — "Equipment"
  FilterWords (HBoxContainer)              — filter_words.gd: Word0–Word3, centred in the caption row
  EquipmentGrid (MarginContainer, @tool)   — equipment_grid.gd; 6 × 6 slots of 72 px at a 76 px pitch
    GridContainer
      Slot1 … Slot48 (InventorySlot)       — persistent pool (SLOT_POOL_SIZE = 48); slots past num_rows × num_columns hidden
  PaginationBar (HBoxContainer)            — pagination_bar.gd
    PageBox / PageLabel ("PAGE")           — 48 px in, so "PAGE" ends at x 536 and the page slots start at 556
    PageButtons (HBoxContainer)            — one page_button.tscn (TextureButton, 28×28) per unlocked page, built in setup()
    Spacer
    CountLabel                             — "held / capacity", ending 16 px before the TrashSlot
    TrashSlot                              — trash_slot.gd (group "TrashSlots"); Cross, the printed ×
  RightTitle (PageTitle)                   — "Gear"
  GearSelector (Control)                   — gear_selector.gd
    Plate (TextureRect)                    — gear_plate_ai.png: the pressed figure and its dotted leader lines
    LeftColumn:  HeadGearSlot, MainWeaponGearSlot, Accessory1GearSlot (accessory_index 0)
    RightColumn: ArmorGearSlot, OffhandGearSlot, Accessory2GearSlot (accessory_index 1)
                                           — gear_slot.gd (group "GearSlots")
    HeadLabel … Accessory2Label            — each slot's name, printed under it
  EquipmentDetails (PanelContainer, PanelPressed, 468×272) — equipment_details.gd
    Content (Control)
      Flow (VBoxContainer)                 — from the content's top
        Header: IconWell (deep slot, Icon), NameColumn (NameInset 2 px, NameLabel, SlotBox 2 px in / SlotLabel 17 px)
        BonusesBlock (16 px over) / Bonuses — one BonusRow (bonus_row.tscn/.gd) per two bonuses, 6 px apart
        DescriptionBlock (19 px over) / Description
      Hint                                 — pinned to the panel's foot, baseline 866 on screen
```

Every `InventorySlot`, `GearSlot` and `TrashSlot` holds a hidden `Marks` panel (`PanelPrinterMarks`), 6 px outside the slot.

### Consumables tab

```
ConsumablesTab (Control, 1400×900, mouse ignored) — consumables_tab.gd: the list, the hotbar's routing,
                                           the shown consumable and the marks
  LeftTitle (PageTitle)                    — "Consumables"
  ListFrame (Control, clips)               — the list's rect grown 8 px left and up and 10 px down, so the rows' marks show whole
    ConsumablesInventoryList (InventoryList) — rows 428 wide, the rail 12 px after them; on this instance the
                                             ScrollContainer doesn't clip (ListFrame does) and the rows sit 0 px apart
      ConsumableRow per stack              — consumable_row.tscn/.gd (VBoxContainer):
                                             Upper (Body ≥ 428×72: Well/Icon, Name over Effect, Count; RuleGap 4 px;
                                             Marks round both), then Rule. The last row hides RuleGap and Rule
  EmptyLabel                               — "No consumables yet."
  RightTitle (PageTitle)                   — "Hotbar"
  ConsumablesHotbar (VBoxContainer)        — consumables_hotbar.gd
    SlotsRow: HotbarSlot ×4 (slot_index 0-3) — hotbar_slot.gd (extends DropTargetSlot): Well (deep or shallow slot),
                                             Icon, Count (PaperTag, flush right, 2 px up), Marks
    KeysRow: Key1–Key4                     — "1"–"4", printed under the slots
  HintLine1, HintLine2                     — the printed hint
  HintRule (HSeparatorPressed)
  ConsumableDetails (PanelContainer, PanelPressed, grows downward) — consumable_details.gd
    Flow
      Header: IconWell (deep slot, Icon), NameColumn (NameInset 10 px, NameLabel, KindBox 2 px in / KindLabel)
      EffectsBlock / Effects               — one TableRow per effect, then the cooldown
      DescriptionBlock / Description
      HintBlock / HintLine / Hint          — the hint's line runs 3 px into the panel's bottom padding
```

### Materials tab

```
MaterialsTab (Control, 1400×900, mouse ignored) — materials_tab.gd: the grid, the shown material and the marks
  LeftTitle (PageTitle)                    — "Materials"
  KindsLabel                               — "N KINDS", in the caption row
  GridFrame (Control, clips)               — the grid's rect grown 6 px left, up and down and 14 px right (the
                                             groove's room), so the slots' marks show whole
    MaterialsInventoryGrid (InventoryGrid) — 6 columns of 72 px slots 4 px apart; on this instance the
                                             ScrollContainer doesn't clip (GridFrame does)
      MaterialSlot per material, then empty slots to the end of the page (or of the last row past it)
                                           — material_slot.tscn/.gd (TextureRect, deep or shallow): Icon,
                                             Count (PaperTag, 2 px in from the right, 4 up), Marks
  EmptyLabel                               — "Nothing gathered yet."
  RightPage (VBoxContainer)                — keeps the details under the title's last line
    TitleBox / RightTitle (PageTitle)      — the material's name; TitleBox's 4 px left margin centres it on the spec's x 1244
    MaterialDetails (PanelContainer, PanelPressed, grows downward) — material_details.gd
      Flow
        Header: IconWell (deep slot, Icon), InfoColumn (KindInset 11 px, KindBox 2 px in / KindLabel "MATERIAL", AmountLabel)
        DescriptionBlock / Description     — flows with its text
        SourcesBlock / Sources             — three TableRows per source; the block's top margin is the gap over
                                             the table, hidden with it
```

### Journal

```
QuestItemsTab (Control, 1400×900, mouse ignored) — quest_items_tab.gd: the list, the shown item and the marks
  LeftTitle (PageTitle)                    — "Journal"
  CaptionLabel                             — "ITEMS OF CONSEQUENCE", in the caption row
  ListFrame (Control, clips)               — the list's rect grown 8 px left and up and 10 px down, so the rows' marks show whole
    JournalList (InventoryList)            — rows 428 wide, the rail 12 px after them; on this instance the
                                             ScrollContainer doesn't clip (ListFrame does) and the rows sit 0 px apart
      JournalRow per quest item            — journal_row.tscn/.gd (VBoxContainer): Upper (Body ≥ 428×72: Well/Icon,
                                             Name over SecondLine, SealBox/Seal or StepBox/StepLabel; RuleGap 4 px;
                                             Marks round both), then Rule. The last row hides RuleGap and Rule
  EmptyLabel                               — "No quest items yet."
  RightPage (VBoxContainer)                — keeps the details under the title's last line
    TitleBox / RightTitle (PageTitle)      — the item's name; TitleBox's 4 px left margin centres it on the spec's x 1244
    JournalDetails (VBoxContainer)         — journal_details.gd; its two panels 16 px apart, each PanelPressed and growing downward
      ItemPanel
        Flow
          Header: IconWell (deep slot, Icon), InfoColumn (KindInset 10 px, KindBox 2 px in / KindLabel "QUEST ITEM", FromLabel)
          DescriptionBlock / Description   — CapRow (CapBox / DropCap, NarrowText), then RestText at full width
      QuestPanel                           — hidden for an item that belongs to no quest
        Flow
          Header (26 px)                   — QuestCaption "QUEST", Seal at the top right, 2 px over the content
          QuestName
          FlavorBlock / Flavor
          StepsBlock / StepsColumn         — StepsRule, then Steps: one QuestStepRow (quest_step_row.tscn/.gd:
                                             Tick, Text, FigureBlock / Figure) per step reached
```

### Shared components

| Component | Location |
|---|---|
| `InventoryScrollHost` (base: `add_slot` / `clear_slots` / `get_slots`, binds ScrollRail) | `scenes/inventory/common/inventory_scroll_host.gd` |
| `InventoryGrid` (GridContainer content, `columns` export, default 6) | `scenes/inventory/common/inventory_grid/` |
| `InventoryList` (VBoxContainer content) | `scenes/inventory/common/inventory_list/` |
| `ScrollRail` (a pressed groove at the host's height; its 4 px ink thumb is as long as the share of the groove's floor the host shows, never shorter than its art, and follows every scroll, by wheel or from code, on even pixels; hides itself when content fits) | `scenes/inventory/common/scroll_rail/` |
| `SortSubBanner` (arrows + dots, `option_changed(index)`, `enabled`) | `scenes/inventory/common/sort_sub_banner/` |
| `TabBanner` (`@tool`; `title`, `title_font_size` exports) | `scenes/inventory/common/tab_banner/` |
| `ItemDescriptionPanel` | `scenes/common/item_description_panel/` |
| `ItemDisplaySlot` (read-only icon + hover tooltip) | `scenes/common/item_display_slot/` |
| `DropTargetSlot` (native drag-and-drop target; `_set_drop_hover()` shows the drop highlight, a tint unless a slot overrides it) | `scenes/common/drop_target_slot.gd` |
| `ItemInstance` (icon visual for an `ItemInstanceData`) | `scenes/inventory/item_instance/` |
| `InventorySlot` → `GearSlot`, `TrashSlot` (72 px pressed slot: `DEEP_TEXTURE` / `SHALLOW_TEXTURE`, `set_marked()`, `set_filtered_out()`) | `scenes/inventory/inventory_view/equipment_tab/` |
| `PageTitle` (`@tool`; a pressed page's title with its ornament, `title` export) | `scenes/inventory/pressed/page_title/` |
| `TableRow` (a row of a details panel's table: a caption in capitals, a BBCode value, a pressed rule; `setup()`, `set_rule_visible()`) | `scenes/inventory/pressed/table_row/` |
| `ItemDragPreview` (the item's 64 px icon centred on the cursor during a native drag; `set_icon()`) | `scenes/inventory/pressed/item_drag_preview/` |
| `PaperTag` (a count on a paper tag, `LabelBookTag`; `set_count()` prints it and rounds the tag's width up to even, so a tag anchored to a slot's right edge starts on an even x) | `scenes/inventory/pressed/paper_tag/` |

## Data Model

### Item classes

```
ItemDefinitionData (Resource)          — item_definition_data.gd
  ├── EquipmentDefinitionData          — equipment/equipment_definition_data.gd
  ├── MaterialDefinitionData           — material_definition_data.gd
  ├── ConsumableDefinitionData         — consumable_definition_data.gd
  └── QuestItemDefinitionData          — quest_item_definition_data.gd
ItemInstanceData (Resource)            — item_instance_data.gd (one equipment item in the grid or a gear slot)
```

All of these live under `scripts/resource_definitions/items/`. Each subclass's `_init()` sets `item_type`, except `MaterialDefinitionData`, which relies on the default `MATERIAL`.

| Enum | Values |
|---|---|
| `ItemDefinitionData.ItemType` | `MATERIAL`, `CONSUMABLE`, `EQUIPMENT`, `QUEST_ITEM` |
| `EquipmentDefinitionData.EquipmentSlot` | `MAIN_HAND` (0), `OFF_HAND` (1), `HEAD` (2), `ARMOR` (3), `ACCESSORY` (4) |

**ItemDefinitionData**

| Field | Type | Default | Notes |
|---|---|---|---|
| `item_id` | `String` | `""` | Key for `has_item()` and `ITEM_OWNED` |
| `item_name` | `String` | `""` | |
| `description` | `String` | `""` | |
| `icon` | `Texture2D` | null | |
| `mini_icon` | `Texture2D` | null | 16 px icon the zone view draws inline (forage card detail line, Now strip). `get_mini_icon()` falls back to `icon` |
| `item_type` | `ItemType` | `MATERIAL` | |
| `stack_size` | `int` | 99 | Not enforced anywhere |
| `base_value` | `float` | 0.0 | Not shown; no economy reads it |

Methods: `get_mini_icon()` returns `mini_icon`, or `icon` when it is null. `ItemDefinitionData` also returns the type's name ("Material", "Consumable", "Equipment" or "Quest Item") and the tooltip lines (`Array[String]`), which each subclass overrides.

**Subclass fields**

| Class | Field | Type | Default | Notes |
|---|---|---|---|---|
| `EquipmentDefinitionData` | `slot_type` | `EquipmentSlot` | `MAIN_HAND` | |
| | `attribute_bonuses` | `Dictionary` (AttributeType int → float) | `{}` | Tooltip: one `+N Attribute` line per non-zero bonus |
| `MaterialDefinitionData` | `source_zone_ids` | `Array[String]` | `[]` | Tooltip line "Source Zones: <ids>" |
| | `source_description` | `String` | `""` | Not shown: the Materials page lists the activities that yield it (`MaterialSources`) |
| | `used_in` | `String` | `""` | Free text. Not shown |
| `ConsumableDefinitionData` | `effects` | `Array[EffectData]` | `[]` | `use()` calls `process()` on each, in order |
| | `cooldown_seconds` | `float` | 0.0 | Metadata only on `main`. Tooltip shows `EffectData.describe()` per effect plus "Cooldown: N.Ns" |
| `QuestItemDefinitionData` | `from_source` | `String` | `""` | The Journal's `From …` line, and the line under the name of an item that belongs to no quest |

**ItemInstanceData**

| Field | Type | Default | Notes |
|---|---|---|---|
| `item_definition` | `ItemDefinitionData` | null | |
| `quantity` | `int` | 1 | Always 1 for equipment |
| `instance_id` | `String` | `""` | Unused |
| `metadata` | `Dictionary` | `{}` | Unused (future enchantments and durability) |

### InventoryData

`InventoryData` is defined in `singletons/persistence_manager/inventory_data.gd` and saved as `SaveGameData.inventory`.

| Field | Type | Notes |
|---|---|---|
| `materials` | `Dictionary[MaterialDefinitionData, int]` | Stack counts |
| `equipment` | `Dictionary` (int → `ItemInstanceData`) | Unequipped gear keyed by global slot index |
| `equipped_gear` | `Dictionary` (`EquipmentSlot` → `ItemInstanceData`) | `MAIN_HAND`, `OFF_HAND`, `HEAD`, `ARMOR` |
| `equipped_accessories` | `Dictionary` (int → `ItemInstanceData`) | Physical accessory slot 0 or 1 |
| `quest_items` | `Dictionary[ItemDefinitionData, int]` | |
| `consumables` | `Dictionary[ConsumableDefinitionData, int]` | Entry erased when it reaches 0 |
| `equipped_consumables` | `Dictionary[int, ConsumableDefinitionData]` | Hotbar slot 0–3 → definition. The count is read from `consumables` |
| `unlocked_equipment_pages` | `int` | Default 2 |

| Constant / method | Value |
|---|---|
| `PAGE_ROWS`, `PAGE_COLUMNS` | 6, 6 |
| `SLOTS_PER_PAGE` | 36 |
| `equipment_capacity()` | `unlocked_equipment_pages * SLOTS_PER_PAGE` (72 by default) |

Stacked dictionaries are keyed by the definition resource itself, not by `item_id`. Two `.tres` files with the same `item_id` would therefore be two separate stacks.

### Loot tables

| Class | Fields |
|---|---|
| `LootTable` (`scripts/resource_definitions/loot/loot_table.gd`) | `entries: Array[LootTableEntry]`. `roll_loot() -> Dictionary` (ItemDefinitionData → int) |
| `LootTableEntry` (`loot_table_entries.gd`) | `item: ItemDefinitionData`, `drop_chance: float` (0–1, default 1.0), `min_quantity: int` (1), `max_quantity: int` (1) |

Each entry rolls independently: `randf() <= drop_chance`, then `randi_range(min, max)`. Quantities for the same item are summed. See [resources/loot_tables/README.md](../../resources/loot_tables/README.md).

## Core Systems

### InventoryManager

| Signal | When |
|---|---|
| `inventory_changed(inventory: InventoryData)` | After every mutation |
| `item_awarded(item: ItemDefinitionData, quantity: int)` | First thing in `award_items()`, before routing. It fires even if the item is then dropped |

| Method | Behaviour |
|---|---|
| `get_inventory()`, `get_material_items()`, `get_quest_items()` | Accessors |
| `award_items(item, quantity)` | Routes by `item_type`: MATERIAL, QUEST_ITEM and CONSUMABLE add to their stack; EQUIPMENT creates one `ItemInstanceData` per unit in the first free slot below capacity. Logs "Looted Nx Name" (materials light gray, equipment purple) or "Obtained Nx Name" (quest items yellow, consumables cyan). A class mismatch logs `Log.error` |
| `equip_item(instance, slot, from_index = -1, accessory_index = -1)` | If the slot is occupied, the occupant moves to `from_index` (or the first free slot when -1). Otherwise the instance is removed from the grid by `from_index`, or by identity search |
| `unequip_item(slot, accessory_index = -1)` | Moves the item to the first free grid slot |
| `unequip_item_to_slot(slot, target_index, accessory_index = -1) -> bool` | Swaps with a compatible grid item. Returns false and changes nothing when the occupant doesn't fit the slot |
| `swap_accessory_slots(from_index, to_index)` | Moves or swaps accessory 0 ↔ 1 |
| `move_equipment(from_index, to_index)` | Moves or swaps within the grid. No bounds or capacity check |
| `has_item(item_id) -> bool` | Scans materials, grid, equipped gear, accessories, quest items and consumables (count > 0) |
| `use_consumable(def) -> bool` | Calls `def.use()`, then decrements or erases the stack. No cooldown check. No caller on `main` |
| `restore_equipment_instance(instance, target_slot_index = -1)` | Trash restore: uses the target if it is valid, empty and below capacity, otherwise the first free slot. No log |
| `restore_material(def, quantity)` | Trash restore for materials. No UI path reaches it |
| `grant_equipment_page()` | Adds one page. No caller on `main` |
| `equip_consumable(def, slot_index)` | Slots 0–3. Clears any other slot holding the same definition |
| `unequip_consumable(slot_index)`, `swap_consumable_slots(from_slot, to_slot)` | Hotbar edits |

### Equipment drag and drop

The Equipment tab uses a manual drag system, not Godot's built-in drag-and-drop:

- Slots forward `gui_input` as `clicked(slot, event)`.
- `EquipmentTab._input()` moves the floating `ItemInstance` (re-parented to the tab, 72×72 at `z_index` 10, centred on the cursor) and handles the button release. It reads each motion event's own `global_position`.
- The tab hit-tests visible grid slots first, then gear slots, then the trash slot.
- While dragging, printer's marks sit on the slot a drop would fill. The tab decides each drop once, from the target under the cursor, and both the drop and the marks act on that decision:
  - a gear slot is marked when its `is_valid_item()` passes;
  - the trash slot is marked unless the item came out of it;
  - a grid slot is marked for a bag item, and for a worn item only when it is free or holds an item that fits the worn item's gear slot (the check `unequip_item_to_slot()` makes);
  - for an item out of the trash, the grid slot `restore_equipment_instance()` would fill is marked, when it is on the page shown: the hovered slot when it is free, else the bag's first free slot;
  - the slot the item came from is never marked.

  The drop clears the marks.
- The global index is `current_page * slots_per_page() + slot.get_index()`. The origin index is captured at pickup, so flipping pages mid-drag is safe.

| Drag | Result |
|---|---|
| Grid → grid | `move_equipment(origin, target)` |
| Grid → gear slot (`is_valid_item`) | `equip_item(instance, slot_type, origin, accessory_index)` |
| Any → gear slot of the wrong type | Item returns to its origin |
| Gear → gear | `swap_accessory_slots()` (only accessory ↔ accessory passes validation) |
| Gear → grid | `unequip_item_to_slot()`. A rejected swap returns the item to its origin |
| Any → trash | `TrashSlot.accept(instance)`. `EquipmentTab` then erases the item from `InventoryData` itself and emits `inventory_changed` |
| Trash → grid | `restore_equipment_instance(instance, target)` |
| Trash → gear slot (valid) | `equip_item(instance, slot_type, -1, accessory_index)` |
| Trash → nowhere | Item goes back into the hold-buffer |
| Origin slot, or nowhere | Item returns to its origin |

Right-click quick-equip ignores the trash slot: a held item is rescued only by dragging it out. `GearSlot.is_valid_item()` passes only `EquipmentDefinitionData` whose `slot_type` matches the gear slot. `GearSelector` logs an error if a singular slot type, or accessory index 0 or 1, has no gear slot.

### Equipment details and marks

- `EquipmentDetails.show_item(data, worn)` prints an item and shows the panel; `clear()` hides it; `get_item()` returns the item shown. Bonuses come from `BookText.bonus_pairs()`, two to a `BonusRow` (`BonusRow.setup(left, right)`, an empty `right` hiding the right half), and the slot caption from `BookText.slot_name()`.
- The panel never grows. It is laid out to the spec's geometry for the longest real item, the Dreadbeast Tooth Necklace: the name's baselines at screen 654 and 688, the slot caption 26 px under the name's last line, the first bonus row's baseline at 752 with a pressed rule 8 px under each row's baseline, the description from 798, and the hint at 866. Shorter items flow up from the same gaps. The header, the bonus rows and the gaps above them are even heights, so every rule lands on an even pixel.
- `EquipmentDetails.wants_hint(name_lines, bonus_count, description_lines)` keeps the hint only while the item's text ends at least 24 px above the hint's line, as the necklace's does: 208 px or less down the panel's content. The text's height is the header (the name column, 64 px plus 34 per extra line, but never under the 72 px icon slot), then the bonus rows (16 px over them, 28 per row with its rule, 6 between rows), then the description (40 px plus 26 per extra line). The name wraps at 346 px and the description at 434 px, so the line counts hold before the panel is laid out.
- `InventorySlot.set_marked()` shows a slot's printer's marks. The tab marks the slot that holds the item shown, and while dragging, the drop target. Picking an item up takes the marks off the slot it leaves.
- `EquipmentTab.open_page()` refreshes the footer, then shows the first item on the grid page, else the first worn piece in the figure's order (`GearSelector.get_slots()`), else clears the details. `InventoryView` calls it on opening the book and on every page turn.
- After every `inventory_changed` and every drop, the tab follows the item shown (deferred, once the slots have re-bound): it marks the visible slot holding it (none when it is on another page) and refreshes its hint. When the item is no longer in the bag or worn, which is how a discard ends, it runs `open_page()`. Flipping to another page follows it too.

### Trash hold-buffer

`TrashSlot` extends `InventorySlot`. `_held` holds either an `ItemInstanceData` (equipment) or a `[definition, quantity]` pair (materials).

| Method | Behaviour |
|---|---|
| `accept(value) -> String` | If something is already held, logs "[color=red]Discarded <name>" and drops that reference (permanent deletion). Stores the new value and renders equipment visuals. Returns the discarded name |
| `get_held()`, `is_holding()`, `clear_hold()` | Accessors. `clear_hold()` also clears the visual |
| `flush_to_inventory()` | Called by `InventoryView` on close for every node in the "TrashSlots" group. Restores the held value through InventoryManager, then calls `clear_hold()` so no icon is left behind |

Only the Equipment tab has a trash slot, so the `[definition, quantity]` path is reachable only from tests: materials can't be discarded, and the Consumables tab's trash path was removed in f0e3e0a.

### Pagination and category filter

**Pagination**
- `EquipmentGrid` keeps a fixed pool of 48 slots. It shows `num_rows × num_columns` of them, capped at the pool size. `num_rows` and `num_columns` are `@tool` knobs that default to `InventoryData.PAGE_ROWS` and `PAGE_COLUMNS`, so a page shows exactly `SLOTS_PER_PAGE` slots. `row_separation` and `col_separation` default to 4.
- `set_page(p)` clamps `p` to `[0, unlocked_equipment_pages - 1]` and re-binds the slot data. It never recreates the slots.
- `PaginationBar.setup(unlocked_pages, active_page)` rebuilds the page buttons: shallow pressed slots, the active one pressed deep. `PaginationBar.set_count(held, capacity)` prints `"held / capacity"`; the tab passes `inventory.equipment.size()` and `equipment_capacity()`. `page_selected(index)` fires on click and `page_hovered(index)` on mouse-enter. The tab flips pages on hover only while a drag is in progress.

**Category filter (Equipment only)**
- `EquipmentTab` builds a list of `{label, match: Callable}` entries, the labels printed as they are:
  - `ALL`: everything
  - `WEAPONS`: `MAIN_HAND`, `OFF_HAND`
  - `ARMOR`: `HEAD`, `ARMOR`
  - `ACCESSORIES`: `ACCESSORY`
- `FilterWords.set_options(labels)` prints the words and selects the first without emitting. It gives each word an even width, and the last one 2 px more when needed, so the centred row and the pressed lozenge sit on the 2 px grid. A left press on another word calls `FilterWords.select(index)` (`LabelBookFilterOn` for it, `LabelBookFilter` for the rest) and emits `option_changed(index)`, which calls `EquipmentGrid.set_category_filter(match)`.
- `EquipmentGrid` calls `InventorySlot.set_filtered_out()` on each slot. A left-out slot is shallow, and its icon's material is `assets/shaders/paper_fade_material.tres`: `paper_fade.gdshader` mixes each texel 70% towards the paper colour `#F7E6CA` and keeps its alpha. Empty slots count as non-matching. Nothing sets `modulate`. The fade re-applies on every page flip and inventory change.

### Consumable hotbar

The hotbar uses Godot's built-in drag-and-drop:

1. **Drag source.** `ConsumableRow._get_drag_data()` returns `{"consumable": def}`. `HotbarSlot._get_drag_data()` returns `{"consumable": def, "from_slot": i}`. Both set an `ItemDragPreview` as the drag preview: the item's 64 px icon, centred on the cursor. The row itself stays as it is.
2. **Drop.** `HotbarSlot` (a `DropTargetSlot`) accepts any dictionary with a `consumable` key and emits `consumable_dropped(def, slot_index, from_slot)`. `ConsumablesHotbar` re-emits the signal. While a payload it accepts hovers it, the slot shows its printer's marks: it overrides `DropTargetSlot._set_drop_hover()`, whose default tints the slot (the Abilities loadout keeps that tint), and never touches `modulate`.
3. **Routing.** `ConsumablesTab` calls `swap_consumable_slots()` when `from_slot >= 0`, otherwise `equip_consumable()`.
4. **Unequip.** Releasing the left button on an equipped slot without dragging calls `unequip_consumable()`.

### Consumables details and marks

- `ConsumableDetails.show_consumable(def, hotbar_slot)` prints a consumable and shows the panel (`hotbar_slot` is -1 when it is not on the hotbar); `clear()` hides it; `get_consumable()` returns the consumable shown. Showing the consumable already shown only reprints its caption, `CONSUMABLE · IN SLOT n`.
- Its table holds one `TableRow` per effect, captioned by `BookText.effect_label()`, with the effect's `describe()` as the value: its decimal point set by `LacquerText.decimal_bbcode()`, then its Madra amounts in Madra ink by `BookText.color_madra()`. A `COOLDOWN` row with `BookText.seconds()` follows when the cooldown is above 0. A row's caption and value share a baseline, its pressed rule 8 px under it, clear of descenders.
- The panel is laid out to the mockup's Crude Scale, which fills the spec's (1008, 512) to (1476, 824), and grows downward with longer text.
- `ConsumableRow.set_marked()` and `HotbarSlot.set_marked()` show a row's or a slot's printer's marks. The tab marks what the player pointed at: a row, or a filled hotbar slot. A hotbar slot's marks also show while a dragged consumable hovers it, and a drag passing over the slot the details show leaves its marks in place.
- A row's marks bracket its slot and its rule as the mockup draws them: (444, 292) to (886, 382) round the first row. The last row has no rule, so its marks end 6 px under its slot, inside the list's frame. `ConsumableRow.set_rule_visible()` hides the rule and the 4 px gap over it together.
- `ConsumablesTab.open_page()` rebuilds the list, then shows the first stack, or hides the details when the pack is empty. `InventoryView` calls it on opening the book and on every page turn.
- After every `inventory_changed` the tab rebuilds the list when the stacks changed, then follows the consumable shown. It reprints its hotbar slot, and keeps the marks on the hotbar slot pointed at while that slot still holds it, otherwise on its row. When the consumable has left the pack, the tab shows the first stack.

### Materials details and marks

- `MaterialDetails.show_material(def, amount)` prints a material and shows the panel; `clear()` hides it; `get_shown_material()` returns the material shown (`CanvasItem.get_material()` already takes the shorter name). Showing the material already shown only reprints how many the player has, through `BookText.thousands()`.
- Its table comes from `MaterialSources.find(material)` (`scripts/utils/material_sources.gd`): one `MaterialSources.Source` per loot entry whose item has the material's `item_id`, in each available `ForageActionData` with a loot table, in each zone of `ZoneManager.get_map_zones()` that is neither `LOCKED` nor `UNCHARTED`. A source holds `activity_name`, `zone_name`, `min_quantity`, `max_quantity` and `interval_seconds`, and prints as three `TableRow`s: `GATHERED BY`, `IN`, and `YIELD` from `BookText.yield_text()`. Each value goes through `LacquerText.decimal_bbcode()`.
- The panel is laid out to the mockup's Spirit Fern, which fills the spec's (1008, 300) to (1476, 646). The description flows, and the table keeps Spirit Fern's gap over it, 94 px from the description's last baseline to the table's first: a longer description pushes the table down, a shorter one pulls it up. The gap belongs to the table's block, so with no source both are left out and the panel ends under the description. A second source or a title that wraps moves the panel's foot down too.
- `MaterialSlot.set_marked()` shows a slot's printer's marks, 6 px outside it. The tab marks the slot of the material shown.
- `MaterialsTab.open_page()` clears the details, rebuilds the grid, then shows the first material, or hides the details and the title when nothing is gathered. Clearing first makes the details work out the sources again, so an activity unlocked since the page last showed is listed. `InventoryView` calls it on opening the book and on every page turn.
- After every `inventory_changed` the tab rebuilds the grid when the stacks changed, then follows the material shown: the marks move to its new slot and its amount follows its stack. When it has left the bag, the tab shows the first material.

### Journal details and marks

- `JournalDetails.show_item(item)` prints a quest item and its quest and shows the details; `clear()` hides them; `get_item()` returns the item shown. Every call reads the item's quest afresh: `QuestManager.get_quest_id_for_item()` ([QUESTS.md](../progression/QUESTS.md#public-api)), then the quest's state.
- The description's first letter is its drop cap (`LabelBookDropCap`), standing two lines tall. `BookText.split_for_drop_cap()` measures the rest in the narrow column's own font: the words that fit two lines of the column, 390 px wide (less when a wide capital leaves less room), run beside the cap, and the rest under it at the full 434 px, at the same 26 px pitch.
- The quest's panel prints one `QuestStepRow` per step reached (`setup(text, ticked, figure)`). A finished quest ticks every step, each reading `QuestStepData.get_progress_text(true)`, its target. An active one ticks the steps before the one the player is on, which is unticked and reads `get_progress_text()`. A step that measures nothing has no figure.
- The panels are laid out to the mockup's Refugee Camp Map, which fills the spec's (1008, 300) to (1476, 496) and (1008, 512) to (1476, 776), and grow downward with longer text.
- `JournalRow.setup(item, second_line, done, step_text)` prints a row: under the name, the quest's name, or the item's `from_source` when it belongs to no quest; at the right, the `DONE` seal when the quest is finished, else `Step k of n` for the step the player is on. `JournalRow.set_marked()` shows a row's printer's marks, which bracket its slot and its rule as a Consumables row's do; `set_rule_visible()` hides the last row's rule.
- `QuestItemsTab.open_page()` rebuilds the list, reading each quest afresh, then shows the first item, or hides the details and the title when the journal is empty. `InventoryView` calls it on opening the book and on every page turn.
- After every `inventory_changed` the tab rebuilds the list when the quest items changed, then follows the item shown, reprinting it; when it has left the bag, the tab shows the first item.

### Refresh on `inventory_changed`

| Listener | Behaviour |
|---|---|
| `EquipmentGrid` | Re-clamps the page and re-binds the visible slots (slots persist), re-applying the filter's fade |
| `EquipmentTab` | `PaginationBar.setup()` rebuilds the page buttons and `set_count()` prints the count. The details and marks follow the item shown (see [Equipment details and marks](#equipment-details-and-marks)) |
| `GearSelector` | Re-binds the six gear slots |
| `ConsumablesHotbar` | Re-binds the four slots |
| `ConsumablesTab` | Rebuilds the list only when `consumables.hash()` changed. The details and marks follow the consumable shown (see [Consumables details and marks](#consumables-details-and-marks)) |
| `MaterialsTab` | Rebuilds the grid only when `materials.hash()` changed. The details and marks follow the material shown (see [Materials details and marks](#materials-details-and-marks)) |
| `QuestItemsTab` | Rebuilds the list only when `quest_items.hash()` changed. The details and marks follow the item shown (see [Journal details and marks](#journal-details-and-marks)) |

### Item flow

```
ForageActionData.loot_table ─(ActionManager ForageTimer, every foraging_interval_in_sec)─▶ LootTable.roll_loot() ─▶ award_items()
AwardLootTableEffectData.process() ─▶ LootTable.roll_loot() ─▶ award_items()
AwardItemEffectData.process() ─▶ award_items()

award_items() ─▶ item_awarded ─▶ AdventureView._loot_items ─▶ AdventureEndCard loot row (ItemDisplaySlot)
              ─▶ inventory_changed ─▶ tabs, GearSelector, hotbar
```

## Integration Points

| System | Connection |
|---|---|
| MainView / ZoneViewState | `open_inventory` (`I`) in `ZoneViewState` pushes `InventoryViewState`. `close_inventory` (`I` or `Escape`) or `open_inventory` plays the close animation, then pops the state. The SystemMenu INVENTORY button fires the same action |
| CharacterManager | Sums `attribute_bonuses` from `equipped_gear` and `equipped_accessories`. This feeds every attribute getter and `get_total_attributes_data()` |
| ActionManager (foraging) | Each time the forage timer finishes, rolls `ForageActionData.loot_table` and awards the result |
| Adventure encounters | `AwardLootTableEffectData` / `AwardItemEffectData` in choice `success_effects`. `AdventureView` listens to `item_awarded` for the end-card loot (one entry per award call; quantity ignored) |
| QuestManager | A quest's `completion_effects` can award items (`q_reach_core_density_10` → Refugee Camp Map). The Journal shows each quest item's quest from `get_quest_id_for_item()`, and its steps' figures from `QuestStepData.get_progress_text()` |
| UnlockConditionData `ITEM_OWNED` (5) | Returns `InventoryManager.has_item(str(target_value))`. `comparison_op` is ignored. `AdventureEncounter.is_eligible()` evaluates it directly. `UnlockManager` does not listen to `inventory_changed` |
| PersistenceManager | `InventoryData` is `SaveGameData.inventory`. InventoryManager re-grabs `live_save_data` on `save_data_reset`, and a reset creates a fresh `InventoryData` |
| LogManager | Award messages and "Discarded <name>" |
| MerchantManager | `award_items(item, 1)` for each purchase (so gear purchases log as "Looted", Crude Scales as "Obtained"). Gear purchases first check `InventoryData.has_free_equipment_slot()`; with every slot full the shop shows "Equipment full" and takes no gold |
| Combat (unmerged) | `equipped_consumables` and `use_consumable()` are the hooks used by the `feat/infallible-chaum-58f8ad` branch |

## Existing Content

### Equipment

These seven items live in `resources/items/equipment/spirit_valley/` and are generated from [ITEMS.md](ITEMS.md).

| id | Name | Slot | Bonuses | base_value | How the player gets it on `main` |
|---|---|---|---|---|---|
| `makeshift_dagger` | Makeshift Dagger | MAIN_HAND | STRENGTH +3, AGILITY +2 | 60 | Merchant, once per save |
| `iron_shortsword` | Iron Shortsword | MAIN_HAND | STRENGTH +5, AGILITY +2 | 150 | Merchant, once per save |
| `cultivators_cowl` | Cultivator's Cowl | HEAD | WILLPOWER +3, SPIRIT +1 | 40 | Merchant, once per save |
| `reinforced_robes` | Reinforced Robes | ARMOR | BODY +4, RESILIENCE +2 | 180 | Merchant, once per save |
| `dreadbeast_tooth_necklace` | Dreadbeast Tooth Necklace | ACCESSORY | STRENGTH +2, AGILITY +2 | 0 | 25% drop from the Ravenous Dreadbeast elite in Shallow Woods (quota 2 per map) |
| `leeching_ring` | Leeching Ring | ACCESSORY | FOUNDATION +2, CONTROL +2 | 120 | Merchant, once per save (planned: Loot) |
| `scripted_bark` | Scripted Bark | OFF_HAND | BODY +2 | 75 | Merchant, once per save (planned: Loot) |

### Materials

These live in `resources/items/materials/`.

| item_id | Name | source_description | used_in | Source on `main` |
|---|---|---|---|---|
| `SpiritFern` | Spirit Fern | "Spirit Valley — shaded hex" | "Reinforced Robes · Greenleaf Tonic" | Spring Forest Foraging, 2–6 per roll |
| `DewdropTear` | Dewdrop Tear | "Glade pool, dawn only" | "Spirit Tea · Mirror Pill" | Spring Forest Foraging, 1–5 per roll |

Both materials have `source_zone_ids = ["SpiritValley"]`, `base_value` 0, an agent-drawn placeholder icon at 64 px (`assets/sprites/items/materials/spirit_fern_ai.png`, `dewdrop_tear_ai.png`), the lacquer kit's mini icon (`lacquer_mini_fern_ai.png`, `lacquer_mini_dewdrop_ai.png`) as `mini_icon`, and the design mockup's placeholder descriptions. Spring Forest Foraging unlocks on the event `q_fill_core_completed`, which fires when the quest "Awaken Your Core" completes.

### Consumables

These live in `resources/items/consumables/`.

| item_id | Name | Effect | cooldown_seconds | base_value | Icon | Source on `main` |
|---|---|---|---|---|---|---|
| `crude_scale` | Crude Scale | `ChangeVitalsEffectData` `madra_change` 20 ("+20 Madra") | 10.0 | 10 | `assets/sprites/items/consumables/crude_scale.png` | Merchant, unlimited |
| `barely_coalesced_scale` | Barely Coalesced Scale | Same: +20 Madra | 10.0 | 1 | None | None |

The two consumables also share the same description. The first scale was renamed Barely Coalesced → Crude in 459aeb6. Commit 21b3cb2 then re-added `barely_coalesced_scale.tres` as "a weaker counterpart", but its values are identical (see Content below).

### Quest items

| item_id | Name | from_source | Notes |
|---|---|---|---|
| `refugee_camp_map` | Refugee Camp Map | "Old Vesh, in the broken shrine" | `stack_size` 1, an agent-drawn placeholder icon at 64 px (`assets/sprites/items/quest_items/refugee_camp_map_ai.png`) |

The map is awarded on completing quest `q_reach_core_density_10` ("Harden Your Core"); step 2 completes on the event `celestial_intervener_dialogue_4`. While the player owns the map and `merchant_discovered` has not fired, the Refugee Camp special encounter is eligible.

### Loot tables

| Table | Location | Entries | Used by |
|---|---|---|---|
| `test_loot_table_foraging.tres` | `resources/zones/spirit_valley_zone/zone_actions/loot_table/` | Dewdrop Tear 100% ×1–5; Spirit Fern 100% ×2–6 | `spring_forest_foraging_action.tres` (rolls every 5.0 s) |
| `test_loot_table_weapon.tres` | same folder | Makeshift Dagger 100% ×1; Iron Shortsword 100% ×1 | `resources/adventure/encounters/test_treasure_encounter.tres` only, which no `AdventureData` references |
| inline sub-resource | `resources/adventure/encounters/shallow_woods/combat_encounters/elite/ravenous_dreadbeast_encounter.tres` | Dreadbeast Tooth Necklace 25% ×1 | "Attack the Dreadbeast" `CombatChoice.success_effects` |

## Key Files

| File | Purpose |
|---|---|
| `singletons/inventory_manager/inventory_manager.gd` | Inventory state and all mutations |
| `singletons/persistence_manager/inventory_data.gd` | Saved inventory container and page constants |
| `scripts/resource_definitions/items/item_definition_data.gd` | Base item class + `ItemType` |
| `scripts/resource_definitions/items/equipment/equipment_definition_data.gd` | `EquipmentSlot`, `attribute_bonuses` |
| `scripts/resource_definitions/items/material_definition_data.gd` | Material fields |
| `scripts/resource_definitions/items/consumable_definition_data.gd` | Effects, cooldown, `use()` |
| `scripts/resource_definitions/items/quest_item_definition_data.gd` | `from_source` |
| `scripts/resource_definitions/items/item_instance_data.gd` | Equipment instance wrapper |
| `scripts/resource_definitions/loot/loot_table.gd`, `loot_table_entries.gd` | Loot rolling |
| `scripts/resource_definitions/effects/award_item_effect_data.gd`, `award_loot_table_effect_data.gd` | Effect-driven awards |
| `scripts/tools/items_md_parser.gd`, `items_md_to_resources.gd` | ITEMS.md → equipment `.tres` generator |
| `scenes/ui/main_view/states/inventory_view_state.gd` | Open/close state (`BookViewState`) |
| `scenes/inventory/inventory_view/inventory_view.gd` | Tab switching with the page turn, trash flush on close (`MenuBookView`) |
| `scenes/ui/book_frame/` | The shared book (`BookFrame`) and the menu views' base (`MenuBookView`) |
| `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`, `tab_button.gd` | Tab buttons |
| `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd` | Equipment drag/drop, quick-equip, filter, trash routing, the shown item and the marks |
| `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd` | Paged slot pool, the filter's fade |
| `scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.gd` | Page buttons, count + trash |
| `scenes/inventory/inventory_view/equipment_tab/filter_words/filter_words.gd` | The printed filter words |
| `scenes/inventory/inventory_view/equipment_tab/equipment_details/equipment_details.gd`, `bonus_row.gd` | The details panel and its bonus rows |
| `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.gd`, `gear_slot.gd` | Gear slots and validation |
| `scenes/inventory/inventory_view/equipment_tab/inventory_slot/inventory_slot.gd` | Base slot: pressed textures, marks, filtered state |
| `scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.gd` | Hold-buffer |
| `assets/shaders/paper_fade.gdshader`, `paper_fade_material.tres` | The filter's opaque fade into the paper |
| `scenes/inventory/inventory_view/consumables_tab/` | `consumables_tab.gd`, `consumable_row.gd`, `consumable_details/consumable_details.gd`, `consumables_hotbar/consumables_hotbar.gd`, `hotbar_slot/hotbar_slot.gd` |
| `scenes/inventory/inventory_view/materials_tab/` | `materials_tab.gd`, `material_slot.gd`, `material_details/material_details.gd` |
| `scripts/utils/material_sources.gd` | Where a material is gathered (`MaterialSources`) |
| `scenes/inventory/inventory_view/quest_items_tab/` | `quest_items_tab.gd`, `journal_row.gd`, `journal_details/journal_details.gd`, `quest_step_row/quest_step_row.gd` |
| `scenes/inventory/common/` | Shared inventory chrome (see table above) |
| `scenes/inventory/pressed/` | The pressed pages' shared pieces: `PageTitle`, `TableRow`, `ItemDragPreview`, `PaperTag` |
| `scenes/common/item_description_panel/`, `item_display_slot/`, `drop_target_slot.gd` | Cross-system item UI |

Tests: `tests/unit/test_inventory_*.gd` and `tests/integration/test_equipment_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[LOW]` **Equipment overflow is silently dropped.** With every slot full, `award_items()` only logs a warning, and `item_awarded` has already fired, so the adventure end card lists an item the player never received.
- `[LOW]` **`use_consumable()` leaves an empty stack on the hotbar.** It erases the stack at zero but leaves the definition in `equipped_consumables`, so the hotbar would show `×0`. This is latent on `main` because nothing calls `use_consumable()`.
- `[LOW]` **An item in the trash is already erased from `InventoryData`.** The SaveTimer autosave (every 5 s) persists that state, so quitting with the inventory open and an item in the trash loses the item.

### Missing Functionality

- `[HIGH]` **Consumables can't be used on `main`.** The Merchant sells `crude_scale`, but no loot table or effect awards either scale, and nothing calls `use_consumable()`. Combat use exists only on the unmerged branch `feat/infallible-chaum-58f8ad` (20 commits, 2026-06-01): `CombatConsumableManager` / `CombatConsumableInstance`, `ConsumableButton`, consumable hotkeys 1–4 and `get_consumable_count()`.
- `[MEDIUM]` **Gear has one source each.** The Merchant sells six pieces once per save, and the Shallow Woods loot only includes the necklace. Loot drops for the merchant gear are planned (Beat 5).
- `[MEDIUM]` **There is no API to spend or remove items.** InventoryManager can't consume materials, take back quest items or sell equipment. The only removal path is the trash, which `EquipmentTab` implements by mutating `InventoryData` directly. Crafting (Elixir Making, Soulsmithing), merchant selling and quest hand-ins all need `remove_*` verbs. The redesign spec's `discard_*` methods were never built.
- `[LOW]` **`grant_equipment_page()` has no caller**, so every player stays at 2 pages (72 slots). The trigger was deferred by the pagination spec.
- `[LOW]` **`stack_size` is never enforced.**
- `[LOW]` **`UnlockManager` never re-evaluates on `inventory_changed`.** An `ITEM_OWNED` condition in `unlock_condition_list.tres` would latch only when some other signal fires. The one current use, the refugee camp, is evaluated directly and is unaffected.

### Content

- `[HIGH]` **The catalog is tiny:** 7 equipment items, 2 materials, 2 consumables and 1 quest item, all Foundation / Spirit Valley. There are no Copper-tier items, and only one equipment drop exists in play.
- `[MEDIUM]` **`barely_coalesced_scale.tres` duplicates `crude_scale.tres`.** It has the same +20 Madra, 10 s cooldown, base value and description, and it has no icon, even though its commit calls it "weaker". Decide its values or delete it; there is no test for it.
- `[MEDIUM]` **Placeholder art and text.** The Refugee Camp Map's icon and the two materials' icons are agent-drawn placeholders, and the materials' descriptions are the design mockup's, until the user replaces them.
- `[LOW]` **Material ids break the naming convention.** `SpiritFern` and `DewdropTear` are PascalCase while every other item id is snake_case. Bringing materials into ITEMS.md later would rename them.
- `[LOW]` **Material lore doesn't match the game.** The `used_in` strings name recipes and items that don't exist (Spirit Tea, Mirror Pill, Greenleaf Tonic). Dewdrop Tear's source text doesn't match its real source, Spring Forest Foraging.
- `[LOW]` **Test-named data files.** The two `test_loot_table_*.tres` files and `test_treasure_encounter.tres` are leftovers, even though the forage table is live. Rename, wire up or delete them.
- `[LOW]` **Iron Shortsword's description says it is "demanding both hands"**, but there is no two-handed rule and OFF_HAND stays free.

### UI

- `[LOW]` **The hotbar prints keys `1`–`4` under its slots**, but `main` has no consumable input actions.
- `[LOW]` **The material tooltip shows the raw zone id** ("Source Zones: SpiritValley").
- `[LOW]` **The Journal reads quest progress when its page opens and when the quest items change.** A step reached while the book lies open shows the next time the page opens.
- `[LOW]` **Tab-button icons shrink** from 0.95 to 0.75 scale in `TabButtonAnimation`. This was reported as janky before the June icon swap (c33064c, c4d3b4e) and hasn't been re-checked (unverified).

### Tech Debt

- `[MEDIUM]` **`EquipmentTab` mutates `InventoryData` directly** when it erases a trashed item, and emits `InventoryManager.inventory_changed` itself. Move this into an InventoryManager verb.
- `[MEDIUM]` **Test gaps.** There are no tests for `LootTable`, `AwardLootTableEffectData`, `AwardItemEffectData`, right-click quick-equip (only its trash-slot guard is tested), `GearSelector` or the generator script.
- `[LOW]` **Two drag systems coexist.** Equipment uses a manual one (`_input` plus hit-testing); consumables use Godot's built-in drag-and-drop.
- `[LOW]` **UI nodes built in code.** `SortSubBanner` creates its dot `TextureRect`s in code and frees the four authored `Dot0-3` nodes.
- `[LOW]` **Coding-standard gaps:**
  - untyped variables (for example `var inventory = get_inventory()` in `inventory_manager.gd`)
  - no `##` docs on `get_inventory`, `get_material_items`, `award_items`, `unequip_item` and `move_equipment`
  - `ItemDefinitionData`'s type-name and tooltip-line getters start with `_` but are called from other classes
- `[LOW]` **`GearSelector` finds its slots through the global "GearSlots" group**, so a second GearSelector in the tree would pick up both sets.
