# Combat View Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the combat view with ability tooltips, keybindings, atmosphere, resource costs, affordability states, and buff tooltips.

**Architecture:** Bottom-up build: extend AbilityStatsDisplay with a compact mode, enhance AbilityButton, wire keybindings and tooltips through AbilitiesPanel, build standalone tooltip components, add atmosphere, and add equip slot hints. All new UI nodes are created programmatically to avoid .tscn UID conflicts.

**Tech Stack:** Godot 4.6, GDScript, existing AbilityStatsDisplay/StatLabel components, Atmosphere scene.

**Spec:** `docs/superpowers/specs/2026-04-15-combat-view-improvements-design.md`

---

### Task 1: Add DAMAGE_TOTAL display mode to AbilityStatsDisplay

**Files:**
- Modify: `scenes/abilities/ability_stats_display/ability_stats_display.gd`

This adds a compact damage mode that only shows the total DMG pill with pulsing gold border — no per-attribute breakdown. The combat tooltip will use this.

- [ ] **Step 1: Add DAMAGE_TOTAL enum value and setup branch**

In `scenes/abilities/ability_stats_display/ability_stats_display.gd`, change the enum and setup method:

```gdscript
enum DisplayMode { DAMAGE, TIMING_COSTS, DAMAGE_TOTAL }
```

Replace the `setup` method body:

```gdscript
func setup(ability_data: AbilityData, mode: DisplayMode = DisplayMode.DAMAGE) -> void:
	_ability_data = ability_data
	_clear_children()

	match mode:
		DisplayMode.DAMAGE:
			_setup_damage(ability_data)
		DisplayMode.TIMING_COSTS:
			_setup_timing_costs(ability_data)
		DisplayMode.DAMAGE_TOTAL:
			_setup_damage_total(ability_data)
```

- [ ] **Step 2: Add _setup_damage_total method**

Add this method after `_setup_damage` (around line 66):

```gdscript
func _setup_damage_total(ability_data: AbilityData) -> void:
	var effect: CombatEffectData = null
	if not ability_data.effects.is_empty():
		effect = ability_data.effects[0]
	if not effect or not _has_damage_or_scaling(effect):
		return

	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var total: float = effect.calculate_value(attrs)

	var total_label: StatLabel = _create_label(
		"DMG", total, Color("#D4A84A"),
		func(n: String, v: float) -> String: return "%s %.0f" % [n, v],
		_build_total_tooltip(effect, attrs, total)
	)
	_setup_damage_border_pulse(total_label)
```

- [ ] **Step 3: Verify existing ability card still works**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import`

Then launch the game and open the abilities view (A key) — verify ability cards still display damage pills with the full breakdown. The DAMAGE_TOTAL mode is unused so far; existing behavior is unchanged.

- [ ] **Step 4: Commit**

```bash
git add scenes/abilities/ability_stats_display/ability_stats_display.gd
git commit -m "feat(abilities): add DAMAGE_TOTAL display mode to AbilityStatsDisplay

Compact mode shows only the total DMG pill with pulsing border,
used by the combat tooltip."
```

---

### Task 2: Add Q/W/E/R input actions to project.godot

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add four input actions**

Append to the `[input]` section in `project.godot`, before the closing of the section (after the `open_abilities` block):

```
ability_slot_1={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}
ability_slot_2={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
ability_slot_3={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
ability_slot_4={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"location":0,"echo":false,"script":null)
]
}
```

Physical keycodes: Q=81, W=87, E=69, R=82.

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat(input): add Q/W/E/R input actions for ability slots"
```

---

### Task 3: Enhance AbilityButton with keybinding hint, cost strip, affordability, and hover signals

**Files:**
- Modify: `scenes/ui/combat/ability_button/ability_button.gd`

This is the largest single change. The button gains: a keybinding label (top-left), a cost strip (bottom), a can't-afford dimming state, and hover signals for tooltip.

- [ ] **Step 1: Rewrite ability_button.gd**

Replace the entire contents of `scenes/ui/combat/ability_button/ability_button.gd`:

