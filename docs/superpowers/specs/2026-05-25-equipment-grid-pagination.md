# Equipment Grid Pagination

**Date:** 2026-05-25
**Status:** Draft (pending user review)
**Approved direction:** design confirmed "lgtm" by user 2026-05-25.

---

## Goal

Replace the Equipment tab's scroll-container grid with an **NGU-Idle-style paginated** grid. Each page holds a fixed 6×6 = 36 slots. The player starts with one page and earns more as a progression bonus. Page-number buttons at the bottom navigate between pages; dragging an item over a page number flips to that page so the item can be dropped there.

### Why

Scrolling muddies the UI — it's awkward to "carry" an item to an off-screen part of the grid while dragging, and the scroll rail competes visually with the cells. Pagination gives clean fixed-size pages, makes earned inventory space feel like a reward, and keeps every slot reachable during a drag via hover-to-flip.

---

## Scope

### In scope

- Rework `EquipmentGrid` from a `ScrollContainer`-based view into a plain fixed 6×6 (36-slot) grid with a `current_page` index. No scroll container, no scroll bar.
- New `PaginationBar` component at the bottom of the Equipment tab: count label + page-number buttons + trash slot, all in one row.
- `InventoryData.unlocked_equipment_pages` counter (default 1) + `SLOTS_PER_PAGE` constant + `equipment_capacity()` helper.
- `InventoryManager`: capacity-aware slot placement, `grant_equipment_page()`.
- Drag/drop global-index mapping (`current_page × 36 + local_slot_index`).
- Instant hover-to-flip page switching during a drag.
- Count shows **total items / total unlocked capacity** (e.g. "14 / 72").
- Locked (not-yet-unlocked) pages are **hidden** — only unlocked page numbers render.
- Move the trash slot from the top GridToolbar into the new bottom PaginationBar (Equipment tab only).
- Unit + integration tests for the data model, capacity logic, and pagination UI behavior.

### Out of scope (deferred)

- **Pagination for Materials / Consumables tabs.** They keep the top `GridToolbar` (count + trash) and their current populate-by-dict-iteration layout. Only Equipment paginates this slice.
- **The actual unlock triggers** that call `grant_equipment_page()`. This slice ships the method + the counter; wiring it to story beats / cultivation milestones / unlock conditions is a follow-up. For now a page can be granted via a dev action or a test.
- **Dedicated page-tab art.** Page buttons render procedurally (Label + parchment stylebox). A polished active/inactive page-tab sprite is a nice-to-have follow-up, not required.
- **Locked-page teasers.** No greyed-out "🔒 page 4" affordance — locked pages are simply absent until unlocked.
- **Reconciling the trash-slot position divergence.** After this slice, Equipment's trash slot sits in the bottom bar while Materials/Consumables keep theirs in the top GridToolbar. Accepted inconsistency; reconcile only if/when those tabs get similar treatment.

---

## Architecture

```
EquipmentTab (Control)
  ├─ EquipmentTabBanner (TextureRect)          ← unchanged
  ├─ SortSubBanner (instance)                  ← unchanged (top)
  ├─ EquipmentGrid (rework: plain 6×6 grid)    ← no scroll
  ├─ PaginationBar (NEW, bottom)
  │    ├─ CountLabel    (left)   "14 / 72"
  │    ├─ PageButtons   (center) [1] [2] [3]
  │    └─ TrashSlot     (right)  ✕   (relocated from GridToolbar)
  ├─ GearSelector (instance)                   ← unchanged (right page)
  └─ ItemDescriptionBox (instance)             ← unchanged (right page)
```

The Equipment tab no longer instances `GridToolbar`. The shared `GridToolbar` scene is untouched and still used by Materials/Consumables.

### Component responsibilities

| Unit | Responsibility | Interface |
|---|---|---|
| `InventoryData` | Holds `unlocked_equipment_pages`; exposes `SLOTS_PER_PAGE` and `equipment_capacity()`. The `equipment` dict stays keyed by global slot index. | `equipment_capacity() -> int` |
| `EquipmentGrid` | Renders exactly 36 slots for `current_page`. Maps local child-index → global slot index. Emits `slot_clicked`. | `set_page(p: int)`, `current_page: int`, `get_slots()`, `slot_clicked` |
| `PaginationBar` | Renders count + one button per unlocked page + the trash slot. Highlights the active page. Emits page navigation signals. | `setup(unlocked_pages, active_page)`, `set_count(used, total)`, `set_active_page(p)`, `trash_slot`, signals `page_selected(i)` / `page_hovered(i)` |
| `equipment_tab.gd` | Wires PaginationBar ↔ EquipmentGrid, owns drag/drop with global-index mapping, handles hover-to-flip during drag. | (tab controller, no public API) |
| `InventoryManager` | Capacity-aware placement + `grant_equipment_page()`. | `grant_equipment_page() -> void` |

