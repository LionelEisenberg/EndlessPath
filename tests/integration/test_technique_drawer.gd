extends GutTest

## Integration tests for the technique drawer (TechniqueDrawer), the zone chest's
## drawer for one learned cycling technique: its detail line, icon and name, the
## drawer in use pulled out and tagged IN USE, the NEW seal and the title row it
## shares with the activity cards, equip on click with a brass flash (and
## nothing on the drawer in use), hover, and long text never widening a drawer.
## Drawers are built with setup on a fresh save with smooth_flow unlocked, as
## the technique list builds them; foundation_technique stays equipped.

const DRAWER_SCENE: PackedScene = preload("res://scenes/cycling/technique_drawer/technique_drawer.tscn")

const FOUNDATION_ID: String = "foundation_technique"
const SMOOTH_ID: String = "smooth_flow"
const FIXTURE_ID: String = "test_technique_drawer_technique"

const DRAWER_PATH: String = "res://assets/ui/lacquer/lacquer_drawer_ai.png"
const DRAWER_RUN_PATH: String = "res://assets/ui/lacquer/lacquer_drawer_run_ai.png"

const DRAWER_SIZE: Vector2 = Vector2(392, 72)
## The faces: the plain drawer, and the one in use with its 4 px shadow.
const FACE_SIZE: Vector2 = Vector2(394, 74)
const FACE_RUN_SIZE: Vector2 = Vector2(396, 76)
## The detail line's box (kit §5.5: 316 px wide, then an ellipsis).
const DETAIL_SIZE: Vector2 = Vector2(316, 18)
## The title row (kit §5.5): the title's corner, the width the title and the
## NEW seal share before the tag, the seal's width and its gap after the title,
## and the tag's corner.
const TITLE_POSITION: Vector2 = Vector2(64, 14)
const TITLE_ROW_WIDTH: float = 232.0
const SEAL_WIDTH: float = 44.0
const SEAL_GAP: float = 10.0
const TAG_POSITION: Vector2 = Vector2(304, 13)

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

#-----------------------------------------------------------------------------
# DETAIL TEXT
#-----------------------------------------------------------------------------

func test_detail_text() -> void:
	assert_eq(TechniqueDrawer.detail_text(_fixture("A", 50.0, 8.0, 0)), "50 Madra · 8 s cycle · no zones")
	assert_eq(TechniqueDrawer.detail_text(_fixture("B", 200.0, 15.0, 4)), "200 Madra · 15 s cycle · 4 zones")
	assert_eq(TechniqueDrawer.detail_text(_fixture("C", 250.0, 8.0, 1)), "250 Madra · 8 s cycle · 1 zone")

func test_detail_text_rounds_madra_and_seconds() -> void:
	assert_eq(TechniqueDrawer.detail_text(_fixture("A", 49.6, 7.5, 2)), "50 Madra · 8 s cycle · 2 zones")
	assert_eq(TechniqueDrawer.detail_text(_fixture("B", 50.4, 7.4, 2)), "50 Madra · 7 s cycle · 2 zones")

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func test_setup_shows_icon_name_and_detail() -> void:
	var smooth: CyclingTechniqueData = _technique(SMOOTH_ID)
	var drawer: TechniqueDrawer = _drawer_for(smooth)
	var icon := _node(drawer, "Icon") as TextureRect
	assert_not_null(smooth.icon, "precondition: the shipped technique has an icon")
	assert_eq(icon.texture, smooth.icon)
	assert_eq(icon.position, Vector2(16, 20))
	assert_eq(icon.size, Vector2(32, 32))
	assert_eq((_node(drawer, "Title") as Label).text, "Smooth Flow Technique")
	assert_eq((_node(drawer, "Detail") as Label).text, "200 Madra · 15 s cycle · 4 zones")
	assert_eq(drawer.technique, smooth)

func test_setup_after_the_drawer_is_ready() -> void:
	var drawer: TechniqueDrawer = DRAWER_SCENE.instantiate() as TechniqueDrawer
	add_child_autofree(drawer)
	drawer.setup(_technique(SMOOTH_ID))
	assert_eq((_node(drawer, "Title") as Label).text, "Smooth Flow Technique")
	assert_eq((_node(drawer, "Detail") as Label).text, "200 Madra · 15 s cycle · 4 zones")
	assert_true(drawer.is_new_shown(), "the NEW seal is set up with the rest")

func test_drawer_is_a_fixed_392_by_72() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_eq(drawer.size, DRAWER_SIZE)
	assert_eq(drawer.custom_minimum_size, DRAWER_SIZE)

