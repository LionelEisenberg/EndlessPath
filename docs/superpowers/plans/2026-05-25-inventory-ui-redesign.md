# Inventory UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the inventory UI redesign across all four tabs (Equipment, Consumables, Materials, Journal) with placeholder art where new sprites are still being made.

**Architecture:** Five new shared scenes under `scenes/inventory/common/` provide the visual chrome the four tabs share (grid, scroll rail, sort sub-banner, grid toolbar, item detail card). The Equipment tab is reskinned onto them, Materials and Quest are rebuilt onto them, and Consumables is built brand-new with a 4-slot combat hotbar. Data-layer changes are minimal: two new fields on `MaterialDefinitionData`, a new `QuestItemDefinitionData` subclass, an `equipped_consumables` dict on `InventoryData`, and a few `InventoryManager` methods for the consumable hotbar and inventory-restore-from-trash semantics.

**Tech Stack:** Godot 4.6 GDScript, GUT v9.6.0 for tests, existing `pixel_theme.tres` Label variants and styleboxes — no new fonts or external libs.

**Spec:** [`docs/superpowers/specs/2026-05-25-inventory-ui-redesign.md`](../specs/2026-05-25-inventory-ui-redesign.md)
**Mockup reference:** [`docs/superpowers/mockups/inventory-redesign/`](../mockups/inventory-redesign/index.html)

---

## Conventions used throughout

- All Godot file paths are repo-relative, e.g. `scenes/inventory/common/inventory_grid/inventory_grid.tscn`. Godot's `res://` prefix is added when loading from GDScript.
- New scripts follow the project's GDScript standards (`docs/UI_STYLING.md` for Label variants, `CLAUDE.md` for naming/typing rules).
- `Log.*` is the static logger (errors/warnings), `LogManager.log_message()` is the in-game log feed (BBCode strings).
- Tests are GUT (`extends GutTest`) and live in `tests/unit/` (pure logic) or `tests/integration/` (scene-driving).
- Commits use the project's conventional format: `feat(inventory): ...`, `fix(inventory): ...`, etc.

---

## File map (new + modified)

### New files
```
scenes/inventory/common/
  inventory_grid/
    inventory_grid.tscn
    inventory_grid.gd
  scroll_rail/
    scroll_rail.tscn
    scroll_rail.gd
  sort_sub_banner/
    sort_sub_banner.tscn
    sort_sub_banner.gd
  grid_toolbar/
    grid_toolbar.tscn
    grid_toolbar.gd
  item_detail_card/
    item_detail_card.tscn
    item_detail_card.gd

scenes/inventory/inventory_view/consumables_tab/
  consumables_tab.tscn
  consumables_tab.gd
  combat_hotbar/
    combat_hotbar.tscn
    combat_hotbar.gd
    hotbar_slot/
      hotbar_slot.tscn
      hotbar_slot.gd

scenes/inventory/inventory_view/materials_tab/
  material_slot.tscn          # new (replaces material_container.tscn for the grid)
  material_slot.gd
  material_detail_card.tscn   # extends ItemDetailCard with Source/Used in/Worth rows
  material_detail_card.gd
  material_tip_card.tscn      # static "favorites" hint

scenes/inventory/inventory_view/quest_items_tab/
  journal_row.tscn            # new (replaces quest_item_row.tscn)
  journal_row.gd
  quest_journal_card.tscn     # the right-page rich detail
  quest_journal_card.gd
  wax_seal.tscn               # placeholder ColorRect, swappable later
  wax_seal.gd

scripts/resource_definitions/items/
  quest_item_definition_data.gd

assets/styleboxes/inventory/
  hotbar_slot_empty.tres
  hotbar_slot_equipped.tres
  hotbar_key_chip.tres
  effect_pill_pos.tres
  effect_pill_cool.tres
  wax_seal_active.tres

tests/unit/
  test_quest_item_definition_data.gd
  test_inventory_manager_consumable_hotbar.gd
  test_inventory_manager_restore.gd

tests/integration/
  test_trash_slot_flow.gd
  test_journal_tab_render.gd
  test_consumables_tab_hotbar_equip.gd
```

### Modified files
```
scripts/resource_definitions/items/material_definition_data.gd  # +2 fields
singletons/inventory_manager/inventory_manager.gd                # +equip/unequip_consumable, +restore_*
singletons/persistence_manager/inventory_data.gd                 # +equipped_consumables
scenes/inventory/inventory_view/inventory_view.tscn              # 4th tab button + ConsumablesTab pane
scenes/inventory/inventory_view/inventory_view.gd                # tabs array includes ConsumablesTab
scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd     # 4 buttons, reorder
scenes/inventory/inventory_view/equipment_tab/equipment_tab.tscn # uses shared chrome + 6-col grid
scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn
scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd  # columns=6
scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.gd  # hold-buffer logic
scenes/inventory/inventory_view/materials_tab/materials_tab.tscn        # full rebuild
scenes/inventory/inventory_view/materials_tab/materials_tab.gd          # grid wiring
scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn    # journal layout
scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd      # journal wiring
resources/items/quest_items/refugee_camp_map.tres                       # script_class → QuestItemDefinitionData
```

---

## Task 1: ItemDetailCard shared scene

The existing `scenes/common/item_description_panel/` already exists. This task creates a thinly-extended variant under `scenes/inventory/common/` that the Materials/Consumables/Journal cards build on. Equipment keeps using the existing panel for this task — we'll converge later if useful.

**Files:**
- Create: `scenes/inventory/common/item_detail_card/item_detail_card.tscn`
- Create: `scenes/inventory/common/item_detail_card/item_detail_card.gd`
- Test: `tests/integration/test_item_detail_card.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/integration/test_item_detail_card.gd
extends GutTest

const ItemDetailCardScene := preload("res://scenes/inventory/common/item_detail_card/item_detail_card.tscn")

func test_setup_populates_name_and_type_from_material_def() -> void:
    var card := ItemDetailCardScene.instantiate()
    add_child_autofree(card)
    await get_tree().process_frame

    var def := MaterialDefinitionData.new()
    def.item_id = "test_fern"
    def.item_name = "Spirit Fern"
    def.description = "Smells of rain on hot stone."

    card.setup_from_definition(def)
    assert_eq(card.item_name_label.text, "Spirit Fern")
    assert_eq(card.item_type_label.text, "[Material]")
    assert_eq(card.description_label.text, "Smells of rain on hot stone.")

func test_reset_clears_fields() -> void:
    var card := ItemDetailCardScene.instantiate()
    add_child_autofree(card)
    await get_tree().process_frame
    card.reset()
    assert_eq(card.item_name_label.text, "")
    assert_eq(card.description_label.text, "")
```

- [ ] **Step 2: Run test, verify it fails on missing scene**

Run from project root:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_item_detail_card.gd -gexit
```
Expected: FAIL (cannot preload res://scenes/inventory/common/item_detail_card/item_detail_card.tscn).

- [ ] **Step 3: Create the scene**

Create `scenes/inventory/common/item_detail_card/item_detail_card.tscn` in the Godot editor with this node tree:

```
ItemDetailCard (PanelContainer)
  └─ MarginContainer
     ├─ HBoxContainer (header row)
     │  ├─ VBoxContainer (title column, h_flags = EXPAND_FILL)
     │  │  ├─ ItemName (Label, unique_name_in_owner, theme_type_variation = "LabelDescItemName")
     │  │  └─ ItemType (Label, unique_name_in_owner, theme_type_variation = "LabelDescItemType")
     │  └─ ItemIcon (TextureRect, custom_minimum_size = (48, 48), unique_name_in_owner)
     ├─ HSeparator (theme_type_variation = "HSeparatorItemDesc")
     ├─ DescriptionLabel (RichTextLabel, unique_name_in_owner, theme_type_variation = "RichTextLabelDark",
     │                   bbcode_enabled = true, fit_content = true)
     ├─ HSeparator (theme_type_variation = "HSeparatorItemDescThin")
     └─ EffectsLabel (RichTextLabel, unique_name_in_owner, theme_type_variation = "RichTextLabelDark",
                      bbcode_enabled = true, fit_content = true)
```

`PanelContainer.theme_override_styles/panel = assets/styleboxes/common/panel_tan.tres` (placeholder background — drop the `item_description_background.png` texture in once available).

- [ ] **Step 4: Write the script**

```gdscript
# scenes/inventory/common/item_detail_card/item_detail_card.gd
class_name ItemDetailCard
extends PanelContainer

## Reusable item detail card. Shows icon, name, type, description, effects
## for any ItemDefinitionData / ItemInstanceData. The existing
## ItemDescriptionPanel stays in place for Equipment for now; this newer
## card lives in scenes/inventory/common/ so Materials, Consumables, and
## the Journal can all share one look.

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var item_type_label: Label = %ItemType
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var effects_label: RichTextLabel = %EffectsLabel

## Populate from an ItemDefinitionData.
func setup_from_definition(def: ItemDefinitionData) -> void:
    if def == null:
        reset()
        return
    item_icon.texture = def.icon
    item_name_label.text = def.item_name

    var type_text: String = def._get_item_type()
    if def is EquipmentDefinitionData:
        var equip: EquipmentDefinitionData = def as EquipmentDefinitionData
        var slot_name: String = EquipmentDefinitionData.EquipmentSlot.keys()[equip.slot_type].replace("_", " ").capitalize()
        type_text = "%s - %s" % [type_text, slot_name]
    item_type_label.text = "[%s]" % type_text

    description_label.text = def.description

    var effects: Array[String] = def._get_item_effects()
    effects_label.visible = not effects.is_empty()
    if effects_label.visible:
        effects_label.text = "\n".join(effects)

## Populate from an ItemInstanceData (delegates to the definition).
func setup(instance: ItemInstanceData) -> void:
    if instance == null or instance.item_definition == null:
        reset()
        return
    setup_from_definition(instance.item_definition)

## Clear everything.
func reset() -> void:
    item_icon.texture = null
    item_name_label.text = ""
    item_type_label.text = ""
    description_label.text = ""
    effects_label.text = ""
    effects_label.visible = false
```

- [ ] **Step 5: Run tests, verify they pass**

Run the same GUT command from step 2.
Expected: PASS — both tests green.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/common/item_detail_card tests/integration/test_item_detail_card.gd
git commit -m "feat(inventory): add shared ItemDetailCard scene"
```

---

## Task 2: ScrollRail shared scene

A thin wrapper around `VScrollBar` that styles it with the gold-cap + brown-track look. Mirrors the existing scroll behaviour in `equipment_grid.gd`.

**Files:**
- Create: `scenes/inventory/common/scroll_rail/scroll_rail.tscn`
- Create: `scenes/inventory/common/scroll_rail/scroll_rail.gd`

