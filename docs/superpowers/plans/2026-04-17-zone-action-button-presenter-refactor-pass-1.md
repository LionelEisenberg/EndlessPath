# ZoneActionButton Presenter Refactor — Pass 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract type-specific logic out of `scenes/zones/zone_action_button/zone_action_button.gd` into per-type presenter scenes, using a shared abstract base class, with zero behavior change for the four existing action types (Forage, Adventure, Cycling, NPC Dialogue).

**Architecture:** Abstract base class `ZoneActionPresenter` extends `Node`. Button scene gains three named slots (`OverlaySlot`, `InlineSlot`, `FooterSlot`). A `PRESENTER_SCENES: Dictionary` on the button maps `ZoneActionData.ActionType` to presenter scene. On `_ready` the button instantiates the right presenter, hands it references to the three slots, and forwards lifecycle calls (`set_is_current`, `can_activate`, `on_activation_rejected`). Each presenter reparents its own pre-authored content into whichever slots it wants to fill.

**Tech Stack:** Godot 4.5 / GDScript, `@abstract` annotations (already used on `EffectData`), Godot `Node.reparent()`, existing `action_card_sweep.gdshader`.

**Spec:** [docs/superpowers/specs/2026-04-17-zone-action-button-presenter-refactor-design.md](../specs/2026-04-17-zone-action-button-presenter-refactor-design.md)

---

## File Structure

| File | Role | Pass |
|---|---|---|
| `scripts/ui/zone_action_presenter.gd` | Abstract base class. Defines `setup()` / `teardown()` / lifecycle hooks. | Create |
| `scenes/zones/zone_action_button/presenters/default_presenter.tscn` + `.gd` | No-op presenter for action types that need no extra UI (Cycling, NPC Dialogue). | Create |
| `scenes/zones/zone_action_button/presenters/foraging_presenter.tscn` + `.gd` | Owns sweep `ColorRect` + foraging floating-text spawn. Subscribes to `ActionManager.foraging_completed`. | Create |
| `scenes/zones/zone_action_button/presenters/adventure_presenter.tscn` + `.gd` | Owns Madra badge + shake + affordability gating. Subscribes to `ResourceManager.madra_changed`. | Create |
| `scenes/zones/zone_action_button/zone_action_button.tscn` | Scene layout — remove `ProgressFill` + `MadraBadgeContainer`, add `OverlaySlot` + `InlineSlot` + `FooterSlot`. | Modify |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Strip type-specific code. Own card styling, click routing, presenter factory, slot wiring, `get_madra_target_global_position` helper. | Modify |

No test files are created or modified in Pass 1. The button scene has no pre-existing GUT coverage — it's a view component with deep coupling to `ActionManager` / `ResourceManager` / live save data, and validating the refactor manually by running the game is the cheaper, more informative path. Verification is done by running the game against zones that exercise all four action types.

---

## Testing Commands

**Run the game from CLI:**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

**Run GUT regression (ensure nothing else broke):**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all tests pass, including `tests/integration/test_training_flow.gd` and `tests/unit/test_zone_progression_data.gd`.

---

## Task 1: Create `ZoneActionPresenter` abstract base

**Files:**
- Create: `scripts/ui/zone_action_presenter.gd`

- [ ] **Step 1: Confirm the `scripts/ui/` directory exists**

```bash
ls scripts/ui 2>/dev/null || mkdir -p scripts/ui
```

- [ ] **Step 2: Create the abstract base file**

Write `scripts/ui/zone_action_presenter.gd` with:

