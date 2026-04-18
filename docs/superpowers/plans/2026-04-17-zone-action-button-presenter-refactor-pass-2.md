# ZoneActionButton Presenter Refactor — Pass 2 Implementation Plan (TrainingPresenter)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Pass 1 must be complete (all tasks landed on the current branch) before starting this plan.**

**Goal:** Add a `TrainingPresenter` scene that renders the training-action UI (per-tick sweep, attribute badge, footer progress bar with gradations and counter, Madra particles, level-up flash) on top of the presenter pattern introduced in Pass 1. Zero edits to `zone_action_button.tscn` beyond the factory dictionary and category color.

**Architecture:** Reuse Pass 1's `ZoneActionPresenter` base and three-slot button shell. Introduce one reusable widget (`TickProgressBar`) for the thin graded progress bar. The presenter subscribes to `ActionManager.training_tick_processed` and `ActionManager.training_level_gained`, drives the footer bar from `TrainingActionData.get_progress_within_level`, sweeps the overlay once per `tick_interval_seconds`, spawns a `FlyingParticle` per tick aimed at the Madra orb (resolved via the button's `get_madra_target_global_position` helper from Pass 1), and plays a 0.3s flash-and-reset tween on the footer bar when a level is gained.

**Tech Stack:** Godot 4.5 / GDScript, existing `action_card_sweep.gdshader`, existing `FlyingParticle` class (`scenes/ui/flying_particle/flying_particle.gd`), `TrainingActionData.get_current_level` / `get_progress_within_level` / `get_ticks_required_for_level` (already shipped by the training-action-infrastructure feature).

**Spec:** [docs/superpowers/specs/2026-04-17-zone-action-button-presenter-refactor-design.md](../specs/2026-04-17-zone-action-button-presenter-refactor-design.md)

---

## Preconditions

Pass 1 must be complete and merged. The following must exist on disk before starting:
- `scripts/ui/zone_action_presenter.gd` (abstract base)
- `scenes/zones/zone_action_button/zone_action_button.gd` with `PRESENTER_SCENES: Dictionary`, `CATEGORY_COLORS: Dictionary`, `get_madra_target_global_position()`, `get_category_color()`, `get_action_card()`, `set_text_dimmed()`
- `scenes/zones/zone_action_button/zone_action_button.tscn` with `OverlaySlot`, `InlineSlot`, `FooterSlot`
- A `TrainingActionData`-backed `.tres` file with `effects_on_level` containing at least one `AwardAttributeEffectData`, e.g. `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres`

---

## File Structure

| File | Role |
|---|---|
| `scenes/ui/tick_progress_bar/tick_progress_bar.gd` + `.tscn` | Reusable 2px-tall progress bar with gradations at 10%..90% and a right-edge "`current / total`" counter label. |
| `scenes/zones/zone_action_button/presenters/training_presenter.gd` + `.tscn` | Presenter for TRAIN_STATS actions. Fills all three slots (OverlaySlot=sweep, InlineSlot=attribute badge, FooterSlot=TickProgressBar). |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Add TRAIN_STATS to `PRESENTER_SCENES` and `CATEGORY_COLORS`. |

No tests created or modified. The TrainingPresenter's logic is either pure data pass-through (pulling values from `TrainingActionData.get_*` methods that are already covered by `tests/unit/test_zone_progression_data.gd` and the plan's self-contained `training_action_data` tests) or signal-driven UI side effects (not cheaply testable in GUT).

---

## Testing Commands

**Run the game from CLI:**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

**Run GUT regression:**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

---

## Task 1: Create `TickProgressBar` widget

**Files:**
- Create: `scenes/ui/tick_progress_bar/tick_progress_bar.gd`
- Create: `scenes/ui/tick_progress_bar/tick_progress_bar.tscn`

- [ ] **Step 1: Confirm target directory exists**

```bash
mkdir -p scenes/ui/tick_progress_bar
```

- [ ] **Step 2: Write the widget script**

Create `scenes/ui/tick_progress_bar/tick_progress_bar.gd`:

```gdscript
class_name TickProgressBar
extends Control
## Thin 2-pixel-tall progress bar with static gradation marks at 10..90% and a
## right-aligned "current / total" counter below the bar.
##
## Call set_progress(current, total) to update the fill and counter.
## Call flash_and_reset(color, duration) to play a brief flash, fade to zero,
## and then resume showing fresh values on the next set_progress call.

const BAR_HEIGHT: float = 2.0
const BAR_COLOR_BG: Color = Color(0.18, 0.18, 0.18, 0.9)
const BAR_COLOR_FILL_DEFAULT: Color = Color(0.83, 0.75, 0.45, 1.0)
const GRADATION_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const GRADATION_WIDTH: float = 1.0
const GRADATION_HEIGHT: float = 4.0  # slightly taller than the bar for visibility
const COUNTER_FONT_SIZE: int = 12
const COUNTER_COLOR: Color = Color(0.72, 0.68, 0.58, 1.0)

@onready var _bar_bg: ColorRect = %BarBg
@onready var _bar_fill: ColorRect = %BarFill
@onready var _gradation_overlay: Control = %GradationOverlay
@onready var _counter_label: Label = %CounterLabel

var _fill_color: Color = BAR_COLOR_FILL_DEFAULT
var _reset_tween: Tween = null

func _ready() -> void:
	_bar_fill.color = _fill_color
	_bar_bg.color = BAR_COLOR_BG
	_gradation_overlay.draw.connect(_draw_gradations)
	_counter_label.add_theme_font_size_override("font_size", COUNTER_FONT_SIZE)
	_counter_label.add_theme_color_override("font_color", COUNTER_COLOR)

## Sets the fill percentage and counter text. `total == 0` clears the bar.
func set_progress(current: int, total: int) -> void:
	_kill_reset_tween()
	_bar_fill.self_modulate.a = 1.0
	if total <= 0:
		_bar_fill.anchor_right = 0.0
		_counter_label.text = ""
		return
	var pct: float = clampf(float(current) / float(total), 0.0, 1.0)
	_bar_fill.anchor_right = pct
	_counter_label.text = "%d / %d" % [current, total]

## Sets the fill color (used by the presenter to tint per category).
func set_fill_color(color: Color) -> void:
	_fill_color = color
	if is_instance_valid(_bar_fill):
		_bar_fill.color = color

## Briefly flashes the bar to `flash_color`, fades to transparent, then snaps
## to zero fill.
func flash_and_reset(flash_color: Color, duration: float = 0.3) -> void:
	_kill_reset_tween()
	_reset_tween = create_tween()
	_reset_tween.tween_property(_bar_fill, "color", flash_color, duration * 0.33)
	_reset_tween.tween_property(_bar_fill, "self_modulate:a", 0.0, duration * 0.66)
	_reset_tween.tween_callback(func() -> void:
		_bar_fill.anchor_right = 0.0
		_bar_fill.color = _fill_color
		_bar_fill.self_modulate.a = 1.0
	)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _kill_reset_tween() -> void:
	if _reset_tween and _reset_tween.is_valid():
		_reset_tween.kill()
	_reset_tween = null

func _draw_gradations() -> void:
	var w: float = _gradation_overlay.size.x
	var h: float = _gradation_overlay.size.y
	for i in range(1, 10):
		var x: float = w * (i / 10.0)
		_gradation_overlay.draw_rect(Rect2(Vector2(x, 0), Vector2(GRADATION_WIDTH, h)), GRADATION_COLOR)
```

- [ ] **Step 3: Create the scene**

Create `scenes/ui/tick_progress_bar/tick_progress_bar.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/tick_progress_bar/tick_progress_bar.gd" id="1_tpb"]

[node name="TickProgressBar" type="Control"]
script = ExtResource("1_tpb")
custom_minimum_size = Vector2(0, 16)
anchor_right = 1.0
mouse_filter = 2

[node name="BarBg" type="ColorRect" parent="."]
unique_name_in_owner = true
anchor_right = 1.0
offset_bottom = 2.0
mouse_filter = 2
color = Color(0.18, 0.18, 0.18, 0.9)

[node name="BarFill" type="ColorRect" parent="."]
unique_name_in_owner = true
anchor_right = 0.0
offset_bottom = 2.0
mouse_filter = 2
color = Color(0.83, 0.75, 0.45, 1)

[node name="GradationOverlay" type="Control" parent="."]
unique_name_in_owner = true
anchor_right = 1.0
offset_top = -1.0
offset_bottom = 3.0
mouse_filter = 2

[node name="CounterLabel" type="Label" parent="."]
unique_name_in_owner = true
anchor_right = 1.0
anchor_top = 1.0
anchor_bottom = 1.0
offset_top = -14.0
offset_bottom = 0.0
mouse_filter = 2
horizontal_alignment = 2
```

- [ ] **Step 4: Visual smoke-test in editor**