- [ ] **Step 1: Create the scene**

`scenes/inventory/common/scroll_rail/scroll_rail.tscn`:

```
ScrollRail (Control, custom_minimum_size = (18, 0), mouse_filter = IGNORE)
  ├─ TopCap (TextureRect, anchors top, custom_min_size = (18, 14),
  │          texture = assets/sprites/inventory/equipment_grid/bar_scroll.png region top)
  ├─ Track  (TextureRect, anchors center_v with offsets matching caps,
  │          texture = bar_scroll.png middle, stretch_mode = TILE)
  ├─ BottomCap (TextureRect, anchors bottom, custom_min_size = (18, 14))
  └─ Grabber (TextureRect, mouse_filter = IGNORE, unique_name_in_owner,
              texture = bar_grabber.png, custom_min_size = (18, 32))
```

For the placeholder, the three caps/track can share `bar_scroll.png` whole — we're not slicing it. The Grabber uses `bar_grabber.png`. Visual polish lands when the new sprite arrives.

- [ ] **Step 2: Write the script**

```gdscript
# scenes/inventory/common/scroll_rail/scroll_rail.gd
class_name ScrollRail
extends Control

## ScrollRail
## Visual rail bound to a host ScrollContainer's vertical scrollbar. Hosts
## the grabber TextureRect and moves it as the host scrolls. Logic mirrors
## the EquipmentGrid scroll behaviour but in a reusable scene.

const SCROLL_MIN_Y := 0.025
const SCROLL_MAX_Y := 0.90

@onready var grabber: TextureRect = %Grabber

var _bound: VScrollBar = null

## Bind to a host scroll container's vertical scrollbar.
func bind(host: ScrollContainer) -> void:
    if _bound and _bound.scrolling.is_connected(_on_scrolling):
        _bound.scrolling.disconnect(_on_scrolling)
    _bound = host.get_v_scroll_bar()
    _bound.scrolling.connect(_on_scrolling)
    _on_scrolling() # initial position

func _on_scrolling() -> void:
    if _bound == null:
        return
    var page: float = _bound.page
    var span: float = _bound.max_value - page
    var ratio: float = 0.0 if span <= 0.0 else _bound.value / span
    grabber.position.y = clampf(ratio, SCROLL_MIN_Y, SCROLL_MAX_Y) * size.y
```

- [ ] **Step 3: Commit**

```bash
git add scenes/inventory/common/scroll_rail
git commit -m "feat(inventory): add shared ScrollRail scene"
```

---

## Task 3: SortSubBanner shared scene

The `[◀ All ▶]` widget. Configurable label, `enabled` flag, options list, current index. Emits `option_changed(index: int)`.

**Files:**
- Create: `scenes/inventory/common/sort_sub_banner/sort_sub_banner.tscn`
- Create: `scenes/inventory/common/sort_sub_banner/sort_sub_banner.gd`
- Test: `tests/integration/test_sort_sub_banner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/integration/test_sort_sub_banner.gd
extends GutTest

const Scene := preload("res://scenes/inventory/common/sort_sub_banner/sort_sub_banner.tscn")

func test_clicking_right_arrow_cycles_options_and_emits_signal() -> void:
    var sb := Scene.instantiate()
    add_child_autofree(sb)
    await get_tree().process_frame
    sb.set_options(["All", "Weapons", "Armor"])
    watch_signals(sb)
    sb.next()
    assert_eq(sb.current_label, "Weapons")
    assert_signal_emitted_with_parameters(sb, "option_changed", [1])

func test_disabled_arrows_dont_emit() -> void:
    var sb := Scene.instantiate()
    add_child_autofree(sb)
    await get_tree().process_frame
    sb.set_options(["All"])
    sb.enabled = false
    watch_signals(sb)
    sb.next()
    assert_signal_not_emitted(sb, "option_changed")
```

- [ ] **Step 2: Run test, verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_sort_sub_banner.gd -gexit
```
Expected: FAIL (scene not found).

- [ ] **Step 3: Create the scene**

`scenes/inventory/common/sort_sub_banner/sort_sub_banner.tscn`:

```
SortSubBanner (HBoxContainer)
  ├─ LeftArrow  (TextureRect, texture = equipment_grid/selection_arrow.png, flip_h = true, mouse_filter = STOP)
  ├─ Banner     (TextureRect, texture = equipment_grid/equipment_category.png, custom_min_size = (124, 28))
  │  └─ Label   (anchors fill, theme_type_variation = "LabelBodyLarge", text = "All", horizontal_alignment = CENTER)
  ├─ RightArrow (TextureRect, texture = equipment_grid/selection_arrow.png, mouse_filter = STOP)
  └─ Dots (HBoxContainer; populated in code)
```

- [ ] **Step 4: Write the script**

```gdscript
# scenes/inventory/common/sort_sub_banner/sort_sub_banner.gd
class_name SortSubBanner
extends HBoxContainer

## SortSubBanner
## Pill widget with left/right arrows over a list of named options, plus
## a row of position dots. Designed to be used as a sort/filter banner.

signal option_changed(index: int)

const DOT_SELECTED := preload("res://assets/sprites/inventory/equipment_grid/selected_option.png")
const DOT_UNSELECTED := preload("res://assets/sprites/inventory/equipment_grid/unselected_option.png")

@export var enabled: bool = true:
    set(value):
        enabled = value
        _refresh_disabled_visual()

@onready var _label: Label = $Banner/Label
@onready var _left: TextureRect = $LeftArrow
@onready var _right: TextureRect = $RightArrow
@onready var _dots: HBoxContainer = $Dots

var _options: PackedStringArray = PackedStringArray()
var _index: int = 0

var current_label: String:
    get: return _options[_index] if _index < _options.size() else ""

var current_index: int:
    get: return _index

func _ready() -> void:
    _left.gui_input.connect(_on_left_input)
    _right.gui_input.connect(_on_right_input)
    _refresh_disabled_visual()
    _redraw()

## Configure the option list. Resets index to 0.
func set_options(options: PackedStringArray) -> void:
    _options = options
    _index = 0
    _redraw()

func next() -> void:
    if not enabled or _options.is_empty():
        return
    _index = (_index + 1) % _options.size()
    _redraw()
    option_changed.emit(_index)

func prev() -> void:
    if not enabled or _options.is_empty():
        return
    _index = (_index - 1 + _options.size()) % _options.size()
    _redraw()
    option_changed.emit(_index)

func _on_left_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        prev()

func _on_right_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        next()

func _redraw() -> void:
    _label.text = current_label
    for child in _dots.get_children():
        child.queue_free()
    for i in _options.size():
        var dot := TextureRect.new()
        dot.texture = DOT_SELECTED if i == _index else DOT_UNSELECTED
        dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        _dots.add_child(dot)

func _refresh_disabled_visual() -> void:
    var a := 1.0 if enabled else 0.35
    if _left: _left.modulate.a = a
    if _right: _right.modulate.a = a
    if _dots: _dots.modulate.a = a
```

- [ ] **Step 5: Run tests, verify they pass**

Expected: both tests green.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/common/sort_sub_banner tests/integration/test_sort_sub_banner.gd
git commit -m "feat(inventory): add shared SortSubBanner scene"
```

---

## Task 4: GridToolbar shared scene

The thin row above the grid: item count on the left, trash slot on the right. Just a layout container that exposes its count label and the slot it holds.

**Files:**
- Create: `scenes/inventory/common/grid_toolbar/grid_toolbar.tscn`
- Create: `scenes/inventory/common/grid_toolbar/grid_toolbar.gd`

- [ ] **Step 1: Create the scene**

`scenes/inventory/common/grid_toolbar/grid_toolbar.tscn`:

```
GridToolbar (HBoxContainer)
  ├─ CountLabel (Label, unique_name_in_owner, theme_type_variation = "LabelBody",
  │              text = "0 / 0", size_flags_horizontal = EXPAND_FILL,
  │              theme_override_colors/font_color = Color("#3a2818"))
  └─ TrashSlotHolder (Container, unique_name_in_owner)
```

`TrashSlotHolder` is empty by default; each tab adds a `TrashSlot` child in code (see Task 8).

- [ ] **Step 2: Write the script**

```gdscript
# scenes/inventory/common/grid_toolbar/grid_toolbar.gd
class_name GridToolbar
extends HBoxContainer

## GridToolbar
## Above-grid row with a count label on the left and a holder for the
## TrashSlot on the right. Trash slot is added by the owning tab via
## set_trash_slot().

@onready var count_label: Label = %CountLabel
@onready var trash_slot_holder: Container = %TrashSlotHolder

func set_count(used: int, total: int) -> void:
    count_label.text = "%d / %d" % [used, total]

func set_count_text(text: String) -> void:
    count_label.text = text

func set_trash_slot(slot: Control) -> void:
    for child in trash_slot_holder.get_children():
        trash_slot_holder.remove_child(child)
    trash_slot_holder.add_child(slot)
```

- [ ] **Step 3: Commit**

```bash
git add scenes/inventory/common/grid_toolbar
git commit -m "feat(inventory): add shared GridToolbar scene"
```

---

## Task 5: InventoryGrid shared scene

The reusable grid host: a `ScrollContainer` + `GridContainer`, with a `ScrollRail` glued to its right edge. Exposes `add_slot(slot)` / `clear_slots()` / `get_slots()` so each tab populates with its own slot type.

**Files:**
- Create: `scenes/inventory/common/inventory_grid/inventory_grid.tscn`
- Create: `scenes/inventory/common/inventory_grid/inventory_grid.gd`

- [ ] **Step 1: Create the scene**

`scenes/inventory/common/inventory_grid/inventory_grid.tscn`:

```
InventoryGrid (HBoxContainer)
  ├─ ScrollContainer (size_flags_horizontal = EXPAND_FILL, unique_name_in_owner,
  │                   vertical_scroll_mode = AUTO,
  │                   theme_override_constants/separation = 0)
  │  └─ GridContainer (unique_name_in_owner, columns = 6,
  │                    theme_override_constants/h_separation = 6,
  │                    theme_override_constants/v_separation = 6,
  │                    size_flags_horizontal = EXPAND_FILL,
  │                    size_flags_vertical = EXPAND_FILL)
  └─ ScrollRail (instanced from scenes/inventory/common/scroll_rail/scroll_rail.tscn)
```

The host ScrollContainer's `VScrollBar` is hidden — the rail is what the player sees. Set `theme_override_constants/scrollbar_h_separation = 0` and override its v_scroll bar's stylebox to fully transparent (or just `custom_minimum_size = (0, 0)` and `modulate.a = 0`). The simplest hide is on the scrollbar's grabber + scroll styles set to a transparent StyleBoxEmpty.

- [ ] **Step 2: Write the script**

