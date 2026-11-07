extends GutTest

## Integration tests for the drill drawer (DrillDrawer), the zone chest's drawer
## for one learned drill while the body refining board is up, and the list that
## holds them (DrillDrawerList): what a drawer shows, a press that equips its drill (and
## nothing on the drawer in use), the NEW seal, the mouse it keeps from its parts,
## a long name that wraps and grows the drawer, and the list's drawers in the
## order the drills were learned. Every test runs on a fresh save with Horse Stance
## learned after Stone Lifting, Stone Lifting equipped, and the original save put
## back after it.

const DRAWER_SCENE: PackedScene = preload("res://scenes/body_refining/drill_drawer/drill_drawer.tscn")
const LIST_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/drill_drawer_list/drill_drawer_list.tscn")

const AttributeType = CharacterAttributesData.AttributeType

const STONE_ID: String = "stone_lifting"
const STANCE_ID: String = "horse_stance"
const LEAF_ID: String = "falling_leaf"
const FIXTURE_ID: String = "test_drill_drawer_drill"

const DRAWER_SIZE: Vector2 = Vector2(392, 92)
## The title's line (kit §5.5).
const TITLE_LINE_HEIGHT: float = 20.0
## A name no shipped drill has: wider than the title row at any seal.
const LONG_NAME: String = "The Exceedingly Long and Winding Name of a Drill"

var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	BodyRefiningManager.unlock_drill(STANCE_ID)

func after_each() -> void:
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A drawer for the drill, built the way the drill list builds one: set up, then
## added.
func _drawer_for(drill: DrillData) -> DrillDrawer:
	var drawer: DrillDrawer = DRAWER_SCENE.instantiate() as DrillDrawer
	drawer.setup(drill)
	add_child_autofree(drawer)
	return drawer

func _drawer(drill_id: String) -> DrillDrawer:
	return _drawer_for(BodyRefiningManager.get_drill(drill_id))

func _node(drawer: DrillDrawer, unique_name: String) -> Node:
	return drawer.get_node("%" + unique_name)

## A drill in no catalog and no save, unseen and not equipped.
func _fixture(drill_name: String) -> DrillData:
	var drill := DrillData.new()
	drill.id = FIXTURE_ID
	drill.drill_name = drill_name
	drill.play_hint = "Hold, then let go in the band"
	drill.rep_seconds = 4.0
	return drill

func _press(drawer: DrillDrawer) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	drawer.gui_input.emit(event)

#-----------------------------------------------------------------------------
# WHAT A DRAWER SHOWS
#-----------------------------------------------------------------------------

## Each drawer shows its drill's icon and name, how it plays with its rep, and the
## stats it trains by their icons and names: Strength, and its other stat.
func test_a_drawer_shows_its_drill() -> void:
	var cases: Array[Dictionary] = [
		{"drill": STONE_ID, "rep": "4 s reps", "trains": [AttributeType.STRENGTH], "not": [AttributeType.BODY, AttributeType.AGILITY]},
		{"drill": STANCE_ID, "rep": "4 s reps", "trains": [AttributeType.STRENGTH, AttributeType.BODY], "not": [AttributeType.AGILITY]},
		{"drill": LEAF_ID, "rep": "2 s reps", "trains": [AttributeType.STRENGTH, AttributeType.AGILITY], "not": [AttributeType.BODY]},
	]
	for case: Dictionary in cases:
		var drill: DrillData = BodyRefiningManager.get_drill(case["drill"])
		var drawer: DrillDrawer = _drawer_for(drill)
		assert_eq((_node(drawer, "Icon") as TextureRect).texture, drill.icon, "%s: its icon" % drill.id)
		assert_eq((_node(drawer, "Title") as Label).text, drill.drill_name, "%s: its name" % drill.id)
		var detail: String = (_node(drawer, "Detail") as Label).text
		assert_true(detail.begins_with(drill.play_hint), "%s: how it plays" % drill.id)
		assert_string_contains(detail, case["rep"], "%s: its rep" % drill.id)
		var trains: String = (_node(drawer, "Trains") as RichTextLabel).text
		for stat: AttributeType in case["trains"]:
			assert_string_contains(trains, StatDisplay.mini_icon_of(stat).resource_path, "%s trains %s, by its icon" % [drill.id, StatDisplay.name_of(stat)])
			assert_string_contains(trains, StatDisplay.name_of(stat), "%s trains %s, by name" % [drill.id, StatDisplay.name_of(stat)])
		for stat: AttributeType in case["not"]:
			assert_false(trains.contains(StatDisplay.name_of(stat)), "%s does not train %s" % [drill.id, StatDisplay.name_of(stat)])
		assert_false(trains.to_lower().contains("minor"), "%s: no screen prints \"minor\"" % drill.id)

## The drill the board plays is pulled out and tagged IN USE; the others are not.
func test_the_drawer_in_use_is_tagged() -> void:
	var stone: DrillDrawer = _drawer(STONE_ID)
	var stance: DrillDrawer = _drawer(STANCE_ID)
	assert_true(stone.is_in_use(), "Stone Lifting is equipped")
	assert_true((_node(stone, "Tag") as CanvasItem).visible, "and tagged")
	assert_false((_node(stance, "Tag") as CanvasItem).visible, "Horse Stance is not")

#-----------------------------------------------------------------------------
# PICKING
#-----------------------------------------------------------------------------

