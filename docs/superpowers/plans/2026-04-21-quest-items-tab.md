# Quest Items Inventory Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third top-level inventory tab ("Quest Items") showing the player's QUEST_ITEM inventory as a clickable list with a shared `ItemDescriptionPanel` detail pane.

**Architecture:** New `QuestItemsTab` scene (list + detail pane) under `scenes/inventory/inventory_view/quest_items_tab/`, plus a `QuestItemRow` sub-scene for individual clickable rows. Plugs into the existing `TabSwitcher` by adding one more `TabButton` and one more entry in the `tabs` array in `InventoryView`. A thin new accessor `InventoryManager.get_quest_items()` mirrors the existing `get_material_items()`.

**Tech Stack:** Godot 4.5, GDScript, GUT v9.6.0.

**Spec reference:** [2026-04-21-quest-items-tab-design.md](../specs/2026-04-21-quest-items-tab-design.md)

**Common commands used below:**

- Headless import (catch parse errors after .tscn / .gd edits):
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
  ```
- Run a single unit test file:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<FILE>.gd -gexit
  ```
- Run the whole suite:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
  ```

**Relevant UIDs (verified real in this checkout):**

| What | UID |
|---|---|
| `item_description_panel.tscn` | `uid://hdpsokiiqmae` |
| `item_description_panel.gd` | `uid://cmn6vn1m4imid` |
| `inventory_view.gd` | `uid://bxs3eblygn8oo` |
| `tab_switcher.gd` | `uid://bevd783gr5t7m` |
| `tab_button.gd` | `uid://r0d5awro0gtx` |
| `tab_button.tscn` | `uid://dnkls2h5eaj10` |

**Relevant existing APIs:**

| API | Description |
|---|---|
| `ItemDescriptionPanel.setup(item_instance_data: ItemInstanceData) -> void` | Populates panel from an instance (icon, name, type, description, effects). |
| `ItemDescriptionPanel.setup_from_definition(definition: ItemDefinitionData) -> void` | Convenience — wraps the def in a new `ItemInstanceData` and calls `setup`. **Use this for quest items** since they don't have per-instance state. |
| `ItemDescriptionPanel.reset() -> void` | Clears all fields. |
| `InventoryManager.get_material_items() -> Dictionary[MaterialDefinitionData, int]` | Mirror for the new `get_quest_items()`. |
| `InventoryManager.inventory_changed(inventory: InventoryData)` signal | Fires on every award/equip/etc. Tab listens to this to rebuild rows. |

---

## Task 1: Add `InventoryManager.get_quest_items`

TDD. Small accessor; unit test drives it.

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager.gd`

- [ ] **Step 1: Write failing test**

Append to `tests/unit/test_inventory_manager.gd` (bottom of file, after the existing `HAS_ITEM` section):

```gdscript
#-----------------------------------------------------------------------------
# GET_QUEST_ITEMS
#-----------------------------------------------------------------------------

func test_get_quest_items_returns_empty_on_fresh_save() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var quest_items := InventoryManager.get_quest_items()
	assert_eq(quest_items.size(), 0, "fresh save should report zero quest items")

func test_get_quest_items_reflects_awards() -> void:
	if not InventoryManager:
		pass_test("InventoryManager not available in test environment")
		return

	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

	var def := ItemDefinitionData.new()
	def.item_id = "get_quest_items_test"
	def.item_name = "Get Quest Items Test"
	def.item_type = ItemDefinitionData.ItemType.QUEST_ITEM
	InventoryManager.award_items(def, 1)

	var quest_items := InventoryManager.get_quest_items()
	assert_eq(quest_items.size(), 1, "should report exactly one quest item after award")
	assert_eq(quest_items.get(def, 0), 1, "awarded item should appear with quantity 1")
```

- [ ] **Step 2: Run failing test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: both new tests fail with "Invalid call. Nonexistent function 'get_quest_items' in base".

- [ ] **Step 3: Implement**

Open `singletons/inventory_manager/inventory_manager.gd`. Find `get_material_items` in the `PUBLIC API` section:

```gdscript
func get_material_items() -> Dictionary[MaterialDefinitionData, int]:
	return live_save_data.inventory.materials
```

Add the parallel accessor immediately after it:

```gdscript
func get_quest_items() -> Dictionary[ItemDefinitionData, int]:
	return live_save_data.inventory.quest_items
