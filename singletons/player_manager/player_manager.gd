extends Node

var vitals_manager: VitalsManager

func _ready() -> void:
	_create_vitals_manager()

## Replaces the player's VitalsManager with a new one, built as at boot, so
## nothing of a run carries over: not its Health, Stamina or Madra, nor its
## regen. The old one leaves the tree at once and is freed at the end of the
## frame, so a board that still holds it never reads a freed object meanwhile.
func reset_vitals() -> void:
	if is_instance_valid(vitals_manager):
		remove_child(vitals_manager)
		vitals_manager.queue_free()
	_create_vitals_manager()

func _create_vitals_manager() -> void:
	vitals_manager = VitalsManager.new()
	vitals_manager.is_player = true
	vitals_manager.name = "PlayerVitalsManager"
	add_child(vitals_manager)