Open `tick_progress_bar.tscn` in the Godot editor. Expected:
- A 2px-tall dark bar spans the full width at the top
- Nine black gradation marks are visible at 10%..90% (each 1px wide, 4px tall)
- A label sits below the bar, right-aligned

Use the inspector to set `anchor_right` of `BarFill` to `0.5` — confirm the fill expands to 50% width. Reset `anchor_right` to `0.0` before saving.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/tick_progress_bar/tick_progress_bar.gd scenes/ui/tick_progress_bar/tick_progress_bar.tscn
git commit -m "feat(ui): add TickProgressBar graded widget with counter"
```

---

## Task 2: Create `TrainingPresenter` script + scene

**Files:**
- Create: `scenes/zones/zone_action_button/presenters/training_presenter.gd`
- Create: `scenes/zones/zone_action_button/presenters/training_presenter.tscn`

- [ ] **Step 1: Write the presenter script**

Create `scenes/zones/zone_action_button/presenters/training_presenter.gd`:

```gdscript
class_name TrainingPresenter
extends ZoneActionPresenter
## Presenter for TRAIN_STATS actions. Fills all three slots:
##   OverlaySlot — per-tick sweep (same shader as foraging, tied to ActionManager.action_timer)
##   InlineSlot  — attribute badge "current / max" (e.g. "0 / 4")
##   FooterSlot  — TickProgressBar showing ticks-within-current-level
##
## Spawns a Madra FlyingParticle on each tick, aimed at the Madra orb.
## Plays a 0.3s flash/fade on the progress bar when a new level is gained.

const TICK_PARTICLE_COLOR: Color = Color(0.5, 0.78, 1.0, 0.85)
const TICK_PARTICLE_SIZE: float = 4.0
const TICK_PARTICLE_DURATION: float = 0.5
const FILL_TINT_OPACITY: float = 0.45
const LEVEL_UP_FLASH_DURATION: float = 0.3

@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _attribute_badge: RichTextLabel = %AttributeBadge
@onready var _tick_progress_bar: TickProgressBar = %TickProgressBar

var _is_tracking_timer: bool = false

func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, inline_slot: Control, footer_slot: Control) -> void:
	action_data = data
	button = owner_button

	_progress_fill.reparent(overlay_slot)
	_progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_fill_color(button.get_category_color())
	_set_fill_amount(0.0)

	_attribute_badge.reparent(inline_slot)

	_tick_progress_bar.reparent(footer_slot)
	_tick_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tick_progress_bar.set_fill_color(button.get_category_color())

	ActionManager.training_tick_processed.connect(_on_tick)
	ActionManager.training_level_gained.connect(_on_level)

	_refresh_from_state()

func teardown() -> void:
	if ActionManager.training_tick_processed.is_connected(_on_tick):
		ActionManager.training_tick_processed.disconnect(_on_tick)
	if ActionManager.training_level_gained.is_connected(_on_level):
		ActionManager.training_level_gained.disconnect(_on_level)

func set_is_current(is_current: bool) -> void:
	if is_current:
		_start_sweep()
	else:
		_stop_sweep()

#-----------------------------------------------------------------------------
# PROCESS — sweep follows ActionManager.action_timer
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _is_tracking_timer:
		var timer: Timer = ActionManager.action_timer
		if timer.wait_time > 0.0 and not timer.is_stopped():
			var progress: float = 1.0 - (timer.time_left / timer.wait_time)
			_set_fill_amount(progress)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_tick(tick_action: TrainingActionData, new_tick_count: int) -> void:
	if tick_action != action_data:
		return
	_update_progress_bar(new_tick_count)
	_update_attribute_badge(new_tick_count)
	_spawn_madra_particle(tick_action)
	# Reset the sweep shader; _process will ramp it back up from 0 as action_timer counts down again.
	_set_fill_amount(0.0)

func _on_level(level_action: TrainingActionData, _new_level: int) -> void:
	if level_action != action_data:
		return
	var flash_color: Color = button.get_category_color()
	_tick_progress_bar.flash_and_reset(flash_color, LEVEL_UP_FLASH_DURATION)

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

func _refresh_from_state() -> void:
	var ticks: int = ZoneManager.get_training_ticks(action_data.action_id)
	_update_progress_bar(ticks)
	_update_attribute_badge(ticks)