```

- [ ] **Step 4: Run test to verify pass**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_inventory_manager.gd -gexit
```
Expected: both new tests pass; nothing else regresses in the file.

- [ ] **Step 5: Commit**

```bash
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager.gd
git commit -m "feat(inventory): add InventoryManager.get_quest_items accessor

Thin wrapper over live_save_data.inventory.quest_items, mirroring
get_material_items. Consumed by the new Quest Items inventory tab."
```

---

## Task 2: Create `QuestItemRow` scene + script

Single clickable row: icon + name. Emits a signal when clicked. No tests — pure UI.

**Files:**
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_item_row.gd`
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_item_row.tscn`

- [ ] **Step 1: Create the script**

Create `scenes/inventory/inventory_view/quest_items_tab/quest_item_row.gd` with:

```gdscript
extends Button

## One row in the Quest Items tab — icon + name. Emits row_clicked with its
## own item when pressed so the parent tab can update the selected item.

signal row_clicked(item: ItemDefinitionData)

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel

var _item: ItemDefinitionData = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()

## Populates the row with the given item.
func set_item(value: ItemDefinitionData) -> void:
	_item = value
	if is_inside_tree():
		_refresh()

## Returns the item currently shown on this row.
func get_item() -> ItemDefinitionData:
	return _item

## Visually marks the row as selected (or not).
func set_selected(value: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0) if not value else Color(1.3, 1.3, 0.8)

func _refresh() -> void:
	if _item == null:
		icon_rect.texture = null
		name_label.text = ""
		return
	icon_rect.texture = _item.icon
	name_label.text = _item.item_name

func _on_pressed() -> void:
	row_clicked.emit(_item)
```

- [ ] **Step 2: Create the scene**

Create `scenes/inventory/inventory_view/quest_items_tab/quest_item_row.tscn` with:

```
[gd_scene load_steps=3 format=3 uid="uid://bquestitemrow001"]

[ext_resource type="Script" path="res://scenes/inventory/inventory_view/quest_items_tab/quest_item_row.gd" id="1_row"]
[ext_resource type="StyleBox" path="res://assets/styleboxes/common/button_invisible.tres" id="2_bi"]

[node name="QuestItemRow" type="Button"]
custom_minimum_size = Vector2(0, 28)
size_flags_horizontal = 3
theme_override_styles/normal = ExtResource("2_bi")
theme_override_styles/normal_mirrored = ExtResource("2_bi")
theme_override_styles/pressed = ExtResource("2_bi")
theme_override_styles/pressed_mirrored = ExtResource("2_bi")
theme_override_styles/hover = ExtResource("2_bi")
theme_override_styles/hover_mirrored = ExtResource("2_bi")
theme_override_styles/hover_pressed = ExtResource("2_bi")
theme_override_styles/hover_pressed_mirrored = ExtResource("2_bi")
theme_override_styles/focus = ExtResource("2_bi")
script = ExtResource("1_row")

[node name="HBox" type="HBoxContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Icon" type="TextureRect" parent="HBox"]
unique_name_in_owner = true
custom_minimum_size = Vector2(20, 20)
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
expand_mode = 1
stretch_mode = 5

[node name="NameLabel" type="Label" parent="HBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
theme_type_variation = &"LabelSmall"
theme_override_colors/font_color = Color(0, 0, 0, 1)
text = "Quest Item"
```

Note: the `button_invisible.tres` stylebox is the same one used by `tab_button.tscn` — consistent with the existing convention. The row appears as a transparent Button node with icon + label laid out inside; Godot handles click detection via the Button's `pressed` signal.

- [ ] **Step 3: Verify import**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no parse errors for the new `.gd` / `.tscn`.

- [ ] **Step 4: Commit**

```bash
git add scenes/inventory/inventory_view/quest_items_tab/quest_item_row.gd scenes/inventory/inventory_view/quest_items_tab/quest_item_row.tscn
git commit -m "feat(inventory): add QuestItemRow scene

Single clickable row with icon + name. Emits row_clicked on press.
Used by the Quest Items tab to list owned items."
```

---

## Task 3: Create `QuestItemsTab` scene + script

The tab pane: list on left, `ItemDescriptionPanel` on right, empty-state label. Listens to `InventoryManager.inventory_changed` and rebuilds rows.

**Files:**
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd`
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn`

