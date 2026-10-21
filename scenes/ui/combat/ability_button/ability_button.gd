class_name AbilityButton
extends MarginContainer

## AbilityButton
## One technique slot on the action bar. A slot is EMPTY, shows a PREVIEW of
## the equipped ability outside combat, or is ACTIVE and bound to a combat
## ability instance (cooldown sweep, casting glow, costs and affordability).

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal pressed
signal hovered(ability_data: AbilityData)
signal unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

enum SlotState { EMPTY, PREVIEW, ACTIVE }

const FALLBACK_KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
const COLOR_CANT_AFFORD: Color = Color("#E06060")
const BORDER_CANT_AFFORD: Color = Color("#553333")
const HOVER_SCALE: Vector2 = Vector2(1.06, 1.06)
const HOVER_BRIGHTNESS: float = 1.2
const PREVIEW_MODULATE: Color = Color(0.8, 0.8, 0.8, 0.75)
const EMPTY_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.35)

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var ability_instance: CombatAbilityInstance
var state: SlotState = SlotState.EMPTY
var _ability_data: AbilityData
var _slot_index: int = -1
var _vitals_manager: VitalsManager
var _is_on_cooldown: bool = false
var _is_casting: bool = false
var _is_hovered: bool = false

var _border_default_modulate: Color = Color.WHITE
var _cost_labels: Array[Label] = []
var _madra_default_color: Color
var _stamina_default_color: Color
var _health_default_color: Color
var _scale_tween: Tween
var _glow_tween: Tween

@onready var button: TextureButton = %Button
@onready var cooldown_progress_bar: TextureProgressBar = %CooldownProgressBar
@onready var cooldown_label: Label = %CooldownLabel
@onready var _background_rect: TextureRect = %BackgroundRect
@onready var _cast_glow: Panel = %CastGlow
@onready var _key_hint_label: Label = %KeyHintLabel
@onready var _cost_strip: PanelContainer = %CostStrip
@onready var _madra_cost_label: Label = %MadraCostLabel
@onready var _stamina_cost_label: Label = %StaminaCostLabel
@onready var _health_cost_label: Label = %HealthCostLabel
@onready var _madra_pip: ColorRect = %MadraPip
@onready var _stamina_pip: ColorRect = %StaminaPip
@onready var _health_pip: ColorRect = %HealthPip

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_border_default_modulate = _background_rect.modulate
	_madra_default_color = _madra_cost_label.get_theme_color("font_color")
	_stamina_default_color = _stamina_cost_label.get_theme_color("font_color")
	_health_default_color = _health_cost_label.get_theme_color("font_color")
	_hide_cooldown()
	_cast_glow.visible = false
	if state == SlotState.EMPTY:
		show_empty(_slot_index)

func _exit_tree() -> void:
	_unbind_instance()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Shows an empty slot: just the frame and its key hint.
func show_empty(slot_index: int) -> void:
	_unbind_instance()
	state = SlotState.EMPTY
	_slot_index = slot_index
	_ability_data = null
	button.visible = false
	_cost_strip.visible = false
	modulate = EMPTY_MODULATE
	_set_key_hint()
	_reset_affordability_visuals()

## Shows an equipped ability outside combat: icon, costs and tooltip, not usable.
func show_preview(data: AbilityData, slot_index: int) -> void:
	_unbind_instance()
	state = SlotState.PREVIEW
	_slot_index = slot_index
	_ability_data = data
	_set_icon(data.icon)
	button.disabled = true
	modulate = PREVIEW_MODULATE
	_set_key_hint()
	_set_cost_strip()
	_reset_affordability_visuals()

