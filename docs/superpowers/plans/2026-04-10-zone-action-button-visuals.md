# Zone Action Button Visual Refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give zone action buttons a category-colored selected state and a left-to-right progress sweep for timed actions (foraging).

**Architecture:** A new sweep shader on a ColorRect inside the existing PanelContainer provides both the selected tint and the progress fill. The shader's `fill_amount` uniform is tweened from 0→1 over the foraging interval, creating a visual progress bar. For non-timed actions, fill is set to 1.0 instantly. A new selected stylebox handles the category-colored border treatment.

**Tech Stack:** Godot 4.5, GDScript, GLSL (canvas_item shader)

---

### Task 1: Create the sweep shader

**Files:**
- Create: `assets/shaders/action_card_sweep.gdshader`

- [ ] **Step 1: Create the shader file**

Create `assets/shaders/action_card_sweep.gdshader`:

```glsl
shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (UV.x < fill_amount) {
		COLOR = COLOR;
	} else {
		COLOR.a = 0.0;
	}
}
```

This keeps the ColorRect's assigned color where `UV.x < fill_amount` and makes everything else transparent. The ColorRect's own `color` property controls the tint hue; the shader just clips it horizontally.

- [ ] **Step 2: Commit**

```bash
git add assets/shaders/action_card_sweep.gdshader
git commit -m "feat(ui): add action card sweep shader for progress fill"
```

---

### Task 2: Create the selected stylebox

**Files:**
- Create: `assets/styleboxes/zones/action_card_selected.tres`

- [ ] **Step 1: Create the stylebox resource**

Create `assets/styleboxes/zones/action_card_selected.tres`:

```tres
[gd_resource type="StyleBoxFlat" format=3 uid="uid://action_card_selected_v1"]

[resource]
content_margin_left = 14.0
content_margin_top = 10.0
content_margin_right = 14.0
content_margin_bottom = 10.0
bg_color = Color(0.18, 0.19, 0.24, 0.8)
border_width_left = 3
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.42, 0.67, 0.37, 0.4)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2
```

Same margins, corner radius, and dark bg as `action_card_normal.tres`. The 3px left border and border color are the key differences — the color here is a default (forage green) that gets overridden programmatically per category in the script.

- [ ] **Step 2: Commit**

```bash
git add assets/styleboxes/zones/action_card_selected.tres
git commit -m "feat(ui): add selected stylebox for zone action cards"
```

---

### Task 3: Add ProgressFill node to the scene

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.tscn`

- [ ] **Step 1: Add the ColorRect with ShaderMaterial to the scene**

Edit `scenes/zones/zone_action_button/zone_action_button.tscn`.

Add ext_resources for the new shader and selected stylebox after the existing ext_resources:

```
[ext_resource type="Shader" uid="uid://action_card_sweep_shader" path="res://assets/shaders/action_card_sweep.gdshader" id="4_sweep_shader"]
[ext_resource type="StyleBox" path="res://assets/styleboxes/zones/action_card_selected.tres" id="5_card_selected"]
```

Add a sub_resource for the ShaderMaterial (after the ext_resources, before the first `[node]`):

```
[sub_resource type="ShaderMaterial" id="ShaderMaterial_sweep"]
resource_local_to_scene = true
shader = ExtResource("4_sweep_shader")
shader_parameter/fill_amount = 0.0
```

Add the ProgressFill ColorRect node as the first child of ActionCard (insert it before the HBoxContainer node):

```
[node name="ProgressFill" type="ColorRect" parent="ActionCard" unique_id=1234567890]
unique_name_in_owner = true
layout_mode = 2
material = SubResource("ShaderMaterial_sweep")
mouse_filter = 2
color = Color(0.42, 0.67, 0.37, 0.45)
```

Notes:
- `unique_name_in_owner = true` allows `%ProgressFill` access in the script
- `layout_mode = 2` (fill) lets PanelContainer size it to fill the card
- `mouse_filter = 2` (IGNORE) so it doesn't intercept clicks
- `material` uses the ShaderMaterial with `resource_local_to_scene = true` so each button instance gets its own fill_amount
- Default color is forage green at 45% opacity (overridden per category in script)

Also update the `load_steps` at the top of the file from `format=3` count — it should increase to account for the new sub_resource.

- [ ] **Step 2: Verify in editor**

Open the scene in Godot editor. Confirm:
- ProgressFill appears as a child of ActionCard, before HBoxContainer
- The ColorRect is invisible (fill_amount = 0.0)
- Selecting the ProgressFill in the inspector shows the ShaderMaterial with fill_amount

- [ ] **Step 3: Commit**

```bash
git add scenes/zones/zone_action_button/zone_action_button.tscn
git commit -m "feat(ui): add ProgressFill ColorRect node to zone action button scene"
```

---

### Task 4: Update script — category colors, selected state, and progress fill reference

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd`