func _update_progress_bar(accumulated_ticks: int) -> void:
	var training: TrainingActionData = action_data as TrainingActionData
	if training == null:
		return
	var level: int = training.get_current_level(accumulated_ticks)
	var cumulative_through_current_level: int = 0
	for i in range(1, level + 1):
		cumulative_through_current_level += training.get_ticks_required_for_level(i)
	var ticks_in_level: int = accumulated_ticks - cumulative_through_current_level
	var ticks_required_for_next: int = training.get_ticks_required_for_level(level + 1)
	_tick_progress_bar.set_progress(ticks_in_level, ticks_required_for_next)

func _update_attribute_badge(accumulated_ticks: int) -> void:
	var training: TrainingActionData = action_data as TrainingActionData
	if training == null:
		return
	var attribute_effect: AwardAttributeEffectData = _find_attribute_effect(training)
	if attribute_effect == null:
		_attribute_badge.text = ""
		return
	var levels_available: int = training.ticks_per_level.size()
	var amount_per_level: float = attribute_effect.amount
	var current_level: int = training.get_current_level(accumulated_ticks)
	var current_total: int = int(round(current_level * amount_per_level))
	var max_total: int = int(round(levels_available * amount_per_level))
	var attr_name: String = CharacterAttributesData.AttributeType.keys()[attribute_effect.attribute_type].capitalize()
	_attribute_badge.text = "[right][color=#D4A84A]%d[/color][color=#7a6a52] / %d %s[/color][/right]" % [current_total, max_total, attr_name]

func _find_attribute_effect(training: TrainingActionData) -> AwardAttributeEffectData:
	for effect in training.effects_on_level:
		if effect is AwardAttributeEffectData:
			return effect as AwardAttributeEffectData
	return null

#-----------------------------------------------------------------------------
# SWEEP CONTROL
#-----------------------------------------------------------------------------

func _set_fill_amount(amount: float) -> void:
	if is_instance_valid(_progress_fill) and _progress_fill.material:
		_progress_fill.material.set_shader_parameter("fill_amount", amount)

func _set_fill_color(cat_color: Color) -> void:
	if is_instance_valid(_progress_fill):
		_progress_fill.color = Color(cat_color, FILL_TINT_OPACITY)

func _start_sweep() -> void:
	_set_fill_amount(0.0)
	_is_tracking_timer = true

func _stop_sweep() -> void:
	_is_tracking_timer = false
	_set_fill_amount(0.0)
	if is_instance_valid(_progress_fill):
		_progress_fill.self_modulate.a = 1.0

#-----------------------------------------------------------------------------
# PARTICLES
#-----------------------------------------------------------------------------

func _spawn_madra_particle(_tick_action: TrainingActionData) -> void:
	var target: Vector2 = button.get_madra_target_global_position()
	if target == Vector2.ZERO:
		return
	var card: PanelContainer = button.get_action_card()
	var spawn_pos: Vector2 = card.global_position + card.size * 0.5
	var particle: FlyingParticle = FlyingParticle.new()
	get_tree().current_scene.add_child(particle)
	particle.launch(spawn_pos, target, TICK_PARTICLE_COLOR, TICK_PARTICLE_DURATION, TICK_PARTICLE_SIZE)