```gdscript
class_name AbilityButton
extends MarginContainer

## AbilityButton
## UI component representing a combat ability.
## Displays cooldown status, keybinding hint, resource costs,
## affordability state, and handles user interaction.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal pressed
signal hovered(instance: CombatAbilityInstance)
signal unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
const COLOR_MADRA: Color = Color("#6BA4D4")
const COLOR_STAMINA: Color = Color("#D4A84A")
const COLOR_HEALTH: Color = Color("#E06060")
const COLOR_CANT_AFFORD: Color = Color("#E06060")
const BORDER_CANT_AFFORD: Color = Color("#553333")

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var ability_instance: CombatAbilityInstance
var _slot_index: int = -1
var _vitals_manager: VitalsManager
var _is_on_cooldown: bool = false
var _is_casting: bool = false

@onready var button: TextureButton = %Button
@onready var cooldown_progress_bar: TextureProgressBar = %CooldownProgressBar
@onready var cooldown_label: Label = %CooldownLabel

# Programmatic UI nodes
var _key_hint_label: Label
var _cost_container: HBoxContainer
var _cost_bg: PanelContainer
var _cost_labels: Array[Label] = []
var _border_rect: TextureRect

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

	# Hover on entire button area (not inner TextureButton)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Ensure overlays don't block mouse from reaching the TextureButton
	cooldown_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cooldown_label.visible = false
	cooldown_progress_bar.visible = false
	cooldown_label.text = ""
	cooldown_progress_bar.value = 0.0

	_border_rect = get_node("BackgroundRect")

## Sets up the button with the given ability instance, slot index, and vitals manager.
func setup(instance: CombatAbilityInstance, slot_index: int = -1, vitals_manager: VitalsManager = null) -> void:
	ability_instance = instance
	_slot_index = slot_index
	_vitals_manager = vitals_manager

	# Set Visuals
	button.tooltip_text = instance.ability_data.ability_name
	button.texture_normal = instance.ability_data.icon
	button.texture_pressed = instance.ability_data.icon
	button.texture_disabled = instance.ability_data.icon
	button.texture_hover = instance.ability_data.icon
	button.texture_focused = instance.ability_data.icon

	# Connect Signals
	ability_instance.cooldown_started.connect(_on_cooldown_started)
	ability_instance.cooldown_updated.connect(_on_cooldown_updated)
	ability_instance.cooldown_ready.connect(_on_cooldown_ready)
	ability_instance.cast_started.connect(_on_cast_started)
	ability_instance.cast_finished.connect(_on_cast_finished)

	# Initial State
	button.disabled = not ability_instance.is_ready()

	# Build UI overlays
	_create_key_hint_label()
	_create_cost_strip()

#-----------------------------------------------------------------------------
# PROCESS — Affordability Check
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not ability_instance or not _vitals_manager:
		return
	if _is_on_cooldown or _is_casting:
		return

	var can_afford: bool = ability_instance.ability_data.can_afford(_vitals_manager)
	_update_affordability_visuals(can_afford)

#-----------------------------------------------------------------------------
# KEYBINDING HINT
#-----------------------------------------------------------------------------

func _create_key_hint_label() -> void:
	if _slot_index < 0 or _slot_index >= KEY_LABELS.size():
		return

	_key_hint_label = Label.new()
	_key_hint_label.text = KEY_LABELS[_slot_index]
	_key_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style
	_key_hint_label.add_theme_font_size_override("font_size", 11)
	_key_hint_label.add_theme_color_override("font_color", Color("#D4A84A"))
	_key_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_key_hint_label.add_theme_constant_override("outline_size", 2)

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	bg.border_color = Color("#D4A84A")
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4.0
	bg.content_margin_right = 5.0
	bg.content_margin_top = 0.0
	bg.content_margin_bottom = 1.0
	_key_hint_label.add_theme_stylebox_override("normal", bg)

	# Position in top-left of BackgroundRect
	_key_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_hint_label.z_index = 3
	_border_rect.add_child(_key_hint_label)
	_key_hint_label.position = Vector2(-2, -2)

#-----------------------------------------------------------------------------
# COST STRIP
#-----------------------------------------------------------------------------

func _create_cost_strip() -> void:
	if not ability_instance:
		return

	var data: AbilityData = ability_instance.ability_data
	var has_costs: bool = data.madra_cost > 0 or data.stamina_cost > 0 or data.health_cost > 0
	if not has_costs:
		return

	# Background panel
	_cost_bg = PanelContainer.new()
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.content_margin_left = 2.0
	bg_style.content_margin_right = 2.0
	bg_style.content_margin_top = 1.0
	bg_style.content_margin_bottom = 1.0
	_cost_bg.add_theme_stylebox_override("panel", bg_style)

	_cost_container = HBoxContainer.new()
	_cost_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cost_container.add_theme_constant_override("separation", 6)
	_cost_bg.add_child(_cost_container)

	if data.madra_cost > 0:
		_add_cost_label("%.0f" % data.madra_cost, COLOR_MADRA, "madra")
	if data.stamina_cost > 0:
		_add_cost_label("%.0f" % data.stamina_cost, COLOR_STAMINA, "stamina")
	if data.health_cost > 0:
		_add_cost_label("%.0f" % data.health_cost, COLOR_HEALTH, "health")

	# Position at bottom of BackgroundRect
	_cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_bg.z_index = 3
	_border_rect.add_child(_cost_bg)
	# Anchor to bottom — set after button is sized
	_cost_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

func _add_cost_label(text: String, color: Color, resource_type: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("resource_type", resource_type)
	label.set_meta("default_color", color)
	_cost_container.add_child(label)
	_cost_labels.append(label)

#-----------------------------------------------------------------------------
# AFFORDABILITY VISUALS
#-----------------------------------------------------------------------------

func _update_affordability_visuals(can_afford: bool) -> void:
	if can_afford:
		button.modulate.a = 1.0
		for label: Label in _cost_labels:
			label.add_theme_color_override("font_color", label.get_meta("default_color"))
	else:
		button.modulate.a = 0.35
		# Tint unaffordable cost labels red
		if _vitals_manager and ability_instance:
			var data: AbilityData = ability_instance.ability_data
			for label: Label in _cost_labels:
				var res_type: String = label.get_meta("resource_type")
				var affordable: bool = true
				if res_type == "madra" and data.madra_cost > _vitals_manager.current_madra:
					affordable = false
				elif res_type == "stamina" and data.stamina_cost > _vitals_manager.current_stamina:
					affordable = false
				elif res_type == "health" and data.health_cost > _vitals_manager.current_health:
					affordable = false
				if not affordable:
					label.add_theme_color_override("font_color", COLOR_CANT_AFFORD)
				else:
					label.add_theme_color_override("font_color", label.get_meta("default_color"))

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_button_pressed() -> void:
	pressed.emit()

func _on_mouse_entered() -> void:
	if ability_instance:
		hovered.emit(ability_instance)

func _on_mouse_exited() -> void:
	unhovered.emit()

func _on_cooldown_started(_duration: float) -> void:
	_is_on_cooldown = true
	button.disabled = true
	button.modulate.a = 1.0
	_show_cooldown()

func _on_cooldown_updated(time_left: float) -> void:
	_show_cooldown()
	cooldown_label.text = "%.1f (s)" % time_left
	cooldown_progress_bar.value = time_left / ability_instance.ability_data.base_cooldown

func _on_cooldown_ready() -> void:
	_is_on_cooldown = false
	button.disabled = false
	_hide_cooldown()

func _on_cast_started(_instance: CombatAbilityInstance, _duration: float) -> void:
	_is_casting = true

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	_is_casting = false

func _show_cooldown() -> void:
	cooldown_label.visible = true
	cooldown_progress_bar.visible = true

func _hide_cooldown() -> void:
	cooldown_label.visible = false
	cooldown_progress_bar.visible = false
```

