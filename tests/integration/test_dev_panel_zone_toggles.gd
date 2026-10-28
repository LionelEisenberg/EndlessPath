extends GutTest

## Integration tests for the dev panel's two zone-map toggles, on its World tab
## (docs/tooling/DEV_TOOLS.md): "Demo zones (locked, uncharted)" shows the two
## demo zones on the map, "Show hidden zones (Test Zone)" shows the zones the
## map hides, and each toggle writes a [DEV] line to the player log.

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")

const ADVANCEMENT_DEMO_ID: String = "AdvancementZoneDemo"
const UNCHARTED_DEMO_ID: String = "UnchartedZoneDemo"
const TEST_ZONE_ID: String = "TestZone"

var _panel: DevPanel = null
var _original_save: SaveGameData

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_panel = add_child_autofree(DEV_PANEL_SCENE.instantiate())

func after_each() -> void:
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)
	_stop_actions()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()

func _stop_actions() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _map_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for zone: ZoneData in ZoneManager.get_map_zones():
		ids.append(zone.zone_id)
	return ids

## The World tab's check with this unique name.
func _check(check_name: String) -> CheckButton:
	return _panel.get_node("%WorldTab").get_node("%" + check_name)

#-----------------------------------------------------------------------------
# DEMO ZONES
#-----------------------------------------------------------------------------

func test_demo_toggle_shows_and_hides_the_demo_zones() -> void:
	var check: CheckButton = _check("DemoZonesCheck")
	check.button_pressed = true
	assert_has(_map_zone_ids(), ADVANCEMENT_DEMO_ID)
	assert_has(_map_zone_ids(), UNCHARTED_DEMO_ID)
	check.button_pressed = false
	assert_does_not_have(_map_zone_ids(), ADVANCEMENT_DEMO_ID)
	assert_does_not_have(_map_zone_ids(), UNCHARTED_DEMO_ID)

func test_demo_toggle_logs_a_dev_line() -> void:
	watch_signals(LogManager)
	_check("DemoZonesCheck").button_pressed = true
	var line: String = get_signal_parameters(LogManager, "message_logged")[0]
	assert_string_contains(line, "[DEV]")
	assert_string_contains(line, "Demo zones: ON")

#-----------------------------------------------------------------------------
# HIDDEN ZONES
#-----------------------------------------------------------------------------

func test_hidden_toggle_shows_and_hides_test_zone() -> void:
	var check: CheckButton = _check("HiddenZonesCheck")
	assert_does_not_have(_map_zone_ids(), TEST_ZONE_ID, "Test Zone starts hidden")
	check.button_pressed = true
	assert_has(_map_zone_ids(), TEST_ZONE_ID)
	check.button_pressed = false
	assert_does_not_have(_map_zone_ids(), TEST_ZONE_ID)

func test_hidden_toggle_logs_a_dev_line() -> void:
	watch_signals(LogManager)
	_check("HiddenZonesCheck").button_pressed = true
	var line: String = get_signal_parameters(LogManager, "message_logged")[0]
	assert_string_contains(line, "[DEV]")
	assert_string_contains(line, "Show hidden zones: ON")
