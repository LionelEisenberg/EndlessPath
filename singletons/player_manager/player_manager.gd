extends Node

var vitals_manager: VitalsManager

func _ready() -> void:
	vitals_manager = VitalsManager.new()
	vitals_manager.is_player = true
	vitals_manager.name = "PlayerVitalsManager"
	add_child(vitals_manager)
