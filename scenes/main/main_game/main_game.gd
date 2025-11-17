extends Node2D

@export var log_print_level: Log.Event = Log.Event.DEBUG


func _ready() -> void:
	# Set the log print level
	Log.set_print_level(log_print_level)
