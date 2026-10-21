class_name CastBar
extends PanelContainer

## CastBar
## Shows the ability a combatant is currently casting: icon, name, a bar
## that fills toward release, and time remaining. Fades out when idle but
## keeps its layout space so surrounding UI never jumps. Optionally ramps
## toward a danger color and pulses just before the cast lands (enemy intent).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const COLOR_INTERRUPTED: Color = Color("#e86a5c")

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Fill stylebox for the progress bar (a StyleBoxFlat to allow the danger ramp).
@export var fill_style: StyleBox
## Fill color reached at the end of the cast. Leave transparent to disable the ramp.
@export var danger_color: Color = Color(0, 0, 0, 0)
## Seconds before release at which the panel starts pulsing (0 disables it).
@export var imminent_time: float = 0.0

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _time_label: Label = %TimeLabel
@onready var _bar: ProgressBar = %Bar

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _ability_manager: CombatAbilityManager
var _active: CombatAbilityInstance
var _duration: float = 0.0
var _fade_tween: Tween
var _pulse_tween: Tween
var _name_default_color: Color
var _fill: StyleBoxFlat
var _base_fill_color: Color
var _base_border_color: Color
var _is_imminent: bool = false

func _ready() -> void:
	# Own copy of the fill so the danger ramp never touches the shared resource.
	var source: StyleBox = fill_style if fill_style else _bar.get_theme_stylebox("fill")
	_fill = source.duplicate() as StyleBoxFlat
	if _fill:
		_base_fill_color = _fill.bg_color
		_base_border_color = _fill.border_color
		_bar.add_theme_stylebox_override("fill", _fill)
	_name_default_color = _name_label.get_theme_color("font_color")
	modulate.a = 0.0

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Listens to every ability of the given manager. Pass null to clear.
func bind(ability_manager: CombatAbilityManager) -> void:
	unbind()
	_ability_manager = ability_manager
	if not _ability_manager:
		return
	for instance: CombatAbilityInstance in _ability_manager.abilities:
		instance.cast_started.connect(_on_cast_started)
		instance.cast_updated.connect(_on_cast_updated)
		instance.cast_finished.connect(_on_cast_finished)
		instance.cast_cancelled.connect(_on_cast_cancelled)

## Disconnects from the current manager and hides the bar immediately.
func unbind() -> void:
	if _ability_manager and is_instance_valid(_ability_manager):
		for instance: CombatAbilityInstance in _ability_manager.abilities:
			if not is_instance_valid(instance):
				continue
			if instance.cast_started.is_connected(_on_cast_started):
				instance.cast_started.disconnect(_on_cast_started)
			if instance.cast_updated.is_connected(_on_cast_updated):
				instance.cast_updated.disconnect(_on_cast_updated)
			if instance.cast_finished.is_connected(_on_cast_finished):
				instance.cast_finished.disconnect(_on_cast_finished)
			if instance.cast_cancelled.is_connected(_on_cast_cancelled):
				instance.cast_cancelled.disconnect(_on_cast_cancelled)
	_ability_manager = null
	_active = null
	_kill_fade()
	_stop_pulse()
	modulate.a = 0.0

#-----------------------------------------------------------------------------
# CAST HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	_active = instance
	_duration = duration
	_icon.texture = instance.ability_data.icon
	_icon.visible = _icon.texture != null
	_name_label.text = instance.ability_data.ability_name
	_name_label.add_theme_color_override("font_color", _name_default_color)
	_bar.max_value = duration
	_bar.value = 0.0
	_time_label.text = "%.1fs" % duration
	_set_danger(0.0)
	_stop_pulse()
	_fade_to(1.0, 0.1)

func _on_cast_updated(instance: CombatAbilityInstance, time_left: float) -> void:
	if instance != _active:
		return
	_bar.value = _duration - time_left
	_time_label.text = "%.1fs" % maxf(time_left, 0.0)
	if danger_color.a > 0.0 and _duration > 0.0:
		var progress: float = clampf(_bar.value / _duration, 0.0, 1.0)
		_set_danger(smoothstep(0.5, 1.0, progress))
	if imminent_time > 0.0 and time_left <= imminent_time and not _is_imminent:
		_start_pulse()

func _on_cast_finished(instance: CombatAbilityInstance) -> void:
	if instance != _active:
		return
	_active = null
	_bar.value = _bar.max_value
	_time_label.text = ""
	_stop_pulse()
	_flash_release()
	_fade_to(0.0, 0.3, 0.15)

func _on_cast_cancelled(instance: CombatAbilityInstance) -> void:
	if instance != _active:
		return
	_active = null
	_name_label.text = "Interrupted"
	_name_label.add_theme_color_override("font_color", COLOR_INTERRUPTED)
	_time_label.text = ""
	_stop_pulse()
	_shake()
	_fade_to(0.0, 0.35, 0.45)

#-----------------------------------------------------------------------------
# ANIMATION
#-----------------------------------------------------------------------------

func _fade_to(alpha: float, duration: float, delay: float = 0.0) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, duration).set_delay(delay)

func _shake() -> void:
	var tween: Tween = create_tween()
	for offset: float in [6.0, -5.0, 3.0, 0.0]:
		tween.tween_property(_bar, "position:x", offset, 0.04)

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

## Blends the fill from its base color toward `danger_color` (0 = base, 1 = danger).
func _set_danger(amount: float) -> void:
	if not _fill:
		return
	if danger_color.a <= 0.0:
		amount = 0.0
	_fill.bg_color = _base_fill_color.lerp(danger_color, amount)
	_fill.border_color = _base_border_color.lerp(danger_color.lightened(0.3), amount)

## Fast throb of the panel when the cast is about to land.
func _start_pulse() -> void:
	_is_imminent = true
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "self_modulate", Color(1.8, 1.5, 1.4, 1.0), 0.12)
	_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, 0.12)

func _stop_pulse() -> void:
	_is_imminent = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	self_modulate = Color.WHITE

## Bright pop when the cast releases.
func _flash_release() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_bar, "modulate", Color(2.2, 2.2, 2.2, 1.0), 0.05)
	tween.tween_property(_bar, "modulate", Color.WHITE, 0.2)