- [ ] **Step 1: Add the new constants, onready reference, and category color mapping**

At the top of `zone_action_button.gd`, add the selected stylebox constant after the existing `CARD_HOVER` line:

```gdscript
const CARD_SELECTED: StyleBox = preload("res://assets/styleboxes/zones/action_card_selected.tres")
```

Add the category color mapping as a class constant after `NORMAL_MODULATE`:

```gdscript
const CATEGORY_COLORS: Dictionary = {
	ZoneActionData.ActionType.FORAGE: Color(0.42, 0.67, 0.37),
	ZoneActionData.ActionType.CYCLING: Color(0.37, 0.66, 0.62),
	ZoneActionData.ActionType.ADVENTURE: Color(0.61, 0.25, 0.25),
	ZoneActionData.ActionType.NPC_DIALOGUE: Color(0.83, 0.66, 0.29),
}
const DEFAULT_CATEGORY_COLOR: Color = Color(0.5, 0.5, 0.5)
const FILL_TINT_OPACITY: float = 0.45
const SWEEP_RESET_DURATION: float = 0.3
```

Add the onready reference after the existing `_madra_badge` line:

```gdscript
@onready var _progress_fill: ColorRect = %ProgressFill
```

Add a tween tracking variable after `_is_affordable`:

```gdscript
var _sweep_tween: Tween = null
```

- [ ] **Step 2: Add the category color helper**

Add a private helper function in the private functions section:

```gdscript
func _get_category_color() -> Color:
	if action_data == null:
		return DEFAULT_CATEGORY_COLOR
	return CATEGORY_COLORS.get(action_data.action_type, DEFAULT_CATEGORY_COLOR)
```

- [ ] **Step 3: Update `_update_card_style()` to use selected stylebox with category border**

Replace the existing `_update_card_style()` function:

```gdscript
func _update_card_style() -> void:
	if is_current_action:
		var selected_style: StyleBoxFlat = CARD_SELECTED.duplicate() as StyleBoxFlat
		var cat_color: Color = _get_category_color()
		selected_style.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.4)
		_action_card.add_theme_stylebox_override("panel", selected_style)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)
```

Note: The left border width (3px) is already set in the `.tres` file. Godot's `StyleBoxFlat.border_color` applies uniformly to all borders, but the thicker left border (3px vs 1px) makes it the dominant visual accent.

- [ ] **Step 4: Update hover to skip when selected**

The existing `_on_mouse_entered()` already checks `not is_current_action`, so hover won't override the selected state. No change needed — just confirm the logic is correct:

```gdscript
# Existing code — no changes needed, hover is already gated:
func _on_mouse_entered() -> void:
	if not is_current_action and _is_affordable:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)
```

- [ ] **Step 5: Commit**

```bash
git add scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "feat(ui): add category color mapping and selected stylebox to zone action button"
```

---

### Task 5: Update script — sweep tween logic and signal wiring

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd`

- [ ] **Step 1: Add the sweep control methods**

Add these private methods in the private functions section of `zone_action_button.gd`:

```gdscript
func _set_fill_amount(amount: float) -> void:
	if is_instance_valid(_progress_fill) and _progress_fill.material:
		_progress_fill.material.set_shader_parameter("fill_amount", amount)

func _set_fill_color(cat_color: Color) -> void:
	if is_instance_valid(_progress_fill):
		_progress_fill.color = Color(cat_color.r, cat_color.g, cat_color.b, FILL_TINT_OPACITY)

func _kill_sweep_tween() -> void:
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	_sweep_tween = null

