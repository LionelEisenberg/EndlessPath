extends GutTest

## Unit tests for the map-first zone view's map data on ZoneManager: the four
## map states (current, open, locked, uncharted), which zones the map shows
## (hidden zones and the dev demo zones), the per-zone last idle action, and
## the "Show me" focus request.

const CHART_CONDITION_ID: String = "test_map_state_chart"
const UNLOCK_CONDITION_ID: String = "test_map_state_unlock"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _condition(condition_id: String) -> UnlockConditionData:
	var condition := UnlockConditionData.new()
	condition.condition_id = condition_id
	condition.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	condition.target_value = condition_id
	return condition

## A zone built in code. The flags decide whether it carries a chart or unlock
## condition at all; tests latch them with UnlockManager.force_unlock_condition.
func _fixture_zone(zone_id: String, with_chart_condition: bool, with_unlock_condition: bool) -> ZoneData:
	var zone := ZoneData.new()
	zone.zone_id = zone_id
	zone.zone_name = zone_id
	if with_chart_condition:
		zone.chart_conditions.append(_condition(CHART_CONDITION_ID))
	if with_unlock_condition:
		zone.zone_unlock_conditions.append(_condition(UNLOCK_CONDITION_ID))
	return zone

func _map_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for zone: ZoneData in ZoneManager.get_map_zones():
		ids.append(zone.zone_id)
	return ids

func _map_zone(zone_id: String) -> ZoneData:
	for zone: ZoneData in ZoneManager.get_map_zones():
		if zone.zone_id == zone_id:
			return zone
	return null

#-----------------------------------------------------------------------------
# MAP STATES
#-----------------------------------------------------------------------------

func test_current_zone_is_current() -> void:
	var current: ZoneData = ZoneManager.get_current_zone()
	assert_eq(ZoneManager.get_zone_map_state(current), ZoneManager.ZoneMapState.CURRENT)

func test_unlocked_other_zone_is_open() -> void:
	var zone := _fixture_zone("FixtureOpenZone", false, true)
	UnlockManager.force_unlock_condition(UNLOCK_CONDITION_ID)
	assert_eq(ZoneManager.get_zone_map_state(zone), ZoneManager.ZoneMapState.OPEN)

func test_zone_without_any_condition_is_open() -> void:
	var zone := _fixture_zone("FixtureFreeZone", false, false)
	assert_true(ZoneManager.is_zone_charted(zone), "no chart conditions means charted")
	assert_eq(ZoneManager.get_zone_map_state(zone), ZoneManager.ZoneMapState.OPEN)

func test_charted_but_not_unlocked_zone_is_locked() -> void:
	var zone := _fixture_zone("FixtureLockedZone", true, true)
	UnlockManager.force_unlock_condition(CHART_CONDITION_ID)
	assert_true(ZoneManager.is_zone_charted(zone))
	assert_eq(ZoneManager.get_zone_map_state(zone), ZoneManager.ZoneMapState.LOCKED)

func test_unchartered_zone_is_uncharted() -> void:
	var zone := _fixture_zone("FixtureUnchartedZone", true, true)
	UnlockManager.force_unlock_condition(UNLOCK_CONDITION_ID)
	assert_false(ZoneManager.is_zone_charted(zone))
	assert_eq(ZoneManager.get_zone_map_state(zone), ZoneManager.ZoneMapState.UNCHARTED,
		"an unmet chart condition wins over met unlock conditions")

func test_locked_current_zone_reads_locked() -> void:
	# Spirit Valley has no unlock conditions; Test Zone needs the first dialogue.
	PersistenceManager.save_game_data.current_selected_zone_id = "TestZone"
	var test_zone: ZoneData = ZoneManager.get_zone_by_id("TestZone")
	assert_eq(ZoneManager.get_zone_map_state(test_zone), ZoneManager.ZoneMapState.LOCKED)
	UnlockManager.force_unlock_condition("celestial_intervener_dialogue_1")
	assert_eq(ZoneManager.get_zone_map_state(test_zone), ZoneManager.ZoneMapState.CURRENT)

#-----------------------------------------------------------------------------
# ZONES ON THE MAP
#-----------------------------------------------------------------------------

func test_map_zones_skip_hidden_test_zone() -> void:
	assert_eq(_map_zone_ids(), ["SpiritValley"] as Array[String])

func test_hidden_zones_toggle_includes_test_zone() -> void:
	watch_signals(ZoneManager)
	ZoneManager.set_hidden_zones_visible(true)
	assert_eq(_map_zone_ids(), ["SpiritValley", "TestZone"] as Array[String], "list order is kept")
	assert_signal_emit_count(ZoneManager, "map_zones_changed", 1)