- [ ] **Step 2: Commit**

```bash
git add scenes/ui/combat/ability_button/ability_button.gd
git commit -m "feat(combat): enhance AbilityButton with keybinding hints, cost strip, affordability, hover signals"
```

---

### Task 4: Update AbilitiesPanel with keybinding handling and vitals wiring

**Files:**
- Modify: `scenes/ui/combat/abilities_panel.gd`
- Modify: `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`

- [ ] **Step 1: Rewrite abilities_panel.gd**

Replace the entire contents of `scenes/ui/combat/abilities_panel.gd`:

```gdscript
class_name AbilitiesPanel
extends PanelContainer

## AbilitiesPanel
## Manages ability buttons in combat, handles keybinding input,
## and hosts the ability tooltip.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var ability_container: HBoxContainer = %AbilitiesContainer
@onready var casting_indicator: VBoxContainer = %CastingIndicator
@onready var ability_info_label: Label = %AbilityInformation
@onready var ability_type_icon: TextureRect = %AbilityTypeIcon
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var cast_timer_label: Label = %CastTimer

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

var ability_button_scene: PackedScene = preload("res://scenes/ui/combat/ability_button/ability_button.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _vitals_manager: VitalsManager
var _ability_buttons: Array[AbilityButton] = []
var _slot_counter: int = 0

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_selected(instance: CombatAbilityInstance)

#-----------------------------------------------------------------------------
# INPUT ACTION NAMES
#-----------------------------------------------------------------------------

const SLOT_ACTIONS: PackedStringArray = [
	"ability_slot_1", "ability_slot_2", "ability_slot_3", "ability_slot_4"
]

func _ready() -> void:
	hide_casting_state()

## Sets the vitals manager for affordability checks on buttons.
func set_vitals_manager(vm: VitalsManager) -> void:
	_vitals_manager = vm

## Registers an ability and creates a button for it.
func register_ability(instance: CombatAbilityInstance) -> void:
	var button: AbilityButton = ability_button_scene.instantiate() as AbilityButton
	ability_container.add_child(button)
	button.setup(instance, _slot_counter, _vitals_manager)

	# Connect button signals
	button.pressed.connect(func() -> void: ability_selected.emit(instance))
	button.hovered.connect(_on_ability_hovered)
	button.unhovered.connect(_on_ability_unhovered)

	# Connect casting signals
	instance.cast_started.connect(_on_cast_started)
	instance.cast_updated.connect(_on_cast_updated)
	instance.cast_finished.connect(_on_cast_finished)

	_ability_buttons.append(button)
	_slot_counter += 1

## Resets the panel by removing all buttons and cleaning up connections.
func reset() -> void:
	hide_casting_state()
	_hide_tooltip()

	for child in ability_container.get_children():
		if child is AbilityButton and is_instance_valid(child.ability_instance):
			var instance: CombatAbilityInstance = child.ability_instance
			if instance.cast_started.is_connected(_on_cast_started):
				instance.cast_started.disconnect(_on_cast_started)
			if instance.cast_updated.is_connected(_on_cast_updated):
				instance.cast_updated.disconnect(_on_cast_updated)
			if instance.cast_finished.is_connected(_on_cast_finished):
				instance.cast_finished.disconnect(_on_cast_finished)

		child.queue_free()

	_ability_buttons.clear()
	_slot_counter = 0
	_vitals_manager = null

#-----------------------------------------------------------------------------
# KEYBINDING INPUT
#-----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	for i: int in range(mini(SLOT_ACTIONS.size(), _ability_buttons.size())):
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			var btn: AbilityButton = _ability_buttons[i]
			if btn.ability_instance and not btn.button.disabled:
				ability_selected.emit(btn.ability_instance)
				_hide_tooltip()
			get_viewport().set_input_as_handled()
			return

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

var _tooltip: Control = null

func _on_ability_hovered(instance: CombatAbilityInstance) -> void:
	# Tooltip is wired externally by CombatAbilityTooltip system (Task 5)
	pass

func _on_ability_unhovered() -> void:
	pass

func _hide_tooltip() -> void:
	pass

#-----------------------------------------------------------------------------
# CASTING UI HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	show_casting_state(instance, duration)

func _on_cast_updated(_instance: CombatAbilityInstance, time_left: float) -> void:
	update_cast_progress(time_left)

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	hide_casting_state()

func show_casting_state(instance: CombatAbilityInstance, total_duration: float) -> void:
	ability_container.visible = false
	casting_indicator.visible = true

	ability_info_label.text = instance.ability_data.ability_name
	progress_bar.max_value = total_duration
	progress_bar.value = total_duration

	update_cast_progress(total_duration)

func update_cast_progress(time_left: float) -> void:
	progress_bar.value = time_left
	cast_timer_label.text = "%.1f / %.1fs" % [time_left, progress_bar.max_value]

func hide_casting_state() -> void:
	casting_indicator.visible = false
	ability_container.visible = true
```