---

## Data model

### `InventoryData` additions

```gdscript
## Slots per equipment page (6 columns × 6 rows). Global slot index for
## page P, local position i is P * SLOTS_PER_PAGE + i.
const SLOTS_PER_PAGE := 36

## Number of equipment pages the player has unlocked. Starts at 1; granted
## by InventoryManager.grant_equipment_page(). Total capacity is
## unlocked_equipment_pages * SLOTS_PER_PAGE.
@export var unlocked_equipment_pages: int = 1

## Total equipment slots currently available across all unlocked pages.
func equipment_capacity() -> int:
    return unlocked_equipment_pages * SLOTS_PER_PAGE
```

`equipment` remains `Dictionary[int, ItemInstanceData]` keyed by global index. No migration needed — existing saves default `unlocked_equipment_pages` to 1, and any existing keys ≥ 36 (the old grid was 60 slots) still load; they'd live on "page 2" if present, but since the player starts with 1 page they wouldn't be visible until a page is granted. (In practice current saves only use low indices.)

> **Edge note:** the old grid allowed indices up to 59 with 1 "page". After this change, with `unlocked_equipment_pages = 1`, capacity is 36, so indices 36–59 would be off-page. This only affects dev saves that manually placed items past index 35; normal play never did (items fill from index 0). Acceptable.

---

## `EquipmentGrid` rework

**File:** `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn` + `.gd`

### Scene
Strip the `ScrollContainer`, `VScrollBar`, `Grabber`, and the hide-scrollbar theme. Root becomes:

```
EquipmentGrid (MarginContainer, script)
  └─ GridContainer (%GridContainer, columns = 6,
                    h_separation = 6, v_separation = 6)
     ├─ InventorySlot × 36   (authored in the scene, or instanced in _ready)
```

### Script
```gdscript
class_name EquipmentGrid
extends MarginContainer

const SLOTS_PER_PAGE := 36   # mirror of InventoryData.SLOTS_PER_PAGE for view math

signal slot_clicked(slot: InventorySlot, event: InputEvent)

@onready var grid_container: GridContainer = %GridContainer

var current_page: int = 0
var inventory_slot_scene: PackedScene = preload("res://scenes/inventory/inventory_view/equipment_tab/inventory_slot/inventory_slot.tscn")

func _ready() -> void:
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _update_grid(InventoryManager.get_inventory())

## Switch to a page and re-render. Clamps to [0, unlocked_pages - 1].
func set_page(page: int) -> void:
    var max_page := InventoryManager.get_inventory().unlocked_equipment_pages - 1
    current_page = clampi(page, 0, max_page)
    _update_grid(InventoryManager.get_inventory())

func get_slots() -> Array[InventorySlot]:
    var slots: Array[InventorySlot] = []
    for child in grid_container.get_children():
        if child is InventorySlot:
            slots.append(child)
    return slots

func _on_inventory_changed(inventory: InventoryData) -> void:
    # A page may have been granted (or removed); re-clamp + re-render.
    set_page(current_page)

func _update_grid(inventory: InventoryData) -> void:
    for slot in grid_container.get_children():
        slot.queue_free()
    var base := current_page * SLOTS_PER_PAGE
    for i in SLOTS_PER_PAGE:
        var slot = inventory_slot_scene.instantiate()
        slot.clicked.connect(_on_slot_clicked)
        grid_container.add_child(slot)
        var global_index := base + i
        if inventory.equipment.has(global_index):
            slot.setup(inventory.equipment[global_index])
        else:
            slot.setup(null)

func _on_slot_clicked(slot: InventorySlot, event: InputEvent) -> void:
    slot_clicked.emit(slot, event)
```

Note: `slot.get_index()` returns the child's position 0–35 within `GridContainer`, which is the **local** index. The tab controller converts it to global with `current_page * SLOTS_PER_PAGE + slot.get_index()`.

---

## `PaginationBar` (new)

**Files:** `scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.tscn` + `.gd`

### Scene
```
PaginationBar (HBoxContainer)
  ├─ CountLabel (Label, LabelInventoryCount variant + 0.5-scale trick, left)
  ├─ PageButtons (HBoxContainer, center, size_flags EXPAND_FILL)
  │    └─ (page buttons added in code)
  └─ TrashSlot (instanced from trash_slot.tscn, right, size_flags SHRINK_END)
```