```gdscript
@abstract class_name ZoneActionPresenter
extends Node
## Base class for ZoneActionButton presenters. A presenter owns the type-specific
## visual content and behavior for one ZoneActionData subtype, while the button
## owns the shell (card styling, click routing, hover feedback, slot layout).
##
## A presenter is a utility Node — its scene root has no layout. The presenter's
## visible children get reparented into the button's slots on setup().

var action_data: ZoneActionData
var button: Control

#-----------------------------------------------------------------------------
# ABSTRACT
#-----------------------------------------------------------------------------

## Called when the button's action_data is assigned. The presenter should:
##   1. Store references (action_data, button, slots it cares about)
##   2. Reparent its own child content into the appropriate slots
##   3. Connect to any game-state signals it needs
@abstract
func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, inline_slot: Control, footer_slot: Control) -> void

## Called from the button's _exit_tree. The presenter should disconnect signals
## and kill any running tweens.
@abstract
func teardown() -> void

#-----------------------------------------------------------------------------
# LIFECYCLE HOOKS (safe defaults, subclasses override as needed)
#-----------------------------------------------------------------------------

## Called when the button's is_current_action flips. Default: no-op.
func set_is_current(_is_current: bool) -> void:
	pass

## Gate for click activation. Return false to veto activation (e.g. adventure
## with insufficient Madra). Default: always allow.
func can_activate() -> bool:
	return true

## Called when can_activate() returned false. Default: no-op.
func on_activation_rejected() -> void:
	pass
```

- [ ] **Step 3: Verify the file parses**

Open the Godot editor:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" project.godot
```
Open `scripts/ui/zone_action_presenter.gd` in the editor. Confirm no parse errors show in the Output panel.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/zone_action_presenter.gd
git commit -m "feat(ui): add ZoneActionPresenter abstract base class"
```

---

## Task 2: Create `DefaultPresenter` (no-op) scene + script

**Files:**
- Create: `scenes/zones/zone_action_button/presenters/default_presenter.gd`
- Create: `scenes/zones/zone_action_button/presenters/default_presenter.tscn`

- [ ] **Step 1: Confirm the target directory exists**

```bash
mkdir -p scenes/zones/zone_action_button/presenters
```

- [ ] **Step 2: Write the script**

Create `scenes/zones/zone_action_button/presenters/default_presenter.gd`:

```gdscript
class_name DefaultZoneActionPresenter
extends ZoneActionPresenter
## Presenter for action types that need no extra UI beyond the card's name+description.
## Used for CYCLING and NPC_DIALOGUE.

func setup(data: ZoneActionData, owner_button: Control, _overlay_slot: Control, _inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button

func teardown() -> void:
	pass
```

- [ ] **Step 3: Create the scene**

Create `scenes/zones/zone_action_button/presenters/default_presenter.tscn` as a single-node scene with:
- Root node: `Node` named `DefaultPresenter`
- Script: `res://scenes/zones/zone_action_button/presenters/default_presenter.gd`

Paste this into the `.tscn` file:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/zones/zone_action_button/presenters/default_presenter.gd" id="1_default"]

[node name="DefaultPresenter" type="Node"]
script = ExtResource("1_default")
```

- [ ] **Step 4: Verify in editor**

Open `default_presenter.tscn` in the Godot editor. Confirm the scene loads with no errors and the script attaches.

- [ ] **Step 5: Commit**

```bash
git add scenes/zones/zone_action_button/presenters/default_presenter.gd scenes/zones/zone_action_button/presenters/default_presenter.tscn
git commit -m "feat(ui): add DefaultZoneActionPresenter no-op presenter"
```

---

## Task 3: Rework `zone_action_button.tscn` scene layout

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.tscn`

This task modifies the scene only — the script still references the old node names, so the scene will temporarily be broken between Task 3 and Task 4. Don't run the game between them; commit them together with Task 4 if you prefer.

- [ ] **Step 1: Open the scene**

Open `scenes/zones/zone_action_button/zone_action_button.tscn` in the Godot editor.

- [ ] **Step 2: Delete `ProgressFill`**

In the Scene panel, select `ActionCard/ProgressFill` and delete it (it moves to the ForagingPresenter in Task 5).

- [ ] **Step 3: Delete `MadraBadgeContainer`**

Select `ActionCard/ContentMargin/HBoxContainer/MadraBadgeContainer` (including its `MadraBadge` and `MadraIcon` children) and delete it (moves to AdventurePresenter in Task 6).

- [ ] **Step 4: Add `OverlaySlot`**

