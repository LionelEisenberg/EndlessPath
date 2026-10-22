# ResourceManager.gd
# AUTOLOADED SINGLETON
extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal madra_changed(new_amount: float)
signal gold_changed(new_amount: float)

#-----------------------------------------------------------------------------
# ENUMS & CONSTANTS
#-----------------------------------------------------------------------------
enum ResourceType {
	# Core Resources
	MADRA,
	GOLD
}

static var RESOURCE_NAMES = {
	ResourceType.MADRA: "Madra",
	ResourceType.GOLD: "Gold"
}

#-----------------------------------------------------------------------------
# RESOURCE DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		Log.critical("ResourceManager: Could not get save_game_data from PersistenceManager on ready!")
	
	if not CultivationManager:
		Log.critical("ResourceManager: CultivationManager is missing!")

func _update_resources() -> void:
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("ResourceManager: live_save_data is null in _update_resources!")
		return
	
	# Emit signals to update UI
	madra_changed.emit(live_save_data.madra)
	gold_changed.emit(live_save_data.gold)

#-----------------------------------------------------------------------------
# GENERAL RESOURCE MANAGEMENT
#-----------------------------------------------------------------------------

## Adds an amount of a resource. A quiet award skips the player-facing log line.
func award_resource(resource_type: ResourceType, amount: float, quiet: bool = false) -> void:
	match resource_type:
		ResourceType.MADRA:
			add_madra(amount, quiet)
		ResourceType.GOLD:
			add_gold(amount, quiet)
		_:
			Log.error("ResourceManager: Unknown resource type: %s" % resource_type)

#-----------------------------------------------------------------------------
# MADRA MANAGEMENT
#-----------------------------------------------------------------------------

## Adds Madra, capped to [0, max Madra]. Logs "Gained N Madra" with the amount
## actually added, unless quiet or less than 1 was added (so a capped add is silent).
func add_madra(amount: float, quiet: bool = false) -> void:
	var before: float = live_save_data.madra
	live_save_data.madra = clamp(before + amount, 0.0, CultivationManager.get_max_madra())
	madra_changed.emit(live_save_data.madra)

	# Snapped: (63.1 + 1.0) - 63.1 is 0.99999... in floating point.
	var added: float = snappedf(live_save_data.madra - before, 0.001)
	if LogManager and not quiet and added >= 1.0:
		LogManager.log_message("[color=cyan]Gained %d Madra[/color]" % int(added))

func spend_madra(amount: float) -> bool:
	if live_save_data.madra >= amount:
		live_save_data.madra -= amount
		madra_changed.emit(live_save_data.madra)
		return true
	return false

func set_madra(amount: float) -> void:
	live_save_data.madra = max(0.0, amount)
	madra_changed.emit(live_save_data.madra)

func get_madra() -> float:
	return live_save_data.madra

func can_afford_madra(amount: float) -> bool:
	return get_madra() >= amount

## Get the maximum Madra the player can bring into an adventure (Foundation capacity).
func get_adventure_madra_capacity() -> float:
	return CharacterManager.get_total_attributes_data().get_max_madra()

## Get the actual Madra budget for an adventure (limited by current pool).
func get_adventure_madra_budget() -> float:
	return min(get_adventure_madra_capacity(), get_madra())

## Get the minimum Madra required to start an adventure (50% of capacity).
func get_adventure_madra_threshold() -> float:
	return get_adventure_madra_capacity() * 0.5

## Check if the player has enough Madra to start an adventure.
func can_start_adventure() -> bool:
	return get_madra() >= get_adventure_madra_threshold()

#-----------------------------------------------------------------------------
# GOLD MANAGEMENT
#-----------------------------------------------------------------------------

## Adds gold. Logs "Gained N Gold" unless quiet.
func add_gold(amount: float, quiet: bool = false) -> void:
	live_save_data.gold += amount
	gold_changed.emit(live_save_data.gold)

	if LogManager and not quiet:
		LogManager.log_message("[color=gold]Gained %d Gold[/color]" % int(amount))

func spend_gold(amount: float) -> bool:
	if live_save_data.gold >= amount:
		live_save_data.gold -= amount
		gold_changed.emit(live_save_data.gold)
		
		if LogManager:
			LogManager.log_message("[color=gold]Spent %d Gold[/color]" % int(amount))
			
		return true
	return false
	
func set_gold(amount: float) -> void:
	live_save_data.set("gold", max(0.0, amount))
	gold_changed.emit(live_save_data.gold)

func get_gold() -> float:
	return live_save_data.gold

func can_afford_gold(amount: float) -> bool:
	return get_gold() >= amount
