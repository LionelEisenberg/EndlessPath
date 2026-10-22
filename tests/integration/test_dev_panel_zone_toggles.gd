extends GutTest

## Integration tests for the dev panel's two zone-map toggles (plan Task 14,
## docs/tooling/DEV_TOOLS.md): "Demo zones (locked, uncharted)" shows the two
## demo zones on the map, "Show hidden zones (Test Zone)" shows the zones the
## map hides, and each toggle writes a [DEV] line to the player log.

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")

const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const TEST_ZONE_ID: String = "TestZone"

var _panel: DevPanel = null

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_panel = add_child_autofree(DEV_PANEL_SCENE.instantiate())

func after_each() -> void:
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _map_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for zone: ZoneData in ZoneManager.get_map_zones():
		ids.append(zone.zone_id)
	return ids

#-----------------------------------------------------------------------------
# DEMO ZONES
#-----------------------------------------------------------------------------

func test_demo_toggle_shows_and_hides_the_demo_zones() -> void:
	var check: CheckButton = _panel.get_node("%DemoZonesCheck")
	check.button_pressed = true
	assert_has(_map_zone_ids(), ADVANCEMENT_DEMO_ID)
	assert_has(_map_zone_ids(), UNCHARTED_DEMO_ID)
	check.button_pressed = false
	assert_does_not_have(_map_zone_ids(), ADVANCEMENT_DEMO_ID)
	assert_does_not_have(_map_zone_ids(), UNCHARTED_DEMO_ID)

func test_demo_toggle_logs_a_dev_line() -> void:
	watch_signals(LogManager)
	_panel.get_node("%DemoZonesCheck").button_pressed = true
	var line: String = get_signal_parameters(LogManager, "message_logged")[0]
	assert_string_contains(line, "[DEV]")
	assert_string_contains(line, "Demo zones: ON")

#-----------------------------------------------------------------------------
# HIDDEN ZONES
#-----------------------------------------------------------------------------

func test_hidden_toggle_shows_and_hides_test_zone() -> void:
	var check: CheckButton = _panel.get_node("%HiddenZonesCheck")
	assert_does_not_have(_map_zone_ids(), TEST_ZONE_ID, "Test Zone starts hidden")
	check.button_pressed = true
	assert_has(_map_zone_ids(), TEST_ZONE_ID)
	check.button_pressed = false
	assert_does_not_have(_map_zone_ids(), TEST_ZONE_ID)

func test_hidden_toggle_logs_a_dev_line() -> void:
	watch_signals(LogManager)
	_panel.get_node("%HiddenZonesCheck").button_pressed = true
	var line: String = get_signal_parameters(LogManager, "message_logged")[0]
	assert_string_contains(line, "[DEV]")
	assert_string_contains(line, "Show hidden zones: ON")