Add a `Control` node as the first child of `ActionCard` (above `ContentMargin`), named `OverlaySlot`:
- Set `layout_mode = 1` (anchors) and set anchors preset to "Full Rect" (anchor_right = 1.0, anchor_bottom = 1.0)
- Set `mouse_filter = 2` (Ignore)
- Mark `unique_name_in_owner = true`

- [ ] **Step 5: Restructure the content row into a VBoxContainer**

Inside `ContentMargin`, the current structure is `HBoxContainer` with `TextSection` + `MadraBadgeContainer`. Replace with (slot types chosen so reparented content auto-sizes without manual anchor math):

- Parent: `VBoxContainer` (replaces current `HBoxContainer` as the direct child of `ContentMargin`)
  - `HBoxContainer` child (new, named `TopRow`, `theme_override_constants/separation = 8`)
    - `TextSection` (move existing VBoxContainer here, keep `size_flags_horizontal = 3`)
    - `InlineSlot` (new **`HBoxContainer`** — auto-sizes to its children; `mouse_filter = 2`, `unique_name_in_owner = true`, `size_flags_horizontal = 8` [Shrink End], `size_flags_vertical = 4` [Shrink Center], `alignment = 2` [End])
  - `FooterSlot` (new **`VBoxContainer`** — children stack vertically and stretch horizontally; `mouse_filter = 2`, `unique_name_in_owner = true`, `size_flags_horizontal = 3` [Fill + Expand])

- [ ] **Step 6: Verify the scene**

Save the scene. Open `scenes/main/main_game/main_game.tscn`. Expect no scene-load errors in the Output panel. The button will look empty (no sweep, no badge, no nodes in the slots) — this is intended until Task 4.

Do **not** commit yet — commit together with Task 4.

---

## Task 4: Rewrite `zone_action_button.gd` as type-agnostic shell

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd`

- [ ] **Step 1: Replace the entire file contents**

Overwrite `scenes/zones/zone_action_button/zone_action_button.gd` with:

```gdscript
extends MarginContainer
## Action card button for zone actions.
## Owns card styling, click routing, and the three slots (OverlaySlot / InlineSlot /
## FooterSlot). Type-specific visuals live in per-type presenter scenes plugged in
## via PRESENTER_SCENES, selected on _ready() by action_data.action_type.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")
const CARD_SELECTED: StyleBox = preload("res://assets/styleboxes/zones/action_card_selected.tres")
const DIMMED_MODULATE: Color = Color(0.55, 0.55, 0.55, 1.0)
const NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)

## Maps active ActionTypes to their category color. Unmapped types fall back to
## DEFAULT_CATEGORY_COLOR.
const CATEGORY_COLORS: Dictionary = {
	ZoneActionData.ActionType.FORAGE: Color(0.42, 0.67, 0.37),
	ZoneActionData.ActionType.CYCLING: Color(0.37, 0.66, 0.62),
	ZoneActionData.ActionType.ADVENTURE: Color(0.61, 0.25, 0.25),
	ZoneActionData.ActionType.NPC_DIALOGUE: Color(0.83, 0.66, 0.29),
}
const DEFAULT_CATEGORY_COLOR: Color = Color(0.5, 0.5, 0.5)

## Maps ActionType to presenter scene. Types not listed here fall back to DEFAULT_PRESENTER_SCENE.
const DEFAULT_PRESENTER_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn")
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
}

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()
		if _presenter:
			_presenter.set_is_current(is_current_action)

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: RichTextLabel = %ActionDescLabel
@onready var _overlay_slot: Control = %OverlaySlot
@onready var _inline_slot: Control = %InlineSlot
@onready var _footer_slot: Control = %FooterSlot

var _presenter: ZoneActionPresenter = null
var _cached_selected_style: StyleBoxFlat = null
var _zone_resource_panel: ZoneResourcePanel = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	_action_card.mouse_entered.connect(_on_mouse_entered)
	_action_card.mouse_exited.connect(_on_mouse_exited)
	_action_card.gui_input.connect(_on_card_input)

	_zone_resource_panel = get_tree().current_scene.find_child("ZoneResourcePanel", true, false) as ZoneResourcePanel

	if action_data:
		_setup_labels()
		_spawn_presenter()

	if ActionManager.get_current_action() == action_data:
		is_current_action = true

