# Equipment Grid Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Equipment tab's scroll-based grid with an NGU-Idle-style paginated grid (fixed 6×6 = 36 slots per page), a bottom PaginationBar (count + page buttons + relocated trash slot), and capacity-aware item placement gated by an `unlocked_equipment_pages` counter.

**Architecture:** `InventoryData` gains a page counter + capacity helper; the `equipment` dict stays keyed by **global** slot index. `EquipmentGrid` becomes a plain 6×6 grid with a `current_page` that maps local child-index → global index. A new `PaginationBar` renders count + page buttons + trash slot and drives page switching (click + hover-during-drag). `equipment_tab.gd` rewires to the PaginationBar and translates every grid-slot index through the current page.

**Tech Stack:** Godot 4.6 GDScript, GUT v9.6.0 tests, existing `pixel_theme.tres` variants (`LabelInventoryCount`).

**Spec:** [`docs/superpowers/specs/2026-05-25-equipment-grid-pagination.md`](../specs/2026-05-25-equipment-grid-pagination.md)

---

## Conventions

- Repo-relative paths; add `res://` when loading from GDScript.
- GDScript standards from `CLAUDE.md`: `##` doc comments on public funcs, explicit return types, `%` unique-name access, `_` private prefix, no `print()`.
- GUT tests `extends GutTest`, in `tests/unit/` (pure logic) or `tests/integration/` (scene-driving).
- Full test run command (used at each task's verification):
  ```
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
  ```
  Current baseline: **504 passing**.

---

## File map

### New files
```
scenes/inventory/inventory_view/equipment_tab/pagination_bar/
  pagination_bar.tscn
  pagination_bar.gd
tests/unit/test_inventory_data_pagination.gd
tests/unit/test_inventory_manager_pages.gd
tests/integration/test_equipment_grid_pagination.gd
tests/integration/test_pagination_bar.gd
tests/integration/test_equipment_drag_paging.gd
```

### Modified files
```
singletons/persistence_manager/inventory_data.gd            # SLOTS_PER_PAGE, unlocked_equipment_pages, equipment_capacity()
singletons/inventory_manager/inventory_manager.gd            # capacity-aware placement, grant_equipment_page()
scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn   # strip scroll, plain 6×6
scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd     # current_page + set_page
scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd                     # rewire to PaginationBar + global index
scenes/inventory/inventory_view/inventory_view.tscn          # EquipmentTab: drop GridToolbar, add PaginationBar, reposition
```

---

## Task 1: InventoryData pagination fields

**Files:**
- Modify: `singletons/persistence_manager/inventory_data.gd`
- Test: `tests/unit/test_inventory_data_pagination.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_inventory_data_pagination.gd
extends GutTest

func test_default_unlocked_pages_is_one() -> void:
    var inv := InventoryData.new()
    assert_eq(inv.unlocked_equipment_pages, 1)

func test_slots_per_page_constant() -> void:
    assert_eq(InventoryData.SLOTS_PER_PAGE, 36)

func test_capacity_one_page() -> void:
    var inv := InventoryData.new()
    assert_eq(inv.equipment_capacity(), 36)

func test_capacity_three_pages() -> void:
    var inv := InventoryData.new()
    inv.unlocked_equipment_pages = 3
    assert_eq(inv.equipment_capacity(), 108)
```

- [ ] **Step 2: Run tests, verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_inventory_data_pagination.gd -gexit
```
Expected: FAIL (`Invalid access to constant 'SLOTS_PER_PAGE'` / missing field).

- [ ] **Step 3: Add the fields**

In `singletons/persistence_manager/inventory_data.gd`, add after the existing `equipped_consumables` field (keep all existing fields intact):

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

- [ ] **Step 4: Run tests, verify they pass**

Run the command from Step 2. Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add singletons/persistence_manager/inventory_data.gd tests/unit/test_inventory_data_pagination.gd
git commit -m "feat(inventory): add unlocked_equipment_pages + capacity to InventoryData"
```

---

## Task 2: InventoryManager — grant page + capacity-aware placement

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager_pages.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_inventory_manager_pages.gd
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func _make_equipment() -> EquipmentDefinitionData:
    var def := EquipmentDefinitionData.new()
    def.item_id = "test_blade"
    def.item_name = "Test Blade"
    return def

func test_grant_equipment_page_increments_and_emits() -> void:
    watch_signals(InventoryManager)
    InventoryManager.grant_equipment_page()
    assert_eq(InventoryManager.get_inventory().unlocked_equipment_pages, 2)
    assert_signal_emitted(InventoryManager, "inventory_changed")

func test_award_fills_first_page_then_stops_at_capacity() -> void:
    var def := _make_equipment()
    # 1 page = 36 slots. Award 36 → all placed at indices 0..35.
    InventoryManager.award_items(def, 36)
    var inv := InventoryManager.get_inventory()
    assert_eq(inv.equipment.size(), 36)
    assert_true(inv.equipment.has(0))
    assert_true(inv.equipment.has(35))
    # 37th item exceeds capacity → not placed.
    InventoryManager.award_items(def, 1)
    assert_eq(InventoryManager.get_inventory().equipment.size(), 36)

func test_granting_a_page_makes_room_for_more() -> void:
    var def := _make_equipment()
    InventoryManager.award_items(def, 36)   # fills page 1
    InventoryManager.grant_equipment_page() # now 2 pages = 72 capacity
    InventoryManager.award_items(def, 1)    # 37th lands at index 36
    var inv := InventoryManager.get_inventory()
    assert_eq(inv.equipment.size(), 37)
    assert_true(inv.equipment.has(36))
```

- [ ] **Step 2: Run tests, verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_inventory_manager_pages.gd -gexit
```
Expected: FAIL (`grant_equipment_page` missing; capacity test fails because current `_add_to_first_available_slot` caps at 50, not 36).

- [ ] **Step 3: Add grant_equipment_page + update capacity cap**

In `singletons/inventory_manager/inventory_manager.gd`, add to the PUBLIC API section (e.g. after the `restore_*` methods):

```gdscript
## Grant the player one more equipment page (a progression reward).
## Increments the unlocked page count and notifies listeners so the
## pagination UI can show the new page.
func grant_equipment_page() -> void:
    var inventory := get_inventory()
    inventory.unlocked_equipment_pages += 1
    inventory_changed.emit(inventory)
```

Then replace the body of the existing private `_add_to_first_available_slot` (currently uses `var max_slots = 50`):

```gdscript
func _add_to_first_available_slot(inventory: InventoryData, item: ItemInstanceData) -> void:
    var capacity := inventory.equipment_capacity()
    for i in capacity:
        if not inventory.equipment.has(i):
            inventory.equipment[i] = item
            return
    var item_id := item.item_definition.item_id if item.item_definition else "?"
    Log.warn("InventoryManager: Equipment full (%d/%d), cannot add %s" % [inventory.equipment.size(), capacity, item_id])
```

- [ ] **Step 4: Harden restore_equipment_instance's explicit-index path**

The spec requires `restore_equipment_instance` to reject out-of-capacity target indices and fall back to first-available. Update its target-index guard (currently `if target_slot_index >= 0 and not inventory.equipment.has(target_slot_index):`):

```gdscript
func restore_equipment_instance(instance: ItemInstanceData, target_slot_index: int = -1) -> void:
    if instance == null:
        Log.error("InventoryManager.restore_equipment_instance: null instance")
        return
    var inventory := get_inventory()
    if target_slot_index >= 0 and target_slot_index < inventory.equipment_capacity() and not inventory.equipment.has(target_slot_index):
        inventory.equipment[target_slot_index] = instance
    else:
        _add_to_first_available_slot(inventory, instance)
    inventory_changed.emit(inventory)
```

- [ ] **Step 5: Run tests, verify they pass**

Run the command from Step 2. Expected: 3/3 pass. Then run the full suite to confirm the capacity change didn't break existing equipment tests:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all green (was 504, now +7 from Tasks 1–2).

- [ ] **Step 6: Commit**

```bash
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager_pages.gd
git commit -m "feat(inventory): grant_equipment_page + capacity-aware slot placement"
```

---

## Task 3: EquipmentGrid rework — fixed 6×6, current_page, no scroll

**Files:**
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn`
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd`
- Test: `tests/integration/test_equipment_grid_pagination.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/integration/test_equipment_grid_pagination.gd
extends GutTest

const GridScene := preload("res://scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn")

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func _inst() -> ItemInstanceData:
    var d := ItemInstanceData.new()
    d.item_definition = EquipmentDefinitionData.new()
    return d

func test_grid_always_has_36_slots() -> void:
    var grid := GridScene.instantiate()
    add_child_autofree(grid)
    await get_tree().process_frame
    assert_eq(grid.get_slots().size(), 36)

func test_set_page_renders_correct_slice() -> void:
    var inv := PersistenceManager.save_game_data.inventory
    inv.unlocked_equipment_pages = 2
    var marker := _inst()
    inv.equipment[36] = marker  # first slot of page 2 (0-based page index 1)

    var grid := GridScene.instantiate()
    add_child_autofree(grid)
    await get_tree().process_frame

    grid.set_page(1)
    await get_tree().process_frame
    var slots := grid.get_slots()
    # Local slot 0 on page 1 maps to global index 36 → should show the marker.
    assert_not_null(slots[0].item_instance, "page-2 slot 0 should hold the item at global index 36")

func test_set_page_clamps_to_unlocked_range() -> void:
    var inv := PersistenceManager.save_game_data.inventory
    inv.unlocked_equipment_pages = 2
    var grid := GridScene.instantiate()
    add_child_autofree(grid)
    await get_tree().process_frame
    grid.set_page(5)  # only pages 0..1 exist
    assert_eq(grid.current_page, 1)
```

- [ ] **Step 2: Run test, verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_equipment_grid_pagination.gd -gexit
```
Expected: FAIL (`set_page` / `current_page` missing; grid may not have 36 slots).

- [ ] **Step 3: Rewrite equipment_grid.tscn**

Replace the scene with a plain grid (strip `ScrollContainer`, `VScrollBar`, `Grabber`, the hide-scrollbar `Theme`, and all authored `InventorySlot` children — slots are created in code):

```
[gd_scene load_steps=2 format=3 uid="uid://u2naqgqaai45"]

[ext_resource type="Script" uid="uid://d317jgqld3fkw" path="res://scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd" id="1_5kgqq"]

[node name="EquipmentGrid" type="MarginContainer"]
offset_right = 236.0
offset_bottom = 220.0
script = ExtResource("1_5kgqq")

[node name="GridContainer" type="GridContainer" parent="."]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/h_separation = 6
theme_override_constants/v_separation = 6
columns = 6
```

(Keep the scene's `uid` and the script's `uid` exactly as above so `inventory_view.tscn`'s ExtResource reference to `equipment_grid.tscn` still resolves.)

- [ ] **Step 4: Rewrite equipment_grid.gd**

```gdscript
class_name EquipmentGrid
extends MarginContainer

## EquipmentGrid
## A fixed 6×6 (36-slot) page of the equipment inventory. The visible page
## is `current_page`; local slot child-index i maps to global inventory
## index current_page * SLOTS_PER_PAGE + i. No scrolling — navigation is
## handled by the PaginationBar.

const SLOTS_PER_PAGE := 36

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
    var inventory := InventoryManager.get_inventory()
    var max_page := inventory.unlocked_equipment_pages - 1
    current_page = clampi(page, 0, max_page)
    _update_grid(inventory)

## Returns the 36 InventorySlot children of the grid.
func get_slots() -> Array[InventorySlot]:
    var slots: Array[InventorySlot] = []
    for child in grid_container.get_children():
        if child is InventorySlot:
            slots.append(child)
    return slots

func _on_inventory_changed(_inventory: InventoryData) -> void:
    # A page may have been granted; re-clamp current_page and re-render.
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

- [ ] **Step 5: Run tests, verify they pass**

Run the command from Step 2. Expected: 3/3 pass.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab/equipment_grid tests/integration/test_equipment_grid_pagination.gd
git commit -m "feat(inventory): EquipmentGrid paginated 6x6, drop scroll container"
```

---

## Task 4: PaginationBar component

**Files:**
- Create: `scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.tscn`
- Create: `scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.gd`
- Test: `tests/integration/test_pagination_bar.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/integration/test_pagination_bar.gd
extends GutTest

const BarScene := preload("res://scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.tscn")

func _bar() -> PaginationBar:
    var bar := BarScene.instantiate()
    add_child_autofree(bar)
    return bar

func test_setup_creates_one_button_per_page() -> void:
    var bar := _bar()
    await get_tree().process_frame
    bar.setup(3, 0)
    assert_eq(bar.page_buttons.get_child_count(), 3)
    bar.setup(1, 0)
    assert_eq(bar.page_buttons.get_child_count(), 1)

func test_clicking_button_emits_page_selected() -> void:
    var bar := _bar()
    await get_tree().process_frame
    bar.setup(3, 0)
    watch_signals(bar)
    var third_btn: Button = bar.page_buttons.get_child(2)
    third_btn.pressed.emit()
    assert_signal_emitted_with_parameters(bar, "page_selected", [2])

func test_hovering_button_emits_page_hovered() -> void:
    var bar := _bar()
    await get_tree().process_frame
    bar.setup(2, 0)
    watch_signals(bar)
    var second_btn: Button = bar.page_buttons.get_child(1)
    second_btn.mouse_entered.emit()
    assert_signal_emitted_with_parameters(bar, "page_hovered", [1])

func test_set_count_formats_label() -> void:
    var bar := _bar()
    await get_tree().process_frame
    bar.set_count(14, 72)
    assert_eq(bar.count_label.text, "14 / 72")

func test_has_trash_slot() -> void:
    var bar := _bar()
    await get_tree().process_frame
    assert_not_null(bar.trash_slot)
    assert_true(bar.trash_slot is TrashSlot)
```

- [ ] **Step 2: Run test, verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_pagination_bar.gd -gexit
```
Expected: FAIL (scene not found).

- [ ] **Step 3: Create pagination_bar.tscn**

Node tree (the CountLabel reuses the crisp-text wrapper pattern from `grid_toolbar.tscn`):

```
PaginationBar (HBoxContainer, theme = pixel_theme.tres, script = pagination_bar.gd,
               theme_override_constants/separation = 8)
  ├─ CountWrapper (Control, clip_contents = true,
  │                custom_minimum_size = (80, 28),
  │                size_flags_horizontal = 0)   # SHRINK_BEGIN — stays left
  │    └─ CountLabel (Label, unique_name_in_owner,
  │                   anchors_preset = 15, anchor_right = 1, anchor_bottom = 1,
  │                   grow_horizontal = 2, grow_vertical = 2,
  │                   scale = Vector2(0.5, 0.5), pivot_offset = Vector2(0, 14),
  │                   theme_type_variation = "LabelInventoryCount",
  │                   text = "0 / 0", vertical_alignment = 1)
  ├─ PageButtons (HBoxContainer, unique_name_in_owner,
  │               size_flags_horizontal = 3,   # EXPAND_FILL — center area
  │               alignment = 1,               # center the buttons
  │               theme_override_constants/separation = 4)
  └─ TrashSlot (instanced from trash_slot.tscn, unique_name_in_owner,
                size_flags_horizontal = 8,     # SHRINK_END — stays right
                size_flags_vertical = 4)
```

ExtResources the scene needs:
- `pixel_theme.tres` (uid `uid://yqkvsb5q7pab`)
- `pagination_bar.gd`
- `trash_slot.tscn` (uid `uid://bx475rcu42d08`)

- [ ] **Step 4: Write pagination_bar.gd**

```gdscript
class_name PaginationBar
extends HBoxContainer

## PaginationBar
## Bottom bar of the Equipment tab: total-item count (left), one button per
## unlocked page (center), and the discard/trash slot (right). Emits
## page_selected on click and page_hovered on mouse-enter (used for the
## drag-to-flip behaviour driven by the EquipmentTab controller).

signal page_selected(index: int)   # 0-based page index, on click
signal page_hovered(index: int)    # 0-based page index, on mouse-enter

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
        page_buttons.add_child(_make_page_button(p))
    _refresh_active_visuals()

## Highlight a different active page without rebuilding the buttons.
func set_active_page(page: int) -> void:
    _active_page = page
    _refresh_active_visuals()

## Set the count text as "<used> / <total>".
func set_count(used: int, total: int) -> void:
    count_label.text = "%d / %d" % [used, total]

func _make_page_button(page_index: int) -> Button:
    var btn := Button.new()
    btn.text = str(page_index + 1)
    btn.focus_mode = Control.FOCUS_NONE
    btn.custom_minimum_size = Vector2(24, 24)
    btn.toggle_mode = true
    btn.pressed.connect(func() -> void: page_selected.emit(page_index))
    btn.mouse_entered.connect(func() -> void: page_hovered.emit(page_index))
    return btn

func _refresh_active_visuals() -> void:
    var i := 0
    for child in page_buttons.get_children():
        if child is Button:
            (child as Button).button_pressed = (i == _active_page)
        i += 1
```

(`toggle_mode` + `button_pressed` gives the active page a visually distinct pressed/down state via the theme's button styles — no new art required.)

- [ ] **Step 5: Run tests, verify they pass**

Run the command from Step 2. Expected: 5/5 pass.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab/pagination_bar tests/integration/test_pagination_bar.gd
git commit -m "feat(inventory): add PaginationBar (count + page buttons + trash)"
```

---

## Task 5: Wire EquipmentTab to PaginationBar + global-index mapping

**Files:**
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd`
- Modify: `scenes/inventory/inventory_view/inventory_view.tscn` (EquipmentTab subtree)
- Test: `tests/integration/test_equipment_drag_paging.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/integration/test_equipment_drag_paging.gd
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func _equipment_tab() -> Node:
    var view := load("res://scenes/inventory/inventory_view/inventory_view.tscn").instantiate()
    add_child_autofree(view)
    return view.find_child("EquipmentTab", true, false)

func test_grid_global_index_uses_current_page() -> void:
    var inv := PersistenceManager.save_game_data.inventory
    inv.unlocked_equipment_pages = 2
    var tab := _equipment_tab()
    await get_tree().process_frame
    tab.equipment_grid.set_page(1)
    await get_tree().process_frame
    var slot0 = tab.equipment_grid.get_slots()[0]
    assert_eq(tab._grid_global_index(slot0), 36, "page 1 slot 0 -> global index 36")

func test_page_hover_flips_page_only_while_dragging() -> void:
    var inv := PersistenceManager.save_game_data.inventory
    inv.unlocked_equipment_pages = 2
    var tab := _equipment_tab()
    await get_tree().process_frame

    # Not dragging: hover should NOT change the page.
    tab._on_page_hovered(1)
    assert_eq(tab.equipment_grid.current_page, 0)

    # Dragging: hover flips to the hovered page.
    tab.is_dragging = true
    tab._on_page_hovered(1)
    assert_eq(tab.equipment_grid.current_page, 1)
```

- [ ] **Step 2: Run test, verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_equipment_drag_paging.gd -gexit
```
Expected: FAIL (`_grid_global_index` / `_on_page_hovered` missing; also the scene still references GridToolbar until Step 4).

- [ ] **Step 3: Rewrite equipment_tab.gd**

Replace the file with the version below. Changes from current: `grid_toolbar` → `pagination_bar`; `_refresh_count` → `_refresh_pagination`; new `_on_page_selected` / `_on_page_hovered`; new `_grid_global_index` helper; every grid-slot `get_index()` routed through `_grid_global_index`.

```gdscript
extends Control

## EquipmentTab
## Left page is the paginated equipment grid + sort sub-banner; the bottom
## PaginationBar holds the count, page buttons, and trash slot. Right page is
## the gear selector + item detail card. Handles drag/drop between grid slots
## (paged → global index), gear slots, and the trash slot (hold-buffer).

@onready var equipment_grid: EquipmentGrid = %EquipmentGrid
@onready var gear_selector: Control = %GearSelector
@onready var selector_sprite: Node2D = %SelectorSprite
@onready var selector_anim: AnimationPlayer = %AnimationPlayer
@onready var item_description_box : TextureRect = %ItemDescriptionBox
@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var pagination_bar: PaginationBar = %PaginationBar
@onready var trash_slot : TrashSlot = pagination_bar.trash_slot

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var dragged_item: Control = null
var original_slot: InventorySlot = null
var is_dragging: bool = false
const POSITION_OFFSET = Vector2(0, -15)
const SELECTOR_OFFSET = Vector2(28, 28)

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
    equipment_grid.slot_clicked.connect(_on_slot_input)
    gear_selector.slot_clicked.connect(_on_slot_input)
    if trash_slot:
        trash_slot.clicked.connect(_on_slot_input)

    pagination_bar.page_selected.connect(_on_page_selected)
    pagination_bar.page_hovered.connect(_on_page_hovered)

    item_description_box.reset()
    selector_sprite.visible = false

    sort_banner.set_options(PackedStringArray(["All", "Weapons", "Armor", "Accessories"]))
    sort_banner.enabled = false  # filtering wiring is deferred per spec

    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _refresh_pagination()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_inventory_changed(_inventory: InventoryData) -> void:
    _refresh_pagination()

func _refresh_pagination() -> void:
    var inventory := InventoryManager.get_inventory()
    pagination_bar.setup(inventory.unlocked_equipment_pages, equipment_grid.current_page)
    pagination_bar.set_count(inventory.equipment.size(), inventory.equipment_capacity())

func _on_page_selected(index: int) -> void:
    equipment_grid.set_page(index)
    pagination_bar.set_active_page(equipment_grid.current_page)

func _on_page_hovered(index: int) -> void:
    if is_dragging:
        equipment_grid.set_page(index)
        pagination_bar.set_active_page(equipment_grid.current_page)

## Global inventory index of a paged grid slot (local child-index + page offset).
func _grid_global_index(slot: InventorySlot) -> int:
    return equipment_grid.current_page * EquipmentGrid.SLOTS_PER_PAGE + slot.get_index()

#-----------------------------------------------------------------------------
# INPUT HANDLING
#-----------------------------------------------------------------------------

func _input(event):
    if is_dragging and dragged_item:
        if event is InputEventMouseMotion:
            dragged_item.global_position = get_global_mouse_position() + POSITION_OFFSET
        elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _drop_item(get_global_mouse_position())

#-----------------------------------------------------------------------------
# DRAG AND DROP
#-----------------------------------------------------------------------------

func _on_slot_input(slot: InventorySlot, event: InputEvent) -> void:
    if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
        _update_selector(slot)
        if not is_dragging:
            if slot.item_instance:
                item_description_box.setup(slot.item_instance.item_instance_data)
            else:
                item_description_box.reset()

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not is_dragging:
            if slot is TrashSlot and (slot as TrashSlot).is_holding():
                _pick_up_from_trash(slot as TrashSlot, event.global_position)
                return
            if slot.item_instance != null:
                _pick_up_item(slot, event.global_position)

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        if not is_dragging and slot.item_instance != null:
            _quick_equip(slot)

func _update_selector(slot: InventorySlot) -> void:
    selector_sprite.global_position = slot.global_position + SELECTOR_OFFSET
    if not selector_sprite.visible:
        selector_sprite.visible = true
        selector_anim.play("start_select")
    elif selector_anim.current_animation != "start_select":
        selector_anim.play("start_select")

func _pick_up_item(slot: InventorySlot, global_mouse_pos: Vector2) -> void:
    var item = slot.grab_item()
    if item:
        dragged_item = item
        is_dragging = true
        original_slot = slot
        if dragged_item.item_instance_data:
            item_description_box.setup(dragged_item.item_instance_data)
        add_child(dragged_item)
        dragged_item.set_anchors_preset(Control.PRESET_TOP_LEFT)
        dragged_item.custom_minimum_size = Vector2(28, 28)
        dragged_item.size = Vector2(28, 28)
        dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
        dragged_item.scale = Vector2(1.0, 1.0)
        dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _drop_item(global_mouse_pos: Vector2) -> void:
    var target_slot = _get_slot_under_mouse(global_mouse_pos)
    dragged_item.scale = Vector2(1.0, 1.0)

    # Trash drop short-circuits everything else.
    if target_slot is TrashSlot:
        _handle_trash_drop(target_slot as TrashSlot)
        _cleanup_drag()
        return

    # Restoring from trash back into inventory.
    if original_slot is TrashSlot:
        if target_slot == null:
            _return_to_original()
            _cleanup_drag()
            return
        var inst: ItemInstanceData = dragged_item.item_instance_data
        if target_slot is GearSlot:
            var gear: GearSlot = target_slot as GearSlot
            if not gear.is_valid_item(inst):
                _return_to_original()
                _cleanup_drag()
                return
            InventoryManager.equip_item(inst, gear.slot_type, -1, gear.accessory_index)
        else:
            InventoryManager.restore_equipment_instance(inst, _grid_global_index(target_slot))
        dragged_item.queue_free()
        _cleanup_drag()
        return

    if target_slot and target_slot != original_slot:
        var item_data = dragged_item.item_instance_data

        if target_slot is GearSlot:
            if not target_slot.is_valid_item(item_data):
                _return_to_original()
                _cleanup_drag()
                return

        if target_slot is GearSlot:
            # Dropping ONTO a gear slot (Equipping)
            if not (original_slot is GearSlot):
                var from_index = _grid_global_index(original_slot)
                InventoryManager.equip_item(item_data, target_slot.slot_type, from_index, target_slot.accessory_index)
                dragged_item.queue_free()
            else:
                InventoryManager.swap_accessory_slots(original_slot.accessory_index, target_slot.accessory_index)
                dragged_item.queue_free()

        elif original_slot is GearSlot:
            # Dropping FROM GearSlot TO Grid (Unequipping to specific slot)
            var target_index = _grid_global_index(target_slot)
            InventoryManager.unequip_item_to_slot(original_slot.slot_type, target_index, original_slot.accessory_index)
            dragged_item.queue_free()
        else:
            # Grid -> Grid (Reordering)
            var from_index = _grid_global_index(original_slot)
            var to_index = _grid_global_index(target_slot)
            InventoryManager.move_equipment(from_index, to_index)
            dragged_item.queue_free()
    else:
        _return_to_original()

    _cleanup_drag()

#-----------------------------------------------------------------------------
# QUICK EQUIP (Right-Click)
#-----------------------------------------------------------------------------

func _quick_equip(slot: InventorySlot) -> void:
    var item_data: ItemInstanceData = slot.item_instance.item_instance_data
    if not item_data.item_definition is EquipmentDefinitionData:
        return

    if slot is GearSlot:
        InventoryManager.unequip_item(slot.slot_type, slot.accessory_index)
    else:
        var equip_def: EquipmentDefinitionData = item_data.item_definition as EquipmentDefinitionData
        var from_index: int = _grid_global_index(slot)
        var accessory_index: int = -1
        if equip_def.slot_type == EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
            var equipped: Dictionary = InventoryManager.get_inventory().equipped_accessories
            if not equipped.has(0):
                accessory_index = 0
            elif not equipped.has(1):
                accessory_index = 1
            else:
                accessory_index = 0
        InventoryManager.equip_item(item_data, equip_def.slot_type, from_index, accessory_index)

#-----------------------------------------------------------------------------
# DRAG HELPERS
#-----------------------------------------------------------------------------

func _return_to_original() -> void:
    if original_slot is TrashSlot:
        var trash := original_slot as TrashSlot
        var data: ItemInstanceData = dragged_item.item_instance_data
        trash.accept(data)
        dragged_item.queue_free()
        return
    original_slot.equip_item(dragged_item)

func _cleanup_drag() -> void:
    if dragged_item:
        dragged_item.z_index = 0
        dragged_item.mouse_filter = Control.MOUSE_FILTER_PASS
    dragged_item = null
    original_slot = null
    is_dragging = false

func _get_slot_under_mouse(global_pos: Vector2) -> InventorySlot:
    for slot in equipment_grid.get_slots():
        if slot.get_global_rect().has_point(global_pos):
            return slot
    for slot in gear_selector.get_slots():
        if slot.get_global_rect().has_point(global_pos):
            return slot
    if trash_slot and trash_slot.get_global_rect().has_point(global_pos):
        return trash_slot
    return null

#-----------------------------------------------------------------------------
# TRASH SLOT
#-----------------------------------------------------------------------------

func _handle_trash_drop(trash: TrashSlot) -> void:
    if dragged_item == null:
        return
    var data: ItemInstanceData = dragged_item.item_instance_data
    trash.accept(data)
    _remove_dragged_from_inventory_state()
    dragged_item.queue_free()

func _remove_dragged_from_inventory_state() -> void:
    if original_slot == null or original_slot is TrashSlot:
        return
    var inventory: InventoryData = InventoryManager.get_inventory()
    if original_slot is GearSlot:
        var gear: GearSlot = original_slot as GearSlot
        if gear.accessory_index >= 0:
            inventory.equipped_accessories.erase(gear.accessory_index)
        else:
            inventory.equipped_gear.erase(gear.slot_type)
    else:
        inventory.equipment.erase(_grid_global_index(original_slot))
    InventoryManager.inventory_changed.emit(inventory)

func _pick_up_from_trash(trash: TrashSlot, global_mouse_pos: Vector2) -> void:
    var held = trash.get_held()
    if held == null:
        return
    if held is ItemInstanceData:
        var visual: Control = trash.grab_item()
        trash.clear_hold()
        if visual == null:
            return
        dragged_item = visual
        is_dragging = true
        original_slot = trash
        add_child(dragged_item)
        dragged_item.set_anchors_preset(Control.PRESET_TOP_LEFT)
        dragged_item.custom_minimum_size = Vector2(28, 28)
        dragged_item.size = Vector2(28, 28)
        dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
        dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if item_description_box:
            item_description_box.setup(held)
```

- [ ] **Step 4: Update inventory_view.tscn EquipmentTab subtree**

In `scenes/inventory/inventory_view/inventory_view.tscn`:

1. Add an ext_resource for the PaginationBar scene near the other inventory ext_resources:
   ```
   [ext_resource type="PackedScene" uid="uid://bx475rcu42d08" ...]   # trash_slot already declared
   [ext_resource type="PackedScene" path="res://scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.tscn" id="32_pagination"]
   ```
   (Use the next free `id` integer in that file.)

2. **Remove** the `GridToolbar` node under `BookBackground/BookContent/EquipmentTab` (the one with `unique_name_in_owner = true` instanced from `26_gridtoolbar`). The equipment tab no longer uses it. Leave the `26_gridtoolbar` ext_resource declaration in place if Materials/Consumables still reference it via their own instances elsewhere in the file (they do — don't remove the ext_resource).

3. **Add** a `PaginationBar` node under `BookBackground/BookContent/EquipmentTab`, positioned along the bottom of the left page, below the `EquipmentGrid`. Use offsets that place it under the grid (the grid currently ends near `offset_bottom = 410`):
   ```
   [node name="PaginationBar" parent="BookBackground/BookContent/EquipmentTab" instance=ExtResource("32_pagination")]
   unique_name_in_owner = true
   layout_mode = 0
   offset_left = 82.0
   offset_top = 414.0
   offset_right = 318.0
   offset_bottom = 446.0
   ```

4. Confirm the `EquipmentGrid` node's offsets still give it 6 visible rows (it was `206`–`410`). With the scroll gone and 36 fixed slots at 6 cols × 6 rows, the grid should fit in roughly that height. Leave its offsets as-is; the GridContainer sizes to its content.

(Exact pixel offsets can be nudged in the editor afterward — the user tunes these visually. The key structural change is GridToolbar-out, PaginationBar-in.)

- [ ] **Step 5: Run the targeted test, then the full suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_equipment_drag_paging.gd -gexit
```
Expected: 2/2 pass.

Then full suite:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all green.

- [ ] **Step 6: Headless boot check**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --quit
```
Expected: no parse errors, no "Node not found" for `%GridToolbar` or `%PaginationBar`.

- [ ] **Step 7: Commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd \
        scenes/inventory/inventory_view/inventory_view.tscn \
        tests/integration/test_equipment_drag_paging.gd
git commit -m "feat(inventory): wire EquipmentTab to PaginationBar + global-index drag mapping"
```

---

## Task 6: Manual in-game verification + dev page grant

**Files:** none (verification only). Optional dev helper noted below.

- [ ] **Step 1: Launch the game and exercise the flow**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Open inventory → Equipment. Confirm:
- No scroll bar; a single 6×6 grid.
- Bottom bar shows "N / 36" count (left), a single "1" page button (center), trash slot (right).
- Items render on page 1.

- [ ] **Step 2: Verify a second page via a temporary grant**

There is no in-game trigger yet (deferred). To verify pagination, temporarily call `InventoryManager.grant_equipment_page()` once — e.g. from a dev console if one exists, OR add a throwaway line in `equipment_tab._ready()` (`InventoryManager.grant_equipment_page()`), launch, confirm a "2" button appears and clicking/hovering it switches pages, then **remove the throwaway line**. Do not commit the throwaway.

Confirm:
- Clicking "2" shows an empty page 2; clicking "1" returns.
- Dragging an item and hovering "2" flips to page 2 mid-drag; dropping on a slot there persists (reopen inventory → item is on page 2).
- Count reads total across pages (e.g. "8 / 72").

- [ ] **Step 3: No commit** (verification only; throwaway grant removed).

---

## Self-Review

**Spec coverage:**
- Scroll container removed → Task 3 ✓
- Page numbers at bottom, navigation → Task 4 (PaginationBar) + Task 5 (wiring) ✓
- Drag across pages by hovering page number → Task 5 (`_on_page_hovered`) + test ✓
- 36 slots per page (6×6) → Task 1 (`SLOTS_PER_PAGE`) + Task 3 (grid) ✓
- Start with one page → Task 1 (`unlocked_equipment_pages = 1` default) ✓
- Count moves next to pagination, total/capacity → Task 4 (bar count) + Task 5 (`_refresh_pagination`) ✓
- Trash relocates to bottom bar → Task 4 (TrashSlot child) + Task 5 (remove GridToolbar) ✓
- Capacity-aware placement + grant API → Task 2 ✓
- No new assets → PaginationBar uses procedural Buttons ✓
- Deferred unlock triggers → Task 6 notes the dev grant; no gameplay trigger built ✓

**Placeholder scan:** No `TBD`/`TODO`/"handle edge cases". Every code step shows full code. Task 5 Step 4 leaves exact pixel offsets to editor-tuning, but the structural change (node add/remove) is fully specified — acceptable, the user tunes offsets visually each round.

**Type consistency:** `SLOTS_PER_PAGE` defined on both `InventoryData` (data) and `EquipmentGrid` (view math) — intentional mirror, both = 36. `set_page`, `current_page`, `get_slots`, `_grid_global_index`, `setup(unlocked_pages, active_page)`, `set_count(used, total)`, `set_active_page`, `page_selected`, `page_hovered`, `grant_equipment_page`, `equipment_capacity` names are consistent across Tasks 1–5 and the tests. `PaginationBar.trash_slot` mirrors the old `GridToolbar.trash_slot` so `inventory_view.gd`'s close-flush over the `TrashSlots` group still works (same `trash_slot.tscn` instance, just re-parented).

**Gap caught + filled:** Right-click `_quick_equip` also used a raw `slot.get_index()` for the grid→gear path — routed through `_grid_global_index` in Task 5 so quick-equip works on pages > 0.
