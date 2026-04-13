extends GutTest

## Tests for AbilityManager singleton.
## Follows the same test pattern as test_path_manager.gd — directly assigns
## internal state to avoid autoload dependency ordering issues.

var _save_data: SaveGameData = null

func before_each() -> void:
	_save_data = SaveGameData.new()
	_save_data.unlocked_ability_ids = ["basic_strike", "enforce"]
	_save_data.equipped_ability_ids = ["basic_strike", "", "", ""]
	AbilityManager._live_save_data = _save_data
	AbilityManager._build_catalog_index()

# ----- Unlock Tests -----

func test_unlock_ability() -> void:
	AbilityManager.unlock_ability("empty_palm")
	assert_true(AbilityManager.is_ability_unlocked("empty_palm"),
		"empty_palm should be unlocked after unlock_ability()")

func test_unlock_idempotent() -> void:
	AbilityManager.unlock_ability("basic_strike")
	var count: int = 0
	for id: String in _save_data.unlocked_ability_ids:
		if id == "basic_strike":
			count += 1
	assert_eq(count, 1, "Duplicate unlock should not add a second entry")

func test_unlock_unknown_id() -> void:
	AbilityManager.unlock_ability("nonexistent_ability")
	assert_push_error("unknown ability_id")
	assert_false(AbilityManager.is_ability_unlocked("nonexistent_ability"),
		"Unknown ability ID should not be added to unlocked list")

func test_unlock_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.unlock_ability("empty_palm")
	assert_signal_emitted(AbilityManager, "ability_unlocked",
		"ability_unlocked signal should fire on unlock")

# ----- Equip Tests -----

func test_equip_ability() -> void:
	AbilityManager.equip_ability("enforce")
	assert_true(AbilityManager.is_ability_equipped("enforce"),
		"enforce should be equipped after equip_ability()")

func test_equip_requires_unlock() -> void:
	var result: bool = AbilityManager.equip_ability("empty_palm")
	assert_push_error("cannot equip locked ability")
	assert_false(result, "Cannot equip an ability that is not unlocked")
	assert_false(AbilityManager.is_ability_equipped("empty_palm"))

func test_equip_slot_limit() -> void:
	AbilityManager.unlock_ability("empty_palm")
	AbilityManager.unlock_ability("power_font")
	AbilityManager.equip_ability("enforce")
	AbilityManager.equip_ability("empty_palm")
	AbilityManager.equip_ability("power_font")
	# All 4 slots should be filled (no empty strings)
	var filled: int = 0
	for id: String in _save_data.equipped_ability_ids:
		if not id.is_empty():
			filled += 1
	assert_eq(filled, 4, "Should have 4 abilities equipped")
	assert_eq(AbilityManager.get_max_slots(), 4)

func test_equip_already_equipped() -> void:
	AbilityManager.equip_ability("basic_strike")
	var count: int = 0
	for id: String in _save_data.equipped_ability_ids:
		if id == "basic_strike":
			count += 1
	assert_eq(count, 1, "Equipping already-equipped ability should not duplicate")

func test_equip_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.equip_ability("enforce")
	assert_signal_emitted(AbilityManager, "equipped_abilities_changed",
		"equipped_abilities_changed signal should fire on equip")

# ----- Unequip Tests -----

func test_unequip_ability() -> void:
	AbilityManager.unequip_ability("basic_strike")
	assert_false(AbilityManager.is_ability_equipped("basic_strike"),
		"basic_strike should not be equipped after unequip")

func test_unequip_not_equipped() -> void:
	AbilityManager.unequip_ability("enforce")
	assert_false(AbilityManager.is_ability_equipped("enforce"))

func test_unequip_emits_signal() -> void:
	watch_signals(AbilityManager)
	AbilityManager.unequip_ability("basic_strike")
	assert_signal_emitted(AbilityManager, "equipped_abilities_changed",
		"equipped_abilities_changed signal should fire on unequip")

# ----- Getter Tests -----

func test_get_equipped_abilities() -> void:
	var equipped: Array[AbilityData] = AbilityManager.get_equipped_abilities()
	assert_eq(equipped.size(), 1, "Should have 1 equipped ability (basic_strike)")
	if equipped.size() > 0:
		assert_eq(equipped[0].ability_id, "basic_strike")

func test_get_unlocked_abilities() -> void:
	var unlocked: Array[AbilityData] = AbilityManager.get_unlocked_abilities()
	assert_eq(unlocked.size(), 2, "Should have 2 unlocked abilities")

func test_get_max_slots() -> void:
	assert_eq(AbilityManager.get_max_slots(), 4)