- [ ] **Step 2: Wire vitals_manager in CombatantInfoPanel**

In `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`, modify the `setup_abilities` method. Find the line:

```gdscript
func setup_abilities(p_ability_manager: CombatAbilityManager) -> void:
```

Replace the entire method with:

```gdscript
func setup_abilities(p_ability_manager: CombatAbilityManager) -> void:
	_cleanup_abilities()

	ability_manager = p_ability_manager

	if ability_manager:
		abilities_panel.visible = true

		# Pass vitals manager for affordability checks
		if vitals_manager:
			abilities_panel.set_vitals_manager(vitals_manager)

		# Connect selection signal
		if not abilities_panel.ability_selected.is_connected(_on_ability_selected):
			abilities_panel.ability_selected.connect(_on_ability_selected)

		# Auto-cleanup when manager is destroyed
		ability_manager.tree_exiting.connect(_on_ability_manager_exiting)

		# Load initial abilities if any
		for ability_instance in ability_manager.abilities:
			_register_ability(ability_instance)
	else:
		abilities_panel.visible = false

		pass
```

- [ ] **Step 3: Verify combat starts without errors**

Run the game, start an adventure, enter combat. Verify:
- Ability buttons show Q/W/E/R hints in top-left
- Cost strip appears at bottom with color-coded values
- Pressing Q/W/E/R activates abilities
- Buttons dim when player can't afford costs

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/combat/abilities_panel.gd scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd
git commit -m "feat(combat): wire keybindings and vitals into AbilitiesPanel