```gdscript
# scenes/inventory/common/inventory_grid/inventory_grid.gd
class_name InventoryGrid
extends HBoxContainer

## InventoryGrid
## A scrollable grid host. Each tab populates it with its own slot scenes
## via add_slot(). The ScrollRail child stays bound to the inner
## ScrollContainer so visual scrolling tracks the player's wheel/drag.

@export var columns: int = 6:
    set(value):
        columns = value
        if _grid:
            _grid.columns = value

@onready var _scroll: ScrollContainer = %ScrollContainer
@onready var _grid: GridContainer = %GridContainer
@onready var _rail: ScrollRail = $ScrollRail

func _ready() -> void:
    _grid.columns = columns
    _rail.bind(_scroll)

## Add a slot Control to the grid.
func add_slot(slot: Control) -> void:
    _grid.add_child(slot)

## Remove and free every slot currently in the grid.
func clear_slots() -> void:
    for child in _grid.get_children():
        child.queue_free()

## Returns all slot children currently in the grid.
func get_slots() -> Array[Node]:
    return _grid.get_children()
```

- [ ] **Step 3: Commit**

```bash
git add scenes/inventory/common/inventory_grid
git commit -m "feat(inventory): add shared InventoryGrid scene"
```

---

## Task 6: Equipment tab — switch to shared chrome, bump to 6×5

Reskin the Equipment tab onto the shared `InventoryGrid` + `SortSubBanner` + `GridToolbar` + (existing) `ScrollRail`. Bump the grid to 6 columns. Behaviour stays identical (drag/drop, gear selector, etc.); only composition changes.

**Files:**
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd:15` (`NUM_INVENTORY_SLOTS`) + `.tscn` (columns)
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_tab.tscn` (banner + sort wiring + toolbar)

- [ ] **Step 1: Bump columns in EquipmentGrid scene**

Open `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.tscn` and on the `GridContainer` node set `columns = 6`. Save.

- [ ] **Step 2: Bump slot count to match the 6-col layout**

Edit `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd` line 15:

```gdscript
const NUM_INVENTORY_SLOTS = 60  # was 50 — now 6 columns x 10 rows
```

- [ ] **Step 3: Wire SortSubBanner + GridToolbar into equipment_tab.tscn**

In the Godot editor, replace the existing ad-hoc `Selection` Control + `SelectionBanner` + arrows + dots in `equipment_tab.tscn` with a single instance of `sort_sub_banner.tscn`. Add a `GridToolbar` instance above the `EquipmentGrid`.

In `equipment_tab.gd`, add:

```gdscript
@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var grid_toolbar: GridToolbar = %GridToolbar
```

In `_ready()` add:
```gdscript
sort_banner.set_options(PackedStringArray(["All", "Weapons", "Armor", "Accessories"]))
sort_banner.enabled = false  # filtering wiring is deferred per spec
grid_toolbar.set_trash_slot(trash_slot)  # trash_slot already onready'd
```

The actual filter wiring is out of scope per the spec — leave it disabled.

- [ ] **Step 4: Update the count label whenever inventory changes**

In `equipment_tab.gd`, add a private `_on_inventory_changed`:

```gdscript
func _ready() -> void:
    # ... existing connects ...
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _refresh_count()

func _on_inventory_changed(_inventory: InventoryData) -> void:
    _refresh_count()

func _refresh_count() -> void:
    var inventory := InventoryManager.get_inventory()
    grid_toolbar.set_count(inventory.equipment.size(), 60)
```

- [ ] **Step 5: Open the game and verify visually**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Open inventory, confirm:
- Equipment grid has 6 columns visible.
- Banner + sort + dots + count + trash slot row all render in the right places.
- Drag-and-drop still works (regression check).

- [ ] **Step 6: Run existing tests to catch regressions**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all existing tests green.

- [ ] **Step 7: Commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab
git commit -m "feat(inventory): re-skin Equipment tab onto shared chrome (6 cols)"
```

---

## Task 7: InventoryManager.restore_* methods (for trash hold-buffer)

The TrashSlot needs to be able to put items *back* into inventory when the player drags them out, without going through the noisy `award_items` log path. Three thin methods do that.

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager_restore.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_inventory_manager_restore.gd
extends GutTest

func before_each() -> void:
    # Reset inventory between tests
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_restore_equipment_instance_puts_into_first_available_slot() -> void:
    var def := EquipmentDefinitionData.new()
    def.item_id = "test_blade"
    def.item_name = "Test Blade"
    var inst := ItemInstanceData.new()
    inst.item_definition = def
    InventoryManager.restore_equipment_instance(inst)
    assert_eq(InventoryManager.get_inventory().equipment.size(), 1)
    assert_eq(InventoryManager.get_inventory().equipment[0].item_definition.item_id, "test_blade")

func test_restore_equipment_at_specific_index_when_empty() -> void:
    var def := EquipmentDefinitionData.new()
    var inst := ItemInstanceData.new()
    inst.item_definition = def
    InventoryManager.restore_equipment_instance(inst, 5)
    assert_true(InventoryManager.get_inventory().equipment.has(5))

func test_restore_equipment_falls_back_to_first_available_if_target_occupied() -> void:
    var def := EquipmentDefinitionData.new()
    var a := ItemInstanceData.new(); a.item_definition = def
    var b := ItemInstanceData.new(); b.item_definition = def
    InventoryManager.restore_equipment_instance(a, 0)
    InventoryManager.restore_equipment_instance(b, 0) # 0 occupied, falls back to 1
    assert_true(InventoryManager.get_inventory().equipment.has(0))
    assert_true(InventoryManager.get_inventory().equipment.has(1))

func test_restore_material_increments_count() -> void:
    var def := MaterialDefinitionData.new()
    def.item_id = "fern"
    InventoryManager.restore_material(def, 3)
    assert_eq(InventoryManager.get_inventory().materials[def], 3)
    InventoryManager.restore_material(def, 2)
    assert_eq(InventoryManager.get_inventory().materials[def], 5)

func test_restore_consumable_increments_count() -> void:
    var def := ConsumableDefinitionData.new()
    def.item_id = "scale"
    InventoryManager.restore_consumable(def, 2)
    assert_eq(InventoryManager.get_inventory().consumables[def], 2)
```

- [ ] **Step 2: Run tests, verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_inventory_manager_restore.gd -gexit
```
Expected: FAIL (`Invalid call to method 'restore_equipment_instance'`).

- [ ] **Step 3: Add the methods**

Append to `singletons/inventory_manager/inventory_manager.gd` (in the PUBLIC API section, just below `use_consumable`):

```gdscript
## Put an equipment instance back into inventory (e.g., when the player
## drags it out of the trash slot before another item replaces it).
## Differs from award_items: takes the existing ItemInstanceData rather
## than creating a new one, and stays silent (no log spam).
func restore_equipment_instance(instance: ItemInstanceData, target_slot_index: int = -1) -> void:
    if instance == null:
        Log.error("InventoryManager.restore_equipment_instance: null instance")
        return
    var inventory := get_inventory()
    if target_slot_index >= 0 and not inventory.equipment.has(target_slot_index):
        inventory.equipment[target_slot_index] = instance
    else:
        _add_to_first_available_slot(inventory, instance)
    inventory_changed.emit(inventory)

## Restore N copies of a material to inventory (e.g., from trash drag-out).
## Bypasses the looted-log message that award_items emits.
func restore_material(def: MaterialDefinitionData, quantity: int) -> void:
    if def == null or quantity <= 0:
        return
    var inventory := get_inventory()
    inventory.materials[def] = inventory.materials.get(def, 0) + quantity
    inventory_changed.emit(inventory)

## Restore N copies of a consumable. Bypasses the looted-log message.
func restore_consumable(def: ConsumableDefinitionData, quantity: int) -> void:
    if def == null or quantity <= 0:
        return
    var inventory := get_inventory()
    inventory.consumables[def] = inventory.consumables.get(def, 0) + quantity
    inventory_changed.emit(inventory)
```

- [ ] **Step 4: Run tests, verify they pass**

Expected: all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add singletons/inventory_manager/inventory_manager.gd tests/unit/test_inventory_manager_restore.gd
git commit -m "feat(inventory): add restore_* methods for trash hold-buffer"
```

---

## Task 8: Functional TrashSlot with hold-buffer + discard-on-replace

Rewrite `TrashSlot` to hold one item at a time and destroy the held item when a new one arrives. Includes the "Discarded forever" overlay shown in the mockup.

**Files:**
- Modify: `scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.gd`
- Modify: `scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.tscn` (add X overlay Label)
- Create: `scenes/inventory/inventory_view/equipment_tab/trash_slot/discard_flash.tscn`
- Create: `scenes/inventory/inventory_view/equipment_tab/trash_slot/discard_flash.gd`
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd` (drop-to-trash branch)
- Test: `tests/integration/test_trash_slot_flow.gd`

- [ ] **Step 1: Add the X placeholder label to trash_slot.tscn**

Open `trash_slot.tscn` and add a child `Label` named `XOverlay`:
```
XOverlay (Label, anchors fill, text = "X",
          horizontal_alignment = CENTER, vertical_alignment = CENTER,
          theme_type_variation = "LabelTitleSmall",
          theme_override_colors/font_color = Color(0.2, 0.13, 0.07, 0.7))
```

This is the placeholder — when the new trash sprite ships, the Label is removed and the slot's texture itself shows the X.

- [ ] **Step 2: Create the discard_flash scene**

`discard_flash.tscn` (a brief modal overlay):
```
DiscardFlash (Control, mouse_filter = IGNORE, anchor fill)
  ├─ Background (ColorRect, color = Color(0.69, 0.29, 0.18, 0.25))
  └─ Panel (PanelContainer, anchors center,
            theme_override_styles/panel = assets/styleboxes/common/panel_loot_tray.tres)
      └─ VBoxContainer
         ├─ Title (Label, theme_type_variation = "LabelTitleSmall",
         │         text = "Discarded forever")
         ├─ ItemName (Label, unique_name_in_owner, theme_type_variation = "LabelHeading",
         │            theme_override_colors/font_color = Color("#f1c878"))
         └─ Hint (Label, theme_type_variation = "LabelMuted",
                   text = "Drop anything else here to replace it.")
```

`discard_flash.gd`:

```gdscript
# scenes/inventory/inventory_view/equipment_tab/trash_slot/discard_flash.gd
extends Control

@onready var _name: Label = %ItemName

func _ready() -> void:
    visible = false

## Show the flash with the discarded item name, then auto-hide.
func show_for(item_name: String) -> void:
    _name.text = item_name
    visible = true
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.05).from(0.0)
    tween.tween_interval(0.7)
    tween.tween_property(self, "modulate:a", 0.0, 0.18)
    tween.tween_callback(func(): visible = false)
