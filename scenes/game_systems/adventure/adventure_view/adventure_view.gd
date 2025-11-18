extends Control

@onready var adventure_tilemap : AdventureTilemap = %AdventureTilemap
@onready var combat : AdventureCombat = %AdventureCombat

@onready var tilemap_view : Control = %TilemapView
@onready var combat_view : Control = %CombatView


func _ready() -> void:
	if ActionManager:
		ActionManager.start_adventure.connect(start_adventure)
		ActionManager.stop_adventure.connect(stop_adventure)
	else:
		Log.critical("AdventureTilemap: ActionManager is missing!")
		
	if adventure_tilemap:
		adventure_tilemap.start_combat.connect(_on_start_combat)
	$Button2.pressed.connect(_on_stop_combat)

func start_adventure(action_data: AdventureActionData) -> void:
	adventure_tilemap.start_adventure(action_data)

func stop_adventure() -> void:
	adventure_tilemap.stop_adventure()

func _on_start_combat(encounter: AdventureEncounter) -> void:
	tilemap_view.visible = false
	combat_view.visible = true

func _on_stop_combat(encounter: AdventureEncounter = null, successful : bool = false) -> void:
	tilemap_view.visible = true
	combat_view.visible = false
	adventure_tilemap._stop_combat(encounter, successful)
	