## Binds the slot to a combat ability instance.
func setup(instance: CombatAbilityInstance, slot_index: int = -1, vitals_manager: VitalsManager = null) -> void:
	_unbind_instance()
	state = SlotState.ACTIVE
	ability_instance = instance
	_ability_data = instance.ability_data
	_slot_index = slot_index
	_vitals_manager = vitals_manager
	_set_icon(_ability_data.icon)
	modulate = Color.WHITE

	ability_instance.cooldown_started.connect(_on_cooldown_started)
	ability_instance.cooldown_updated.connect(_on_cooldown_updated)
	ability_instance.cooldown_ready.connect(_on_cooldown_ready)
	ability_instance.cast_started.connect(_on_cast_started)
	ability_instance.cast_finished.connect(_on_cast_finished)
	ability_instance.cast_cancelled.connect(_on_cast_cancelled)

	# Abilities start on an initial cooldown before the HUD binds to them.
	_is_on_cooldown = instance.cooldown_timer != null and not instance.cooldown_timer.is_stopped()
	button.disabled = not instance.is_ready()
	if _is_on_cooldown:
		_show_cooldown()

	_set_key_hint()
	_set_cost_strip()

## Brief press "punch" — called for both clicks and keybinds.
func flash_press() -> void:
	_background_rect.pivot_offset = _background_rect.size / 2.0
	_kill(_scale_tween)
	_scale_tween = create_tween()
	_scale_tween.tween_property(_background_rect, "scale", Vector2(0.92, 0.92), 0.05)
	_scale_tween.tween_property(_background_rect, "scale", _rest_scale(), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

#-----------------------------------------------------------------------------
# PROCESS — Affordability Check
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if state != SlotState.ACTIVE or not _vitals_manager:
		return
	if _is_on_cooldown or _is_casting:
		return
	_update_affordability_visuals(_ability_data.can_afford(_vitals_manager))

#-----------------------------------------------------------------------------
# VISUAL SETUP
#-----------------------------------------------------------------------------

func _set_icon(icon: Texture2D) -> void:
	button.texture_normal = icon
	button.texture_pressed = icon
	button.texture_disabled = icon
	button.texture_hover = icon
	button.texture_focused = icon
	button.visible = true

func _set_key_hint() -> void:
	var key_text: String = _get_key_label()
	_key_hint_label.text = key_text
	_key_hint_label.get_parent().visible = not key_text.is_empty()

## Reads the slot's key from the InputMap so the hint follows remaps.
func _get_key_label() -> String:
	if _slot_index < 0:
		return ""
	var action: String = "ability_slot_%d" % (_slot_index + 1)
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			var key_event: InputEventKey = event as InputEventKey
			if not key_event:
				continue
			var keycode: Key = key_event.keycode
			if keycode == KEY_NONE:
				keycode = DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode)
			var label: String = OS.get_keycode_string(keycode)
			if not label.is_empty():
				return label
	return FALLBACK_KEY_LABELS[_slot_index] if _slot_index < FALLBACK_KEY_LABELS.size() else ""

func _set_cost_strip() -> void:
	_cost_labels.clear()
	_set_cost(_madra_cost_label, _madra_pip, _ability_data.madra_cost)
	_set_cost(_stamina_cost_label, _stamina_pip, _ability_data.stamina_cost)
	_set_cost(_health_cost_label, _health_pip, _ability_data.health_cost)
	_cost_strip.visible = not _cost_labels.is_empty()

func _set_cost(label: Label, pip: ColorRect, cost: float) -> void:
	label.visible = cost > 0
	pip.visible = label.visible
	if label.visible:
		label.text = "%.0f" % cost
		_cost_labels.append(label)

#-----------------------------------------------------------------------------
# AFFORDABILITY VISUALS
#-----------------------------------------------------------------------------

func _update_affordability_visuals(can_afford: bool) -> void:
	if can_afford:
		_reset_affordability_visuals()
		return
	button.modulate.a = 0.35
	_background_rect.modulate = BORDER_CANT_AFFORD
	_set_cost_color(_madra_cost_label, _madra_default_color, _ability_data.madra_cost > _vitals_manager.current_madra)
	_set_cost_color(_stamina_cost_label, _stamina_default_color, _ability_data.stamina_cost > _vitals_manager.current_stamina)
	_set_cost_color(_health_cost_label, _health_default_color, _ability_data.health_cost > _vitals_manager.current_health)