func _exit_tree() -> void:
	if ActionManager.current_action_changed.is_connected(_on_current_action_changed):
		ActionManager.current_action_changed.disconnect(_on_current_action_changed)
	if _presenter:
		_presenter.teardown()

## Sets up the card with action data.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_instance_valid(_action_name_label):
		_setup_labels()
	if is_instance_valid(_overlay_slot):
		_spawn_presenter()

#-----------------------------------------------------------------------------
# PUBLIC API (called by presenters)
#-----------------------------------------------------------------------------

## Returns the color bucket for this action's type. Presenters use it for tinting.
func get_category_color() -> Color:
	if action_data == null:
		return DEFAULT_CATEGORY_COLOR
	return CATEGORY_COLORS.get(action_data.action_type, DEFAULT_CATEGORY_COLOR)

## Returns the global position of the Madra orb on the zone resource panel,
## or Vector2.ZERO if the panel couldn't be located.
func get_madra_target_global_position() -> Vector2:
	if _zone_resource_panel:
		return _zone_resource_panel.get_madra_orb_global_position()
	return Vector2.ZERO

## Dim the name+description labels (used by AdventurePresenter when unaffordable).
func set_text_dimmed(dimmed: bool) -> void:
	var modulate_color: Color = DIMMED_MODULATE if dimmed else NORMAL_MODULATE
	if is_instance_valid(_action_name_label):
		_action_name_label.modulate = modulate_color
	if is_instance_valid(_action_desc_label):
		_action_desc_label.modulate = modulate_color

## The card's global rect, used by presenters that need spawn positions.
func get_action_card() -> PanelContainer:
	return _action_card

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _spawn_presenter() -> void:
	if _presenter:
		_presenter.teardown()
		_presenter.queue_free()
		_presenter = null

	var scene: PackedScene = PRESENTER_SCENES.get(action_data.action_type, DEFAULT_PRESENTER_SCENE) as PackedScene
	if scene == null:
		Log.error("ZoneActionButton: no presenter scene for action_type %s" % action_data.action_type)
		return
	_presenter = scene.instantiate() as ZoneActionPresenter
	add_child(_presenter)
	_presenter.setup(action_data, self, _overlay_slot, _inline_slot, _footer_slot)

func _setup_labels() -> void:
	_action_name_label.text = action_data.action_name
	if action_data.description != "":
		_action_desc_label.text = action_data.description
		_action_desc_label.visible = true
	else:
		_action_desc_label.text = ""
		_action_desc_label.visible = false

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_current_action:
			return
		if _presenter and not _presenter.can_activate():
			_presenter.on_activation_rejected()
			return
		ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	var can_hover: bool = _presenter == null or _presenter.can_activate()
	if not is_current_action and can_hover:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)

func _on_mouse_exited() -> void:
	_update_card_style()

func _update_card_style() -> void:
	if is_current_action:
		if _cached_selected_style == null:
			_cached_selected_style = CARD_SELECTED.duplicate() as StyleBoxFlat
		var cat_color: Color = get_category_color()
		_cached_selected_style.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.4)
		_action_card.add_theme_stylebox_override("panel", _cached_selected_style)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	is_current_action = ActionManager.get_current_action() == action_data
```

- [ ] **Step 2: Launch the game**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

- [ ] **Step 3: Visually verify the button works for Cycling + NPC Dialogue types**

Navigate to a zone that has both a Cycling and an NPC Dialogue action. Expected:
- Button renders with name + description
- Hover shows hover style
- Click selects the action (confirm in the log window)
- Selecting the action shows the "selected" border style
- No sweep (foraging-specific), no Madra badge (adventure-specific) — that's expected

The Foraging + Adventure buttons will be missing their sweep / badge too — this is intended until Task 5 and Task 6.

- [ ] **Step 4: Commit scene + script together**

```bash
git add scenes/zones/zone_action_button/zone_action_button.tscn scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "refactor(ui): split ZoneActionButton into shell + presenter slots"
```

---

## Task 5: Create `ForagingPresenter`

**Files:**
- Create: `scenes/zones/zone_action_button/presenters/foraging_presenter.gd`
- Create: `scenes/zones/zone_action_button/presenters/foraging_presenter.tscn`
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd` (add FORAGE entry)

