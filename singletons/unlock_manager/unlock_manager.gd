# UnlockManager.gd
# AUTOLOADED SINGLETON
extends Node

## The enum for all game systems
enum GameSystem {
	ZONE,
	CYCLING,
	SCRIPTING,
	ELIXIR_MAKING,
	SOULSMITHING,
	ADVENTURING
}

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal game_systems_updated(unlocked_game_systems: Array[GameSystem])

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------
var live_save_data: SaveGameData = null

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_initialize_from_save)
		_initialize_from_save()
	else:
		printerr("CRITICAL - UnlockManager: Could not get save_game_data from PersistenceManager on ready!")

func _initialize_from_save() -> void:
	game_systems_updated.emit(live_save_data.unlocked_game_systems)

#-----------------------------------------------------------------------------
# GAME SYSTEM UNLOCK FUNCTIONS
#-----------------------------------------------------------------------------

## The main function to unlock a new game system.
func unlock_game_system(system: GameSystem):
	if system not in live_save_data.unlocked_game_systems:
		live_save_data.unlocked_game_systems.append(system)
		game_systems_updated.emit(live_save_data.unlocked_game_systems)

## Returns the full list of unlocked game system enums.
func get_unlocked_game_systems() -> Array[GameSystem]:
	return live_save_data.unlocked_game_systems

## A public function for other nodes to check a game system's status.
func is_game_system_unlocked(system: GameSystem) -> bool:
	return system in live_save_data.unlocked_game_systems