Q/W/E/R activate abilities. AbilityButton receives vitals_manager
from CombatantInfoPanel for affordability checks."
```

---

### Task 5: Build CombatAbilityTooltip and wire into AbilitiesPanel

**Files:**
- Create: `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd`
- Create: `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn`
- Modify: `scenes/ui/combat/abilities_panel.gd`

- [ ] **Step 1: Create combat_ability_tooltip.gd**

Create `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd`:

```gdscript
class_name CombatAbilityTooltip
extends PanelContainer

## CombatAbilityTooltip
## Compact ability info popup for combat view.
## Shows icon, name, total damage, cooldown, cast time, and costs.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const TOOLTIP_WIDTH: float = 280.0
const CARD_BG: Color = Color(0.239, 0.18, 0.133, 1.0) # #3D2E22
const CARD_BORDER: Color = Color(0.549, 0.4, 0.278, 1.0) # #8C6647

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

const AbilityStatsDisplayScene: PackedScene = preload("res://scenes/abilities/ability_stats_display/ability_stats_display.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _icon_rect: TextureRect
var _name_label: Label
var _damage_display: AbilityStatsDisplay
var _timing_display: AbilityStatsDisplay

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = TOOLTIP_WIDTH

	# Panel style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", style)

	_build_layout()

func _build_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header row: icon + name
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(40, 40)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"LabelAbilityBody"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_name_label)

	# Stats rows
	_damage_display = AbilityStatsDisplayScene.instantiate()
	_damage_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_damage_display)

	_timing_display = AbilityStatsDisplayScene.instantiate()
	_timing_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_timing_display)

## Populates the tooltip with ability data.
func show_for_ability(ability_data: AbilityData) -> void:
	_icon_rect.texture = ability_data.icon
	_name_label.text = ability_data.ability_name
	_damage_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.DAMAGE_TOTAL)
	_timing_display.setup(ability_data, AbilityStatsDisplay.DisplayMode.TIMING_COSTS)

	# Hide damage row if ability has no damage (e.g., Enforce is a self-buff)
	_damage_display.visible = not ability_data.effects.is_empty()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false

## Positions the tooltip above the given control, centered horizontally.
func position_above(control: Control) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	var tooltip_size: Vector2 = size
	var x: float = control_rect.position.x + (control_rect.size.x - tooltip_size.x) / 2.0
	var y: float = control_rect.position.y - tooltip_size.y - 8.0

	# Flip below if would overflow top
	if y < 0:
		y = control_rect.position.y + control_rect.size.y + 8.0

	# Clamp horizontal
	x = clampf(x, 4.0, get_viewport_rect().size.x - tooltip_size.x - 4.0)

	global_position = Vector2(x, y)
```

- [ ] **Step 2: Create combat_ability_tooltip.tscn**

Create `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://yqkvsb5q7pab" path="res://assets/themes/pixel_theme.tres" id="2_theme"]

[node name="CombatAbilityTooltip" type="PanelContainer"]
custom_minimum_size = Vector2(280, 0)
theme = ExtResource("2_theme")
script = ExtResource("1_script")
```

- [ ] **Step 3: Wire tooltip into AbilitiesPanel**

In `scenes/ui/combat/abilities_panel.gd`, replace the tooltip section (the `_tooltip` var and the three placeholder methods):

Replace:
```gdscript
var _tooltip: Control = null

func _on_ability_hovered(instance: CombatAbilityInstance) -> void:
	# Tooltip is wired externally by CombatAbilityTooltip system (Task 5)
	pass

func _on_ability_unhovered() -> void:
	pass

func _hide_tooltip() -> void:
	pass
```

With:
```gdscript
const CombatAbilityTooltipScene: PackedScene = preload("res://scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn")
var _tooltip: CombatAbilityTooltip = null

func _setup_tooltip() -> void:
	_tooltip = CombatAbilityTooltipScene.instantiate()
	add_child(_tooltip)

func _on_ability_hovered(instance: CombatAbilityInstance) -> void:
	if not _tooltip:
		_setup_tooltip()

	_tooltip.show_for_ability(instance.ability_data)

	# Find the button that emitted this
	for btn: AbilityButton in _ability_buttons:
		if btn.ability_instance == instance:
			# Defer positioning to next frame so tooltip sizes itself first
			(func() -> void: _tooltip.position_above(btn)).call_deferred()
			break

