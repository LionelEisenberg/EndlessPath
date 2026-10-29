extends GutTest

## Integration tests for the lacquer dock (Dock, lacquer kit §5.4): the Path
## button's brass ring and count seal following the path point balance, the
## Abilities ring with no count while an unlocked ability sits unequipped, a
## save reset clearing both, a press parsing the button's input action, then
## releasing it, and the dock keeping its clicks from the map.

const DOCK_SCENE_PATH: String = "res://scenes/ui/dock/dock.tscn"

const SCREEN_SIZE: Vector2 = Vector2(1920.0, 1080.0)

## An ability the fresh save has not unlocked (it starts with basic_strike and
## enforce, both equipped).
const SPARE_ABILITY_ID: String = "empty_palm"
const TEST_PATH_NODE_ID: String = "dock_test_node"

var _dock: Dock = null

## Records the open_path presses the game's input handlers would see.
class ActionProbe:
	extends Node

	var presses: int = 0

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"open_path"):
			presses += 1

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_use_fresh_save()

func after_each() -> void:
	Input.action_release(&"open_path")
	# A save reset also gives PathManager its real tree back after
	# _use_test_path_node().
	_use_fresh_save()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _use_fresh_save(save: SaveGameData = SaveGameData.new()) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## Adds the dock scene inside a 1920x1080 stand-in for the zone view.
func _add_dock() -> Dock:
	var screen: Control = Control.new()
	screen.size = SCREEN_SIZE
	add_child_autofree(screen)
	var scene: PackedScene = load(DOCK_SCENE_PATH)
	_dock = scene.instantiate()
	screen.add_child(_dock)
	return _dock

func _button(button_name: String) -> SystemMenuButton:
	return _dock.get_node("%" + button_name) as SystemMenuButton

## A node inside one button's own scene.
func _part(button: SystemMenuButton, unique_name: String) -> Node:
	return button.get_node("%" + unique_name)

func _is_shown(button: SystemMenuButton, unique_name: String) -> bool:
	return (_part(button, unique_name) as CanvasItem).is_visible_in_tree()

## Which of the three faces shows: "normal", "ring" or "hover". Exactly one is
## expected to.
func _shown_faces(button: SystemMenuButton) -> Array[String]:
	var shown: Array[String] = []
	if _is_shown(button, "FaceNormal"):
		shown.append("normal")
	if _is_shown(button, "FaceRing"):
		shown.append("ring")
	if _is_shown(button, "FaceHover"):
		shown.append("hover")
	return shown

## Makes PathManager's current tree a one-node tree costing `cost` points, so
## a test can spend points through purchase_node(). after_each's save reset
## restores the real tree.
func _use_test_path_node(cost: int) -> void:
	var node: PathNodeData = PathNodeData.new()
	node.id = TEST_PATH_NODE_ID
	node.display_name = "Dock Test Node"
	node.point_cost = cost
	node.max_purchases = 1
	node.required_stage = CultivationManager.AdvancementStage.FOUNDATION
	var nodes: Array[PathNodeData] = [node]
	var tree: PathTreeData = PathTreeData.new()
	tree.path_id = "dock_test_path"
	tree.nodes = nodes
	PathManager._current_tree = tree

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_dock_stops_clicks() -> void:
	_add_dock()
	assert_eq(_dock.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a click on the dock's shelf never reaches the map")

#-----------------------------------------------------------------------------
# NOTIFICATIONS
#-----------------------------------------------------------------------------

func test_path_count_follows_points() -> void:
	_add_dock()
	var path_button: SystemMenuButton = _button("PathButton")

	PathManager.add_points(3)
	assert_true(path_button.has_notification(), "points to spend notify the Path button")
	assert_eq(path_button.get_notification_count(), 3)
	assert_eq(_shown_faces(path_button), ["ring"] as Array[String], "the brass ring replaces the plain face")
	assert_true(_is_shown(path_button, "CountSeal"), "the count seal shows")
	assert_eq((_part(path_button, "CountSeal").get_node("%CountLabel") as Label).text, "3")

	_use_test_path_node(3)
	assert_true(PathManager.purchase_node(TEST_PATH_NODE_ID), "the test node is bought with all 3 points")
	assert_false(path_button.has_notification(), "no points left: no notification")
	assert_eq(path_button.get_notification_count(), 0)
	assert_eq(_shown_faces(path_button), ["normal"] as Array[String])
	assert_false(_is_shown(path_button, "CountSeal"), "the seal hides with the ring")

func test_path_reads_balance_on_ready() -> void:
	var save: SaveGameData = SaveGameData.new()
	save.path_points = 2
	_use_fresh_save(save)
	_add_dock()
	var path_button: SystemMenuButton = _button("PathButton")
	assert_true(path_button.has_notification(), "a balance saved before the dock existed shows")
	assert_eq(path_button.get_notification_count(), 2)
	assert_eq((_part(path_button, "CountSeal").get_node("%CountLabel") as Label).text, "2")

func test_abilities_ring_without_count() -> void:
	_add_dock()
	var abilities_button: SystemMenuButton = _button("AbilitiesButton")

	AbilityManager.unlock_ability(SPARE_ABILITY_ID)
	assert_true(abilities_button.has_notification(), "an unequipped unlock notifies Abilities")
	assert_eq(abilities_button.get_notification_count(), 0, "the Abilities notification has no count")
	assert_eq(_shown_faces(abilities_button), ["ring"] as Array[String])
	assert_false(_is_shown(abilities_button, "CountSeal"), "a ring with no count has no seal")

	AbilityManager.equip_ability(SPARE_ABILITY_ID)
	assert_false(abilities_button.has_notification(), "equipping it clears the ring")
	assert_eq(_shown_faces(abilities_button), ["normal"] as Array[String])

func test_save_reset_clears_notifications() -> void:
	_add_dock()
	PathManager.add_points(2)
	AbilityManager.unlock_ability(SPARE_ABILITY_ID)
	assert_true(_button("PathButton").has_notification())
	assert_true(_button("AbilitiesButton").has_notification())

	_use_fresh_save()
	assert_false(_button("PathButton").has_notification(), "the fresh save has no points")
	assert_false(_button("AbilitiesButton").has_notification(), "the fresh save has every unlock equipped")

#-----------------------------------------------------------------------------
# PRESS
#-----------------------------------------------------------------------------

func test_pressing_parses_the_action() -> void:
	_add_dock()
	var probe: ActionProbe = add_child_autofree(ActionProbe.new())
	_button("PathButton").pressed.emit()
	# Input buffers parsed events until the next frame's flush.
	await wait_process_frames(2)
	assert_eq(probe.presses, 1, "the Path button fires open_path once")

## A parsed press with no release would leave open_path held for the rest of
## the session (Input.is_action_pressed stays true).
func test_pressing_releases_the_action() -> void:
	_add_dock()
	_button("PathButton").pressed.emit()
	await wait_process_frames(2)
	assert_false(Input.is_action_pressed(&"open_path"), "open_path is released again")
