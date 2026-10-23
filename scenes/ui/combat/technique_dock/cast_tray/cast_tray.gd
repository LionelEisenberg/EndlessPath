class_name CastTray
extends Control

## The cast tray over the technique dock (spec: The technique dock, Cast tray):
## while the player casts a technique, its name, the jade cast rod filling
## toward the release and the time left to a tenth, its decimal point in Yatra
## One. It shows outright when a cast starts, steps with the cast and hides
## outright when the cast lands or is cancelled. bind() follows every ability
## instance of the player's CombatAbilityManager; unbind() lets them go and
## hides the tray. It never takes the pointer.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The time left, to a tenth of a second.
const TIME_FORMAT: String = "%.1f s"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %NameLabel
@onready var _cast_rod: LacquerRod = %CastRod
@onready var _time_text: RichTextLabel = %TimeText

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The instances bind() connected, which unbind() disconnects.
var _bound_instances: Array[CombatAbilityInstance] = []
## The instance whose cast the tray shows, and that cast's length.
var _active: CombatAbilityInstance = null
var _duration: float = 0.0

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Follows the casts of every instance of ability_manager. A manager bound
## earlier is let go first. Null just unbinds.
func bind(ability_manager: CombatAbilityManager) -> void:
	unbind()
	if ability_manager == null:
		return
	for instance: CombatAbilityInstance in ability_manager.abilities:
		instance.cast_started.connect(_on_cast_started)
		instance.cast_updated.connect(_on_cast_updated)
		instance.cast_finished.connect(_on_cast_finished)
		instance.cast_cancelled.connect(_on_cast_cancelled)
		_bound_instances.append(instance)

## Lets go of the bound instances and hides the tray at once.
func unbind() -> void:
	for instance: CombatAbilityInstance in _bound_instances:
		if not is_instance_valid(instance):
			continue
		for connection: Array in [
			[instance.cast_started, _on_cast_started],
			[instance.cast_updated, _on_cast_updated],
			[instance.cast_finished, _on_cast_finished],
			[instance.cast_cancelled, _on_cast_cancelled],
		]:
			var sig: Signal = connection[0]
			if sig.is_connected(connection[1]):
				sig.disconnect(connection[1])
	_bound_instances.clear()
	_active = null
	hide()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The rod at 1 - time left / the cast's length, and the time left.
func _show_time_left(time_left: float) -> void:
	_cast_rod.set_fraction(1.0 - time_left / _duration if _duration > 0.0 else 1.0)
	_time_text.text = LacquerText.decimal_bbcode(TIME_FORMAT % maxf(time_left, 0.0))

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	_active = instance
	_duration = duration
	_name_label.text = instance.ability_data.ability_name
	_show_time_left(duration)
	show()

func _on_cast_updated(instance: CombatAbilityInstance, time_left: float) -> void:
	if instance != _active:
		return
	_show_time_left(time_left)

func _on_cast_finished(instance: CombatAbilityInstance) -> void:
	if instance != _active:
		return
	_active = null
	hide()

func _on_cast_cancelled(instance: CombatAbilityInstance) -> void:
	if instance != _active:
		return
	_active = null
	hide()
