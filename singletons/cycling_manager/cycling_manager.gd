extends Node

## Manages cycling technique state — which techniques are unlocked and equipped.
## Authoritative owner of all cycling technique data. It also records which
## unlocked techniques the player has seen (the NEW seal on a technique drawer)
## and holds a snapshot of the running cycle and the last finished cycle's result
## for the zone UI to read.

signal technique_unlocked(technique: CyclingTechniqueData)
signal equipped_technique_changed(technique: CyclingTechniqueData)
## Emitted when the running cycle's measured Madra rate moves to another tenth (the
## rate snapped to RATE_STEP changes), including the drop to 0 when the session
## ends. The rate passed is the measured one, not snapped.
signal madra_rate_changed(rate: float)
## Emitted when the last finished cycle's result changes: a cycle ended, or the
## board cleared it (null then).
signal last_cycle_changed(result: CycleResult)

## The step the Madra rate is announced and shown in, a tenth: madra_rate_changed
## fires when the rate snapped to it changes, and the cabinet and the Now tray show
## the rate snapped to it.
const RATE_STEP: float = 0.1

var _live_save_data: SaveGameData = null
var _technique_catalog: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var _techniques_by_id: Dictionary = {}  # String -> CyclingTechniqueData

# The running cycle's snapshot. It is transient: never saved.
var _cycle_running: bool = false
var _cycle_elapsed: float = 0.0
var _cycle_duration: float = 0.0
var _madra_rate: float = 0.0
# The rate madra_rate_changed last announced, snapped to RATE_STEP.
var _announced_rate: float = 0.0
# The last finished cycle's result, for the chest's line under the Now tray. It is
# transient: never saved.
var _last_cycle_result: CycleResult = null

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("CyclingManager: Could not get save_game_data from PersistenceManager on ready!")
	_initialize_seen_techniques()

# ----- Public API -----

## Returns every cycling technique in the catalog, in catalog order: the ones
## has_technique() knows.
func get_all_techniques() -> Array[CyclingTechniqueData]:
	var result: Array[CyclingTechniqueData] = []
	for technique: CyclingTechniqueData in _techniques_by_id.values():
		result.append(technique)
	return result

## Returns true if the catalog has a technique with this ID. An unknown ID gives
## false, with no error.
func has_technique(technique_id: String) -> bool:
	return _techniques_by_id.has(technique_id)

## Returns full resource data for all unlocked technique IDs.
func get_unlocked_techniques() -> Array[CyclingTechniqueData]:
	var result: Array[CyclingTechniqueData] = []
	if not _live_save_data:
		return result
	for technique_id: String in _live_save_data.unlocked_cycling_technique_ids:
		if _techniques_by_id.has(technique_id):
			result.append(_techniques_by_id[technique_id])
	return result

## Returns the currently equipped technique, or null if none.
func get_equipped_technique() -> CyclingTechniqueData:
	if not _live_save_data:
		return null
	return _techniques_by_id.get(_live_save_data.equipped_cycling_technique_id, null)

## Unlocks a cycling technique by ID. Idempotent — skips if already unlocked.
func unlock_technique(technique_id: String) -> void:
	if not _live_save_data:
		return
	if technique_id in _live_save_data.unlocked_cycling_technique_ids:
		return
	if not _techniques_by_id.has(technique_id):
		push_error("CyclingManager: unknown technique_id '%s'" % technique_id)
		return
	_live_save_data.unlocked_cycling_technique_ids.append(technique_id)
	Log.info("CyclingManager: Unlocked technique '%s'" % technique_id)
	technique_unlocked.emit(_techniques_by_id[technique_id])

## Sets the equipped technique by ID. Must be unlocked first.
func equip_technique(technique_id: String) -> void:
	if not _live_save_data:
		return
	if not _techniques_by_id.has(technique_id):
		push_error("CyclingManager: unknown technique_id '%s'" % technique_id)
		return
	if technique_id not in _live_save_data.unlocked_cycling_technique_ids:
		push_error("CyclingManager: cannot equip locked technique '%s'" % technique_id)
		return
	_live_save_data.equipped_cycling_technique_id = technique_id
	Log.info("CyclingManager: Equipped technique '%s'" % technique_id)
	equipped_technique_changed.emit(_techniques_by_id[technique_id])

## Returns true if the technique is currently unlocked.
func is_technique_unlocked(technique_id: String) -> bool:
	if not _live_save_data:
		return false
	return technique_id in _live_save_data.unlocked_cycling_technique_ids

## Returns true if any unlocked cycling technique is not currently equipped.
## Used by UI (badges) to signal "you have something new to equip."
## Derived from existing save fields; no new save schema needed.
func has_unequipped_unlocks() -> bool:
	if not _live_save_data:
		return false
	var unlocked: Array = _live_save_data.unlocked_cycling_technique_ids
	if unlocked.is_empty():
		return false
	var equipped: String = _live_save_data.equipped_cycling_technique_id
	for technique_id: String in unlocked:
		if technique_id != equipped:
			return true
	return false