func _on_ability_unhovered() -> void:
	_hide_tooltip()

func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.hide_tooltip()
```

- [ ] **Step 4: Verify tooltip appears on hover**

Run the game, enter combat. Hover over ability buttons — tooltip should appear above with icon, name, DMG pill, and timing/cost pills. Move mouse away — tooltip disappears. Press Q/W/E/R while hovering — ability fires and tooltip hides.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn scenes/ui/combat/abilities_panel.gd
git commit -m "feat(combat): add CombatAbilityTooltip with hover display

Compact tooltip shows icon, name, total DMG, cooldown, cast time,
and costs. Reuses AbilityStatsDisplay in DAMAGE_TOTAL and TIMING_COSTS
modes."
```

---

### Task 6: Build CombatBuffTooltip, add BuffIcon hover, wire into CombatantInfoPanel

**Files:**
- Create: `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd`
- Create: `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn`
- Modify: `scenes/ui/combat/buff_icon/buff_icon.gd`
- Modify: `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`

- [ ] **Step 1: Create combat_buff_tooltip.gd**

Create `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd`:

```gdscript
class_name CombatBuffTooltip
extends PanelContainer

## CombatBuffTooltip
## Shows buff details on hover: name, description, duration, stacks.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const TOOLTIP_WIDTH: float = 220.0
const CARD_BG: Color = Color(0.239, 0.18, 0.133, 1.0)
const CARD_BORDER: Color = Color(0.549, 0.4, 0.278, 1.0)
const COLOR_GOLD: Color = Color("#D4A84A")
const COLOR_BEIGE: Color = Color("#F0E5D8")
const COLOR_TAN: Color = Color("#A89070")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _icon_rect: TextureRect
var _name_label: Label
var _desc_label: Label
var _duration_label: Label
var _stacks_label: Label
var _active_buff: ActiveBuff

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = TOOLTIP_WIDTH

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", style)

	_build_layout()

func _build_layout() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header: icon + name
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(32, 32)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", COLOR_BEIGE)
	_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03, 1))
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_name_label)

	# Description
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", COLOR_TAN)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_desc_label)

	# Meta row: duration + stacks
	var meta: HBoxContainer = HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 12)
	vbox.add_child(meta)

	_duration_label = Label.new()
	_duration_label.add_theme_font_size_override("font_size", 12)
	_duration_label.add_theme_color_override("font_color", COLOR_GOLD)
	_duration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(_duration_label)

	_stacks_label = Label.new()
	_stacks_label.add_theme_font_size_override("font_size", 12)
	_stacks_label.add_theme_color_override("font_color", COLOR_BEIGE)
	_stacks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(_stacks_label)

## Shows the tooltip for the given active buff.
func show_for_buff(buff: ActiveBuff) -> void:
	_active_buff = buff
	var data: BuffEffectData = buff.buff_data

	_icon_rect.texture = data.buff_icon
	_name_label.text = data.buff_id.capitalize()
	_desc_label.text = _build_description(data)
	_update_meta()

	visible = true

## Hides the tooltip.
func hide_tooltip() -> void:
	_active_buff = null
	visible = false

## Updates duration in real time while visible.
func _process(_delta: float) -> void:
	if visible and _active_buff:
		_update_meta()

func _update_meta() -> void:
	if _active_buff:
		_duration_label.text = "%.1fs remaining" % _active_buff.time_remaining
		if _active_buff.stack_count > 1:
			_stacks_label.text = "x%d stacks" % _active_buff.stack_count
			_stacks_label.visible = true
		else:
			_stacks_label.visible = false

## Positions to the right of the given control.
func position_beside(control: Control) -> void:
	var rect: Rect2 = control.get_global_rect()
	var x: float = rect.position.x + rect.size.x + 8.0
	var y: float = rect.position.y

	# Flip left if would overflow right
	if x + size.x > get_viewport_rect().size.x:
		x = rect.position.x - size.x - 8.0

	global_position = Vector2(x, y)

func _build_description(data: BuffEffectData) -> String:
	match data.buff_type:
		BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE:
			var parts: PackedStringArray = []
			for attr_type: CharacterAttributesData.AttributeType in data.attribute_modifiers:
				var mult: float = data.attribute_modifiers[attr_type]
				var attr_name: String = CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()
				parts.append("%s x%.1f" % [attr_name, mult])
			return ", ".join(parts)
		BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			return "%.1f damage per second" % data.dot_damage_per_tick
		BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER:
			return "Outgoing damage x%.1f" % data.damage_multiplier
		BuffEffectData.BuffType.INCOMING_DAMAGE_MODIFIER:
			return "Incoming damage x%.1f" % data.damage_multiplier
	return ""
```