func test_drawer_keeps_its_size_in_a_wider_column() -> void:
	# A container wider than the drawer must not stretch its hover and click
	# area past it.
	var column := VBoxContainer.new()
	column.size = Vector2(500.0, 400.0)
	add_child_autofree(column)
	var drawer: TechniqueDrawer = DRAWER_SCENE.instantiate() as TechniqueDrawer
	drawer.setup(_technique(SMOOTH_ID))
	column.add_child(drawer)
	await wait_process_frames(2)
	assert_eq(drawer.size, DRAWER_SIZE)

#-----------------------------------------------------------------------------
# THE DRAWER IN USE
#-----------------------------------------------------------------------------

func test_drawer_in_use_is_pulled_out() -> void:
	var drawer: TechniqueDrawer = _drawer(FOUNDATION_ID)
	var face := _node(drawer, "Face") as TextureRect
	var tag_label := _node(drawer, "TagLabel") as Label
	assert_true(drawer.is_in_use())
	assert_eq((_node(drawer, "Drawer") as Control).position, Vector2(-2, -2))
	assert_eq(face.texture, load(DRAWER_RUN_PATH))
	assert_eq(face.size, FACE_RUN_SIZE, "the face fits its texture")
	assert_true((_node(drawer, "Tag") as TextureRect).visible, "the tag shows")
	assert_eq(tag_label.text, "IN USE")
	assert_eq(tag_label.get_theme_color("font_color"), ThemeConstants.LACQUER_CREAM)

func test_other_drawer_is_plain() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	var face := _node(drawer, "Face") as TextureRect
	assert_false(drawer.is_in_use())
	assert_eq((_node(drawer, "Drawer") as Control).position, Vector2.ZERO)
	assert_eq(face.texture, load(DRAWER_PATH))
	assert_eq(face.size, FACE_SIZE, "the face fits its texture")
	assert_false((_node(drawer, "Tag") as TextureRect).visible, "no tag on a drawer that is not in use")

func test_refresh_follows_the_equipped_technique() -> void:
	var foundation: TechniqueDrawer = _drawer(FOUNDATION_ID)
	var smooth: TechniqueDrawer = _drawer(SMOOTH_ID)
	CyclingManager.equip_technique(SMOOTH_ID)
	foundation.refresh()
	smooth.refresh()
	assert_true(smooth.is_in_use())
	assert_eq((_node(smooth, "Drawer") as Control).position, Vector2(-2, -2))
	assert_eq((_node(smooth, "Face") as TextureRect).texture, load(DRAWER_RUN_PATH))
	assert_true((_node(smooth, "Tag") as TextureRect).visible)
	assert_false(foundation.is_in_use())
	assert_eq((_node(foundation, "Drawer") as Control).position, Vector2.ZERO, "the old drawer goes back in")
	assert_eq((_node(foundation, "Face") as TextureRect).texture, load(DRAWER_PATH))
	assert_eq((_node(foundation, "Face") as TextureRect).size, FACE_SIZE, "and its face shrinks back")
	assert_false((_node(foundation, "Tag") as TextureRect).visible)

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

func test_click_equips_and_flashes() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	var flash := _node(drawer, "FlashFrame") as LacquerFrameOverlay
	assert_false(drawer.is_in_use(), "precondition: foundation is equipped")
	watch_signals(CyclingManager)
	_press(drawer)
	assert_eq(_equipped_id(), SMOOTH_ID)
	assert_signal_emit_count(CyclingManager, "equipped_technique_changed", 1)
	assert_true(flash.visible, "the brass frame shows")
	assert_true(flash.is_flashing())
	assert_true(drawer.is_in_use(), "the drawer is pulled out at once")
	assert_eq((_node(drawer, "Drawer") as Control).position, Vector2(-2, -2))

func test_click_on_the_drawer_in_use_does_nothing() -> void:
	# Review Focus 3: the drawer in use ignores the press, so a running cycle is
	# never ended by it.
	var drawer: TechniqueDrawer = _drawer(FOUNDATION_ID)
	var flash := _node(drawer, "FlashFrame") as LacquerFrameOverlay
	assert_true(drawer.is_in_use(), "precondition: foundation is equipped")
	watch_signals(CyclingManager)
	_press(drawer)
	assert_eq(_equipped_id(), FOUNDATION_ID)
	assert_signal_not_emitted(CyclingManager, "equipped_technique_changed")
	assert_false(flash.is_flashing(), "nothing flashes")
	assert_false(flash.visible)
	assert_true(drawer.is_in_use())

