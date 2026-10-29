extends GutTest

## Integration tests for the technique drawer (TechniqueDrawer), the zone chest's
## drawer for one learned cycling technique: its detail line, icon and name, the
## drawer in use tagged IN USE, the NEW seal (cleared when the pointer leaves the
## drawer or on a press), equip on click (and nothing on the drawer in use), the
## mouse it keeps from its parts, and a long name, which wraps and grows the
## drawer (never wider).
## Drawers are built with setup on a fresh save with smooth_flow unlocked, as
## the technique list builds them; foundation_technique stays equipped.

const DRAWER_SCENE: PackedScene = preload("res://scenes/cycling/technique_drawer/technique_drawer.tscn")

const FOUNDATION_ID: String = "foundation_technique"
const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"
const FIXTURE_ID: String = "test_technique_drawer_technique"

const DRAWER_SIZE: Vector2 = Vector2(392, 72)
## The title's line (kit §5.5).
const TITLE_LINE_HEIGHT: float = 20.0
## Names the shipped techniques don't have: one wider than the row leaves
## beside the NEW seal but not than the detail line, and one wider than both.
const NAME_WRAPS_BESIDE_SEAL: String = "Seven Heavens Reverberating Flow"
const LONG_NAME: String = "The Exceedingly Long and Winding Name of a Technique"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	CyclingManager.unlock_technique(SMOOTH_ID)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The catalog's technique with this id, which must be unlocked.
func _technique(technique_id: String) -> CyclingTechniqueData:
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		if technique.id == technique_id:
			return technique
	fail_test("precondition: %s is unlocked" % technique_id)
	return null

## A drawer for the technique, built the way the technique list builds one: set
## up, then added.
func _drawer_for(technique: CyclingTechniqueData) -> TechniqueDrawer:
	var drawer: TechniqueDrawer = DRAWER_SCENE.instantiate() as TechniqueDrawer
	drawer.setup(technique)
	add_child_autofree(drawer)
	return drawer

func _drawer(technique_id: String) -> TechniqueDrawer:
	return _drawer_for(_technique(technique_id))

func _node(drawer: TechniqueDrawer, unique_name: String) -> Node:
	return drawer.get_node("%" + unique_name)

## A technique that is in no catalog and no save, for the names and numbers the
## shipped ones don't have. It is unseen and not equipped.
func _fixture(technique_name: String, madra: float, seconds: float, zone_count: int) -> CyclingTechniqueData:
	var technique := CyclingTechniqueData.new()
	technique.id = FIXTURE_ID
	technique.technique_name = technique_name
	technique.base_madra_per_cycle = madra
	technique.cycle_duration = seconds
	for i: int in zone_count:
		technique.cycling_zones.append(CyclingZoneData.new())
	return technique

