extends Node2D

@onready var tile_map: TileMapLayer = %TileMapLayer
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
	

func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