func test_a_press_equips_its_drill_and_marks_it_seen() -> void:
	var stance: DrillDrawer = _drawer(STANCE_ID)
	assert_false(BodyRefiningManager.is_drill_seen(STANCE_ID), "precondition: Horse Stance is unseen")
	_press(stance)
	assert_eq(BodyRefiningManager.get_equipped_drill().id, STANCE_ID, "the press equips it")
	assert_eq(PersistenceManager.save_game_data.equipped_drill_id, STANCE_ID, "saved, so the board opens on it")
	assert_true(stance.is_in_use(), "its drawer is in use")
	assert_false(stance.is_new_shown(), "and NEW clears at once")
	BodyRefiningManager.equip_drill(STONE_ID)
	assert_true(BodyRefiningManager.is_drill_seen(STANCE_ID), "seen, so NEW stays cleared once another drill is in use")

func test_the_drawer_in_use_ignores_a_press() -> void:
	var stone: DrillDrawer = _drawer(STONE_ID)
	watch_signals(BodyRefiningManager)
	_press(stone)
	assert_signal_not_emitted(BodyRefiningManager, "equipped_drill_changed", "the drill in use stays as it is")
	assert_eq(BodyRefiningManager.get_equipped_drill().id, STONE_ID)

## The chest turns to the drawers under a cursor that has just clicked the
## training card, so the pointer arriving keeps NEW and its leaving clears it.
func test_new_clears_when_the_pointer_leaves() -> void:
	var stance: DrillDrawer = _drawer(STANCE_ID)
	assert_true(stance.is_new_shown(), "precondition: a drill learned after the save began is NEW")
	assert_false(_drawer(STONE_ID).is_new_shown(), "the drill in use never is")
	stance.mouse_entered.emit()
	assert_true(stance.is_new_shown(), "NEW stays while the pointer is on the drawer")
	stance.mouse_exited.emit()
	assert_false(stance.is_new_shown(), "the pointer leaving clears it")
	assert_true(BodyRefiningManager.is_drill_seen(STANCE_ID), "and the drill is seen")

#-----------------------------------------------------------------------------
# TEXT AND THE MOUSE
#-----------------------------------------------------------------------------

func test_a_long_name_wraps_and_the_drawer_grows() -> void:
	var drawer: DrillDrawer = _drawer_for(_fixture(LONG_NAME))
	var title := _node(drawer, "Title") as Label
	assert_eq(drawer.size, DRAWER_SIZE + Vector2(0, title.size.y - TITLE_LINE_HEIGHT), "the drawer grows by the name's extra lines, never wider")
	assert_eq(title.text, LONG_NAME, "the whole name")
	assert_gt(title.get_line_count(), 1, "wraps")
	assert_eq(title.get_visible_line_count(), title.get_line_count(), "and every line shows")
	var trains := _node(drawer, "Trains") as RichTextLabel
	assert_eq(trains.position.y + trains.size.y + DrillDrawer.ROOM_UNDER_TRAINS, drawer.size.y, "the Trains line stays inside it")
	assert_eq(drawer.size.y, _drawer_for(_fixture("Short")).size.y + title.size.y - TITLE_LINE_HEIGHT, "a short name's drawer, grown by the extra lines")

func test_a_drawer_takes_the_mouse_and_its_parts_do_not() -> void:
	# A part that took the mouse would end the drawer's hover each time the
	# pointer crossed it.
	var drawer: DrillDrawer = _drawer(STANCE_ID)
	assert_eq(drawer.mouse_filter, Control.MOUSE_FILTER_STOP)
	var parts: Array[Node] = drawer.find_children("*", "Control", true, false)
	assert_gt(parts.size(), 0, "precondition: the drawer has parts")
	for part: Node in parts:
		# The Trains line's own scroll bar, hidden while the line fits its content.
		if part.get_parent() is RichTextLabel:
			continue
		assert_eq((part as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % part.name)

#-----------------------------------------------------------------------------
# THE LIST
#-----------------------------------------------------------------------------

## Only learned drills show, in the order they were learned. Learning one rebuilds
## the list, and equipping one refreshes every drawer.
func test_the_list_lists_the_learned_drills_in_order() -> void:
	var list: DrillDrawerList = LIST_SCENE.instantiate() as DrillDrawerList
	add_child_autofree(list)
	list.build()
	assert_eq(list.get_drawer_count(), 2, "Stone Lifting and Horse Stance")
	var rows: Array[Control] = list.get_slide_rows()
	assert_eq((rows[0] as DrillDrawer).drill.id, STONE_ID, "first learned, first")
	assert_eq((rows[1] as DrillDrawer).drill.id, STANCE_ID)
	assert_null(list.get_drawer(LEAF_ID), "a drill still to learn stays a surprise")
	assert_eq(list.get_content_height(), 2 * DRAWER_SIZE.y + DrillDrawerList.DRAWER_GAP, "two drawers and a gap")
	watch_signals(list)
	BodyRefiningManager.unlock_drill(LEAF_ID)
	assert_eq(list.get_drawer_count(), 3, "learning a drill adds its drawer")
	assert_not_null(list.get_drawer(LEAF_ID))
	assert_signal_emitted(list, "layout_changed", "and the chest re-measures")
	BodyRefiningManager.equip_drill(LEAF_ID)
	assert_true(list.get_drawer(LEAF_ID).is_in_use(), "equipping a drill puts its drawer in use")
	assert_true((_node(list.get_drawer(LEAF_ID), "Tag") as CanvasItem).visible, "tagged")
	assert_false((_node(list.get_drawer(STONE_ID), "Tag") as CanvasItem).visible, "and the last one's tag goes")