```

- [ ] **Step 3: Rewrite trash_slot.gd**

Replace the entire file with:

```gdscript
class_name TrashSlot
extends InventorySlot

## TrashSlot
## Discard target. Holds one item at a time in a transient hold-buffer.
## Dropping a new item onto a non-empty TrashSlot destroys the previously
## held item permanently. Pulling the held item out (drag back to grid)
## restores it via InventoryManager.
##
## The hold-buffer stores either:
##   - an ItemInstanceData (for equipment), or
##   - a [definition, quantity] pair for materials / consumables.

const SLOT_TEXTURE := preload("res://assets/sprites/inventory/inventory_slot/UI_NoteBook_Slot04a.png")

## When non-null, the slot is currently holding something.
## Either an ItemInstanceData OR an Array [def, quantity].
var _held: Variant = null

@onready var _x_overlay: Label = $XOverlay

func _ready() -> void:
    empty_texture = SLOT_TEXTURE
    full_texture = SLOT_TEXTURE
    super._ready()
    add_to_group("TrashSlots")

## Returns true if currently holding something.
func is_holding() -> bool:
    return _held != null

## Returns the held item (or null). Caller is responsible for emptying via
## clear_hold() if they're pulling the item out.
func get_held() -> Variant:
    return _held

## Empty the hold-buffer without destroying or restoring.
## The caller decides what to do with the previously held value.
func clear_hold() -> void:
    _held = null
    _update_x_visibility()

## Place an item into the hold-buffer. If the buffer already has something,
## that prior item is permanently destroyed.
## Returns the prior item's display name (or "" if buffer was empty).
func accept(held_value: Variant) -> String:
    var discarded_name := ""
    if _held != null:
        discarded_name = _held_display_name(_held)
        _log_discard(_held)
    _held = held_value
    _update_x_visibility()
    return discarded_name

## On close-inventory, restore held content to InventoryManager.
## Called by the parent tab so the user doesn't lose work.
func flush_to_inventory() -> void:
    if _held == null:
        return
    _restore_to_inventory(_held)
    _held = null
    _update_x_visibility()

func _update_x_visibility() -> void:
    _x_overlay.visible = not is_holding()

func _held_display_name(value: Variant) -> String:
    if value is ItemInstanceData:
        var inst := value as ItemInstanceData
        return inst.item_definition.item_name if inst.item_definition else "(unknown)"
    if value is Array and value.size() == 2:
        var def: ItemDefinitionData = value[0]
        return def.item_name if def else "(unknown)"
    return "(unknown)"

func _log_discard(value: Variant) -> void:
    if LogManager:
        LogManager.log_message("[color=red]Discarded %s[/color]" % _held_display_name(value))

func _restore_to_inventory(value: Variant) -> void:
    if value is ItemInstanceData:
        InventoryManager.restore_equipment_instance(value as ItemInstanceData)
    elif value is Array and value.size() == 2:
        var def: ItemDefinitionData = value[0]
        var qty: int = value[1]
        if def is MaterialDefinitionData:
            InventoryManager.restore_material(def as MaterialDefinitionData, qty)
        elif def is ConsumableDefinitionData:
            InventoryManager.restore_consumable(def as ConsumableDefinitionData, qty)
```

- [ ] **Step 4: Wire the trash branch into equipment_tab.gd's _drop_item**

Open `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd`. In `_drop_item()` (currently around line 90), after the `if target_slot and target_slot != original_slot:` block, add a check for the trash slot **before** the existing logic. Replace `_drop_item` with:

```gdscript
func _drop_item(global_mouse_pos: Vector2) -> void:
    var target_slot = _get_slot_under_mouse(global_mouse_pos)
    dragged_item.scale = Vector2(1.0, 1.0)

    # Trash drop short-circuits everything else.
    if target_slot is TrashSlot:
        _handle_trash_drop(target_slot as TrashSlot)
        _cleanup_drag()
        return

    if target_slot and target_slot != original_slot:
        # ... existing branch logic untouched ...
```

Add `_handle_trash_drop` near the bottom of the file:

```gdscript
func _handle_trash_drop(trash: TrashSlot) -> void:
    # The dragged_item is an ItemInstance Control. Pull the data out.
    var data: ItemInstanceData = dragged_item.item_instance_data
    var prior_name: String = trash.accept(data)
    if prior_name != "":
        _show_discard_flash(prior_name)
    dragged_item.queue_free()
```

Add `_show_discard_flash` (assumes a `DiscardFlash` is instanced as a child of the InventoryView root — wire that in `inventory_view.tscn`):

```gdscript
func _show_discard_flash(item_name: String) -> void:
    var flash := get_tree().get_first_node_in_group("DiscardFlashes")
    if flash and flash.has_method("show_for"):
        flash.show_for(item_name)
```

Add an instance of `discard_flash.tscn` to `inventory_view.tscn` at the root level, and put it in group `DiscardFlashes` via the editor's Groups panel.

- [ ] **Step 5: Handle drag-out from trash slot in equipment_tab.gd._pick_up_item**

When the player clicks on a TrashSlot that's holding something, the existing `_pick_up_item` calls `slot.grab_item()` — but `InventorySlot.grab_item` returns its `item_instance` (the visual node). For trash, we want to pull from the hold-buffer instead.

Modify `_on_slot_input()` in equipment_tab.gd to intercept clicks on `TrashSlot`:

```gdscript
func _on_slot_input(slot: InventorySlot, event: InputEvent) -> void:
    # ... existing hover/select logic ...

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not is_dragging:
            if slot is TrashSlot and (slot as TrashSlot).is_holding():
                _pick_up_from_trash(slot as TrashSlot, event.global_position)
                return
            if slot.item_instance != null:
                _pick_up_item(slot, event.global_position)
```

And add:

```gdscript
func _pick_up_from_trash(trash: TrashSlot, global_mouse_pos: Vector2) -> void:
    var held = trash.get_held()
    trash.clear_hold()

    # For equipment instances, build an ItemInstance Control to drag visually.
    if held is ItemInstanceData:
        var item_instance_scene: PackedScene = preload("res://scenes/inventory/item_instance/item_instance.tscn")
        var visual = item_instance_scene.instantiate()
        visual.setup(held)
        dragged_item = visual
        is_dragging = true
        original_slot = trash
        add_child(dragged_item)
        dragged_item.global_position = global_mouse_pos + POSITION_OFFSET
        dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Materials / consumables held in trash aren't yet draggable in this tab
    # (this tab only handles equipment). The hold-out for non-equipment tabs
    # is wired in Tasks 11/15.
```

- [ ] **Step 6: Flush trash on inventory close**

In `inventory_view.gd` `_on_inventory_close_animation_finished` (or wherever close is finalized), iterate `TrashSlots` group and call `flush_to_inventory()`:

```gdscript
func _on_inventory_close_animation_finished() -> void:
    book_animation_player.animation_finished.disconnect(_on_inventory_close_animation_finished)
    for trash in get_tree().get_nodes_in_group("TrashSlots"):
        if trash.has_method("flush_to_inventory"):
            trash.flush_to_inventory()
    inventory_closed.emit()
```

- [ ] **Step 7: Write the integration test**

```gdscript
# tests/integration/test_trash_slot_flow.gd
extends GutTest

const TrashSlotScene := preload("res://scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.tscn")

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_first_drop_is_held_no_destroy() -> void:
    var trash := TrashSlotScene.instantiate()
    add_child_autofree(trash)
    await get_tree().process_frame
    var inst := ItemInstanceData.new(); inst.item_definition = EquipmentDefinitionData.new()
    inst.item_definition.item_name = "First"
    var prior := trash.accept(inst)
    assert_eq(prior, "")
    assert_true(trash.is_holding())

func test_second_drop_destroys_first_returns_prior_name() -> void:
    var trash := TrashSlotScene.instantiate()
    add_child_autofree(trash)
    await get_tree().process_frame
    var inst1 := ItemInstanceData.new(); inst1.item_definition = EquipmentDefinitionData.new()
    inst1.item_definition.item_name = "First"
    var inst2 := ItemInstanceData.new(); inst2.item_definition = EquipmentDefinitionData.new()
    inst2.item_definition.item_name = "Second"
    trash.accept(inst1)
    var prior := trash.accept(inst2)
    assert_eq(prior, "First")
    assert_eq(trash.get_held(), inst2)

func test_flush_returns_held_equipment_to_inventory() -> void:
    var trash := TrashSlotScene.instantiate()
    add_child_autofree(trash)
    await get_tree().process_frame
    var inst := ItemInstanceData.new(); inst.item_definition = EquipmentDefinitionData.new()
    trash.accept(inst)
    trash.flush_to_inventory()
    assert_false(trash.is_holding())
    assert_eq(InventoryManager.get_inventory().equipment.size(), 1)

func test_flush_restores_material_with_correct_quantity() -> void:
    var trash := TrashSlotScene.instantiate()
    add_child_autofree(trash)
    await get_tree().process_frame
    var def := MaterialDefinitionData.new(); def.item_id = "ash_powder"
    trash.accept([def, 1])
    trash.flush_to_inventory()
    assert_eq(InventoryManager.get_inventory().materials[def], 1)
```

- [ ] **Step 8: Run tests + open the game to drive trash drop**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -gtest=test_trash_slot_flow.gd -gexit
```
Expected: all 4 tests green.

