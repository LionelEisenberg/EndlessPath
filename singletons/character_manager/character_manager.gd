# CharacterManager.gd
# AUTOLOADED SINGLETON
extends Node

## CharacterManager
## Central manager for the player's attributes and the stats derived from them.
## Trained levels live in the save; every bonus (gear today, path perks and
## elixirs later) is a source in a StatModifierStack, asked when a stat is
## read. get_stat() is the one read: an attribute is its trained value with its
## modifiers; a derived stat is CharacterAttributesData's formula over the
## total attributes, then its own modifiers. Each total is worked out once and
## cached until the stats change: every change this manager makes or hears of
## (a level, the inventory, a save reset, a modifier source) empties the cache
## just before stats_changed, so a listener always reads the new totals.

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------

# Use the AttributeType from CharacterAttributesData
const AttributeType = CharacterAttributesData.AttributeType
const Stat = StatModifierData.Stat

## The source name the equipped gear's bonuses are under.
const GEAR_SOURCE: StringName = &"gear"

## Get the display name for an attribute type
static func get_attribute_display_name(attr_type: AttributeType) -> String:
	return CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

## Emitted when any total stat may have changed: after a trained level
## changes, after any inventory change (equipping or removing gear moves the
## bonuses), after a save reset, and after a modifier source is set or removed.
## Listeners re-read get_stat() or get_total_attributes_data().
signal stats_changed

## Emitted once by each add_stat_xp(), add_stat_levels() and set_stat_level()
## call: the stat's XP toward its next level, and the XP that level costs.
signal stat_xp_changed(stat: AttributeType, xp: float, xp_to_next: float)

## Emitted for each level a stat gains, and once by set_stat_level(), after the
## level is written.
signal stat_level_changed(stat: AttributeType, level: int)

#-----------------------------------------------------------------------------
# LEVEL CURVE
#-----------------------------------------------------------------------------

## The level curve: the XP each level costs and the value each level gives.
@export var stat_progression: StatProgressionData = preload("res://resources/character/stat_progression.tres")

#-----------------------------------------------------------------------------
# PLAYER DATA (Held by this manager)
#-----------------------------------------------------------------------------

# --- Persistent State (via shared SaveGameData) ---
var live_save_data: SaveGameData = null # Reference set in _ready

## Every bonus to the player's stats, by source.
var _modifiers: StatModifierStack = StatModifierStack.new()

## Every total read since the stats last changed, Stat to float. A read with
## gear on asks every source for every stat of the block (DM-06), so get_stat()
## answers from here, and _stats_changed() empties it.
var _stat_cache: Dictionary = {}

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("CharacterManager: Initializing")
	_modifiers.set_source(GEAR_SOURCE, _gear_modifiers)

	if PersistenceManager and PersistenceManager.save_game_data:
		live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_update_resources)
		_update_resources()
	else:
		Log.critical("CharacterManager: Could not get save_game_data from PersistenceManager on ready!")
	InventoryManager.inventory_changed.connect(_on_inventory_changed)

## Binds the live save, at start and after each save reset: every stat may have
## changed with it.
func _update_resources() -> void:
	Log.info("CharacterManager: Updating resources from save data")
	live_save_data = PersistenceManager.save_game_data
	if live_save_data == null:
		Log.critical("CharacterManager: live_save_data is null in _update_resources!")
		return
	_stats_changed()

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_stats_changed()

## Empties the stat cache, then emits stats_changed, so every listener reads
## the new totals.
func _stats_changed() -> void:
	_stat_cache.clear()
	stats_changed.emit()


#-----------------------------------------------------------------------------
# STATS (Base + Modifiers)
#-----------------------------------------------------------------------------

## Returns the stat's total. An attribute is its trained value (its level's
## value on the level curve) with its modifiers. A derived stat is its formula
## on CharacterAttributesData over the total attributes, then its own modifiers.
## Armor and Ward start at 0 and come from their modifiers alone. Cached until
## the stats change.
func get_stat(stat: Stat) -> float:
	if _stat_cache.has(stat):
		return _stat_cache[stat]
	var total: float = _modifiers.apply(stat, _get_base_stat(stat))
	_stat_cache[stat] = total
	return total