```

- [ ] **Step 2: Create the scene**

Create `scenes/zones/zone_action_button/presenters/training_presenter.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scenes/zones/zone_action_button/presenters/training_presenter.gd" id="1_train"]
[ext_resource type="Shader" uid="uid://action_card_sweep_shader" path="res://assets/shaders/action_card_sweep.gdshader" id="2_sweep"]
[ext_resource type="PackedScene" path="res://scenes/ui/tick_progress_bar/tick_progress_bar.tscn" id="3_tpb"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_train_sweep"]
resource_local_to_scene = true
shader = ExtResource("2_sweep")
shader_parameter/fill_amount = 0.0

[node name="TrainingPresenter" type="Node"]
script = ExtResource("1_train")

[node name="ProgressFill" type="ColorRect" parent="."]
unique_name_in_owner = true
anchor_right = 1.0
anchor_bottom = 1.0
material = SubResource("ShaderMaterial_train_sweep")
mouse_filter = 2
color = Color(0.55, 0.45, 0.75, 0.45)

[node name="AttributeBadge" type="RichTextLabel" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(90, 0)
size_flags_vertical = 4
mouse_filter = 2
bbcode_enabled = true
fit_content = true
scroll_active = false

[node name="TickProgressBar" parent="." instance=ExtResource("3_tpb")]
unique_name_in_owner = true
```

- [ ] **Step 3: Open in editor and verify the scene loads**

Open `training_presenter.tscn` in the Godot editor. Expected:
- Root `TrainingPresenter` node with script attached
- Child `ProgressFill` (ColorRect with shader material)
- Child `AttributeBadge` (RichTextLabel)
- Child `TickProgressBar` (instance)

No parse errors in the Output panel.

- [ ] **Step 4: Commit**

```bash
git add scenes/zones/zone_action_button/presenters/training_presenter.gd scenes/zones/zone_action_button/presenters/training_presenter.tscn
git commit -m "feat(ui): add TrainingPresenter for TRAIN_STATS action type"
```

---

## Task 3: Register `TRAIN_STATS` in the button factory + category colors

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd`

- [ ] **Step 1: Add the category color**

Edit the `CATEGORY_COLORS` dict in `scenes/zones/zone_action_button/zone_action_button.gd`. Add a TRAIN_STATS entry between the existing entries so it reads:

```gdscript
const CATEGORY_COLORS: Dictionary = {
	ZoneActionData.ActionType.FORAGE: Color(0.42, 0.67, 0.37),
	ZoneActionData.ActionType.CYCLING: Color(0.37, 0.66, 0.62),
	ZoneActionData.ActionType.ADVENTURE: Color(0.61, 0.25, 0.25),
	ZoneActionData.ActionType.NPC_DIALOGUE: Color(0.83, 0.66, 0.29),
	ZoneActionData.ActionType.TRAIN_STATS: Color(0.55, 0.45, 0.75),
}
```

- [ ] **Step 2: Register the presenter scene**

Update the `PRESENTER_SCENES` dict in the same file to include the TRAIN_STATS entry:

```gdscript
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
	ZoneActionData.ActionType.ADVENTURE: preload("res://scenes/zones/zone_action_button/presenters/adventure_presenter.tscn"),
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.TRAIN_STATS: preload("res://scenes/zones/zone_action_button/presenters/training_presenter.tscn"),
}
```

- [ ] **Step 3: Commit**

```bash
git add scenes/zones/zone_action_button/zone_action_button.gd
git commit -m "feat(ui): wire TrainingPresenter into ZoneActionButton factory"
```

---

## Task 4: Full end-to-end verification

**Files:**
- None (verification only)

- [ ] **Step 1: Run GUT tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass, including `tests/integration/test_training_flow.gd`.

- [ ] **Step 2: Launch the game and open a zone with a training action**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Navigate to Spirit Valley (the `spirit_well_training_action.tres` zone action should be available once unlocked).

- [ ] **Step 3: Verify idle-state rendering**

Before selecting the training action, confirm:
- Card renders with name "Spirit Well" + description
- Inline slot shows attribute badge `0 / 4 Spirit` (since `ticks_per_level.size()` = 4 and the `spirit_well_spirit_award_effect.tres` grants 1 Spirit per level)
- Footer shows an empty 2px bar with gradation marks and counter `0 / 60`
- No sweep animation (not currently selected)

- [ ] **Step 4: Select the training action and verify per-tick behavior**

Click the button to select. Over the next 3 seconds confirm:
- The sweep overlay progresses left→right over each 1-second interval (matching `tick_interval_seconds`)
- On each tick:
  - Footer counter increments: `1 / 60`, `2 / 60`, `3 / 60`
  - Footer bar fill grows by ~1.67% per tick
  - A Madra particle spawns at the card and flies to the Madra orb
  - Madra balance increases by 1.5 (from `spirit_well_madra_trickle_effect.tres`)
  - Sweep resets to 0 and begins a new sweep

- [ ] **Step 5: Verify level-up behavior**

Let the training run to 60 ticks (or temporarily edit `spirit_well_training_action.tres` `ticks_per_level = Array[int]([3, 300, 600, 1200])` for faster verification — revert before committing). At level-up confirm:
- Footer bar flashes in the category color (purple), fades to transparent over ~0.3s
- Footer bar snaps back to 0 fill, counter resets to `0 / 300`
- Attribute badge updates to `1 / 4 Spirit`
- Spirit attribute increased on the character sheet (verify via character view)

- [ ] **Step 6: Verify deselect behavior**

Select a different zone action. Confirm:
- Training sweep stops (fill_amount → 0)
- Attribute badge + progress bar still visible but static (reflect persisted ticks)
- Re-selecting the training action resumes sweeps cleanly

- [ ] **Step 7: Verify no console errors**

Check the Godot editor's Output panel after playing the game — no errors or warnings related to `TrainingPresenter`, `TickProgressBar`, or `ZoneActionButton`.

- [ ] **Step 8: If all good, no commit required**

Verification only. If any regression is found, fix in-place and commit with message `fix(ui): <description>`.