func _press(drawer: TechniqueDrawer, button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	drawer.gui_input.emit(event)

func _equipped_id() -> String:
	return PersistenceManager.save_game_data.equipped_cycling_technique_id

## Checks that the drawer is never wider, and that the list reads its height.
func _assert_the_list_reads_its_height(drawer: TechniqueDrawer) -> void:
	assert_eq(drawer.size.x, DRAWER_SIZE.x, "the drawer is never wider")
	assert_eq(drawer.custom_minimum_size, drawer.size, "the list reads the height")

#-----------------------------------------------------------------------------
# DETAIL TEXT
#-----------------------------------------------------------------------------

func test_detail_text() -> void:
	assert_eq(TechniqueDrawer.detail_text(_fixture("A", 50.0, 8.0, 0)), "50 Madra · 8 s cycle · no zones")
	assert_eq(TechniqueDrawer.detail_text(_fixture("B", 200.0, 15.0, 4)), "200 Madra · 15 s cycle · 4 zones")
	assert_eq(TechniqueDrawer.detail_text(_fixture("C", 250.0, 8.0, 1)), "250 Madra · 8 s cycle · 1 zone")

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func test_setup_shows_icon_name_and_detail() -> void:
	var smooth: CyclingTechniqueData = _technique(SMOOTH_ID)
	var drawer: TechniqueDrawer = _drawer_for(smooth)
	var icon := _node(drawer, "Icon") as TextureRect
	assert_not_null(smooth.icon, "precondition: the shipped technique has an icon")
	assert_eq(icon.texture, smooth.icon)
	assert_eq((_node(drawer, "Title") as Label).text, "Smooth Flow Technique")
	assert_eq((_node(drawer, "Detail") as Label).text, "200 Madra · 15 s cycle · 4 zones")
	assert_eq(drawer.technique, smooth)

#-----------------------------------------------------------------------------
# THE DRAWER IN USE
#-----------------------------------------------------------------------------

func test_refresh_follows_the_equipped_technique() -> void:
	var foundation: TechniqueDrawer = _drawer(FOUNDATION_ID)
	var smooth: TechniqueDrawer = _drawer(SMOOTH_ID)
	CyclingManager.equip_technique(SMOOTH_ID)
	foundation.refresh()
	smooth.refresh()
	assert_true(smooth.is_in_use())
	assert_true((_node(smooth, "Tag") as TextureRect).visible, "the IN USE tag moves to the new drawer")
	assert_false(foundation.is_in_use())
	assert_false((_node(foundation, "Tag") as TextureRect).visible, "and leaves the old one")

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

func test_click_equips() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_false(drawer.is_in_use(), "precondition: foundation is equipped")
	watch_signals(CyclingManager)
	_press(drawer)
	assert_eq(_equipped_id(), SMOOTH_ID)
	assert_signal_emit_count(CyclingManager, "equipped_technique_changed", 1)
	assert_true(drawer.is_in_use(), "the drawer is in use at once")

func test_click_on_the_drawer_in_use_does_nothing() -> void:
	# Review Focus 3: the drawer in use ignores the press, so a running cycle is
	# never ended by it.
	var drawer: TechniqueDrawer = _drawer(FOUNDATION_ID)
	assert_true(drawer.is_in_use(), "precondition: foundation is equipped")
	watch_signals(CyclingManager)
	_press(drawer)
	assert_eq(_equipped_id(), FOUNDATION_ID)
	assert_signal_not_emitted(CyclingManager, "equipped_technique_changed")
	assert_true(drawer.is_in_use())

func test_only_a_left_press_equips() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	_press(drawer, MOUSE_BUTTON_RIGHT)
	_press(drawer, MOUSE_BUTTON_LEFT, false)
	assert_eq(_equipped_id(), FOUNDATION_ID, "a right press and a left release do not equip")

func test_equipping_marks_the_technique_seen() -> void:
	# The equipped technique counts as seen only while it is equipped, so the
	# press itself records it: smooth stays seen once another technique is in use.
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_true(drawer.is_new_shown(), "precondition: smooth is NEW")
	_press(drawer)
	CyclingManager.equip_technique(FOUNDATION_ID)
	drawer.refresh()
	assert_false(drawer.is_in_use(), "precondition: foundation is equipped again")
	assert_true(CyclingManager.is_technique_seen(SMOOTH_ID))
	assert_false(drawer.is_new_shown())

#-----------------------------------------------------------------------------
# THE NEW SEAL AND A LONG NAME
#-----------------------------------------------------------------------------

func test_new_seal_shows_for_an_unseen_technique() -> void:
	assert_true(_drawer(SMOOTH_ID).is_new_shown(), "smooth was unlocked after the save was first initialised")
	assert_false(_drawer(FOUNDATION_ID).is_new_shown(), "the technique in use is never NEW")

func test_new_seal_clears_when_the_pointer_leaves_or_on_a_press() -> void:
	# The chest can turn to the drawers under a cursor that has just clicked the
	# Wilderness Cycling card, so the pointer's first move can land on a drawer
	# the player has not looked at yet. Hover keeps NEW; the pointer leaving the
	# drawer clears it, and so does a press that equips its technique.
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	var smooth: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_true(smooth.is_new_shown(), "precondition: smooth is NEW")
	smooth.mouse_entered.emit()
	assert_true(smooth.is_new_shown(), "NEW stays while the pointer is on the drawer")
	assert_false(CyclingManager.is_technique_seen(SMOOTH_ID), "and the technique is not seen yet")
	smooth.mouse_exited.emit()
	assert_false(smooth.is_new_shown(), "the pointer leaving clears it")
	assert_true(CyclingManager.is_technique_seen(SMOOTH_ID))
	var torrential: TechniqueDrawer = _drawer(TORRENTIAL_ID)
	torrential.mouse_entered.emit()
	assert_true(torrential.is_new_shown(), "precondition: torrential is hovered and NEW")
	_press(torrential)
	assert_false(torrential.is_new_shown(), "a press that equips it clears NEW at once")

func test_a_long_name_wraps_beside_the_seal_and_the_drawer_grows() -> void:
	var drawer: TechniqueDrawer = _drawer_for(_fixture(LONG_NAME, 50.0, 8.0, 0))
	var title := _node(drawer, "Title") as Label
	assert_true(drawer.is_new_shown(), "precondition: an unseen technique shows NEW")
	assert_eq(title.text, LONG_NAME, "the whole name")
	assert_gt(title.get_line_count(), 1, "wraps")
	assert_eq(title.get_visible_line_count(), title.get_line_count(), "and every line shows")
	assert_eq(drawer.size.y, DRAWER_SIZE.y + title.size.y - TITLE_LINE_HEIGHT, "the drawer grows by its extra lines")
	_assert_the_list_reads_its_height(drawer)

func test_a_name_that_wraps_beside_the_seal_fits_once_it_clears() -> void:
	var drawer: TechniqueDrawer = _drawer_for(_fixture(NAME_WRAPS_BESIDE_SEAL, 50.0, 8.0, 0))
	var title := _node(drawer, "Title") as Label
	assert_eq(title.get_line_count(), 2, "precondition: beside the seal the name takes two lines")
	assert_gt(drawer.size.y, DRAWER_SIZE.y, "precondition: and the drawer grew")
	watch_signals(drawer)
	drawer.mouse_exited.emit()
	assert_false(drawer.is_new_shown(), "precondition: the pointer leaving cleared the seal")
	assert_eq(title.get_line_count(), 1, "without the seal the name fits one line")
	assert_eq(drawer.size, DRAWER_SIZE, "and the drawer is 72 again")
	assert_signal_emitted(drawer, "height_changed", "which the list hears")
	_assert_the_list_reads_its_height(drawer)

#-----------------------------------------------------------------------------
# THE MOUSE
#-----------------------------------------------------------------------------

func test_drawer_takes_the_mouse_and_its_parts_do_not() -> void:
	# A part that took the mouse would end the drawer's hover each time the
	# pointer crossed it.
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_eq(drawer.mouse_filter, Control.MOUSE_FILTER_STOP)
	var parts: Array[Node] = drawer.find_children("*", "Control", true, false)
	assert_gt(parts.size(), 0, "precondition: the drawer has parts")
	for part: Node in parts:
		assert_eq((part as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % part.name)
