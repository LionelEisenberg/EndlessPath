extends Node
## Holds the player's VitalsManager: a run's Health and Stamina, with their
## maxima and regen, and the player's Madra, which is ResourceManager's saved
## pool seen through it. Combat, the vitals plate, the technique dock and the
## dev tools all reach the player's vitals here.

## The player's vitals. reset_vitals() replaces it, so hold it only as long as
## a run.
var vitals_manager: VitalsManager

func _ready() -> void:
	_create_vitals_manager()

## Replaces the player's VitalsManager with a new one, built as at boot, so
## nothing of a run carries over: not its Health or Stamina, nor its regen.
## Madra is ResourceManager's saved pool and stays. The old one leaves the tree at once and is freed at the end of the
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