## Returns the six stats, armor and Ward (base + modifiers) as one block, a
## snapshot that does not follow later changes.
func get_total_attributes_data() -> CharacterAttributesData:
	var totals := CharacterAttributesData.new()
	for attr_type: AttributeType in AttributeType.values():
		totals.set_attribute(attr_type, get_stat(StatModifierData.for_attribute(attr_type)))
	totals.armor = get_stat(Stat.ARMOR)
	totals.ward = get_stat(Stat.WARD)
	return totals

## Returns the stat's total as it would be with its trained level at `level`,
## every other bonus as it is now. The worn gear is counted again on that
## level's trained value, so a floored percent that steps up with the level
## counts: the Character book's next-level figures read it. At the stat's own
## level it is get_stat().
func get_stat_at_level(stat: AttributeType, level: int) -> float:
	var trained_value: float = stat_progression.get_value_for_level(level)
	var gear_change: float = -get_gear_bonus(stat)
	for equipment: EquipmentDefinitionData in _equipped_gear():
		gear_change += equipment.get_stat_bonus(stat, trained_value)
	# The gear source still gives today's bonus, so the base carries the change.
	return _modifiers.apply(StatModifierData.for_attribute(stat), trained_value + gear_change)

## The flat points the worn gear adds to the stat: each equipped item's and
## accessory's get_stat_bonus() on the stat's trained value, summed. It is gear's
## FLAT amount before any PERCENT modifier, which StatModifierStack applies after
## every FLAT one.
func get_gear_bonus(stat: AttributeType) -> float:
	var trained_value: float = get_trained_value(stat)
	var bonus: float = 0.0
	for equipment: EquipmentDefinitionData in _equipped_gear():
		bonus += equipment.get_stat_bonus(stat, trained_value)
	return bonus

## Adds a modifier source, or replaces the one under that name. The provider
## takes no arguments and returns Array[StatModifierData]; it is asked when a
## stat is read after the stats change, so a source whose modifiers change sets
## itself again. "gear" is taken by the equipped gear.
func set_modifier_source(source: StringName, provider: Callable) -> void:
	_modifiers.set_source(source, provider)
	_stats_changed()

## Removes a modifier source, if there is one under that name.
func remove_modifier_source(source: StringName) -> void:
	_modifiers.remove_source(source)
	_stats_changed()

#-----------------------------------------------------------------------------
# TRAINED LEVELS
#-----------------------------------------------------------------------------

## The stat's trained level, from the save. A stat never trained is at Lv 1.
func get_stat_level(stat: AttributeType) -> int:
	if live_save_data == null:
		return 1
	return live_save_data.stat_training.get_level(stat)

## The stat's XP toward its next level.
func get_stat_xp(stat: AttributeType) -> float:
	if live_save_data == null:
		return 0.0
	return live_save_data.stat_training.get_xp(stat)

## The XP the stat's next level costs on the level curve, also at the cap,
## where training no longer reaches that level.
func get_stat_xp_to_next(stat: AttributeType) -> float:
	return stat_progression.get_xp_to_next(get_stat_level(stat))

## The highest level a stat can be trained to in the current stage, read live
## from the stage, so the breakthrough raises it.
func get_stat_level_cap() -> int:
	return CultivationManager.get_stat_level_cap()

## True when the stat's trained level is at or past the stage's cap. Bonuses
## never count: gear can lift a total past the cap, but not the level.
func is_stat_capped(stat: AttributeType) -> bool:
	return get_stat_level(stat) >= get_stat_level_cap()

## The stat's value from its trained level alone, before any bonus. It reads
## the training record, never get_stat(), so a modifier source can call it.
func get_trained_value(stat: AttributeType) -> float:
	return stat_progression.get_value_for_level(get_stat_level(stat))

