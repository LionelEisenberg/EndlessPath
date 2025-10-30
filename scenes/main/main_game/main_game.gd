extends Node2D

@export var reset_save_data : bool = false

func _ready() -> void:
	if reset_save_data and PersistenceManager:
		PersistenceManager.load_new_save_data()