- [ ] **Step 1: Write the presenter script**

Create `scenes/zones/zone_action_button/presenters/foraging_presenter.gd`:

```gdscript
class_name ForagingPresenter
extends ZoneActionPresenter
## Presenter for FORAGE actions. Owns the sweep ColorRect (action_card_sweep shader)
## and spawns floating text for rolled loot on foraging_completed.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")
const FLOATING_TEXT_TRAJECTORY: Vector2 = Vector2(-200, -40)
const FLOATING_TEXT_COLOR: Color = Color(0.75, 0.92, 0.65)
const FILL_TINT_OPACITY: float = 0.45
const SWEEP_RESET_DURATION: float = 0.3
const SWEEP_FADE_IN_DURATION: float = 0.1

@onready var _progress_fill: ColorRect = %ProgressFill

var _sweep_tween: Tween = null
var _is_tracking_timer: bool = false

func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, _inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button
	_progress_fill.reparent(overlay_slot)
	_progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_fill_color(button.get_category_color())
	_set_fill_amount(0.0)
	ActionManager.foraging_completed.connect(_on_foraging_completed)

func teardown() -> void:
	if ActionManager.foraging_completed.is_connected(_on_foraging_completed):
		ActionManager.foraging_completed.disconnect(_on_foraging_completed)
	_kill_sweep_tween()

func set_is_current(is_current: bool) -> void:
	if is_current:
		_start_sweep()
	else:
		_stop_sweep()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _is_tracking_timer:
		var timer: Timer = ActionManager.action_timer
		if timer.wait_time > 0.0 and not timer.is_stopped():
			var progress: float = 1.0 - (timer.time_left / timer.wait_time)
			_set_fill_amount(progress)

func _set_fill_amount(amount: float) -> void:
	if is_instance_valid(_progress_fill) and _progress_fill.material:
		_progress_fill.material.set_shader_parameter("fill_amount", amount)

func _set_fill_color(cat_color: Color) -> void:
	if is_instance_valid(_progress_fill):
		_progress_fill.color = Color(cat_color, FILL_TINT_OPACITY)

func _kill_sweep_tween() -> void:
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	_sweep_tween = null

func _start_sweep() -> void:
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	_is_tracking_timer = true

func _reset_and_restart_sweep() -> void:
	_is_tracking_timer = false
	_set_fill_amount(1.0)
	_kill_sweep_tween()
	_sweep_tween = create_tween()
	var cat_color: Color = button.get_category_color()
	var flash: Color = Color(cat_color.r * 1.5, cat_color.g * 3.0, cat_color.b * 1.5, 1.0)
	_sweep_tween.tween_property(_progress_fill, "self_modulate", flash, 0.1).set_ease(Tween.EASE_OUT)
	_sweep_tween.tween_property(_progress_fill, "self_modulate:a", 0.0, SWEEP_RESET_DURATION).set_ease(Tween.EASE_OUT)
	_sweep_tween.tween_callback(func() -> void:
		_progress_fill.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		_is_tracking_timer = true
	)
	_sweep_tween.tween_property(_progress_fill, "self_modulate:a", 1.0, SWEEP_FADE_IN_DURATION)

func _stop_sweep() -> void:
	_is_tracking_timer = false
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	if is_instance_valid(_progress_fill):
		_progress_fill.self_modulate.a = 1.0

func _on_foraging_completed(items: Dictionary) -> void:
	if action_data != ActionManager.get_current_action():
		return
	_reset_and_restart_sweep()
	_spawn_floating_text(items)

func _spawn_floating_text(items: Dictionary) -> void:
	if items.is_empty():
		return
	var text_parts: Array[String] = []
	for item in items:
		var quantity: int = items[item]
		text_parts.append("+%d %s" % [quantity, item.item_name])
	var full_text: String = ", ".join(text_parts)
	var floating_text: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	get_tree().current_scene.add_child(floating_text)
	var spawn_pos: Vector2 = button.get_action_card().global_position + Vector2(-150, 20)
	floating_text.show_text(full_text, FLOATING_TEXT_COLOR, spawn_pos, FLOATING_TEXT_TRAJECTORY)
```