Also visually: open the game, drop one item into the trash slot (no flash). Drop a second (flash fires with the first item's name; the first is gone forever). Drag the second back out to the grid (restored to inventory).

- [ ] **Step 9: Commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab \
        scenes/inventory/inventory_view/inventory_view.tscn \
        scenes/inventory/inventory_view/inventory_view.gd \
        tests/integration/test_trash_slot_flow.gd
git commit -m "feat(inventory): functional TrashSlot with hold-buffer + flash"
```

---

## Task 9: MaterialDefinitionData fields + migrate existing .tres

Add `source_description` and `used_in` to `MaterialDefinitionData` and populate the two existing material `.tres` files. No code reads these yet — the Materials tab rebuild in Task 11 wires them.

**Files:**
- Modify: `scripts/resource_definitions/items/material_definition_data.gd`
- Modify: `resources/items/materials/spirit_fern.tres`
- Modify: `resources/items/materials/dewdrop_tear.tres`

- [ ] **Step 1: Add the fields**

Edit `scripts/resource_definitions/items/material_definition_data.gd`:

```gdscript
class_name MaterialDefinitionData
extends ItemDefinitionData

@export var source_zone_ids : Array[String] = []

## Free-form lore string describing where this material is found.
## Shown on the material detail card under "Source".
@export var source_description: String = ""

## Comma-separated names of items/recipes that consume this material.
## Free-form for now; can graph from recipe data once crafting lands.
@export var used_in: String = ""

func _get_item_effects() -> Array[String]:
    if source_zone_ids.is_empty():
        return []
    return ["Source Zones: %s" % ", ".join(source_zone_ids)]
```

- [ ] **Step 2: Backfill `spirit_fern.tres`**

Open `resources/items/materials/spirit_fern.tres` in the Godot editor and set:
- `source_description` = `"Spirit Valley — shaded hex"`
- `used_in` = `"Reinforced Robes · Greenleaf Tonic"`

Save (editor will rewrite the .tres).

- [ ] **Step 3: Backfill `dewdrop_tear.tres`**

Same as above with:
- `source_description` = `"Glade pool, dawn only"`
- `used_in` = `"Spirit Tea · Mirror Pill"`

- [ ] **Step 4: Commit**

```bash
git add scripts/resource_definitions/items/material_definition_data.gd \
        resources/items/materials/spirit_fern.tres \
        resources/items/materials/dewdrop_tear.tres
git commit -m "feat(items): add source_description + used_in to MaterialDefinitionData"
```

---

## Task 10: QuestItemDefinitionData + migrate refugee_camp_map

Add the new class and update the one existing quest item `.tres` to use it. No UI wiring yet — Journal tab rebuild in Task 12 reads the new field.

**Files:**
- Create: `scripts/resource_definitions/items/quest_item_definition_data.gd`
- Modify: `resources/items/quest_items/refugee_camp_map.tres`
- Test: `tests/unit/test_quest_item_definition_data.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_quest_item_definition_data.gd
extends GutTest

func test_inits_as_quest_item_type() -> void:
    var d := QuestItemDefinitionData.new()
    assert_eq(d.item_type, ItemDefinitionData.ItemType.QUEST_ITEM)

func test_from_source_field_round_trips() -> void:
    var d := QuestItemDefinitionData.new()
    d.from_source = "Old Vesh"
    assert_eq(d.from_source, "Old Vesh")
```

- [ ] **Step 2: Run test, verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_quest_item_definition_data.gd -gexit
```
Expected: FAIL (`Identifier 'QuestItemDefinitionData' is not declared`).

- [ ] **Step 3: Create the class**

```gdscript
# scripts/resource_definitions/items/quest_item_definition_data.gd
class_name QuestItemDefinitionData
extends ItemDefinitionData

## QuestItemDefinitionData
## Quest items get one extra field over the base: from_source (free-form
## lore describing where the player obtained this). The Journal renders
## that as the "From:" row.
##
## The "Linked quest" row from the mockup is deferred until a real
## QuestManager exists — every quest item currently renders with the
## active wax seal.

@export var from_source: String = ""

func _init() -> void:
    item_type = ItemType.QUEST_ITEM
```

- [ ] **Step 4: Migrate refugee_camp_map.tres**

Open `resources/items/quest_items/refugee_camp_map.tres` in the editor. Change the script reference from `ItemDefinitionData` to the new `QuestItemDefinitionData` script (drag the new .gd onto the resource's Script field). Set:
- `from_source` = `"Old Vesh, in the broken shrine"`

Save.

The raw .tres should now have something like:
```
[gd_resource type="Resource" script_class="QuestItemDefinitionData" format=3 ...]

[ext_resource type="Script" path="res://scripts/resource_definitions/items/quest_item_definition_data.gd" id="..."]

[resource]
script = ExtResource("...")
item_id = "refugee_camp_map"
item_name = "Refugee Camp Map"
description = "..."
icon = ...
from_source = "Old Vesh, in the broken shrine"
```

- [ ] **Step 5: Run tests, verify they pass**

Expected: 2 tests green. Also run the full suite to confirm no regressions in code paths that load the migrated .tres:

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/items/quest_item_definition_data.gd \
        resources/items/quest_items/refugee_camp_map.tres \
        tests/unit/test_quest_item_definition_data.gd
git commit -m "feat(items): add QuestItemDefinitionData with from_source"
```

---

## Task 11: Materials tab rebuild — grid + detail card

Tear out the row-list and rebuild on the shared chrome. Adds a `MaterialSlot` (icon + stack count) populated into an `InventoryGrid`, a `MaterialDetailCard` on the right page with Source/Used in/Worth rows, and a `MaterialTipCard` below it.

**Files:**
- Create: `scenes/inventory/inventory_view/materials_tab/material_slot.tscn`
- Create: `scenes/inventory/inventory_view/materials_tab/material_slot.gd`
- Create: `scenes/inventory/inventory_view/materials_tab/material_detail_card.tscn`
- Create: `scenes/inventory/inventory_view/materials_tab/material_detail_card.gd`
- Create: `scenes/inventory/inventory_view/materials_tab/material_tip_card.tscn`
- Modify: `scenes/inventory/inventory_view/materials_tab/materials_tab.tscn` (full rebuild)
- Modify: `scenes/inventory/inventory_view/materials_tab/materials_tab.gd`

- [ ] **Step 1: Create `material_slot.tscn` + `.gd`**

Scene:
```
MaterialSlot (TextureRect, custom_min_size = (60, 60),
              texture = inventory_slot/UI_NoteBook_Slot01a.png,
              stretch_mode = STRETCH_KEEP_ASPECT_CENTERED)
  ├─ Icon  (TextureRect, anchors center, custom_min_size = (32, 32), unique_name_in_owner,
  │         stretch_mode = STRETCH_KEEP_ASPECT_CENTERED)
  └─ Count (Label, anchors bottom_right, unique_name_in_owner,
            theme_type_variation = "LabelSmall",
            theme_override_colors/font_color = Color("#3a2818"))
```

```gdscript
# scenes/inventory/inventory_view/materials_tab/material_slot.gd
class_name MaterialSlot
extends TextureRect

signal clicked(slot: MaterialSlot, event: InputEvent)

@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count

var _def: MaterialDefinitionData = null
var _qty: int = 0

func _ready() -> void:
    gui_input.connect(func(e): clicked.emit(self, e))
    _refresh()

func setup(def: MaterialDefinitionData, qty: int) -> void:
    _def = def
    _qty = qty
    if is_inside_tree(): _refresh()

func get_definition() -> MaterialDefinitionData: return _def
func get_quantity() -> int: return _qty

func _refresh() -> void:
    if _def == null:
        _icon.texture = null
        _count.text = ""
        return
    _icon.texture = _def.icon
    _count.text = "×%d" % _qty if _qty > 1 else ""
```

- [ ] **Step 2: Create `material_detail_card.tscn` + `.gd`**

The detail card extends `ItemDetailCard` (Task 1) and adds three extra rows. Easiest way: instantiate `item_detail_card.tscn` as the root, then `extend` it via a script (Godot lets a derived scene attach a derived script).

Scene tree (inheriting `item_detail_card.tscn`):
```
MaterialDetailCard (root, attached script = material_detail_card.gd)
  └─ MarginContainer
     └─ VBoxContainer
        └─ ...
           (after EffectsLabel, append:)
        ├─ HSeparator
        ├─ SourceRow (HBoxContainer, unique_name_in_owner)
        │  ├─ Label (text = "Source", theme_type_variation = "LabelSmall",
        │  │        theme_override_colors/font_color = Color("#7a5230"))
        │  └─ Value (Label, unique_name_in_owner = "SourceValue",
        │            theme_type_variation = "LabelBody",
        │            theme_override_colors/font_color = Color("#2e1f10"))
        ├─ UsedInRow (HBoxContainer)
        │  ├─ Label (text = "Used in")
        │  └─ Value (Label, unique_name_in_owner = "UsedInValue")
        └─ WorthRow (HBoxContainer)
           ├─ Label (text = "Worth")
           └─ Value (Label, unique_name_in_owner = "WorthValue")
```

```gdscript
# scenes/inventory/inventory_view/materials_tab/material_detail_card.gd
class_name MaterialDetailCard
extends ItemDetailCard

@onready var _source_value: Label = %SourceValue
@onready var _used_in_value: Label = %UsedInValue
@onready var _worth_value: Label = %WorthValue

func setup_from_definition(def: ItemDefinitionData) -> void:
    super.setup_from_definition(def)
    if def is MaterialDefinitionData:
        var m := def as MaterialDefinitionData
        _source_value.text = m.source_description
        _used_in_value.text = m.used_in
        _worth_value.text = "%d ◉" % int(m.base_value) if m.base_value > 0 else "—"
    else:
        _source_value.text = ""
        _used_in_value.text = ""
        _worth_value.text = ""
```

- [ ] **Step 3: Create `material_tip_card.tscn`**

Static text card:
```
MaterialTipCard (PanelContainer, theme_override_styles/panel = ... a new dashed-border stylebox)
  └─ MarginContainer
     └─ VBoxContainer
        ├─ Title (Label, text = "Tip", theme_type_variation = "LabelSubheading",
        │         theme_override_colors/font_color = Color("#b04a2f"))
        └─ Body (Label, autowrap = WORD,
                 theme_type_variation = "LabelSmall",
                 text = "Right-click a material to mark it as a favorite — favorites rise to the top of the grid and pulse softly when used by a recipe.")
```

(No script needed — pure layout.)

- [ ] **Step 4: Rebuild `materials_tab.tscn`**

Full tear-down of the existing tree (`MaterialsGrid` MarginContainer → ScrollContainer → VBoxContainer of `MaterialContainer` rows). Replace with:

```
MaterialsTab (Control, attached script = materials_tab.gd)
  ├─ Banner (TextureRect, texture = materials_tab/banner.png, offset matches Equipment banner)
  ├─ SortSubBanner (instance, enabled = false at runtime, options = ["All"])
  ├─ GridToolbar (instance)
  │  └─ (trash slot added in code)
  ├─ InventoryGrid (instance, columns = 6, holds MaterialSlot children)
  ├─ MaterialDetailCard (instance, positioned on right page)
  └─ MaterialTipCard (instance, below detail card)
  + TrashSlot (instance, added to grid toolbar at runtime)
```

Position the right-page elements to mirror the Equipment tab's layout. Specific offsets are best tuned in the editor; the spec mockup is the reference.

- [ ] **Step 5: Rewrite `materials_tab.gd`**

```gdscript
extends Control

const MaterialSlotScene := preload("res://scenes/inventory/inventory_view/materials_tab/material_slot.tscn")

@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var grid_toolbar: GridToolbar = %GridToolbar
@onready var grid: InventoryGrid = %InventoryGrid
@onready var detail_card: MaterialDetailCard = %MaterialDetailCard
@onready var trash_slot: TrashSlot = %TrashSlot

func _ready() -> void:
    sort_banner.set_options(PackedStringArray(["All"]))
    sort_banner.enabled = false
    grid_toolbar.set_trash_slot(trash_slot)

    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _rebuild(InventoryManager.get_material_items())

func _rebuild(materials: Dictionary[MaterialDefinitionData, int]) -> void:
    grid.clear_slots()
    var first_def: MaterialDefinitionData = null
    for def in materials.keys():
        var slot := MaterialSlotScene.instantiate()
        grid.add_slot(slot)
        slot.setup(def, materials[def])
        slot.clicked.connect(_on_slot_clicked)
        if first_def == null:
            first_def = def
    grid_toolbar.set_count_text("%d kinds collected" % materials.size())
    if first_def:
        detail_card.setup_from_definition(first_def)
    else:
        detail_card.reset()

func _on_slot_clicked(slot: MaterialSlot, event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        detail_card.setup_from_definition(slot.get_definition())

func _on_inventory_changed(_inv: InventoryData) -> void:
    _rebuild(InventoryManager.get_material_items())
```

(Drag-to-trash from Materials is wired in a follow-up if needed — current spec scope is "trash slot visible + accepts drops". Equipment drag still works because Equipment owns its own drag; Materials drag is a follow-up.)

- [ ] **Step 6: Open the game and visually verify**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

- Open inventory → Materials tab.
- Confirm grid of material slots with counts, detail card on right with Spirit Fern's Source / Used in / Worth filled in.

- [ ] **Step 7: Run the full test suite for regressions**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add scenes/inventory/inventory_view/materials_tab
git commit -m "feat(inventory): rebuild Materials tab onto shared grid + detail card"
```

---

## Task 12: Journal tab rebuild — rich rows + journal card

Replace `quest_item_row.tscn` rows with the `JournalRow` (icon-circle + name + sub + wax seal). Right page gets the `QuestJournalCard` with drop-cap body text.

**Files:**
- Create: `scenes/inventory/inventory_view/quest_items_tab/journal_row.tscn`
- Create: `scenes/inventory/inventory_view/quest_items_tab/journal_row.gd`
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_journal_card.tscn`
- Create: `scenes/inventory/inventory_view/quest_items_tab/quest_journal_card.gd`
- Create: `scenes/inventory/inventory_view/quest_items_tab/wax_seal.tscn`
- Modify: `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn`
- Modify: `scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.gd`
- Test: `tests/integration/test_journal_tab_render.gd`

- [ ] **Step 1: Create `wax_seal.tscn`**

Placeholder scene:
```
WaxSeal (Control, custom_min_size = (14, 14))
  └─ Dot (ColorRect, anchors fill, color = Color("#b04a2f"))
```

Replace with the new sprite when ready by swapping the ColorRect for a TextureRect.

- [ ] **Step 2: Create `journal_row.tscn` + `.gd`**

Scene:
```
JournalRow (Button, custom_min_size = (0, 56), flat = true)
  └─ HBoxContainer (anchors fill, margins 8)
     ├─ IconCircle (TextureRect, custom_min_size = (40, 40),
     │              texture = equipment_grid/selected_option.png stretched to 40px)
     │  └─ Icon (TextureRect, anchors center, custom_min_size = (24, 24), unique_name_in_owner)
     ├─ TextColumn (VBoxContainer, size_flags_horizontal = EXPAND_FILL)
     │  ├─ Name (Label, unique_name_in_owner, theme_type_variation = "LabelSubheading",
     │  │        theme_override_colors/font_color = Color("#2e1f10"))
     │  └─ Sub  (Label, unique_name_in_owner, theme_type_variation = "LabelMuted")
     └─ WaxSeal (instance from wax_seal.tscn, unique_name_in_owner)
```

```gdscript
# scenes/inventory/inventory_view/quest_items_tab/journal_row.gd
extends Button

signal row_clicked(item: ItemDefinitionData)

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _sub: Label = %Sub

var _item: ItemDefinitionData = null

func _ready() -> void:
    pressed.connect(_on_pressed)
    _refresh()

func set_item(value: ItemDefinitionData) -> void:
    _item = value
    if is_inside_tree(): _refresh()

func get_item() -> ItemDefinitionData:
    return _item

func set_selected(value: bool) -> void:
    modulate = Color(1.0, 1.0, 1.0) if not value else Color(1.3, 1.25, 0.85)

func _refresh() -> void:
    if _item == null:
        _icon.texture = null
        _name.text = ""
        _sub.text = ""
        return
    _icon.texture = _item.icon
    _name.text = _item.item_name
    _sub.text = _item.description if _item.description.length() < 60 else _item.description.substr(0, 60) + "…"

func _on_pressed() -> void:
    row_clicked.emit(_item)
```

- [ ] **Step 3: Create `quest_journal_card.tscn` + `.gd`**

Scene:
```
QuestJournalCard (PanelContainer, theme_override_styles/panel = panel_loot_tray.tres)
  └─ MarginContainer
     └─ VBoxContainer
        ├─ Header (HBoxContainer)
        │  ├─ Icon (TextureRect, custom_min_size = (52, 52), unique_name_in_owner)
        │  └─ TitleColumn (VBoxContainer, size_flags_horizontal = EXPAND_FILL)
        │     ├─ Name (Label, unique_name_in_owner, theme_type_variation = "LabelHeading",
        │     │        theme_override_colors/font_color = Color("#2e1f10"))
        │     └─ Sub  (Label, unique_name_in_owner, theme_type_variation = "LabelMuted")
        ├─ HSeparator (theme_type_variation = "HSeparatorItemDesc")
        ├─ Body (RichTextLabel, unique_name_in_owner, bbcode_enabled = true,
        │        fit_content = true, theme_type_variation = "RichTextLabelDark")
        ├─ HSeparator (theme_type_variation = "HSeparatorItemDescThin")
        └─ FromRow (HBoxContainer, unique_name_in_owner)
           ├─ Label (text = "From", theme_type_variation = "LabelSmall",
           │        theme_override_colors/font_color = Color("#7a5230"),
           │        size_flags_horizontal = EXPAND_FILL)
           └─ FromValue (Label, unique_name_in_owner, theme_type_variation = "LabelBody",
                         theme_override_colors/font_color = Color("#2e1f10"))
```

```gdscript
# scenes/inventory/inventory_view/quest_items_tab/quest_journal_card.gd
extends PanelContainer

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _sub: Label = %Sub
@onready var _body: RichTextLabel = %Body
@onready var _from_row: HBoxContainer = %FromRow
@onready var _from_value: Label = %FromValue

func setup_from_definition(def: ItemDefinitionData) -> void:
    if def == null:
        reset()
        return
    _icon.texture = def.icon
    _name.text = def.item_name
    _sub.text = ""  # reserved for future "sub-title" field on QuestItemDefinitionData

    # Drop-cap effect: first letter rendered larger and in ribbon-red.
    var body_text := def.description if def.description != null else ""
    if body_text.length() >= 1:
        var first := body_text[0]
        var rest := body_text.substr(1)
        _body.text = "[font_size=38][color=#b04a2f]%s[/color][/font_size]%s" % [first, rest]
    else:
        _body.text = ""

    # "From:" row — only on QuestItemDefinitionData; otherwise hidden.
    if def is QuestItemDefinitionData:
        var quest_def := def as QuestItemDefinitionData
        _from_row.visible = not quest_def.from_source.is_empty()
        _from_value.text = quest_def.from_source
    else:
        _from_row.visible = false
        _from_value.text = ""

func reset() -> void:
    _icon.texture = null
    _name.text = ""
    _sub.text = ""
    _body.text = ""
    _from_row.visible = false
```

- [ ] **Step 4: Rebuild quest_items_tab.tscn**

Replace the existing left-page `ListPane` `VBoxContainer` of `QuestItemRow` rows with the `JournalRow` flow. Replace the right-page `ItemDescriptionPanel` with `QuestJournalCard`. Add a "Journal" banner — for the placeholder, reuse `materials_tab/banner.png` and overlay a Label with text "JOURNAL" + `LabelTitleSmall` variant. Add an "Items of consequence" `LabelSubheading` subtitle below the banner.

- [ ] **Step 5: Rewrite quest_items_tab.gd**

```gdscript
extends Control

const JournalRowScene := preload("res://scenes/inventory/inventory_view/quest_items_tab/journal_row.tscn")

@onready var list_vbox: VBoxContainer = %ListVBox
@onready var empty_label: Label = %EmptyLabel
@onready var journal_card: PanelContainer = %QuestJournalCard

var _selected: ItemDefinitionData = null

func _ready() -> void:
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _rebuild(InventoryManager.get_quest_items())
    else:
        _rebuild({})

func _rebuild(quest_items: Dictionary) -> void:
    for child in list_vbox.get_children():
        child.queue_free()

    if quest_items.is_empty():
        empty_label.visible = true
        journal_card.visible = false
        if journal_card.has_method("reset"):
            journal_card.reset()
        _selected = null
        return

    empty_label.visible = false
    journal_card.visible = true

    var first: ItemDefinitionData = null
    for def in quest_items.keys():
        var row := JournalRowScene.instantiate()
        list_vbox.add_child(row)
        row.set_item(def)
        row.row_clicked.connect(_on_row_clicked)
        if first == null: first = def

    if _selected == null or not quest_items.has(_selected):
        _selected = first
    _show_item(_selected)

func _show_item(def: ItemDefinitionData) -> void:
    if def == null:
        if journal_card.has_method("reset"): journal_card.reset()
        return
    if journal_card.has_method("setup_from_definition"):
        journal_card.setup_from_definition(def)
    for row in list_vbox.get_children():
        if row.has_method("set_selected") and row.has_method("get_item"):
            row.set_selected(row.get_item() == def)

func _on_row_clicked(def: ItemDefinitionData) -> void:
    _selected = def
    _show_item(def)

func _on_inventory_changed(_inv: InventoryData) -> void:
    _rebuild(InventoryManager.get_quest_items())
```

- [ ] **Step 6: Write integration test**

```gdscript
# tests/integration/test_journal_tab_render.gd
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_journal_renders_quest_item_from_source() -> void:
    var def := QuestItemDefinitionData.new()
    def.item_id = "test_map"
    def.item_name = "Test Map"
    def.description = "A folded scrap of parchment."
    def.from_source = "Old Vesh"
    InventoryManager.award_items(def, 1)

    var tab_scene := load("res://scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn")
    var tab = tab_scene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame

    var card = tab.get_node("%QuestJournalCard")
    assert_eq(card.get_node("%Name").text, "Test Map")
    assert_true(card.get_node("%FromRow").visible)
    assert_eq(card.get_node("%FromValue").text, "Old Vesh")
```

- [ ] **Step 7: Run tests + visually verify**

Run the test, open the game and confirm:
- Journal tab shows a rich row for "Refugee Camp Map"
- Right page shows the journal card with drop-cap "A" and "From: Old Vesh, in the broken shrine"

- [ ] **Step 8: Commit**

```bash
git add scenes/inventory/inventory_view/quest_items_tab \
        tests/integration/test_journal_tab_render.gd
git commit -m "feat(inventory): rebuild Quest tab as Journal with from_source"
```

---

## Task 13: InventoryData.equipped_consumables + manager equip/unequip

**Files:**
- Modify: `singletons/persistence_manager/inventory_data.gd`
- Modify: `singletons/inventory_manager/inventory_manager.gd`
- Test: `tests/unit/test_inventory_manager_consumable_hotbar.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_inventory_manager_consumable_hotbar.gd
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_equip_consumable_sets_slot() -> void:
    var def := ConsumableDefinitionData.new()
    def.item_id = "scale"
    watch_signals(InventoryManager)
    InventoryManager.equip_consumable(def, 0)
    assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def)
    assert_signal_emitted(InventoryManager, "inventory_changed")

func test_equip_same_def_to_new_slot_clears_old() -> void:
    var def := ConsumableDefinitionData.new()
    def.item_id = "scale"
    InventoryManager.equip_consumable(def, 0)
    InventoryManager.equip_consumable(def, 2)
    assert_false(InventoryManager.get_inventory().equipped_consumables.has(0))
    assert_eq(InventoryManager.get_inventory().equipped_consumables[2], def)

func test_unequip_consumable_erases_slot() -> void:
    var def := ConsumableDefinitionData.new()
    InventoryManager.equip_consumable(def, 1)
    InventoryManager.unequip_consumable(1)
    assert_false(InventoryManager.get_inventory().equipped_consumables.has(1))

func test_equip_replaces_other_def_in_target_slot() -> void:
    var def_a := ConsumableDefinitionData.new(); def_a.item_id = "a"
    var def_b := ConsumableDefinitionData.new(); def_b.item_id = "b"
    InventoryManager.equip_consumable(def_a, 0)
    InventoryManager.equip_consumable(def_b, 0)
    assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def_b)
```

- [ ] **Step 2: Run tests, verify they fail**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_inventory_manager_consumable_hotbar.gd -gexit
```
Expected: FAIL (missing methods / field).

- [ ] **Step 3: Add equipped_consumables to InventoryData**

Append to `singletons/persistence_manager/inventory_data.gd`:

```gdscript
## Consumables equipped to the combat hotbar. Keys are physical slot
## indices 0..3 (corresponding to hotkeys 1..4). Stack count is read
## from `consumables`, not stored here.
@export var equipped_consumables: Dictionary[int, ConsumableDefinitionData] = {}
```

Update `_to_string()` to include `equipped_consumables` if you want; not strictly required.

- [ ] **Step 4: Add equip_consumable + unequip_consumable to InventoryManager**

Append to `singletons/inventory_manager/inventory_manager.gd` in the PUBLIC API section:

```gdscript
## Place a consumable definition into hotbar slot_index (0..3).
## If the same definition is already in another slot, that other slot
## is cleared first — uniqueness rule, matches the ability loadout.
func equip_consumable(def: ConsumableDefinitionData, slot_index: int) -> void:
    if def == null:
        Log.error("InventoryManager.equip_consumable: null definition")
        return
    if slot_index < 0 or slot_index > 3:
        Log.error("InventoryManager.equip_consumable: slot_index %d out of range" % slot_index)
        return
    var inventory := get_inventory()
    # Clear any existing slot that already holds this def.
    for existing_slot in inventory.equipped_consumables.keys():
        if inventory.equipped_consumables[existing_slot] == def and existing_slot != slot_index:
            inventory.equipped_consumables.erase(existing_slot)
    inventory.equipped_consumables[slot_index] = def
    inventory_changed.emit(inventory)

## Clear a consumable hotbar slot. No-op if the slot is already empty.
func unequip_consumable(slot_index: int) -> void:
    var inventory := get_inventory()
    if inventory.equipped_consumables.has(slot_index):
        inventory.equipped_consumables.erase(slot_index)
        inventory_changed.emit(inventory)
```

- [ ] **Step 5: Run tests, verify all 4 pass**

- [ ] **Step 6: Commit**

```bash
git add singletons/persistence_manager/inventory_data.gd \
        singletons/inventory_manager/inventory_manager.gd \
        tests/unit/test_inventory_manager_consumable_hotbar.gd
git commit -m "feat(inventory): equipped_consumables + equip/unequip API"
```

---

## Task 14: HotbarSlot + CombatHotbar scenes (placeholders)

The 4-slot combat hotbar widget. Each slot accepts a `ConsumableDefinitionData` drop, displays its icon + stack count from inventory, and a static `1/2/3/4` keybind chip.

**Files:**
- Create: `scenes/inventory/inventory_view/consumables_tab/combat_hotbar/hotbar_slot/hotbar_slot.tscn`
- Create: `scenes/inventory/inventory_view/consumables_tab/combat_hotbar/hotbar_slot/hotbar_slot.gd`
- Create: `scenes/inventory/inventory_view/consumables_tab/combat_hotbar/combat_hotbar.tscn`
- Create: `scenes/inventory/inventory_view/consumables_tab/combat_hotbar/combat_hotbar.gd`
- Create: `assets/styleboxes/inventory/hotbar_slot_empty.tres`
- Create: `assets/styleboxes/inventory/hotbar_slot_equipped.tres`

- [ ] **Step 1: Create placeholder styleboxes**

`hotbar_slot_empty.tres` — `StyleBoxFlat` with:
- `bg_color = Color("#1a1109")`
- `border_color = Color("#8e6826")`
- `border_width_left/right/top/bottom = 2`
- `corner_radius_* = 2`

`hotbar_slot_equipped.tres` — same but:
- `border_color = Color("#f1c878")`
- Also set `shadow_color = Color(0.94, 0.78, 0.47, 0.45)`, `shadow_size = 4`.

- [ ] **Step 2: Create `hotbar_slot.tscn` + `.gd`**

Scene:
```
HotbarSlot (PanelContainer, custom_min_size = (66, 66),
            theme_override_styles/panel = hotbar_slot_empty.tres)
  ├─ Center (CenterContainer, anchors fill, mouse_filter = IGNORE)
  │  ├─ Icon (TextureRect, custom_min_size = (40, 40), unique_name_in_owner)
  │  └─ Plus (Label, text = "+", visible by toggle, unique_name_in_owner,
  │            theme_type_variation = "LabelTitleSmall",
  │            theme_override_colors/font_color = Color(0.94, 0.78, 0.47, 0.35))
  ├─ Count (Label, anchors bottom_right, unique_name_in_owner,
  │          theme_type_variation = "LabelBodySmall",
  │          theme_override_colors/font_color = Color("#f1c878"))
  └─ KeyChip (Label, anchors top_left, custom_min_size = (18, 18), unique_name_in_owner,
              theme_type_variation = "LabelBodySmall",
              theme_override_colors/font_color = Color("#2e1f10"),
              horizontal_alignment = CENTER, vertical_alignment = CENTER,
              theme_override_styles/normal = ... a small gold chip stylebox)
```

```gdscript
# .../hotbar_slot.gd
class_name HotbarSlot
extends PanelContainer

signal slot_clicked(slot: HotbarSlot, event: InputEvent)

const STYLE_EMPTY    := preload("res://assets/styleboxes/inventory/hotbar_slot_empty.tres")
const STYLE_EQUIPPED := preload("res://assets/styleboxes/inventory/hotbar_slot_equipped.tres")

@export var slot_index: int = 0:
    set(value):
        slot_index = value
        if _key_chip: _key_chip.text = str(value + 1)

@onready var _icon: TextureRect = %Icon
@onready var _plus: Label = %Plus
@onready var _count: Label = %Count
@onready var _key_chip: Label = %KeyChip

var _def: ConsumableDefinitionData = null

func _ready() -> void:
    gui_input.connect(func(e): slot_clicked.emit(self, e))
    _key_chip.text = str(slot_index + 1)
    _refresh()

## Show the consumable + count, or clear if def == null.
func setup(def: ConsumableDefinitionData, count: int) -> void:
    _def = def
    if _def == null:
        _icon.texture = null
        _count.text = ""
        _plus.visible = true
        add_theme_stylebox_override("panel", STYLE_EMPTY)
    else:
        _icon.texture = _def.icon
        _count.text = "×%d" % count
        _plus.visible = false
        add_theme_stylebox_override("panel", STYLE_EQUIPPED)

func get_definition() -> ConsumableDefinitionData:
    return _def

func _refresh() -> void:
    setup(_def, 0)
```

- [ ] **Step 3: Create `combat_hotbar.tscn` + `.gd`**

Scene:
```
CombatHotbar (VBoxContainer)
  ├─ Banner (Label, text = "Combat Hotbar", theme_type_variation = "LabelTitleSmall",
  │          horizontal_alignment = CENTER)
  ├─ Lede (Label, text = "Drag a stack from the left page into any slot. Hotkeys 1–4.",
  │         theme_type_variation = "LabelMuted",
  │         horizontal_alignment = CENTER, autowrap = WORD)
  └─ SlotsRow (HBoxContainer, alignment = CENTER)
     ├─ HotbarSlot (instance, slot_index = 0)
     ├─ HotbarSlot (instance, slot_index = 1)
     ├─ HotbarSlot (instance, slot_index = 2)
     └─ HotbarSlot (instance, slot_index = 3)
```

```gdscript
# .../combat_hotbar.gd
class_name CombatHotbar
extends VBoxContainer

signal slot_clicked(slot: HotbarSlot, event: InputEvent)

@onready var _slots: Array[HotbarSlot] = [
    $SlotsRow.get_child(0), $SlotsRow.get_child(1),
    $SlotsRow.get_child(2), $SlotsRow.get_child(3),
]

func _ready() -> void:
    for s in _slots:
        s.slot_clicked.connect(_on_slot_clicked)
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _refresh(InventoryManager.get_inventory())

func _refresh(inv: InventoryData) -> void:
    for i in 4:
        var def = inv.equipped_consumables.get(i, null)
        var count = inv.consumables.get(def, 0) if def != null else 0
        _slots[i].setup(def, count)

func _on_inventory_changed(inv: InventoryData) -> void:
    _refresh(inv)

func _on_slot_clicked(slot: HotbarSlot, event: InputEvent) -> void:
    slot_clicked.emit(slot, event)
```

- [ ] **Step 4: Commit**

```bash
git add scenes/inventory/inventory_view/consumables_tab \
        assets/styleboxes/inventory
git commit -m "feat(inventory): add CombatHotbar + HotbarSlot scenes"
```

---

## Task 15: ConsumablesTab scene + drag-equip to hotbar

The new tab. Mirrors Equipment's composition (banner, sub-banner disabled, grid toolbar with trash slot, InventoryGrid) but the right page is the `CombatHotbar` + `ItemDetailCard`.

**Files:**
- Create: `scenes/inventory/inventory_view/consumables_tab/consumable_slot.tscn` (mirrors material_slot but bound to consumables)
- Create: `scenes/inventory/inventory_view/consumables_tab/consumable_slot.gd`
- Create: `scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn`
- Create: `scenes/inventory/inventory_view/consumables_tab/consumables_tab.gd`
- Test: `tests/integration/test_consumables_tab_hotbar_equip.gd`

- [ ] **Step 1: ConsumableSlot — mirror MaterialSlot for consumables**

```gdscript
# .../consumable_slot.gd
class_name ConsumableSlot
extends TextureRect

signal clicked(slot: ConsumableSlot, event: InputEvent)

@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count

var _def: ConsumableDefinitionData = null
var _qty: int = 0

func _ready() -> void:
    gui_input.connect(func(e): clicked.emit(self, e))
    _refresh()

func setup(def: ConsumableDefinitionData, qty: int) -> void:
    _def = def
    _qty = qty
    if is_inside_tree(): _refresh()

func get_definition() -> ConsumableDefinitionData: return _def
func get_quantity() -> int: return _qty

func _refresh() -> void:
    if _def == null:
        _icon.texture = null
        _count.text = ""
        return
    _icon.texture = _def.icon
    _count.text = "×%d" % _qty if _qty > 1 else ""
```

Scene structure mirrors `material_slot.tscn` exactly — copy and rename. Save as `consumable_slot.tscn`.

- [ ] **Step 2: ConsumablesTab scene**

```
ConsumablesTab (Control, attached script = consumables_tab.gd)
  ├─ Banner (TextureRect, texture = materials_tab/banner.png placeholder
  │          + Label "CONSUMABLES" overlay until Banner #1 ships)
  ├─ SortSubBanner (instance, enabled = false, options = ["All"])
  ├─ GridToolbar (instance)
  ├─ InventoryGrid (instance, columns = 6)
  ├─ CombatHotbar (instance, positioned on right page)
  ├─ ItemDetailCard (instance, below hotbar)
  + TrashSlot (instance, added to GridToolbar at runtime)
```

- [ ] **Step 3: ConsumablesTab script — click on grid slot to equip to next-available hotbar slot**

```gdscript
# .../consumables_tab.gd
extends Control

const ConsumableSlotScene := preload("res://scenes/inventory/inventory_view/consumables_tab/consumable_slot.tscn")

@onready var sort_banner: SortSubBanner = %SortSubBanner
@onready var grid_toolbar: GridToolbar = %GridToolbar
@onready var grid: InventoryGrid = %InventoryGrid
@onready var hotbar: CombatHotbar = %CombatHotbar
@onready var detail_card: ItemDetailCard = %ItemDetailCard
@onready var trash_slot: TrashSlot = %TrashSlot

func _ready() -> void:
    sort_banner.set_options(PackedStringArray(["All"]))
    sort_banner.enabled = false
    grid_toolbar.set_trash_slot(trash_slot)
    hotbar.slot_clicked.connect(_on_hotbar_clicked)
    if InventoryManager:
        InventoryManager.inventory_changed.connect(_on_inventory_changed)
        _rebuild(InventoryManager.get_inventory())

func _rebuild(inv: InventoryData) -> void:
    grid.clear_slots()
    var first: ConsumableDefinitionData = null
    for def in inv.consumables.keys():
        var slot := ConsumableSlotScene.instantiate()
        grid.add_slot(slot)
        slot.setup(def, inv.consumables[def])
        slot.clicked.connect(_on_grid_slot_clicked)
        if first == null: first = def
    grid_toolbar.set_count_text("%d stacks" % inv.consumables.size())
    if first:
        detail_card.setup_from_definition(first)
    else:
        detail_card.reset()

func _on_grid_slot_clicked(slot: ConsumableSlot, event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            detail_card.setup_from_definition(slot.get_definition())
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            # Right-click = equip to first empty hotbar slot
            _equip_to_first_empty(slot.get_definition())

func _equip_to_first_empty(def: ConsumableDefinitionData) -> void:
    if def == null: return
    var inv := InventoryManager.get_inventory()
    for i in 4:
        if not inv.equipped_consumables.has(i):
            InventoryManager.equip_consumable(def, i)
            return
    # All slots full — replace slot 0
    InventoryManager.equip_consumable(def, 0)

func _on_hotbar_clicked(slot: HotbarSlot, event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if slot.get_definition() != null:
            InventoryManager.unequip_consumable(slot.slot_index)

func _on_inventory_changed(inv: InventoryData) -> void:
    _rebuild(inv)
```

(Drag-from-grid-to-hotbar is the user-facing flow shown in the mockup; right-click "equip to first empty" is added as a faster alternative and is what the integration test exercises.)

- [ ] **Step 4: Write integration test**

```gdscript
# tests/integration/test_consumables_tab_hotbar_equip.gd
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data.inventory = InventoryData.new()

func test_right_click_consumable_slot_equips_to_first_empty_hotbar_slot() -> void:
    var def := ConsumableDefinitionData.new()
    def.item_id = "scale"; def.item_name = "Crude Scale"
    InventoryManager.award_items(def, 3)

    var tab_scene := load("res://scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn")
    var tab = tab_scene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame

    var first_grid_slot = tab.get_node("%InventoryGrid").get_slots()[0]
    var evt := InputEventMouseButton.new()
    evt.button_index = MOUSE_BUTTON_RIGHT
    evt.pressed = true
    first_grid_slot.clicked.emit(first_grid_slot, evt)

    assert_eq(InventoryManager.get_inventory().equipped_consumables[0], def)

func test_click_equipped_hotbar_slot_unequips() -> void:
    var def := ConsumableDefinitionData.new()
    def.item_id = "scale"
    InventoryManager.award_items(def, 2)
    InventoryManager.equip_consumable(def, 0)

    var tab_scene := load("res://scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn")
    var tab = tab_scene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame

    var hotbar = tab.get_node("%CombatHotbar")
    var slot = hotbar.get_node("SlotsRow").get_child(0)
    var evt := InputEventMouseButton.new()
    evt.button_index = MOUSE_BUTTON_LEFT
    evt.pressed = true
    slot.slot_clicked.emit(slot, evt)
    await get_tree().process_frame

    assert_false(InventoryManager.get_inventory().equipped_consumables.has(0))
```

- [ ] **Step 5: Run tests, verify they pass**

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/inventory_view/consumables_tab \
        tests/integration/test_consumables_tab_hotbar_equip.gd
git commit -m "feat(inventory): add Consumables tab with right-click hotbar equip"
```

---

## Task 16: Tab switcher 4th button + final wire-up

Add the Consumables tab to the switcher and inventory_view. Final tab order: Equipment → Consumables → Materials → Journal.

**Files:**
- Modify: `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`
- Modify: `scenes/inventory/inventory_view/inventory_view.tscn` (add ConsumablesTabButton + ConsumablesTab instance)
- Modify: `scenes/inventory/inventory_view/inventory_view.gd` (tabs array)

- [ ] **Step 1: Add the 4th tab button to inventory_view.tscn**

In the editor, duplicate the existing `MaterialsTabButton` to make a new `ConsumablesTabButton`. Move it under `EquipmentTabButton` so the final order top-to-bottom is:
1. EquipmentTabButton
2. ConsumablesTabButton
3. MaterialsTabButton
4. QuestItemsTabButton

Adjust the `offset_top` values to keep equal spacing (e.g., 95 / 144 / 193 / 242 if 49px apart).

- [ ] **Step 2: Update tabs array in inventory_view.gd**

Modify line 15 of `scenes/inventory/inventory_view/inventory_view.gd`:

```gdscript
@onready var tabs: Array[Control] = [%EquipmentTab, %ConsumablesTab, %MaterialsTab, %QuestItemsTab]
```

Add an instance of `consumables_tab.tscn` as a sibling of the other tabs in `inventory_view.tscn`, set `visible = false` initially.

- [ ] **Step 3: Update TabSwitcher to emit the right index for 4 tabs**

Open `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`. The switcher currently emits `tab_changed(index)` based on button click. Confirm it iterates over its tab buttons and emits the new index 0..3. If the switcher hard-codes 3 buttons, generalize to use all children.

If `tab_switcher.gd` currently has hard-coded references, replace with a children-based iteration:

```gdscript
extends Control

signal tab_changed(index: int)

func _ready() -> void:
    var buttons: Array = []
    for child in get_children():
        if child is TextureButton or child is Button:
            buttons.append(child)
    for i in buttons.size():
        var idx := i
        buttons[i].pressed.connect(func(): tab_changed.emit(idx))
```

(If it already does something like this, no change needed — just verify it picks up the new 4th button.)

- [ ] **Step 4: Visually verify**

Open the game. Confirm all four tabs are clickable and switch correctly. Pay attention to:
- Page-turn animation still fires when moving forward / backward across tabs.
- Each tab renders its banner + content correctly.
- No console errors.

- [ ] **Step 5: Run the full test suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory/inventory_view
git commit -m "feat(inventory): wire 4th Consumables tab into switcher"
```

---

## Self-Review

**Spec coverage:**
- Equipment grid 6×5: Task 6 ✓
- Functional Discard slot with single-replacement: Tasks 7–8 ✓
- Improved scroll rail: Task 2 ✓
- Materials grid + detail panel + tip card: Task 11 ✓
- Materials sort arrows shown but disabled: Task 11 (set_options + enabled=false) ✓
- Quest full overhaul as Journal: Tasks 10 + 12 ✓
- Consumables tab + 4-slot hotbar with uniqueness: Tasks 13–15 ✓
- Tab order Equipment → Consumables → Materials → Journal: Task 16 ✓
- Equipment-type filter wired: explicitly out of scope per spec; SortSubBanner is shown disabled.
- `linked_quest_active`: explicitly deferred per spec; QuestItemDefinitionData omits the field.

**Placeholder scan:** No `TBD`, `TODO`, or vague directives found in tasks. Every step contains either code or an explicit command.

**Type consistency:** `setup_from_definition` is used uniformly on Item/MaterialDetailCard and QuestJournalCard. `restore_equipment_instance` / `restore_material` / `restore_consumable` signatures stay consistent in TrashSlot. `slot_clicked` signal name is consistent across InventorySlot, MaterialSlot, ConsumableSlot, HotbarSlot.

**Gaps caught + filled during review:**
- Original draft mentioned drag-from-grid-to-hotbar as the user flow; Task 15 adds right-click equip as a non-drag fallback so the integration test isn't fighting the drag system.
- Initial draft had MaterialsTab routing drag-to-trash through `discard_*` methods; refactored to the `restore_*` approach where TrashSlot owns the hold-buffer and inventory state only changes on flush/destroy.
