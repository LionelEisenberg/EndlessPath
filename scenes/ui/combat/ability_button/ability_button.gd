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