- [ ] **Step 1: Create the script**

Create `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd` with:

```gdscript
extends Control

## Quest Items tab — renders a list of owned quest items with a shared
## ItemDescriptionPanel showing the currently-selected item. Empty state
## hides the description panel and shows a centered label instead.

@onready var list_vbox: VBoxContainer = %ListVBox
@onready var empty_label: Label = %EmptyLabel
@onready var description_panel: ItemDescriptionPanel = %ItemDescriptionPanel

var _row_scene: PackedScene = preload("res://scenes/inventory/inventory_view/quest_items_tab/quest_item_row.tscn")
var _selected_item: ItemDefinitionData = null

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild_rows(InventoryManager.get_quest_items())
	else:
		_rebuild_rows({})

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _rebuild_rows(quest_items: Dictionary) -> void:
	for child in list_vbox.get_children():
		child.queue_free()

	if quest_items.is_empty():
		empty_label.visible = true
		description_panel.visible = false
		description_panel.reset()
		_selected_item = null
		return

	empty_label.visible = false
	description_panel.visible = true

	var first_item: ItemDefinitionData = null
	for item in quest_items.keys():
		var row = _row_scene.instantiate()
		list_vbox.add_child(row)
		row.set_item(item)
		row.row_clicked.connect(_on_row_clicked)
		if first_item == null:
			first_item = item

	# Preserve selection across rebuilds if the item still exists;
	# otherwise fall back to the first row.
	if _selected_item == null or not quest_items.has(_selected_item):
		_selected_item = first_item
	_show_item(_selected_item)

func _show_item(item: ItemDefinitionData) -> void:
	if item == null:
		description_panel.reset()
		return
	description_panel.setup_from_definition(item)
	for row in list_vbox.get_children():
		if row.has_method("get_item") and row.has_method("set_selected"):
			row.set_selected(row.get_item() == item)

func _on_row_clicked(item: ItemDefinitionData) -> void:
	_selected_item = item
	_show_item(item)

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_rebuild_rows(InventoryManager.get_quest_items())
```

- [ ] **Step 2: Create the scene**

Create `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn` with:

```
[gd_scene load_steps=3 format=3 uid="uid://bquestitemstab001"]

[ext_resource type="Script" path="res://scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd" id="1_tab"]
[ext_resource type="PackedScene" uid="uid://hdpsokiiqmae" path="res://scenes/common/item_description_panel/item_description_panel.tscn" id="2_desc"]

[node name="QuestItemsTab" type="Control"]
anchors_preset = 0
offset_right = 40.0
offset_bottom = 40.0
script = ExtResource("1_tab")

[node name="ListPane" type="MarginContainer" parent="."]
layout_mode = 0
offset_left = 82.5
offset_top = 183.5
offset_right = 310.5
offset_bottom = 371.5
theme_override_constants/margin_top = 5
theme_override_constants/margin_bottom = 5

[node name="ScrollContainer" type="ScrollContainer" parent="ListPane"]
layout_mode = 2
horizontal_scroll_mode = 0
vertical_scroll_mode = 3

[node name="ListVBox" type="VBoxContainer" parent="ListPane/ScrollContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3

[node name="EmptyLabel" type="Label" parent="."]
unique_name_in_owner = true
visible = false
layout_mode = 0
offset_left = 82.5
offset_top = 250.0
offset_right = 310.5
offset_bottom = 290.0
theme_type_variation = &"LabelSmall"
theme_override_colors/font_color = Color(0, 0, 0, 1)
text = "No quest items yet."
horizontal_alignment = 1
vertical_alignment = 1

[node name="ItemDescriptionBox" type="Control" parent="."]
layout_mode = 0
offset_left = 386.0
offset_top = 257.5
offset_right = 810.0
offset_bottom = 521.5
scale = Vector2(0.5, 0.5)

[node name="ItemDescriptionPanel" parent="ItemDescriptionBox" instance=ExtResource("2_desc")]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

Note: The layout offsets (`offset_left = 82.5`, `offset_right = 310.5`, the ItemDescriptionBox at `(386, 257.5)`, etc.) are copied from the equipment tab's existing `ItemDescriptionBox` + `MaterialsTab.MaterialsGrid` positions so the new tab visually aligns with the other tabs inside the inventory book frame.

- [ ] **Step 3: Verify import**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no parse errors. `%ListVBox`, `%EmptyLabel`, and `%ItemDescriptionPanel` unique names are present.

- [ ] **Step 4: Run full unit suite as regression check**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: no regressions beyond pre-existing unrelated failures.

- [ ] **Step 5: Commit**

```bash
git add scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn
git commit -m "feat(inventory): add QuestItemsTab scene

