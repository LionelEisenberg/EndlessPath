extends Node

## Manages body refining drills: which drills are unlocked and equipped, and
## which unlocked drills the player has seen (the NEW mark). Authoritative owner
## of the drill catalog. It pays each rep through pay_rep(): Strength XP and the
## drill's other stat's XP through CharacterManager.add_stat_xp(), so XP earned at
## the cap is lost, and Health through ResourceManager.add_health(), which a
## capped Strength still refills, recording in the set's result what each stat
## took. It also holds a snapshot of the set being played, for the Now strip,
## and counts each set played to its last rep in the play stats (finish_set()).
## Modelled on CyclingManager.

signal drill_unlocked(drill: DrillData)
signal equipped_drill_changed(drill: DrillData)

const AttributeType = CharacterAttributesData.AttributeType
const Tier = DrillRules.Tier

var _live_save_data: SaveGameData = null
var _drill_catalog: DrillList = preload("res://resources/body_refining/drills/drill_list.tres")
var _drills_by_id: Dictionary = {}  # String -> DrillData

# The running set's snapshot. It is transient: never saved.
var _set_running: bool = false
var _set_reps: int = 0
var _set_rep: int = 0
var _rep_progress: float = 0.0

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
	_pay_stat_xp(AttributeType.STRENGTH, DrillRules.xp_for_rep(drill.strength_xp_per_rep, tier), result)
	if drill.has_minor_stat():
		_pay_stat_xp(drill.minor_stat as AttributeType, DrillRules.xp_for_rep(drill.minor_xp_per_rep, tier), result)
	if result != null:
		result.add_rep(tier, restored)
	return restored

## The Health a PERFECT rep of `drill` restores at the player's Strength total
## (gear included): what the board's pay line and the Now strip show.
func perfect_rep_health(drill: DrillData) -> float:
	return DrillRules.health_for_rep(drill, Tier.PERFECT, CharacterManager.get_stat(StatModifierData.Stat.STRENGTH))

# ----- The set session -----
# A snapshot of the set being played, for the Now strip. The drill board writes
# it with start, update and end; the rest only read it. It is never saved.

## Starts a set session of `reps` reps, on its first rep with none of it played.
## A session that is already running is replaced.
func start_set_session(reps: int) -> void:
	_set_running = true
	_set_reps = reps
	_set_rep = 1
	_rep_progress = 0.0

## Updates the running session: the rep being played, counted from 1, and how
## far through it the set is, 0 to 1. Does nothing when no session is running.
func update_set_session(rep: int, rep_progress: float) -> void:
	if not _set_running:
		return
	_set_rep = rep
	_rep_progress = clampf(rep_progress, 0.0, 1.0)

## Ends the session and clears the snapshot.
func end_set_session() -> void:
	_set_running = false
	_set_reps = 0
	_set_rep = 0
	_rep_progress = 0.0

## Returns true while a set session is running.
func is_set_running() -> bool:
	return _set_running

## Returns the rep being played, counted from 1. 0 when no set is running.
func get_set_rep() -> int:
	return _set_rep

## Returns how many reps the running set has. 0 when none is running.
func get_set_reps() -> int:
	return _set_reps

## Returns how far through the rep being played the set is, 0 to 1.
func get_rep_progress() -> float:
	return _rep_progress

## Returns how far through the whole set it is, 0 to 1: the reps behind it and
## the share of the one being played. 0 when no set is running.
func get_set_progress() -> float:
	if not _set_running or _set_reps <= 0:
		return 0.0
	return clampf((_set_rep - 1 + _rep_progress) / _set_reps, 0.0, 1.0)

## A set has ended: counts it in the save's play stats when it was played to
## its last rep (`result` complete), then ends the session. A set stopped short
## counts nothing.
func finish_set(result: DrillSetResult) -> void:
	if result != null and result.is_complete() and _live_save_data:
		_live_save_data.stats.count_set_finished()
	end_set_session()

# ----- Private -----

## Pays `stat` `xp` through CharacterManager.add_stat_xp(), and records what the
## stat took in `result` when one is given: less than paid means the cap took
## the rest. Paying nothing records nothing.
func _pay_stat_xp(stat: AttributeType, xp: float, result: DrillSetResult) -> void:
	if xp <= 0.0:
		return
	var taken: float = CharacterManager.add_stat_xp(stat, xp)
	if result != null:
		result.record_stat_xp(stat, taken, taken < xp)

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