The CountLabel reuses the same crisp-text pattern committed earlier (`scale = Vector2(0.5, 0.5)`, `pivot_offset`, `LabelInventoryCount` variant). The TrashSlot is the same `trash_slot.tscn` instance, exposed via a `trash_slot` property like `GridToolbar` did, so the tab controller and the close-flush logic keep working unchanged.

### Page buttons (procedural)
Each page button is a `Button` (or a clickable `PanelContainer` + Label) showing the 1-based page number. Active page is tinted/bordered (e.g. gold border or brightened modulate); inactive pages use the resting parchment style. Styling reuses existing styleboxes + the inventory-count label look — **no new art required**.

### Script
```gdscript
class_name PaginationBar
extends HBoxContainer

signal page_selected(index: int)   # 0-based, on click
signal page_hovered(index: int)    # 0-based, on mouse-enter (drag-flip)

@onready var count_label: Label = %CountLabel
@onready var page_buttons: HBoxContainer = %PageButtons
@onready var trash_slot: TrashSlot = %TrashSlot

var _active_page: int = 0

## Rebuild the page-button row for `unlocked_pages` and mark `active_page`.
func setup(unlocked_pages: int, active_page: int) -> void:
    _active_page = active_page
    for child in page_buttons.get_children():
        child.queue_free()
    for p in unlocked_pages:
        var btn := _make_page_button(p)
        page_buttons.add_child(btn)
    _refresh_active_visuals()

func set_active_page(p: int) -> void:
    _active_page = p
    _refresh_active_visuals()

func set_count(used: int, total: int) -> void:
    count_label.text = "%d / %d" % [used, total]

func _make_page_button(page_index: int) -> Control:
    var btn := Button.new()
    btn.text = str(page_index + 1)
    btn.pressed.connect(func(): page_selected.emit(page_index))
    btn.mouse_entered.connect(func(): page_hovered.emit(page_index))
    # styling applied here / via theme variation
    return btn

func _refresh_active_visuals() -> void:
    var i := 0
    for child in page_buttons.get_children():
        # active page gets the highlighted look
        child.set("button_pressed", i == _active_page) # or modulate, per styling
        i += 1
```

(Exact button styling lands during implementation; the interface above is the contract.)

---

## `equipment_tab.gd` changes

- Replace `grid_toolbar` references with `pagination_bar`.
- `@onready var trash_slot: TrashSlot = pagination_bar.trash_slot` (mirrors the current `grid_toolbar.trash_slot` pattern).
- In `_ready()`:
  - `pagination_bar.page_selected.connect(_on_page_selected)`
  - `pagination_bar.page_hovered.connect(_on_page_hovered)`
  - `_refresh_pagination()` (sets up buttons + count from the inventory)
- New handlers:
  ```gdscript
  func _on_page_selected(index: int) -> void:
      equipment_grid.set_page(index)
      pagination_bar.set_active_page(index)

  func _on_page_hovered(index: int) -> void:
      if is_dragging:
          equipment_grid.set_page(index)
          pagination_bar.set_active_page(index)

  func _on_inventory_changed(_inv: InventoryData) -> void:
      _refresh_pagination()

  func _refresh_pagination() -> void:
      var inv := InventoryManager.get_inventory()
      pagination_bar.setup(inv.unlocked_equipment_pages, equipment_grid.current_page)
      pagination_bar.set_count(inv.equipment.size(), inv.equipment_capacity())
  ```
