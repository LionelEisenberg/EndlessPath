extends GutTest

## Integration test: full Beat 3b flow.
## 1. Quest starts. CD < 10 → NPC 4 hidden, Merchant hidden, quest step 1 not complete.
## 2. CD reaches 10 → step 1 complete, NPC 4 visible.
## 3. Fire celestial_intervener_dialogue_4 event → step 2 completes → quest
##    completes → map in inventory.
## 4. Filter a fake pool with the refugee camp + a control encounter → camp eligible.
## 5. Fire merchant_discovered → Merchant zone action visible.
## 6. Re-filter the pool → camp no longer eligible (merchant_discovered=true
##    trips the gate).

const ZONE_ID: String = "SpiritValley"
const QUEST_ID: String = "q_reach_core_density_10"
const NPC4_ACTION_ID: String = "celestial_intervener_dialogue_4"
const MERCHANT_ACTION_ID: String = "spirit_valley_merchant"
const MAP_ITEM_ID: String = "refugee_camp_map"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	# Unit tests may have replaced QuestManager._quest_catalog and _quests_by_id
	# with test-only stubs. Restore the real catalog and rebuild the index so
	# integration tests operate on live data.
	QuestManager._quest_catalog = load("res://resources/quests/quest_list.tres")
	QuestManager._build_catalog_index()

func _has_action(action_id: String) -> bool:
	for a in ZoneManager.get_available_actions(ZONE_ID):
		if a.action_id == action_id:
			return true
	return false

func _refugee_camp_encounter() -> AdventureEncounter:
	return load("res://resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres") as AdventureEncounter

func _filter_pool(pool: Array) -> Array:
	var generator_script: GDScript = load("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
	var generator = generator_script.new()
	var result: Array = generator._build_eligible_special_pool(pool)
	generator.queue_free()
	return result

func _push_cd_to_10() -> void:
	var save := PersistenceManager.save_game_data
	save.core_density_level = 10.0
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)

func test_full_beat_3b_flow() -> void:
	# --- Start the quest. ---
	QuestManager.start_quest(QUEST_ID)
	assert_true(QuestManager.has_active_quest(QUEST_ID), "quest should be active")
	assert_false(_has_action(NPC4_ACTION_ID), "NPC 4 must be hidden before CD 10")
	assert_false(InventoryManager.has_item(MAP_ITEM_ID), "map must not be owned yet")

	# --- Reach CD 10 → quest step 1 completes, NPC 4 visible. ---
	_push_cd_to_10()
	assert_true(_has_action(NPC4_ACTION_ID), "NPC 4 must be visible at CD 10")

	# --- NPC 4 click fires dialogue_4 event → quest step 2 + completion. ---
	EventManager.trigger_event(NPC4_ACTION_ID)
	assert_false(QuestManager.has_active_quest(QUEST_ID), "quest should have completed")
	assert_true(QuestManager.has_completed_quest(QUEST_ID), "quest should be in the completed set")
	assert_true(InventoryManager.has_item(MAP_ITEM_ID), "map should be in inventory after quest completion")

	# --- Refugee camp encounter is eligible for placement now. ---
	var pool: Array = [_refugee_camp_encounter()]
	var eligible: Array = _filter_pool(pool)
	assert_eq(eligible.size(), 1, "refugee camp should be eligible once the map is owned and merchant undiscovered")

	# --- Visit fires merchant_discovered. Merchant zone action visible. ---
	assert_false(_has_action(MERCHANT_ACTION_ID), "Merchant must be hidden before discovery")
	EventManager.trigger_event("merchant_discovered")
	assert_true(_has_action(MERCHANT_ACTION_ID), "Merchant must be visible after discovery")

	# --- Re-generating an adventure now filters the camp out. ---
	var re_eligible: Array = _filter_pool(pool)
	assert_eq(re_eligible.size(), 0, "refugee camp must no longer be eligible once merchant_discovered fired")