func _start_sweep(duration: float) -> void:
	_kill_sweep_tween()
	_set_fill_amount(0.0)
	_sweep_tween = create_tween()
	_sweep_tween.tween_method(_set_fill_amount, 0.0, 1.0, duration)

func _reset_and_restart_sweep(duration: float) -> void:
	_kill_sweep_tween()
	_sweep_tween = create_tween()
	# Smooth reset from 1.0 to 0.0
	_sweep_tween.tween_method(_set_fill_amount, 1.0, 0.0, SWEEP_RESET_DURATION).set_ease(Tween.EASE_OUT)
	# Then fill again
	_sweep_tween.tween_method(_set_fill_amount, 0.0, 1.0, duration)

func _stop_sweep() -> void:
	_kill_sweep_tween()
	_set_fill_amount(0.0)
```

- [ ] **Step 2: Add the selection handler that starts sweep or sets static fill**

Add this method that orchestrates the fill behavior when selection changes:

```gdscript
func _update_progress_fill() -> void:
	if not is_instance_valid(_progress_fill):
		return

	if is_current_action and action_data:
		var cat_color: Color = _get_category_color()
		_set_fill_color(cat_color)

		if action_data is ForageActionData:
			var forage_data: ForageActionData = action_data as ForageActionData
			_start_sweep(forage_data.foraging_interval_in_sec)
		else:
			# Non-timed action: instant full tint
			_set_fill_amount(1.0)
	else:
		_stop_sweep()
```

- [ ] **Step 3: Wire up signal connections in `_ready()`**

In the existing `_ready()` function, add the foraging_completed connection. Insert after the `ActionManager.current_action_changed.connect(_on_current_action_changed)` line:

```gdscript
	ActionManager.foraging_completed.connect(_on_foraging_completed)
```

- [ ] **Step 4: Add the foraging_completed handler**

Add the signal handler:

```gdscript
func _on_foraging_completed(_items: Dictionary) -> void:
	if is_current_action and action_data is ForageActionData:
		var forage_data: ForageActionData = action_data as ForageActionData
		_reset_and_restart_sweep(forage_data.foraging_interval_in_sec)
```

- [ ] **Step 5: Update the `is_current_action` setter to trigger fill update**

Update the existing setter for `is_current_action` to also call `_update_progress_fill()`:

```gdscript
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()
		if is_instance_valid(_progress_fill):
			_update_progress_fill()
```

- [ ] **Step 6: Add cleanup for the foraging_completed signal in `_exit_tree()`**

In the existing `_exit_tree()` function, add after the existing disconnect block:

```gdscript
	if ActionManager.foraging_completed.is_connected(_on_foraging_completed):
		ActionManager.foraging_completed.disconnect(_on_foraging_completed)
	_kill_sweep_tween()
```

- [ ] **Step 7: Commit**

```bash
git add scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "feat(ui): add sweep tween logic and foraging progress fill"
```

---

### Task 6: Manual testing and verification

- [ ] **Step 1: Run the game and test forage action selection**

Run: `godot --path . scenes/main/main_game/main_game.tscn` (or press F5 in editor)

Navigate to a zone with a forage action. Click the forage action button. Verify:
- The card border changes to green (category color) with a 3px left accent
- The background tint sweeps left-to-right over the foraging interval (~5 seconds)
- When the sweep reaches 100% and loot rolls, it smoothly resets and starts again
- The sweep continues cycling as long as the action is selected

- [ ] **Step 2: Test deselection**

Click a different action (or the same action again if that deselects). Verify:
- The sweep stops immediately
- The fill resets to 0 (card returns to normal dark appearance)
- The border returns to the normal subtle style

- [ ] **Step 3: Test non-timed action selection (cycling/adventure/dialogue)**

Click a cycling or dialogue action button. Verify:
- The card immediately shows the full background tint (no sweep, instant fill)
- The border matches the category color (teal for cycling, gold for dialogue, red for adventure)

- [ ] **Step 4: Test hover behavior**

Hover over a non-selected action button. Verify:
- Hover still shows the gold-bordered hover style (existing behavior)
- Hovering over the selected button does NOT change its appearance

- [ ] **Step 5: Final commit if any adjustments were made**

If any tweaks were needed during testing:

```bash
git add -p  # stage specific changes
git commit -m "fix(ui): tune zone action button visual feedback"
```