## Every stat's trained value, AttributeType to float. Like
## get_trained_value(), it never calls get_stat().
func get_trained_values() -> Dictionary:
	var values: Dictionary = {}
	for stat: AttributeType in AttributeType.values():
		values[stat] = get_trained_value(stat)
	return values

## Adds XP to the stat and raises it a level for each level the XP pays for,
## up to the stage's cap. A capped stat holds no XP, so what arrives (and what
## it held) is lost, and the level-up that reaches the cap drops the XP left
## over. Emits stat_level_changed and logs a line for each level gained,
## stat_xp_changed once, and stats_changed once when a level was gained.
## Returns the XP the stat took: all of `amount` short of the cap, only what
## bought the level that reaches it, and none at the cap.
func add_stat_xp(stat: AttributeType, amount: float) -> float:
	if live_save_data == null:
		Log.error("CharacterManager: Cannot add stat XP - live_save_data is null")
		return 0.0
	var training: StatTrainingData = live_save_data.stat_training

	# A capped stat holds no XP, so what arrives (and what it held) is lost
	if is_stat_capped(stat):
		training.set_xp(stat, 0.0)
		stat_xp_changed.emit(stat, 0.0, get_stat_xp_to_next(stat))
		return 0.0

	var start_level: int = training.get_level(stat)
	var cap: int = get_stat_level_cap()
	var taken: float = amount
	training.set_xp(stat, training.get_xp(stat) + amount)
	var cost: float = get_stat_xp_to_next(stat)
	while training.get_xp(stat) >= cost:
		# A free level costs 0 XP and passes every check: stop here instead of
		# levelling for nothing (or forever)
		if cost <= 0.0:
			Log.error("CharacterManager: Cannot level %s past Lv %d - the next level costs no XP" % [
				get_attribute_display_name(stat),
				training.get_level(stat),
			])
			break
		var level: int = training.get_level(stat) + 1
		var reached_cap: bool = level >= cap
		# The level-up that reaches the cap drops the XP left over
		if reached_cap:
			taken -= training.get_xp(stat) - cost
		training.set_xp(stat, 0.0 if reached_cap else training.get_xp(stat) - cost)
		_raise_stat_level(stat, level)
		if reached_cap:
			break
		cost = get_stat_xp_to_next(stat)

	stat_xp_changed.emit(stat, training.get_xp(stat), get_stat_xp_to_next(stat))
	if training.get_level(stat) != start_level:
		_stats_changed()
	return taken

## Raises the stat `count` levels, one at a time, up to the stage's cap: the
## levels past it are lost, and a stat at or past the cap stays where it is.
## The XP toward the next level is kept, unless the call reaches the cap, which
## drops it. Emits stat_level_changed and logs a line for each level gained,
## stat_xp_changed once, and stats_changed once when a level was gained.
func add_stat_levels(stat: AttributeType, count: int) -> void:
	if live_save_data == null:
		Log.error("CharacterManager: Cannot add stat levels - live_save_data is null")
		return
	var training: StatTrainingData = live_save_data.stat_training
	var start_level: int = training.get_level(stat)
	var cap: int = get_stat_level_cap()
	var target: int = maxi(start_level, mini(start_level + count, cap))
	for level: int in range(start_level + 1, target + 1):
		# The level-up that reaches the cap drops the XP: a capped stat holds none
		if level >= cap:
			training.set_xp(stat, 0.0)
		_raise_stat_level(stat, level)

	stat_xp_changed.emit(stat, training.get_xp(stat), get_stat_xp_to_next(stat))
	if target != start_level:
		_stats_changed()