- [ ] **Step 2: Create combat_buff_tooltip.tscn**

Create `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://yqkvsb5q7pab" path="res://assets/themes/pixel_theme.tres" id="2_theme"]

[node name="CombatBuffTooltip" type="PanelContainer"]
custom_minimum_size = Vector2(220, 0)
theme = ExtResource("2_theme")
script = ExtResource("1_script")
```

- [ ] **Step 3: Add hover signals to BuffIcon**

In `scenes/ui/combat/buff_icon/buff_icon.gd`, add signals and a stored reference to the buff data. Add after the existing signal section (there are none currently, so add after the class docstring):

After line 7 (`## Displays icon, duration, and stack count.`), add:

```gdscript

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal hovered(buff_data: BuffEffectData)
signal unhovered
```

Add a `_buff_data` variable after the existing state variables (after line 23 `var is_active: bool = false`):

```gdscript
var _buff_data: BuffEffectData
```

In the `setup` method, store the buff data and connect mouse signals. Replace the entire `setup` method:

```gdscript
func setup(buff_data: BuffEffectData, duration: float, stack_count: int) -> void:
	_buff_data = buff_data

	# Set Icon
	if buff_texture:
		buff_texture.texture = buff_data.buff_icon

	# Set State
	max_duration = duration
	time_left = duration
	is_active = true

	# Initial Update
	update_duration(duration)
	update_stacks(stack_count)

	# Enable mouse hover
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
```

Add the mouse handlers at the end of the file:

```gdscript
func _on_mouse_entered() -> void:
	if _buff_data:
		hovered.emit(_buff_data)

func _on_mouse_exited() -> void:
	unhovered.emit()
```

- [ ] **Step 4: Wire buff tooltip into CombatantInfoPanel**

In `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`, add tooltip management.

Add after the `buff_icon_scene` preload line (around line 30):

```gdscript
var buff_tooltip_scene: PackedScene = preload("res://scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn")
var _buff_tooltip: CombatBuffTooltip
```

In the `_on_buff_applied` method, after `active_buff_icons[buff_id] = icon`, add:

```gdscript
	icon.hovered.connect(_on_buff_icon_hovered.bind(buff_id))
	icon.unhovered.connect(_on_buff_icon_unhovered)
```

Add the tooltip handler methods before the `_cleanup_buffs` method:

```gdscript
func _on_buff_icon_hovered(buff_data: BuffEffectData, buff_id: String) -> void:
	if not buff_manager:
		return
	var buff: ActiveBuff = buff_manager._find_buff_by_id(buff_id)
	if not buff:
		return

	if not _buff_tooltip:
		_buff_tooltip = buff_tooltip_scene.instantiate()
		add_child(_buff_tooltip)

	_buff_tooltip.show_for_buff(buff)

	if active_buff_icons.has(buff_id):
		var icon: BuffIcon = active_buff_icons[buff_id]
		(func() -> void: _buff_tooltip.position_beside(icon)).call_deferred()

func _on_buff_icon_unhovered() -> void:
	if _buff_tooltip:
		_buff_tooltip.hide_tooltip()
```

In `_cleanup_buffs`, add before `active_buff_icons.clear()`:

```gdscript
	if _buff_tooltip:
		_buff_tooltip.hide_tooltip()
```

- [ ] **Step 5: Verify buff tooltips**

Run the game, enter combat, use the Enforce ability (self-buff). Hover over the buff icon that appears — tooltip should show name, "Strength x1.5, Spirit x1.5", and countdown timer. Move mouse away — tooltip disappears.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn scenes/ui/combat/buff_icon/buff_icon.gd scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd
git commit -m "feat(combat): add buff tooltips with live duration updates

Shows buff name, effect description, remaining time, and stack count.
Duration updates each frame while tooltip is visible."
```

---

### Task 7: Add atmosphere to combat view

**Files:**
- Modify: `scenes/combat/adventure_combat/adventure_combat.gd`

The Atmosphere scene is added programmatically as a child of AdventureCombat. It uses exported properties, which we set in code to match the adventure tilemap settings.

- [ ] **Step 1: Add atmosphere setup in adventure_combat.gd**

At the top of `adventure_combat.gd`, add after the `combatant_scene` preload:

```gdscript
var atmosphere_scene: PackedScene = preload("res://scenes/atmosphere/atmosphere.tscn")
```

Add a new variable after `enemy_combatant`:

```gdscript
var _atmosphere: Node
```

In the `_ready` method, add atmosphere creation:

```gdscript
func _ready() -> void:
	Log.info("AdventureCombat: Initialized")
	_setup_atmosphere()
