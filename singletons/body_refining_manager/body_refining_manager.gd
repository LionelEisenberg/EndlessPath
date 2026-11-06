extends Node

## Manages body refining drills: which drills are unlocked and equipped, and
## which unlocked drills the player has seen (the NEW mark). Authoritative owner
## of the drill catalog. It pays each rep through pay_rep(): Strength XP and the
## drill's other stat's XP through CharacterManager.add_stat_xp(), so XP earned at
## the cap is lost, and Health through ResourceManager.add_health(), which a
## capped Strength still refills. Modelled on CyclingManager.

signal drill_unlocked(drill: DrillData)
signal equipped_drill_changed(drill: DrillData)

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

var _live_save_data: SaveGameData = null
var _drill_catalog: DrillList = preload("res://resources/body_refining/drills/drill_list.tres")
var _drills_by_id: Dictionary = {}  # String -> DrillData

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("BodyRefiningManager: Could not get save_game_data from PersistenceManager on ready!")
	_initialize_seen_drills()

# ----- Public API -----

## Returns every drill in the catalog, in catalog order: the ones has_drill()
## knows.
func get_all_drills() -> Array[DrillData]:
	var result: Array[DrillData] = []
	for drill: DrillData in _drills_by_id.values():
		result.append(drill)
	return result

## Returns true if the catalog has a drill with this ID. An unknown ID gives
## false, with no error.
func has_drill(drill_id: String) -> bool:
	return _drills_by_id.has(drill_id)

## Returns the drill with this ID, or null for an unknown ID.
func get_drill(drill_id: String) -> DrillData:
	return _drills_by_id.get(drill_id, null)

## Returns the unlocked drills the catalog knows, in the order they were
## unlocked.
func get_unlocked_drills() -> Array[DrillData]:
	var result: Array[DrillData] = []
	if not _live_save_data:
		return result
	for drill_id: String in _live_save_data.unlocked_drill_ids:
		if _drills_by_id.has(drill_id):
			result.append(_drills_by_id[drill_id])
	return result

## Returns the currently equipped drill, or null if none.
func get_equipped_drill() -> DrillData:
	if not _live_save_data:
		return null
	return _drills_by_id.get(_live_save_data.equipped_drill_id, null)

## Unlocks a drill by ID. Idempotent: skips one already unlocked.
func unlock_drill(drill_id: String) -> void:
	if not _live_save_data:
		return
	if drill_id in _live_save_data.unlocked_drill_ids:
		return
	if not _drills_by_id.has(drill_id):
		push_error("BodyRefiningManager: unknown drill_id '%s'" % drill_id)
		return
	_live_save_data.unlocked_drill_ids.append(drill_id)
	Log.info("BodyRefiningManager: Unlocked drill '%s'" % drill_id)
	drill_unlocked.emit(_drills_by_id[drill_id])

## Sets the equipped drill by ID. It must be unlocked first.
func equip_drill(drill_id: String) -> void:
	if not _live_save_data:
		return
	if not _drills_by_id.has(drill_id):
		push_error("BodyRefiningManager: unknown drill_id '%s'" % drill_id)
		return
	if drill_id not in _live_save_data.unlocked_drill_ids:
		push_error("BodyRefiningManager: cannot equip locked drill '%s'" % drill_id)
		return
	_live_save_data.equipped_drill_id = drill_id
	Log.info("BodyRefiningManager: Equipped drill '%s'" % drill_id)
	equipped_drill_changed.emit(_drills_by_id[drill_id])

## Returns true if the drill is currently unlocked.
func is_drill_unlocked(drill_id: String) -> bool:
	if not _live_save_data:
		return false
	return drill_id in _live_save_data.unlocked_drill_ids

# ----- Seen drills -----

## Records that the player has seen the drill, which clears its NEW mark.
## Ignores an empty id and a drill that is already recorded.
func mark_drill_seen(drill_id: String) -> void:
	if not _live_save_data or drill_id.is_empty():
		return
	if drill_id in _live_save_data.seen_drill_ids:
		return
	_live_save_data.seen_drill_ids.append(drill_id)

## Returns true when the player has seen the drill (no NEW mark). The equipped
## drill always counts as seen: it is in use.
func is_drill_seen(drill_id: String) -> bool:
	if not _live_save_data or drill_id.is_empty():
		return false
	if drill_id in _live_save_data.seen_drill_ids:
		return true
	return drill_id == _live_save_data.equipped_drill_id

# ----- Reps -----

## Pays one rep of `drill` judged `tier`, and records it in `result` when one is
## given. The Health comes first, at the player's Strength total (gear included)
## before the rep's XP: DrillRules.health_for_rep(), through
## ResourceManager.add_health() without a log line. Then the XP: Strength's, and
## the drill's other stat's when it has one, each once, through
## CharacterManager.add_stat_xp(). XP is paid at full Health too, and a capped
## stat loses its XP while the rep still refills Health. A MISS pays nothing.
## Returns the Health the rep restored, which is less than it paid near the max.
func pay_rep(drill: DrillData, tier: Tier, result: DrillSetResult = null) -> float:
	if drill == null:
		push_error("BodyRefiningManager: cannot pay a rep of no drill")
		return 0.0
	var strength: float = CharacterManager.get_stat(StatModifierData.Stat.STRENGTH)
	var health: float = DrillRules.health_for_rep(drill, tier, strength)
	var restored: float = ResourceManager.add_health(health, true) if health > 0.0 else 0.0
	var strength_xp: float = DrillRules.xp_for_rep(drill.strength_xp_per_rep, tier)
	if strength_xp > 0.0:
		CharacterManager.add_stat_xp(AttributeType.STRENGTH, strength_xp)
	if drill.has_minor_stat():
		var minor_xp: float = DrillRules.xp_for_rep(drill.minor_xp_per_rep, tier)
		if minor_xp > 0.0:
			CharacterManager.add_stat_xp(drill.minor_stat as AttributeType, minor_xp)
	if result != null:
		result.add_rep(tier, restored)
	return restored

# ----- Private -----

func _build_catalog_index() -> void:
	_drills_by_id.clear()
	for drill: DrillData in _drill_catalog.drills:
		if drill and not drill.id.is_empty():
			_drills_by_id[drill.id] = drill

## On a save's first initialisation, marks every drill unlocked at that moment
## as seen, so only drills unlocked later show the NEW mark.
func _initialize_seen_drills() -> void:
	if not _live_save_data or _live_save_data.seen_drills_initialized:
		return
	for drill_id: String in _live_save_data.unlocked_drill_ids:
		mark_drill_seen(drill_id)
	_live_save_data.seen_drills_initialized = true

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
	_initialize_seen_drills()
