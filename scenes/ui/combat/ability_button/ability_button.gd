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
@onready var _background_rect: TextureRect = %BackgroundRect
@onready var _key_hint_label: Label = %KeyHintLabel
@onready var _cost_strip: PanelContainer = %CostStrip
@onready var _madra_cost_label: Label = %MadraCostLabel
@onready var _stamina_cost_label: Label = %StaminaCostLabel
@onready var _health_cost_label: Label = %HealthCostLabel

var _border_default_modulate: Color = Color.WHITE
var _cost_labels: Array[Label] = []
var _madra_default_color: Color
var _stamina_default_color: Color
var _health_default_color: Color

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	cooldown_label.visible = false
	cooldown_progress_bar.visible = false
	cooldown_label.text = ""
	cooldown_progress_bar.value = 0.0

	_border_default_modulate = _background_rect.modulate
	_madra_default_color = _madra_cost_label.get_theme_color("font_color")
	_stamina_default_color = _stamina_cost_label.get_theme_color("font_color")
	_health_default_color = _health_cost_label.get_theme_color("font_color")
	_key_hint_label.get_parent().visible = false
	_cost_strip.visible = false

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

	_set_key_hint()
	_set_cost_strip()

func _exit_tree() -> void:
	if ability_instance and is_instance_valid(ability_instance):
		if ability_instance.cooldown_started.is_connected(_on_cooldown_started):
			ability_instance.cooldown_started.disconnect(_on_cooldown_started)
		if ability_instance.cooldown_updated.is_connected(_on_cooldown_updated):
			ability_instance.cooldown_updated.disconnect(_on_cooldown_updated)
		if ability_instance.cooldown_ready.is_connected(_on_cooldown_ready):
			ability_instance.cooldown_ready.disconnect(_on_cooldown_ready)
		if ability_instance.cast_started.is_connected(_on_cast_started):
			ability_instance.cast_started.disconnect(_on_cast_started)
		if ability_instance.cast_finished.is_connected(_on_cast_finished):
			ability_instance.cast_finished.disconnect(_on_cast_finished)

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

func _set_key_hint() -> void:
	if _slot_index < 0 or _slot_index >= KEY_LABELS.size():
		_key_hint_label.get_parent().visible = false
		return

	_key_hint_label.text = KEY_LABELS[_slot_index]
	_key_hint_label.get_parent().visible = true

#-----------------------------------------------------------------------------
# COST STRIP
#-----------------------------------------------------------------------------

func _set_cost_strip() -> void:
	if not ability_instance:
		return

	var data: AbilityData = ability_instance.ability_data
	_cost_labels.clear()

	if data.madra_cost > 0:
		_madra_cost_label.text = "%.0f" % data.madra_cost
		_madra_cost_label.visible = true
		_cost_labels.append(_madra_cost_label)
	else:
		_madra_cost_label.visible = false

	if data.stamina_cost > 0:
		_stamina_cost_label.text = "%.0f" % data.stamina_cost
		_stamina_cost_label.visible = true
		_cost_labels.append(_stamina_cost_label)
	else:
		_stamina_cost_label.visible = false

	if data.health_cost > 0:
		_health_cost_label.text = "%.0f" % data.health_cost
		_health_cost_label.visible = true
		_cost_labels.append(_health_cost_label)
	else:
		_health_cost_label.visible = false

	_cost_strip.visible = not _cost_labels.is_empty()

#-----------------------------------------------------------------------------
# AFFORDABILITY VISUALS
#-----------------------------------------------------------------------------

func _update_affordability_visuals(can_afford: bool) -> void:
	if can_afford:
		button.modulate.a = 1.0
		_background_rect.modulate = _border_default_modulate
		_madra_cost_label.add_theme_color_override("font_color", _madra_default_color)
		_stamina_cost_label.add_theme_color_override("font_color", _stamina_default_color)
		_health_cost_label.add_theme_color_override("font_color", _health_default_color)
	else:
		button.modulate.a = 0.35
		_background_rect.modulate = BORDER_CANT_AFFORD
		if _vitals_manager and ability_instance:
			var data: AbilityData = ability_instance.ability_data
			if data.madra_cost > _vitals_manager.current_madra:
				_madra_cost_label.add_theme_color_override("font_color", COLOR_CANT_AFFORD)
			else:
				_madra_cost_label.add_theme_color_override("font_color", _madra_default_color)
			if data.stamina_cost > _vitals_manager.current_stamina:
				_stamina_cost_label.add_theme_color_override("font_color", COLOR_CANT_AFFORD)
			else:
				_stamina_cost_label.add_theme_color_override("font_color", _stamina_default_color)
			if data.health_cost > _vitals_manager.current_health:
				_health_cost_label.add_theme_color_override("font_color", COLOR_CANT_AFFORD)
			else:
				_health_cost_label.add_theme_color_override("font_color", _health_default_color)

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
