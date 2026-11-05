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
	CharacterManager.stats_changed.connect(_on_stats_changed)

## Binds the live save, at start and after each save reset. A pool above the
## max (a save from before the one max, or from more Mind gear) loads at the
## max. Both resources are announced each time, cut or not: the screens and the
## unlock sweep re-read them on these signals.
func _update_resources() -> void:
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("ResourceManager: live_save_data is null in _update_resources!")
		return

	if _clamp_to_max():
		Log.info("ResourceManager: Madra was past its max of %d. Loaded at the max" % int(get_max_madra()))

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

## Adds Madra, held to [0, max], and returns the amount actually added (0 at the
## max). Logs "Gained N Madra" with that amount, unless quiet or less than 1 was
## added (so an add at the max is silent).
func add_madra(amount: float, quiet: bool = false) -> float:
	var before: float = live_save_data.madra
	live_save_data.madra = clampf(before + amount, 0.0, get_max_madra())
	madra_changed.emit(live_save_data.madra)

	# Snapped: (63.1 + 1.0) - 63.1 is 0.99999... in floating point.
	var added: float = snappedf(live_save_data.madra - before, 0.001)
	if LogManager and not quiet and added >= 1.0:
		LogManager.log_message("[color=cyan]Gained %d Madra[/color]" % int(added))
	return added

## Spends `amount` of Madra and returns true when the pool holds that much.
## Otherwise it spends nothing and returns false. Logs nothing.
func spend_madra(amount: float) -> bool:
	if live_save_data.madra >= amount:
		live_save_data.madra -= amount
		madra_changed.emit(live_save_data.madra)
		return true
	return false

## Sets the pool to `amount`, held to [0, max]. Logs nothing.
func set_madra(amount: float) -> void:
	live_save_data.madra = clampf(amount, 0.0, get_max_madra())
	madra_changed.emit(live_save_data.madra)

## The Madra in the pool.
func get_madra() -> float:
	return live_save_data.madra

## The most Madra the pool holds: the max Madra stat (Mind x 10, then its
## modifiers). Every Madra readout shows the pool against it.
func get_max_madra() -> float:
	return CharacterManager.get_stat(StatModifierData.Stat.MAX_MADRA)

## The Madra a run needs to start: half the max, so Mind and gear move it.
func get_adventure_madra_threshold() -> float:
	return get_max_madra() * 0.5

## True when the pool holds at least the adventure threshold.
func can_start_adventure() -> bool:
	return get_madra() >= get_adventure_madra_threshold()

## Lowers a pool above the max to the max, emitting nothing. Returns whether
## it did.
func _clamp_to_max() -> bool:
	var max_madra: float = get_max_madra()
	if live_save_data.madra <= max_madra:
		return false
	live_save_data.madra = max_madra
	return true

## A max that drops brings the pool down. On a save reset CharacterManager
## announces the new save's stats before this binds it: skip, as
## _update_resources() clamps once it has.
func _on_stats_changed() -> void:
	if live_save_data == null or CharacterManager.live_save_data != live_save_data:
		return
	if _clamp_to_max():
		madra_changed.emit(live_save_data.madra)

#-----------------------------------------------------------------------------
# GOLD MANAGEMENT
#-----------------------------------------------------------------------------

## Adds gold. Logs "Gained N Gold" unless quiet. A positive amount counts as gold
## earned in the save's play stats; set_gold() and spend_gold() never do.
func add_gold(amount: float, quiet: bool = false) -> void:
	live_save_data.gold += amount
	if amount > 0.0:
		live_save_data.stats.add_gold_earned(amount)
	gold_changed.emit(live_save_data.gold)

	if LogManager and not quiet:
		LogManager.log_message("[color=gold]Gained %d Gold[/color]" % int(amount))

## Spends `amount` of gold and returns true when the purse holds that much,
## logging "Spent N Gold". Otherwise it spends nothing, logs nothing and
## returns false.
func spend_gold(amount: float) -> bool:
	if live_save_data.gold >= amount:
		live_save_data.gold -= amount
		gold_changed.emit(live_save_data.gold)
		
		if LogManager:
			LogManager.log_message("[color=gold]Spent %d Gold[/color]" % int(amount))
			
		return true
	return false

## Sets the purse to `amount`, never below 0. Logs nothing.
func set_gold(amount: float) -> void:
	live_save_data.set("gold", max(0.0, amount))
	gold_changed.emit(live_save_data.gold)

## The gold in the purse.
func get_gold() -> float:
	return live_save_data.gold

## True when the purse holds at least `amount`.
func can_afford_gold(amount: float) -> bool:
	return get_gold() >= amount
