# Quest Items Inventory Tab (Design)

> **Status:** Spec only. No implementation yet.
> **Source:** Follow-up to [Beat 3b — Merchant Unlock](./2026-04-21-beat-3b-merchant-unlock-design.md) §8 Out-of-Scope ("Quest-items inventory tab").
> **Scope:** Add a third top-level tab to the inventory view for QUEST_ITEM-typed items. List + detail-pane layout. No new gameplay behavior.

---

## 1. Goal

Give the player a permanent, inspectable surface for the Refugee Camp Map (and future quest items). Today the player sees each quest item only as a one-line log message on acquisition; the item lives in `InventoryData.quest_items` but is invisible in the UI. A dedicated tab makes these narrative tokens durable and browsable.

---

## 2. Player flow

1. Player opens the inventory (I key). The inventory book animates open. Three tab buttons appear in the tab switcher: **Equipment**, **Materials**, **Quest Items**.
2. Player clicks **Quest Items**. Page-turn animation plays. The tab pane shows a list of owned quest items on the left and an `ItemDescriptionPanel` on the right showing the first item's details.
3. Player clicks another row → the detail pane updates to that item.
4. If the player has no quest items yet, the list pane shows a single centered label: *"No quest items yet."* The detail pane is hidden.

---

## 3. Scene structure

New files under `scenes/inventory/inventory_view/quest_items_tab/`:

| File | Responsibility |
|---|---|
| `quest_items_tab.tscn` / `.gd` | Top-level pane. Owns the list container + `ItemDescriptionPanel`. Listens to `InventoryManager.inventory_changed` and rebuilds rows. Manages selection state (which row is "active"). |
| `quest_item_row.tscn` / `.gd` | Single clickable row: icon + name. Emits `row_clicked(item: ItemDefinitionData)` so the tab can update the detail pane. |

**Layout:** horizontal split — list on the left (scrollable `VBoxContainer` inside a `ScrollContainer`), `ItemDescriptionPanel` on the right. The split is 40/60 or similar; finalize during layout work.

**`ItemDescriptionPanel` reuse:** the shared component already exists at `scenes/common/.../item_description_panel.tscn` (per CLAUDE.md — used by inventory sidebar and end-card loot tooltips). The new tab instantiates and drives it; no changes to the component itself.

---

## 4. Data wiring

### 4.1 `InventoryManager.get_quest_items`

Add a public accessor mirroring the existing `get_material_items()`:

```gdscript
func get_quest_items() -> Dictionary[ItemDefinitionData, int]:
    return live_save_data.inventory.quest_items
```

Placed in the `PUBLIC API` section near `get_material_items()`.

### 4.2 `QuestItemsTab` script behavior

```gdscript
extends Control

@onready var list_vbox: VBoxContainer = %ListVBox
@onready var empty_label: Label = %EmptyLabel
@onready var description_panel: Control = %ItemDescriptionPanel

var _row_scene: PackedScene = preload(".../quest_item_row.tscn")
var _selected_item: ItemDefinitionData = null

func _ready() -> void:
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _rebuild_rows(InventoryManager.get_quest_items())

func _rebuild_rows(quest_items: Dictionary) -> void:
    # Clear
    for child in list_vbox.get_children():
        child.queue_free()

    if quest_items.is_empty():
        empty_label.visible = true
        description_panel.visible = false
        _selected_item = null
        return

    empty_label.visible = false
    description_panel.visible = true

    var first: ItemDefinitionData = null
    for item in quest_items.keys():
        var row := _row_scene.instantiate()
        row.item = item
        row.row_clicked.connect(_on_row_clicked)
        list_vbox.add_child(row)
        if first == null:
            first = item

    # Preserve selection across rebuilds if the item still exists;
    # otherwise fall back to the first row.
    if _selected_item == null or not quest_items.has(_selected_item):
        _selected_item = first
    _show_item(_selected_item)

func _on_row_clicked(item: ItemDefinitionData) -> void:
    _selected_item = item
    _show_item(item)

func _show_item(item: ItemDefinitionData) -> void:
    description_panel.set_item(item)  # uses ItemDescriptionPanel's existing API

func _on_inventory_changed(_inventory: InventoryData) -> void:
    _rebuild_rows(InventoryManager.get_quest_items())
```

Exact public method name on `ItemDescriptionPanel` (`set_item` vs `display_item`, etc.) is resolved during implementation by reading the existing component — do not invent a new API; match whatever the inventory sidebar and end card already call.

### 4.3 `QuestItemRow` script behavior