func _reset_affordability_visuals() -> void:
	button.modulate.a = 1.0
	_background_rect.modulate = _border_default_modulate
	_set_cost_color(_madra_cost_label, _madra_default_color, false)
	_set_cost_color(_stamina_cost_label, _stamina_default_color, false)
	_set_cost_color(_health_cost_label, _health_default_color, false)

func _set_cost_color(label: Label, default_color: Color, cant_afford: bool) -> void:
	label.add_theme_color_override("font_color", COLOR_CANT_AFFORD if cant_afford else default_color)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_button_pressed() -> void:
	if state == SlotState.ACTIVE:
		pressed.emit()

func _on_mouse_entered() -> void:
	if state == SlotState.EMPTY:
		return
	_is_hovered = true
	_tween_scale(HOVER_SCALE, 0.08)
	button.self_modulate = Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, 1.0)
	hovered.emit(_ability_data)

func _on_mouse_exited() -> void:
	if not _is_hovered:
		return
	_is_hovered = false
	_tween_scale(Vector2.ONE, 0.12)
	button.self_modulate = Color.WHITE
	unhovered.emit()

func _on_cooldown_started(_duration: float) -> void:
	_is_on_cooldown = true
	button.disabled = true
	button.modulate.a = 1.0
	_show_cooldown()

func _on_cooldown_updated(time_left: float) -> void:
	_show_cooldown()
	cooldown_label.text = "%.1f" % time_left
	cooldown_progress_bar.value = time_left / maxf(_ability_data.base_cooldown, 0.001)

func _on_cooldown_ready() -> void:
	_is_on_cooldown = false
	button.disabled = false
	_hide_cooldown()
	_pulse()

func _on_cast_started(_instance: CombatAbilityInstance, _duration: float) -> void:
	_is_casting = true
	_set_casting_glow(true)

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_set_casting_glow(false)

func _on_cast_cancelled(_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_set_casting_glow(false)

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

func _unbind_instance() -> void:
	if ability_instance and is_instance_valid(ability_instance):
		for pair: Array in [
			[ability_instance.cooldown_started, _on_cooldown_started],
			[ability_instance.cooldown_updated, _on_cooldown_updated],
			[ability_instance.cooldown_ready, _on_cooldown_ready],
			[ability_instance.cast_started, _on_cast_started],
			[ability_instance.cast_finished, _on_cast_finished],
			[ability_instance.cast_cancelled, _on_cast_cancelled],
		]:
			var sig: Signal = pair[0]
			if sig.is_connected(pair[1]):
				sig.disconnect(pair[1])
	ability_instance = null
	_vitals_manager = null
	_is_on_cooldown = false
	_is_casting = false
	if is_node_ready():
		_hide_cooldown()
		_set_casting_glow(false)

func _show_cooldown() -> void:
	cooldown_label.visible = true
	cooldown_progress_bar.visible = true

func _hide_cooldown() -> void:
	cooldown_label.visible = false
	cooldown_progress_bar.visible = false

func _set_casting_glow(is_on: bool) -> void:
	_kill(_glow_tween)
	_cast_glow.visible = is_on
	if is_on:
		_cast_glow.modulate.a = 1.0
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_cast_glow, "modulate:a", 0.45, 0.3).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(_cast_glow, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func _pulse() -> void:
	_background_rect.pivot_offset = _background_rect.size / 2.0
	_kill(_scale_tween)
	var rest: Vector2 = _rest_scale()
	_scale_tween = create_tween()
	_scale_tween.tween_property(_background_rect, "scale", rest * 1.1, 0.08).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_background_rect, "scale", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tween_scale(target: Vector2, duration: float) -> void:
	_background_rect.pivot_offset = _background_rect.size / 2.0
	_kill(_scale_tween)
	_scale_tween = create_tween()
	_scale_tween.tween_property(_background_rect, "scale", target, duration).set_ease(Tween.EASE_OUT)

func _rest_scale() -> Vector2:
	return HOVER_SCALE if _is_hovered else Vector2.ONE

func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
