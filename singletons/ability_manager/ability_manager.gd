extends Node

## Manages ability state — which abilities are unlocked and equipped.
## Authoritative owner of all ability data. Mirrors CyclingManager pattern.

signal ability_unlocked(ability: AbilityData)
signal equipped_abilities_changed()

const MAX_SLOTS: int = 4

var _live_save_data: SaveGameData = null
var _ability_catalog: AbilityListData = preload("res://resources/abilities/ability_list.tres")
var _abilities_by_id: Dictionary = {}  # String -> AbilityData

func _ready() -> void:
	_build_catalog_index()
	if PersistenceManager:
		_live_save_data = PersistenceManager.save_game_data
		_ensure_equipped_array_size()
		PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	else:
		Log.critical("AbilityManager: Could not get save_game_data from PersistenceManager on ready!")

# ----- Public API -----

## Returns full resource data for all unlocked ability IDs.
func get_unlocked_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if not _live_save_data:
		return result
	for ability_id: String in _live_save_data.unlocked_ability_ids:
		if _abilities_by_id.has(ability_id):
			result.append(_abilities_by_id[ability_id])
	return result

## Returns full resource data for all equipped ability IDs (skips empty slots).
func get_equipped_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if not _live_save_data:
		return result
	for ability_id: String in _live_save_data.equipped_ability_ids:
		if not ability_id.is_empty() and _abilities_by_id.has(ability_id):
			result.append(_abilities_by_id[ability_id])
	return result

## Returns the ability ID at a specific slot index, or "" if empty.
func get_ability_at_slot(slot_index: int) -> String:
	if not _live_save_data:
		return ""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return ""
	return _live_save_data.equipped_ability_ids[slot_index]

## Unlocks an ability by ID. Idempotent — skips if already unlocked.
func unlock_ability(ability_id: String) -> void:
	if not _live_save_data:
		return
	if ability_id in _live_save_data.unlocked_ability_ids:
		return
	if not _abilities_by_id.has(ability_id):
		push_error("AbilityManager: unknown ability_id '%s'" % ability_id)
		return
	_live_save_data.unlocked_ability_ids.append(ability_id)
	Log.info("AbilityManager: Unlocked ability '%s'" % ability_id)
	ability_unlocked.emit(_abilities_by_id[ability_id])

## Equips an ability at a specific slot. Must be unlocked first. Returns false if failed.
func equip_ability_at_slot(ability_id: String, slot_index: int) -> bool:
	if not _live_save_data:
		return false
	if not _abilities_by_id.has(ability_id):
		push_error("AbilityManager: unknown ability_id '%s'" % ability_id)
		return false
	if ability_id not in _live_save_data.unlocked_ability_ids:
		push_error("AbilityManager: cannot equip locked ability '%s'" % ability_id)
		return false
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		push_error("AbilityManager: invalid slot_index %d" % slot_index)
		return false
	# Remove from any existing slot first
	_clear_ability_from_slots(ability_id)
	_live_save_data.equipped_ability_ids[slot_index] = ability_id
	Log.info("AbilityManager: Equipped ability '%s' in slot %d" % [ability_id, slot_index])
	equipped_abilities_changed.emit()
	return true

## Equips an ability in the first available empty slot. Returns false if no slot free.
func equip_ability(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	if not _abilities_by_id.has(ability_id):
		push_error("AbilityManager: unknown ability_id '%s'" % ability_id)
		return false
	if ability_id not in _live_save_data.unlocked_ability_ids:
		push_error("AbilityManager: cannot equip locked ability '%s'" % ability_id)
		return false
	if is_ability_equipped(ability_id):
		return true
	# Find first empty slot
	for i: int in range(MAX_SLOTS):
		if _live_save_data.equipped_ability_ids[i].is_empty():
			_live_save_data.equipped_ability_ids[i] = ability_id
			Log.info("AbilityManager: Equipped ability '%s' in slot %d" % [ability_id, i])
			equipped_abilities_changed.emit()
			return true
	push_error("AbilityManager: cannot equip '%s' — all %d slots full" % [ability_id, MAX_SLOTS])
	return false

## Unequips an ability by ID (clears its slot).
func unequip_ability(ability_id: String) -> void:
	if not _live_save_data:
		return
	if not is_ability_equipped(ability_id):
		return
	_clear_ability_from_slots(ability_id)
	Log.info("AbilityManager: Unequipped ability '%s'" % ability_id)
	equipped_abilities_changed.emit()

## Returns true if the ability is currently unlocked.
func is_ability_unlocked(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	return ability_id in _live_save_data.unlocked_ability_ids

## Returns true if the ability is currently equipped.
func is_ability_equipped(ability_id: String) -> bool:
	if not _live_save_data:
		return false
	return ability_id in _live_save_data.equipped_ability_ids

## Returns the maximum number of ability equip slots.
func get_max_slots() -> int:
	return MAX_SLOTS

# ----- Private -----

func _ensure_equipped_array_size() -> void:
	if not _live_save_data:
		return
	while _live_save_data.equipped_ability_ids.size() < MAX_SLOTS:
		_live_save_data.equipped_ability_ids.append("")

func _clear_ability_from_slots(ability_id: String) -> void:
	for i: int in range(MAX_SLOTS):
		if _live_save_data.equipped_ability_ids[i] == ability_id:
			_live_save_data.equipped_ability_ids[i] = ""

func _build_catalog_index() -> void:
	_abilities_by_id.clear()
	for ability: AbilityData in _ability_catalog.abilities:
		if ability and not ability.ability_id.is_empty():
			_abilities_by_id[ability.ability_id] = ability

func _on_save_data_reset() -> void:
	_live_save_data = PersistenceManager.save_game_data
	_ensure_equipped_array_size()