List of quest items (via QuestItemRow) + shared ItemDescriptionPanel
detail pane. Rebuilds on InventoryManager.inventory_changed. Empty
state shows 'No quest items yet.' and hides the description panel."
```

---

## Task 4: Wire the new tab into `InventoryView` and `TabSwitcher`

Edit two `.gd` files and two `.tscn` files in one atomic commit — the wiring is only half-working if either side lands alone.

**Files:**
- Modify: `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`
- Modify: `scenes/inventory/inventory_view/inventory_view.gd`
- Modify: `scenes/inventory/inventory_view/inventory_view.tscn`

- [ ] **Step 1: Update `tab_switcher.gd`**

Open `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`. Replace the top section so the new tab is represented:

```gdscript
extends Control

signal tab_changed(index: int)

var current_tab_index: int = 0
@onready var equipment_tab_button: Control = %EquipmentTabButton
@onready var materials_tab_button: Control = %MaterialsTabButton
@onready var quest_items_tab_button: Control = %QuestItemsTabButton
@onready var tab_buttons: Array[Control] = [
	equipment_tab_button,
	materials_tab_button,
	quest_items_tab_button,
]
```

Leave the rest of the file unchanged — `_ready` and `_on_tab_button_opened` iterate `tab_buttons` and naturally handle a 3-entry array.

- [ ] **Step 2: Update `inventory_view.gd`**

Open `scenes/inventory/inventory_view/inventory_view.gd`. Modify only the `tabs` line to add the new tab:

```gdscript
@onready var tabs: Array[Control] = [%EquipmentTab, %MaterialsTab, %QuestItemsTab]
```

Leave everything else in the file unchanged — `_on_tab_changed` already iterates `tabs` and naturally handles the third entry.

- [ ] **Step 3: Update `inventory_view.tscn` — add new ext_resources**

Open `scenes/inventory/inventory_view/inventory_view.tscn`. Near the top, where other ext_resources live (look at the existing `ExtResource` lines — they are in the first ~27 lines of the file), add two new lines:

```
[ext_resource type="PackedScene" uid="uid://bquestitemstab001" path="res://scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn" id="24_qtab"]
```

The `tab_button.tscn` ext_resource already exists as id `3_eyvfv` (used by the existing two tab button instances) — reuse it, do NOT add a new one.

- [ ] **Step 4: Update `inventory_view.tscn` — add `QuestItemsTabButton`**

Find the existing `MaterialsTabButton` node in `inventory_view.tscn`. It looks like:

```
[node name="MaterialsTabButton" parent="BookBackground/BookContent/TabSwitcher" unique_id=709037587 instance=ExtResource("3_eyvfv")]
unique_name_in_owner = true
layout_mode = 0
offset_left = 55.5
offset_top = 144.0
offset_right = 55.5
offset_bottom = 144.0
```

Immediately after this block, add a third tab button stacked below with a larger `offset_top` (so the three tabs are visually spaced — the existing spacing is ~49 pixels between consecutive tabs: 95 → 144, so the third goes at 193):

```
[node name="QuestItemsTabButton" parent="BookBackground/BookContent/TabSwitcher" unique_id=931205040 instance=ExtResource("3_eyvfv")]
unique_name_in_owner = true
layout_mode = 0
offset_left = 55.5
offset_top = 193.0
offset_right = 55.5
offset_bottom = 193.0
```

The `unique_id=931205040` is a fresh value — pick any unused large integer. Godot may regenerate it on save; that's fine.

- [ ] **Step 5: Update `inventory_view.tscn` — instance `QuestItemsTab`**

Find the existing `MaterialsTab` node in `inventory_view.tscn`. It's declared roughly like:

```
[node name="MaterialsTab" type="Control" parent="BookBackground/BookContent" unique_id=2080808482]
unique_name_in_owner = true
visible = false
anchors_preset = 0
offset_right = 40.0
offset_bottom = 40.0
script = ExtResource("21_26fxh")
```

It has many child nodes after it. After the ENTIRE MaterialsTab subtree (the node and all children — find the last `MaterialContainer` child line), add the new tab instance. Keep it simple — instance it via the ext_resource, don't hand-author children:

```
[node name="QuestItemsTab" parent="BookBackground/BookContent" unique_id=1012340856 instance=ExtResource("24_qtab")]
unique_name_in_owner = true
visible = false
```

The `parent` path matches the other tabs (`BookBackground/BookContent`). `visible = false` matches the initial-state convention (only the first tab starts visible; `InventoryView._ready()` handles initial-visibility logic).

- [ ] **Step 6: Import + verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: clean. No "Missing node `%QuestItemsTabButton`" or "Missing `%QuestItemsTab`" errors.

- [ ] **Step 7: Run full test suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: no regressions beyond pre-existing unrelated failures.

- [ ] **Step 8: Commit**

```bash
git add scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd scenes/inventory/inventory_view/inventory_view.gd scenes/inventory/inventory_view/inventory_view.tscn
git commit -m "feat(inventory): wire Quest Items tab into InventoryView

