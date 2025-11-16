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
# MADRA MANAGEMENT
#-----------------------------------------------------------------------------

func add_madra(amount: float) -> void:
	var level = CultivationManager.get_core_density_level()
	var stage_res = CultivationManager._get_current_stage_resource()
	var max_madra = stage_res.get_max_madra(level) if stage_res else 0.0

	# Cap madra value within [0, max_madra]
	live_save_data.madra = clamp(live_save_data.madra + amount, 0.0, max_madra)
	madra_changed.emit(live_save_data.madra)

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

#-----------------------------------------------------------------------------
# GOLD MANAGEMENT
#-----------------------------------------------------------------------------

func add_gold(amount: float) -> void:	
	live_save_data.gold += amount
	gold_changed.emit(live_save_data.gold)

func spend_gold(amount: float) -> bool:
	if live_save_data.gold >= amount:
		live_save_data.gold -= amount
		gold_changed.emit(live_save_data.gold)
		return true
	return false
	
func set_gold(amount: float) -> void:
	live_save_data.set("gold", max(0.0, amount))
	gold_changed.emit(live_save_data.gold)

func get_gold() -> float:
	return live_save_data.gold

func can_afford_gold(amount: float) -> bool:
	return get_gold() >= amount
