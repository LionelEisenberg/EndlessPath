extends Node2D

@onready var tile_map: HexagonTileMapLayer = %HexagonTileMapLayer
@onready var character_body: CharacterBody2D = %CharacterBody2D

var current_adventure_action_data : AdventureActionData = null

func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureTilemap: ActionManager is missing!")

func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)
	
	current_adventure_action_data = action_data

	_generate_adventure_tilemap()

func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	current_adventure_action_data = null

	# TODO: Clear the tilemap for the adventure and reset the character to the starting position

func _generate_adventure_tilemap() -> void:
	pass

func _clear_adventure_tilemap() -> void:
	# TODO: Clear the tilemap for the adventure and reset the character to the starting position
	pass