Adds a third TabButton stacked below Materials and instances the new
QuestItemsTab scene as a sibling of the existing tabs. Page-turn
animation and visibility logic already support N tabs."
```

---

## Task 5: Manual playtest verification

No new automated tests — UI rendering is not covered by GUT. Playtest the scene in-game.

- [ ] **Step 1: Launch the game**

From the project root:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --path . scenes/main/main_game/main_game.tscn
```

- [ ] **Step 2: Empty-state verification**

1. Start a fresh save (delete `user://save.tres` or use the dev panel reset).
2. Press **I** to open the inventory. Book animation plays.
3. Click the third tab button (stacked below Materials, top-left of the book).
4. Page-turn animation plays, then the Quest Items tab appears.
5. **Expected:** centered label "No quest items yet." is visible. No description panel. No rows.

- [ ] **Step 3: Populated-state verification**

1. Trigger a quest-item award. Either:
   - Use the dev panel to award the Refugee Camp Map directly (if there's a "give item" affordance).
   - Play the Beat 3b chain: complete Beat 1 → Beat 2 → cycle to CD 10 → click NPC 4 → dialogue 4 awards the map.
2. Open inventory → Quest Items tab.
3. **Expected:**
   - One row: icon + "Refugee Camp Map".
   - Row is auto-selected (slightly highlighted via the modulate tint).
   - Right-side description panel shows the map's icon, name "Refugee Camp Map", type "Quest Item", description ("A hand-drawn map leading to a camp of survivors hidden in the valley.").

- [ ] **Step 4: Multi-item verification (optional)**

If a second quest item can be awarded (dev panel or mocked), confirm:
- Both rows appear.
- Clicking a different row updates the description panel.
- Only one row shows the "selected" tint at a time.

- [ ] **Step 5: Tab-switch regression check**

1. Click each of the three tab buttons in order (Equipment → Materials → Quest Items → Equipment).
2. **Expected:** page-turn animation plays in the correct direction each time; no visual glitches; each tab's content renders correctly.

- [ ] **Step 6: Update status in the Beat 3b spec**

Open `docs/superpowers/specs/2026-04-21-beat-3b-merchant-unlock-design.md`. In §8 Out of scope, find the "Quest-items inventory tab" bullet. Replace its text with:

```
- **Quest-items inventory tab.** ✅ Implemented (see [2026-04-21-quest-items-tab-design.md](./2026-04-21-quest-items-tab-design.md) + plan).
```

- [ ] **Step 7: Commit the doc update**

```bash
git add docs/superpowers/specs/2026-04-21-beat-3b-merchant-unlock-design.md
git commit -m "docs(beat-3b): mark quest-items inventory tab as implemented

The follow-up spec has landed. Updates the cross-reference so the
Beat 3b spec stays accurate."
```

---

## Done

At this point:
- `InventoryManager.get_quest_items()` returns the `quest_items` dict and is unit-tested.
- A `QuestItemRow` scene renders a single clickable row.
- A `QuestItemsTab` scene ties rows + shared `ItemDescriptionPanel` together and reacts to `InventoryManager.inventory_changed`.
- The `InventoryView` has a third tab wired through `TabSwitcher` with matching visual scaffolding.
- Playtest confirmed empty-state and populated-state behavior.
- Beat 3b's spec is updated to reflect that its follow-up has landed.