func test_only_a_left_press_equips() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	_press(drawer, MOUSE_BUTTON_RIGHT)
	_press(drawer, MOUSE_BUTTON_LEFT, false)
	assert_eq(_equipped_id(), FOUNDATION_ID, "a right press and a left release do not equip")
	assert_false((_node(drawer, "FlashFrame") as LacquerFrameOverlay).is_flashing())

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
# NEW SEAL AND THE TITLE ROW
#-----------------------------------------------------------------------------

func test_new_seal_shows_for_an_unseen_technique() -> void:
	assert_true(_drawer(SMOOTH_ID).is_new_shown(), "smooth was unlocked after the save was first initialised")
	assert_false(_drawer(FOUNDATION_ID).is_new_shown(), "the technique in use is never NEW")

func test_new_seal_clears_on_hover() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_true(drawer.is_new_shown(), "precondition: smooth is NEW")
	drawer.mouse_entered.emit()
	assert_false(drawer.is_new_shown())
	assert_true(CyclingManager.is_technique_seen(SMOOTH_ID))

func test_title_row_is_laid_out_like_the_cards() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	var title := _node(drawer, "Title") as Label
	var seal := _node(drawer, "NewSeal") as TextureRect
	var tag := _node(drawer, "Tag") as TextureRect
	assert_true(drawer.is_new_shown(), "precondition: the seal shows")
	assert_eq(title.position, TITLE_POSITION)
	assert_eq(seal.position, Vector2(title.position.x + title.size.x + SEAL_GAP, TAG_POSITION.y))
	assert_eq(tag.position, TAG_POSITION)
	drawer.mouse_entered.emit()
	assert_eq(title.position, TITLE_POSITION, "the title stays when the seal clears")

func test_long_name_ellipsizes_before_the_seal_and_tag() -> void:
	var drawer: TechniqueDrawer = _drawer_for(_fixture("The Exceedingly Long and Winding Name of a Technique ".repeat(4), 50.0, 8.0, 0))
	var title := _node(drawer, "Title") as Label
	var seal := _node(drawer, "NewSeal") as TextureRect
	var tag := _node(drawer, "Tag") as TextureRect
	assert_true(drawer.is_new_shown(), "precondition: an unseen technique shows NEW")
	assert_eq(drawer.size, DRAWER_SIZE, "the drawer stays 392 wide")
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(title.size.x, TITLE_ROW_WIDTH - SEAL_GAP - SEAL_WIDTH, "the title stops where the seal starts")
	assert_lte(seal.position.x + seal.size.x, tag.position.x, "the seal ends before the tag")
	drawer.mouse_entered.emit()
	assert_eq(title.size.x, TITLE_ROW_WIDTH, "without the seal the title runs up to the tag")

#-----------------------------------------------------------------------------
# DETAIL LINE
#-----------------------------------------------------------------------------

func test_long_detail_ellipsizes_inside_its_line() -> void:
	var drawer: TechniqueDrawer = _drawer_for(_fixture("Long", 123456789012.0, 987654321.0, 12))
	await wait_process_frames(1)
	var detail := _node(drawer, "Detail") as Label
	var font: Font = detail.get_theme_font(&"font")
	var text_width: float = font.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail.get_theme_font_size(&"font_size")).x
	assert_gt(text_width, DETAIL_SIZE.x, "precondition: the line is wider than its box")
	assert_eq(detail.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(detail.position, Vector2(64, 38))
	assert_eq(detail.size, DETAIL_SIZE)
	assert_eq(drawer.size, DRAWER_SIZE)

#-----------------------------------------------------------------------------
# HOVER AND THE MOUSE
#-----------------------------------------------------------------------------

func test_hover_frame_follows_the_mouse() -> void:
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	var frame := _node(drawer, "HoverFrame") as LacquerFrameOverlay
	assert_false(frame.visible, "hidden until hovered")
	drawer.mouse_entered.emit()
	assert_true(frame.visible)
	drawer.mouse_exited.emit()
	assert_false(frame.visible)

func test_drawer_takes_the_mouse_and_its_parts_do_not() -> void:
	# A part that took the mouse would end the drawer's hover each time the
	# pointer crossed it.
	var drawer: TechniqueDrawer = _drawer(SMOOTH_ID)
	assert_eq(drawer.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(drawer.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	var parts: Array[Node] = drawer.find_children("*", "Control", true, false)
	assert_gt(parts.size(), 0, "precondition: the drawer has parts")
	for part: Node in parts:
		assert_eq((part as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % part.name)