```

Add the setup method after `_ready`:

```gdscript
func _setup_atmosphere() -> void:
	_atmosphere = atmosphere_scene.instantiate()
	# Match adventure tilemap settings
	_atmosphere.vignette_radius = 0.5
	_atmosphere.vignette_softness = 0.35
	_atmosphere.vignette_color = Color(0.0, 0.005, 0.025, 1.0)
	_atmosphere.cyan_mote_count = 25
	_atmosphere.warm_mote_count = 8
	# Insert at index 0 so it renders behind everything
	add_child(_atmosphere)
	move_child(_atmosphere, 0)
```

- [ ] **Step 2: Verify atmosphere appears in combat**

Run the game, enter combat. Verify: vignette darkening around edges, drifting mist sprites, and particle motes visible behind combatants.

- [ ] **Step 3: Commit**

```bash
git add scenes/combat/adventure_combat/adventure_combat.gd
git commit -m "feat(combat): add atmosphere to combat view

Instances Atmosphere scene with vignette, mist, and spirit motes
matching adventure tilemap settings."
```

---

### Task 8: Add keybinding hints to AbilityEquipSlot

**Files:**
- Modify: `scenes/abilities/equip_slot/equip_slot.gd`

- [ ] **Step 1: Add keybinding hint label to equip_slot.gd**

In `scenes/abilities/equip_slot/equip_slot.gd`, add the constant and variable after the existing vars:

```gdscript
const KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
var _key_hint_label: Label
```

In the `setup(index: int)` method, add at the end:

```gdscript
	_create_key_hint()
```

Add the method at the end of the file (before the last helper methods):

```gdscript
func _create_key_hint() -> void:
	if _slot_index < 0 or _slot_index >= KEY_LABELS.size():
		return
	if _key_hint_label:
		return

	_key_hint_label = Label.new()
	_key_hint_label.text = KEY_LABELS[_slot_index]
	_key_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_hint_label.add_theme_font_size_override("font_size", 11)
	_key_hint_label.add_theme_color_override("font_color", Color("#D4A84A"))
	_key_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_key_hint_label.add_theme_constant_override("outline_size", 2)

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	bg.border_color = Color("#D4A84A")
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4.0
	bg.content_margin_right = 5.0
	bg.content_margin_top = 0.0
	bg.content_margin_bottom = 1.0
	_key_hint_label.add_theme_stylebox_override("normal", bg)

	_key_hint_label.z_index = 3
	add_child(_key_hint_label)
	_key_hint_label.position = Vector2(-2, -2)
```

- [ ] **Step 2: Verify hints appear in abilities view**

Run the game, open abilities view (A key). The 4 equip slots should show Q/W/E/R badges in their top-left corners.

- [ ] **Step 3: Commit**

```bash
git add scenes/abilities/equip_slot/equip_slot.gd
git commit -m "feat(abilities): add Q/W/E/R keybinding hints to equip slots

Display-only hints that teach the player which slot maps to which
combat keybinding."
```

---

### Task 9: Update COMBAT.md to mark resolved items

**Files:**
- Modify: `docs/combat/COMBAT.md`

- [ ] **Step 1: Mark resolved UI items**

In `docs/combat/COMBAT.md`, in the "Work Remaining > UI" section, strike through the resolved items:

```markdown
- ~~`[HIGH]` Ability icons don't disable or visually indicate when the player can't afford the cost (not enough madra/stamina) — ability just silently fails to cast~~ *(Fixed — can't-afford visual state dims icon and turns cost labels red)*
- ~~`[HIGH]` No ability tooltips — hovering over an ability icon shows no information (cost, cooldown, damage, description). New players can't learn the system without them~~ *(Fixed — CombatAbilityTooltip shows on hover)*
- ~~`[MEDIUM]` No buff tooltips — hovering over a buff icon shows no information (effect, duration remaining, stacks)~~ *(Fixed — CombatBuffTooltip shows on hover with live duration)*
```

- [ ] **Step 2: Commit**

```bash
git add docs/combat/COMBAT.md
git commit -m "docs(combat): mark resolved UI items in COMBAT.md"
```