## The dev tools' setter: puts the stat at any level from 1, past the cap too,
## with `xp` held inside the level, from 0 to one point short of the level's
## cost. Emits stat_level_changed, stat_xp_changed and stats_changed once each,
## and logs nothing: a set is no level reached.
func set_stat_level(stat: AttributeType, level: int, xp: float = 0.0) -> void:
	if live_save_data == null:
		Log.error("CharacterManager: Cannot set a stat level - live_save_data is null")
		return
	var training: StatTrainingData = live_save_data.stat_training
	var new_level: int = maxi(level, 1)
	var cost: float = stat_progression.get_xp_to_next(new_level)
	training.set_level(stat, new_level)
	training.set_xp(stat, minf(maxf(xp, 0.0), maxf(cost - 1.0, 0.0)))
	stat_level_changed.emit(stat, new_level)
	stat_xp_changed.emit(stat, training.get_xp(stat), cost)
	_stats_changed()

#-----------------------------------------------------------------------------
# DERIVED STATS (Calculated from attributes)
#-----------------------------------------------------------------------------
# These are basic stat calculations. Combat systems use these for their own logic.

## Get the character's gold multiplier from stats/equipment/cultivation
## Returns: float multiplier (1.0 = no bonus)
## Future: Can be affected by luck stat, equipment bonuses, cultivation stage, etc.
func get_gold_multiplier() -> float:
	# TODO: Implement based on character stats/equipment/cultivation
	# Example: return 1.0 + (get_attribute(AttributeType.LUCK) * 0.01)
	return 1.0


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## The stat before its modifiers: an attribute's trained value, or a derived
## stat's formula over the total attributes; armor and Ward start at 0.
func _get_base_stat(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH:
			return get_total_attributes_data().get_max_health()
		Stat.MAX_STAMINA:
			return get_total_attributes_data().get_max_stamina()
		Stat.MAX_MADRA:
			return get_total_attributes_data().get_max_madra()
		Stat.STAMINA_REGEN:
			return get_total_attributes_data().get_stamina_regen()
		Stat.DODGE_CHANCE:
			return get_total_attributes_data().get_dodge_chance()
		Stat.MADRA_COST_CUT:
			return get_total_attributes_data().get_madra_cost_cut()
		Stat.COOLDOWN_CUT:
			return get_total_attributes_data().get_cooldown_cut()
		Stat.ARMOR, Stat.WARD:
			return 0.0
	return get_trained_value(StatModifierData.attribute_of(stat))

## Writes the stat's new level, then announces it: stat_level_changed and the
## player's log line. add_stat_xp() and add_stat_levels() call it once a level.
func _raise_stat_level(stat: AttributeType, level: int) -> void:
	live_save_data.stat_training.set_level(stat, level)
	stat_level_changed.emit(stat, level)
	LogManager.log_message("[b]%s[/b] reached Lv %d" % [get_attribute_display_name(stat), level])

## The definitions of every equipped item and accessory. It reads this
## manager's own save, not InventoryManager's, so during a save reset it
## already sees the new save (CharacterManager hears the reset first). No save
## or inventory gives none; empty slots and items that are not equipment are
## skipped.
func _equipped_gear() -> Array[EquipmentDefinitionData]:
	var gear: Array[EquipmentDefinitionData] = []
	if live_save_data == null or live_save_data.inventory == null:
		return gear
	var inventory: InventoryData = live_save_data.inventory
	for instance: ItemInstanceData in inventory.equipped_gear.values() + inventory.equipped_accessories.values():
		if instance == null:
			continue
		var equipment := instance.item_definition as EquipmentDefinitionData
		if equipment != null:
			gear.append(equipment)
	return gear

## The gear source: the modifiers of every equipped item and accessory, their
## stat percents counted on the trained values. It reads the training record,
## never get_stat(): get_stat() asks this source, so calling it here would
## recurse.
func _gear_modifiers() -> Array[StatModifierData]:
	var modifiers: Array[StatModifierData] = []
	var trained_values: Dictionary = get_trained_values()
	for equipment: EquipmentDefinitionData in _equipped_gear():
		modifiers.append_array(equipment.get_stat_modifiers(trained_values))
	return modifiers