- [ ] **Step 2: Create the scene**

Create `scenes/zones/zone_action_button/presenters/foraging_presenter.tscn` with these contents:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/zones/zone_action_button/presenters/foraging_presenter.gd" id="1_forage"]
[ext_resource type="Shader" uid="uid://action_card_sweep_shader" path="res://assets/shaders/action_card_sweep.gdshader" id="2_sweep"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_sweep"]
resource_local_to_scene = true
shader = ExtResource("2_sweep")
shader_parameter/fill_amount = 0.0

[node name="ForagingPresenter" type="Node"]
script = ExtResource("1_forage")

[node name="ProgressFill" type="ColorRect" parent="."]
unique_name_in_owner = true
anchor_right = 1.0
anchor_bottom = 1.0
material = SubResource("ShaderMaterial_sweep")
mouse_filter = 2
color = Color(0.42, 0.67, 0.37, 0.45)
```

- [ ] **Step 3: Register FORAGE in the presenter factory**

In `scenes/zones/zone_action_button/zone_action_button.gd`, update the `PRESENTER_SCENES` dict to add the FORAGE entry:

```gdscript
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
}
```

- [ ] **Step 4: Launch the game and verify**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Navigate to a zone with a Forage action. Click it to select. Expected:
- The sweep overlay progresses from left to right at the foraging interval
- On each completion, floating text appears ("+1 Wooden Branch" etc.) and the sweep flash/fade/restart plays
- Selecting a different action stops the sweep
- Returning to the forage action restarts the sweep from 0

- [ ] **Step 5: Commit**

```bash
git add scenes/zones/zone_action_button/presenters/foraging_presenter.gd scenes/zones/zone_action_button/presenters/foraging_presenter.tscn scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "feat(ui): extract ForagingPresenter for FORAGE action type"
```

---

## Task 6: Create `AdventurePresenter`

**Files:**
- Create: `scenes/zones/zone_action_button/presenters/adventure_presenter.gd`
- Create: `scenes/zones/zone_action_button/presenters/adventure_presenter.tscn`
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd` (add ADVENTURE entry)

- [ ] **Step 1: Write the presenter script**

Create `scenes/zones/zone_action_button/presenters/adventure_presenter.gd`:

```gdscript
class_name AdventurePresenter
extends ZoneActionPresenter
## Presenter for ADVENTURE actions. Owns the Madra badge (current / threshold or
## current / capacity) and the shake-reject animation. Gates activation on
## ResourceManager.can_start_adventure().

@onready var _madra_badge_container: HBoxContainer = %MadraBadgeContainer
@onready var _madra_badge: RichTextLabel = %MadraBadge

var _is_affordable: bool = true

func setup(data: ZoneActionData, owner_button: Control, _overlay_slot: Control, inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button
	_madra_badge_container.reparent(inline_slot)
	_madra_badge_container.visible = true
	ResourceManager.madra_changed.connect(_on_madra_changed)
	_update_state()

func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_madra_changed):
		ResourceManager.madra_changed.disconnect(_on_madra_changed)

func can_activate() -> bool:
	return _is_affordable

func on_activation_rejected() -> void:
	_shake_reject()
	if LogManager:
		var threshold: float = ResourceManager.get_adventure_madra_threshold()
		var current: float = ResourceManager.get_madra()
		LogManager.log_message("[color=red]Not enough Madra! Need %.0f, have %.0f[/color]" % [threshold, current])

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _update_state() -> void:
	_is_affordable = ResourceManager.can_start_adventure()
	_update_madra_badge()
	button.set_text_dimmed(not _is_affordable)

func _update_madra_badge() -> void:
	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var current: float = ResourceManager.get_madra()
	var capacity: float = ResourceManager.get_adventure_madra_capacity()
	if current >= threshold:
		_madra_badge.text = "[right][font_size=20][color=#D4A84A]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, capacity]
	else:
		_madra_badge.text = "[right][font_size=20][color=#E06060]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, threshold]

func _on_madra_changed(_amount: float) -> void:
	_update_state()

func _shake_reject() -> void:
	_madra_badge_container.pivot_offset = _madra_badge_container.size * 0.5
	var tween: Tween = create_tween()
	var original_pos: Vector2 = _madra_badge_container.position
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.10, 1.10), 0.05)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-2, 0), 0.03)
	tween.tween_property(_madra_badge_container, "position", original_pos, 0.05)
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.0, 1.0), 0.1)
```