func test_demo_toggle_adds_two_zones_and_emits() -> void:
	watch_signals(ZoneManager)
	ZoneManager.set_demo_zones_visible(true)
	assert_eq(_map_zone_ids(), ["SpiritValley", "AdvancementZoneDemo", "UnchartedZoneDemo"] as Array[String])
	assert_signal_emit_count(ZoneManager, "map_zones_changed", 1)

	ZoneManager.set_demo_zones_visible(false)
	assert_eq(_map_zone_ids(), ["SpiritValley"] as Array[String])
	assert_signal_emit_count(ZoneManager, "map_zones_changed", 2)

func test_repeated_toggle_does_not_emit() -> void:
	ZoneManager.set_demo_zones_visible(true)
	watch_signals(ZoneManager)
	ZoneManager.set_demo_zones_visible(true)
	ZoneManager.set_hidden_zones_visible(false)
	assert_signal_not_emitted(ZoneManager, "map_zones_changed")

func test_demo_zones_states() -> void:
	ZoneManager.set_demo_zones_visible(true)
	assert_eq(ZoneManager.get_zone_map_state(_map_zone("AdvancementZoneDemo")), ZoneManager.ZoneMapState.LOCKED)
	assert_eq(ZoneManager.get_zone_map_state(_map_zone("UnchartedZoneDemo")), ZoneManager.ZoneMapState.UNCHARTED)

func test_demo_zones_stay_out_of_the_zone_list() -> void:
	ZoneManager.set_demo_zones_visible(true)
	assert_false(ZoneManager.has_zone("AdvancementZoneDemo"), "a save can never stand in a demo zone")
	assert_false(ZoneManager.has_zone("UnchartedZoneDemo"))
	for zone: ZoneData in ZoneManager.get_all_zones():
		assert_false(zone.zone_id.ends_with("Demo"), "%s must not be in zone_data_list.tres" % zone.zone_id)

func test_advancement_demo_requirement_names_a_real_action() -> void:
	ZoneManager.set_demo_zones_visible(true)
	var demo: ZoneData = _map_zone("AdvancementZoneDemo")
	assert_not_null(ZoneManager.get_action_by_id(demo.requirement_action_id), "Show me needs a card to scroll to")

#-----------------------------------------------------------------------------
# TEST ZONE (OPEN-ZONE DEMO)
#-----------------------------------------------------------------------------

func test_test_zone_sits_west_of_spirit_valley() -> void:
	var spirit_valley: ZoneData = ZoneManager.get_zone_by_id("SpiritValley")
	var test_zone: ZoneData = ZoneManager.get_zone_by_id("TestZone")
	assert_eq(spirit_valley.tilemap_location, Vector2i(0, 0), "the kit centres the map on Spirit Valley's cell")
	assert_eq(test_zone.tilemap_location, Vector2i(-1, 0), "the kit puts Test Zone one cell west, on the west route")

func test_test_zone_has_no_lore() -> void:
	var test_zone: ZoneData = ZoneManager.get_zone_by_id("TestZone")
	assert_eq(test_zone.description, "", "the kit shows Test Zone's panel with no About button")

#-----------------------------------------------------------------------------
# LAST IDLE ACTION
#-----------------------------------------------------------------------------

func test_last_idle_action_id_defaults_to_empty() -> void:
	assert_eq(ZoneManager.get_last_idle_action_id("SpiritValley"), "")

func test_last_idle_action_id_is_per_zone() -> void:
	ZoneManager.set_last_idle_action_id("SpiritValley", "aura_well_training")
	ZoneManager.set_last_idle_action_id("TestZone", "sprint_forest_foraging_action")
	assert_eq(ZoneManager.get_last_idle_action_id("SpiritValley"), "aura_well_training")
	assert_eq(ZoneManager.get_last_idle_action_id("TestZone"), "sprint_forest_foraging_action")
	assert_eq(PersistenceManager.save_game_data.get_zone_progression_data("SpiritValley").last_idle_action_id,
		"aura_well_training", "it is written to the save")

#-----------------------------------------------------------------------------
# ACTION FOCUS
#-----------------------------------------------------------------------------

func test_request_action_focus_emits() -> void:
	watch_signals(ZoneManager)
	ZoneManager.request_action_focus("shallow_woods_adventure_action")
	assert_signal_emitted_with_parameters(ZoneManager, "action_focus_requested", ["shallow_woods_adventure_action"])
