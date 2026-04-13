extends Node

## Manages cycling technique state — which techniques are unlocked and equipped.
## Authoritative owner of all cycling technique data.

signal technique_unlocked(technique: CyclingTechniqueData)
signal equipped_technique_changed(technique: CyclingTechniqueData)

var _live_save_data: SaveGameData = null
var _technique_catalog: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var _techniques_by_id: Dictionary = {}  # String -> CyclingTechniqueData

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("CyclingManager: Could not get save_game_data from PersistenceManager on ready!")

# ----- Public API -----

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

# ----- Private -----

func _build_catalog_index() -> void:
	_techniques_by_id.clear()
	for technique: CyclingTechniqueData in _technique_catalog.cycling_techniques:
		if technique and not technique.id.is_empty():
			_techniques_by_id[technique.id] = technique

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