- [ ] **Step 2: Create the scene**

Create `scenes/zones/zone_action_button/presenters/adventure_presenter.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/zones/zone_action_button/presenters/adventure_presenter.gd" id="1_adv"]
[ext_resource type="Texture2D" uid="uid://b33dvnifjhgr7" path="res://assets/sprites/ui/resources/madra_icon.png" id="2_madra_icon"]

[node name="AdventurePresenter" type="Node"]
script = ExtResource("1_adv")

[node name="MadraBadgeContainer" type="HBoxContainer" parent="."]
unique_name_in_owner = true
size_flags_horizontal = 8
size_flags_vertical = 4
mouse_filter = 1
tooltip_text = "Madra Requirement"
theme_override_constants/separation = 4

[node name="MadraBadge" type="RichTextLabel" parent="MadraBadgeContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(70, 0)
layout_mode = 2
size_flags_vertical = 4
mouse_filter = 2
bbcode_enabled = true
fit_content = true
scroll_active = false

[node name="MadraIcon" type="TextureRect" parent="MadraBadgeContainer"]
custom_minimum_size = Vector2(20, 20)
layout_mode = 2
size_flags_vertical = 4
mouse_filter = 2
texture = ExtResource("2_madra_icon")
expand_mode = 3
stretch_mode = 5
```

- [ ] **Step 3: Register ADVENTURE in the presenter factory**

In `scenes/zones/zone_action_button/zone_action_button.gd`, update the `PRESENTER_SCENES` dict:

```gdscript
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
	ZoneActionData.ActionType.ADVENTURE: preload("res://scenes/zones/zone_action_button/presenters/adventure_presenter.tscn"),
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
}
```

- [ ] **Step 4: Launch and verify affordable case**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Navigate to a zone with an Adventure action. Cycle enough to have Madra ≥ threshold. Expected:
- Badge shows `<current> / <capacity>` in gold (#D4A84A)
- Action name + description show at normal brightness
- Clicking starts the adventure drain animation

- [ ] **Step 5: Verify unaffordable case**

From a fresh save (or by spending all Madra), confirm while Madra < threshold:
- Badge shows `<current> / <threshold>` in red (#E06060)
- Action name + description are dimmed
- Clicking triggers the shake animation + red log message, does not start the adventure

- [ ] **Step 6: Commit**

```bash
git add scenes/zones/zone_action_button/presenters/adventure_presenter.gd scenes/zones/zone_action_button/presenters/adventure_presenter.tscn scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "feat(ui): extract AdventurePresenter for ADVENTURE action type"
```

---

## Task 7: Full regression sweep

**Files:**
- None (verification only)

- [ ] **Step 1: Run GUT tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all existing tests pass. No new failures.

- [ ] **Step 2: Run the game and sanity-check every action type**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Visit zones with each of: Forage, Adventure, Cycling, NPC Dialogue. Confirm for each:
- Card renders with name + description
- Hover + selected border styling works
- Click-to-select works (with shake-reject for unaffordable adventure)
- No `CATEGORY_COLORS` fallback warnings in the Output panel
- `zone_action_button.gd` no longer contains any `action_data is X` or `action_type == X` checks (verify with `grep -n "action_type ==\|action_data is" scenes/zones/zone_action_button/zone_action_button.gd` → should return nothing)

- [ ] **Step 3: If all good, no commit required**

This task is verification only. If any regression is found, fix in-place and commit with message `fix(ui): <description>`.