```gdscript
extends Button  # or Control with a gui_input handler — match tab_button's pattern

signal row_clicked(item: ItemDefinitionData)

@export var item: ItemDefinitionData : set = _set_item

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel

func _set_item(value: ItemDefinitionData) -> void:
    item = value
    if is_inside_tree():
        _update_visuals()

func _ready() -> void:
    pressed.connect(_on_pressed)  # or connect gui_input if Control-based
    _update_visuals()

func _update_visuals() -> void:
    if item == null:
        return
    if item.icon:
        icon_rect.texture = item.icon
    name_label.text = item.item_name

func _on_pressed() -> void:
    row_clicked.emit(item)
```

Row visual style (background, hover, selected state) follows whatever `tab_button.tscn` or `material_container.tscn` already uses — match the existing inventory visual vocabulary, do not introduce new theme tokens.

---

## 5. Tab switcher integration

### 5.1 `TabSwitcher` changes

File: `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`

Add a third `tab_button` ref + append to the `tab_buttons` array:

```gdscript
@onready var equipment_tab_button: Control = %EquipmentTabButton
@onready var materials_tab_button: Control = %MaterialsTabButton
@onready var quest_items_tab_button: Control = %QuestItemsTabButton
@onready var tab_buttons: Array[Control] = [
    equipment_tab_button,
    materials_tab_button,
    quest_items_tab_button,
]
```

Corresponding `.tscn` edit: add a third `TabButton` instance with `%QuestItemsTabButton` as unique name, label "Quest Items", same styling as the other two buttons. Placeholder icon for MVP (any existing texture).

### 5.2 `InventoryView` changes

File: `scenes/inventory/inventory_view/inventory_view.gd`

Extend the `tabs` array:

```gdscript
@onready var tabs: Array[Control] = [%EquipmentTab, %MaterialsTab, %QuestItemsTab]
```

Corresponding `.tscn` edit: add `QuestItemsTab` scene as a sibling of the other two tabs under the book-content hierarchy, with `%QuestItemsTab` unique name.

No changes to `_on_tab_changed`, animation logic, or page-turn direction logic — they all iterate the `tabs` array and naturally support N tabs.

### 5.3 Visibility initialization

`InventoryView._ready()` currently sets all tabs invisible then `tabs[0].visible = true`. The new tab is index 2, so it starts hidden — no change needed.

---

## 6. Empty state

When `get_quest_items().is_empty()`:
- An `%EmptyLabel` (pre-authored in the tab's `.tscn`, hidden by default) becomes visible. Text: *"No quest items yet."* Centered in the list pane.
- The `ItemDescriptionPanel` is hidden via `.visible = false`.
- `_selected_item = null`.

When a quest item is awarded while the tab is open, `inventory_changed` fires → `_rebuild_rows` runs → the empty label hides, the first row appears and auto-selects.

---

## 7. Testing

### Unit

- Extend `tests/unit/test_inventory_manager.gd` with `test_get_quest_items_returns_dict` — award a QUEST_ITEM, call `get_quest_items()`, assert the item appears with quantity 1.

### Manual playtest (non-gating)

- Fresh save, open inventory → Quest Items tab → confirm empty state label shows and description panel is hidden.
- Use dev panel (or the Beat 3b dialogue 4 flow) to award the Refugee Camp Map → return to inventory → confirm Map appears in the Quest Items list, auto-selected, with its description visible.
- Add a second quest item (via dev panel or a second test item) → confirm list scrolls, clicking a row updates the description pane.

### Integration

No new integration test required. The Beat 3b integration test already exercises the `InventoryData.quest_items` → `has_item` → `get_inventory().quest_items` data path. This feature is a presentation layer over that data; UI rendering is not covered by GUT and is verified by playtest.

---

## 8. Out of scope / follow-ups

- **Quest item quantity display.** `stack_size = 1` for quest items today, so quantity is always 1. Not shown in rows. If future quest items become stackable (e.g., a key type), a quantity badge can land in the row scene without redesign.
- **Row actions (discard, use, etc.).** Quest items are passive tokens right now. No right-click menu, no drag-drop. If a future item needs to be consumable, revisit.
- **Sorting / filtering.** Insertion order is fine for the foreseeable count (1–5 items). Alphabetical sort + search can come when the list grows.
- **Dedicated quest-item icons.** All quest items currently use the project's placeholder `64.png`. Real art is a polish task.
- **Tab-button badge for new items.** A "you have a new quest item" indicator on the tab button would be nice for discoverability. Deferred — out of scope for the MVP tab.
- **Dev panel entry for quest items.** Convenience for playtesting. Flag as a follow-up in the dev-panel doc rather than bundling here.