- **Global-index mapping:** anywhere the drag/drop code currently uses `original_slot.get_index()` or `target_slot.get_index()` for a grid slot, multiply through the page:
  ```gdscript
  func _grid_global_index(slot: InventorySlot) -> int:
      return equipment_grid.current_page * EquipmentGrid.SLOTS_PER_PAGE + slot.get_index()
  ```
  Use `_grid_global_index(slot)` for `move_equipment`, `equip_item` (from_index), `unequip_item_to_slot` (target_index), and `restore_equipment_instance` (target index). GearSlot indices are unaffected (gear slots aren't in the paged grid).

> **Subtlety:** `_get_slot_under_mouse` returns the slot under the cursor. With hover-flip, by the time the player releases over a slot, `current_page` already reflects the page they flipped to, so `_grid_global_index` resolves correctly against the visible page.

---

## `InventoryManager` changes

```gdscript
## Grant the player one more equipment page (progression reward).
func grant_equipment_page() -> void:
    var inventory := get_inventory()
    inventory.unlocked_equipment_pages += 1
    inventory_changed.emit(inventory)
```

Update `_add_to_first_available_slot` to cap at capacity:

```gdscript
func _add_to_first_available_slot(inventory: InventoryData, item: ItemInstanceData) -> void:
    var capacity := inventory.equipment_capacity()
    for i in capacity:
        if not inventory.equipment.has(i):
            inventory.equipment[i] = item
            return
    Log.warn("InventoryManager: Equipment full (%d/%d), cannot add %s" % [
        inventory.equipment.size(), capacity, item.item_definition.item_id if item.item_definition else "?"])
```

`restore_equipment_instance` already falls back to `_add_to_first_available_slot`, so it inherits the capacity cap automatically. Its explicit `target_slot_index` path should also reject indices `>= capacity` (fall back to first-available).

---

## Data flow summary

1. **Open inventory** → `equipment_tab._ready` → `_refresh_pagination()` builds buttons (1 button if 1 page) + count; `EquipmentGrid` renders page 0.
2. **Click page button** → `page_selected` → `set_page` + `set_active_page` → grid re-renders that page's 36-slot slice.
3. **Drag item, hover page button** → `page_hovered` (only acts if `is_dragging`) → `set_page` flips the visible page; the dragged ghost (child of EquipmentTab) persists; drop maps to the new page's global index.
4. **Inventory changes** (item moved, page granted) → `inventory_changed` → `_refresh_pagination` (rebuilds button row if page count changed) + grid re-renders current page (re-clamped).
5. **Grant page** (dev/test/future trigger) → `grant_equipment_page` → `inventory_changed` → a new page button appears.

---

## Testing

### Unit (`tests/unit/`)

`test_inventory_data_pagination.gd`:
- `equipment_capacity()` returns `unlocked_equipment_pages * 36` (1 page → 36, 3 pages → 108).
- Default `unlocked_equipment_pages == 1`.

`test_inventory_manager_pages.gd`:
- `grant_equipment_page()` increments the counter and emits `inventory_changed`.
- `_add_to_first_available_slot` fills indices 0..35 on a 1-page inventory, then warns/declines the 37th item (capacity reached).
- After `grant_equipment_page()`, the 37th item lands at index 36.

### Integration (`tests/integration/`)

`test_equipment_grid_pagination.gd`:
- `EquipmentGrid` always has exactly 36 slot children.
- `set_page(1)` on a 2-page inventory renders the slice for indices 36–71 (place an item at index 36, assert it shows in slot 0 after `set_page(1)`).
- `set_page` clamps to the unlocked range (set_page(5) with 2 pages → current_page == 1).

`test_pagination_bar.gd`:
- `setup(3, 0)` creates 3 page buttons; `setup(1, 0)` creates 1.
- Clicking button index 2 emits `page_selected(2)`.
- `mouse_entered` on a button emits `page_hovered(idx)`.
- `set_count(14, 72)` → label text "14 / 72".

`test_equipment_drag_paging.gd` (controller-level, mirrors the existing trash-flow test style):
- Drive `_grid_global_index` math: with `current_page = 1`, a slot at child-index 0 maps to global index 36.
- Hover-flip: simulate `page_hovered(1)` while `is_dragging` → `equipment_grid.current_page == 1`.

---

## Migration / risk notes

- No save migration required (`unlocked_equipment_pages` defaults to 1; `equipment` dict unchanged).
- The old `EquipmentGrid` exposed `%VScrollBar` / `%Grabber` / `%ScrollContainer`; after the rework those node refs are gone. Confirm nothing outside `equipment_grid.gd` references them (the tab controller only uses `slot_clicked` and `get_slots()`).
- `GridToolbar` stays in the project (Materials/Consumables). Only the Equipment tab stops instancing it.
- Equipment trash-slot relocates to the bottom bar — the `TrashSlots` group membership (used by `inventory_view.gd` close-flush) is preserved because it's the same `trash_slot.tscn` instance, just re-parented into PaginationBar.

---

## Decisions resolved 2026-05-25

| Question | Decision |
|---|---|
| Unlock mechanism | Simple `unlocked_equipment_pages: int = 1` counter on `InventoryData` (persisted via SaveGameData). Triggers deferred. |
| Page size | 36 slots (6×6). |
| Locked pages | Hidden entirely — only unlocked page numbers render. |
| Count meaning | Total items / total unlocked capacity ("14 / 72"). |
| Drag-across-pages | Instant switch on hover of a page button. |
| Layout | Approach 2 — single bottom bar: count + page numbers + trash slot. GridToolbar removed from Equipment tab. |
| Assets | None required; page buttons procedural. Dedicated page-tab sprite is an optional follow-up. |