# ----- Seen techniques -----

## Records that the player has seen the technique, which clears its NEW seal.
## Ignores an empty id and a technique that is already recorded.
func mark_technique_seen(technique_id: String) -> void:
	if not _live_save_data or technique_id.is_empty():
		return
	if technique_id in _live_save_data.seen_cycling_technique_ids:
		return
	_live_save_data.seen_cycling_technique_ids.append(technique_id)

## Returns true when the player has seen the technique (no NEW seal).
## The equipped technique always counts as seen: it is in use.
func is_technique_seen(technique_id: String) -> bool:
	if not _live_save_data or technique_id.is_empty():
		return false
	if technique_id in _live_save_data.seen_cycling_technique_ids:
		return true
	return technique_id == _live_save_data.equipped_cycling_technique_id

# ----- Cycle session -----
# A snapshot of the running cycle for the zone UI (the Now tray and the cultivator
# cabinet). The cycling technique writes it with start, update and end; the rest
# only read it.

## Starts a cycle session of the given length in seconds, with no time elapsed and
## no Madra drawn. A session that is already running is replaced.
func start_cycle_session(duration: float) -> void:
	_cycle_running = true
	_cycle_elapsed = 0.0
	_cycle_duration = duration
	_set_madra_rate(0.0)

## Updates the running session with the seconds elapsed and the measured Madra
## rate (Madra per second). Does nothing when no session is running.
func update_cycle_session(elapsed: float, madra_rate: float) -> void:
	if not _cycle_running:
		return
	_cycle_elapsed = elapsed
	_set_madra_rate(madra_rate)

## Ends the session and clears the snapshot. Announces the drop to 0 if a Madra
## rate was showing.
func end_cycle_session() -> void:
	_cycle_running = false
	_cycle_elapsed = 0.0
	_cycle_duration = 0.0
	_set_madra_rate(0.0)

## Returns true while a cycle session is running.
func is_cycle_running() -> bool:
	return _cycle_running

## Returns how far through the cycle it is, from 0 to 1. 0 when none is running.
func get_cycle_progress() -> float:
	if not _cycle_running or _cycle_duration <= 0.0:
		return 0.0
	return clampf(_cycle_elapsed / _cycle_duration, 0.0, 1.0)

## Returns the seconds the running cycle has been going. 0 when none is running.
func get_cycle_elapsed() -> float:
	return _cycle_elapsed

## Returns the running cycle's length in seconds. 0 when none is running.
func get_cycle_duration() -> float:
	return _cycle_duration

## Returns the Madra the running cycle draws per second. 0 when none is running.
func get_madra_rate() -> float:
	return _madra_rate

# ----- The last cycle -----

## Records `result` as the last finished cycle's, for the chest to show under the
## Now tray, and counts it as a finished cycle in the save's play stats. The
## cycling board calls it when a cycle ends. A null result is no cycle and counts
## nothing.
func set_last_cycle_result(result: CycleResult) -> void:
	_last_cycle_result = result
	if result != null and _live_save_data:
		_live_save_data.stats.count_cycle_finished()
	last_cycle_changed.emit(result)

## Forgets the last finished cycle, as the board does when it opens or switches
## technique. Announces it only if there was one.
func clear_last_cycle_result() -> void:
	if _last_cycle_result == null:
		return
	_last_cycle_result = null
	last_cycle_changed.emit(null)

## Returns the last finished cycle's result, or null when none is kept.
func get_last_cycle_result() -> CycleResult:
	return _last_cycle_result

# ----- Private -----

func _build_catalog_index() -> void:
	_techniques_by_id.clear()
	for technique: CyclingTechniqueData in _technique_catalog.cycling_techniques:
		if technique and not technique.id.is_empty():
			_techniques_by_id[technique.id] = technique

## On a save's first initialisation, marks every technique unlocked at that
## moment as seen, so only techniques unlocked later show the NEW seal.
func _initialize_seen_techniques() -> void:
	if not _live_save_data or _live_save_data.seen_cycling_techniques_initialized:
		return
	for technique_id: String in _live_save_data.unlocked_cycling_technique_ids:
		mark_technique_seen(technique_id)
	_live_save_data.seen_cycling_techniques_initialized = true

## Stores the measured Madra rate, and emits madra_rate_changed when the rate
## snapped to RATE_STEP has changed since the last announcement.
func _set_madra_rate(rate: float) -> void:
	_madra_rate = rate
	var snapped_rate: float = snappedf(rate, RATE_STEP)
	if is_equal_approx(snapped_rate, _announced_rate):
		return
	_announced_rate = snapped_rate
	madra_rate_changed.emit(rate)

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
	_initialize_seen_techniques()
	clear_last_cycle_result()
