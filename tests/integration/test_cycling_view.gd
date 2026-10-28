extends GutTest

## Integration tests for the cycling board (CyclingView): the status line's copy
## and how the board keeps it, the board's layout and mouse filters, the title
## that follows the equipped technique, the result a cycle leaves for the chest
## and the one log line it writes, the Madra and XP pellets and the zone floaters it draws over
## the cabinet, the Auto toggle, the presses that reach the ball through the
## board, and what a close or a reopening leaves behind. The board
## is built the way MainView builds it: the cabinet beside it, the view shown
## and the cabinet handed over, and the technique stepped by hand with advance()
## (its own processing is off, so the real mouse never races a test). The
## technique is smooth_flow, a 15 s cycle of 200 Madra with 4 zones, on a fresh
## save (25 Madra, cap 100).

const VIEW_SCENE_PATH: String = "res://scenes/cycling/cycling_view/cycling_view.tscn"
const VIEW_SCENE: PackedScene = preload(VIEW_SCENE_PATH)
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")

const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"
const FOUNDATION_ID: String = "foundation_technique"
const CYCLING_ACTION_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const AURA_WELL_EVENT: String = "aura_well_discovered"

## The XP pellets' ramp by tier, in the order of CyclingRules.Tier: OK is tan, GOOD
## is cream and PERFECT is brass.
const TIER_RAMPS: Array[LacquerPellet.Ramp] = [
	LacquerPellet.Ramp.TAN,
	LacquerPellet.Ramp.CREAM,
	LacquerPellet.Ramp.BRASS,
]

## The two text rects that stand on an odd y: the font puts their glyphs on the
## mock's rows there (the Esc label at y 45, the title at y 57), not on the 2 px
## grid. Every other node of the board stands on even px.
const ODD_TEXT_RECTS: Array[String] = ["EscLabel", "TitleLabel"]

## The board grows by stretching its plain middle: rows 132 to 535 of its art,
## which are all the same.
const BOARD_STRETCH_TOP: int = 132
const BOARD_STRETCH_BOTTOM: int = 535

## A technique name and a status line too long for one line of the board.
const LONG_TITLE: String = "The Heaven-Shaking Thousandfold Smooth Flow Technique"
const LONG_STATUS: String = "Cycling · 12 / 15 s · follow the ball · Madra full · zones still pay XP"
## The room the board keeps under its footer for its bottom frame, corner
## brackets and shadow once it grows; with one line each it has 42.
const ROOM_UNDER_FOOTER: float = 30.0

## A cursor far from the ball and from every zone.
const FAR: Vector2 = Vector2(-9999.0, -9999.0)

## One frame at 60 FPS. A cycle is run for its duration plus one frame, because
## 900 sums of 1 / 60 can land a hair under 15.
const FRAME: float = 1.0 / 60.0
const CYCLE_SECONDS: float = 15.0

var _plate: CultivatorPlate = null
var _view: CyclingView = null
var _technique: CyclingTechnique = null
var _effects: Control = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	CyclingManager.unlock_technique(SMOOTH_ID)
	CyclingManager.equip_technique(SMOOTH_ID)
	_plate = add_child_autofree(PLATE_SCENE.instantiate())
	_view = VIEW_SCENE.instantiate() as CyclingView
	_view.cultivator_plate = _plate
	add_child_autofree(_view)
	_view.show()
	_technique = _node("CyclingTechnique") as CyclingTechnique
	# Only the steps these tests take move the cycle, never the real mouse.
	_technique.set_process(false)
	_effects = _node("EffectsLayer") as Control

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session or a last result left behind would leak into later files.
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	_plate = null
	_view = null
	_technique = null
	_effects = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _node(unique_name: String) -> Node:
	return _view.get_node("%" + unique_name)

## Waits a frame, so the nodes the board took out of the tree and queue-freed (a
## switch's old zones and floaters, the pellets a hide frees) are gone before GUT
## counts orphans.
func _await_queued_frees() -> void:
	await wait_process_frames(1)

## Steps `seconds` of frames at `fps`, with the cursor on the ball (the drawn
## centre) or far away.
## Where the ready ball waits on screen: smooth_flow's start, (320, 464) in curve
## space, scaled about the figure's corner with the path, past the technique's
## position, snapped to even px.
func _ready_ball() -> Vector2:
	var start: Vector2 = _technique.path_pivot + (Vector2(320.0, 464.0) - _technique.path_pivot) * _technique.path_scale
	return ((_technique.global_position + start) / 2.0).round() * 2.0

## The last finished cycle's line as the chest shows it, or "" with none: the
## board records each cycle's result on CyclingManager.
func _last_line() -> String:
	var result: CycleResult = CyclingManager.get_last_cycle_result()
	return result.result_line() if result != null else ""

func _run(seconds: float, fps: float, track: bool) -> void:
	for _frame: int in roundi(seconds * fps):
		_technique.advance(1.0 / fps, _technique.get_ball_global_position() if track else FAR)

## Steps 60 FPS frames with the cursor far away until `done` returns true, the
## cycle ends or `limit` seconds pass. Returns whether `done` is true.
func _step_until(done: Callable, limit: float = 20.0) -> bool:
	for _frame: int in roundi(limit * 60.0):
		if done.call() or not _technique.is_cycling():
			break
		_technique.advance(FRAME, FAR)
	return done.call()

func _zone(index: int) -> CyclingZone:
	return _technique.cycling_zones[index]

## The ball's true distance to the zone: the path follower's, not the drawn ball's.
func _distance_to(zone: CyclingZone) -> float:
	return (_technique.get_node("%PathFollow2D") as PathFollow2D).global_position.distance_to(zone.global_position)

## Starts a cycle and steps it until zone 0 is closer than `within` px (or just
## active, when within is 0).
func _approach_zone_0(within: float) -> CyclingZone:
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	var reached: bool = _step_until(func() -> bool:
		return zone.get_state() == CyclingZone.State.ACTIVE and (within <= 0.0 or _distance_to(zone) < within))
	assert_true(reached, "precondition: the ball comes within %s px of zone 0" % within)
	return zone

## The Madra and XP pellets in the effects layer, in the order they were sent.
func _pellets() -> Array[LacquerPellet]:
	var found: Array[LacquerPellet] = []
	for child: Node in _effects.get_children():
		if child is LacquerPellet:
			found.append(child as LacquerPellet)
	return found

## The text of the cabinet's Label `unique_name`.
func _plate_text(unique_name: String) -> String:
	return (_plate.get_node("%" + unique_name) as Label).text.strip_edges()

## The pellets in the effects layer in `ramp`.
func _pellets_in(ramp: LacquerPellet.Ramp) -> Array[LacquerPellet]:
	var found: Array[LacquerPellet] = []
	for pellet: LacquerPellet in _pellets():
		if pellet.get_ramp() == ramp:
			found.append(pellet)
	return found

## The zone floaters in the effects layer, in the order of the zones.
func _floaters() -> Array[LacquerFloater]:
	var found: Array[LacquerFloater] = []
	for child: Node in _effects.get_children():
		if child is LacquerFloater:
			found.append(child as LacquerFloater)
	return found

func _left_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

## A press pushed through the viewport at `position`, with two physics frames on
## each side. The physics server learns where an Area2D is at its next step, so
## the frames before let it catch up with the areas the test just made or moved,
## and the frames after let physics picking deliver the press. The position is in
## the viewport's own coordinates (push_input's local coordinates): the headless
## window is 64 px square, so the usual window-to-viewport stretch would move it.
func _press_at(position: Vector2) -> void:
	await wait_physics_frames(2)
	var event: InputEventMouseButton = _left_press()
	event.position = position
	event.global_position = position
	get_viewport().push_input(event, true)
	await wait_physics_frames(2)

#-----------------------------------------------------------------------------
# THE STATUS LINE
#-----------------------------------------------------------------------------

func test_status_line_copy() -> void:
	assert_eq(CyclingView.status_line(false, false, 0.0, 15.0, false, false, true), CyclingView.READY_FIRST)
	assert_eq(CyclingView.status_line(true, false, 0.0, 15.0, false, false, true), CyclingView.READY_AGAIN)
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, false, true), "Cycling · 9 / 15 s")
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, false, false, true), "Cycling · 9 / 15 s · follow the ball")
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, true, true), CyclingView.MADRA_FULL_ZONES)
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, true, false), CyclingView.MADRA_FULL)

func test_status_line_strings_are_the_spec_copy() -> void:
	assert_eq(CyclingView.READY_FIRST, "Click the Madra ball to begin a cycle.")
	assert_eq(CyclingView.READY_AGAIN, "Click the ball for another cycle.")
	assert_eq(CyclingView.CYCLING_FORMAT, "Cycling · %d / %d s")
	assert_eq(CyclingView.FOLLOW_SUFFIX, " · follow the ball")
	assert_eq(CyclingView.MADRA_FULL, "Madra full")
	assert_eq(CyclingView.MADRA_FULL_ZONES, "Madra full · zones still pay XP")
	assert_eq(CyclingView.AUTO_ON_TEXT, "Auto · on")
	assert_eq(CyclingView.AUTO_OFF_TEXT, "Auto · off")

func test_status_line_counts_whole_seconds() -> void:
	assert_eq(CyclingView.status_line(false, true, 0.0, 8.0, true, false, true), "Cycling · 0 / 8 s")
	assert_eq(CyclingView.status_line(false, true, 7.99, 8.0, true, false, true), "Cycling · 7 / 8 s", "seconds count down from the floor")
	assert_eq(CyclingView.status_line(false, true, 14.99, 15.0, false, false, false), "Cycling · 14 / 15 s · follow the ball")

func test_a_ready_board_reads_the_ready_line_even_with_madra_full() -> void:
	# Madra at the cap only changes the line of a cycle that runs.
	assert_eq(CyclingView.status_line(false, false, 0.0, 15.0, false, true, true), CyclingView.READY_FIRST)
	assert_eq(CyclingView.status_line(true, false, 0.0, 15.0, false, true, false), CyclingView.READY_AGAIN)

func test_madra_full_wins_over_tracking() -> void:
	# Full Madra says why nothing is drawn, whether or not the cursor follows.
	assert_eq(CyclingView.status_line(false, true, 3.0, 15.0, false, true, true), CyclingView.MADRA_FULL_ZONES)

func test_the_status_label_follows_the_cycle() -> void:
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "ready before the first cycle")
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 0 / 15 s", "the cursor follows the ball")
	_technique.advance(FRAME, FAR)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 0 / 15 s · follow the ball", "the cursor drifted off")
	_run(6.0, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 6 / 15 s · follow the ball")
	_run(CYCLE_SECONDS, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.READY_AGAIN, "ready again after a cycle")

func test_the_status_label_says_madra_is_full() -> void:
	ResourceManager.set_madra(CultivationManager.get_max_madra())
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.MADRA_FULL_ZONES)

## A full core takes no XP, so a technique's zones pay none and the line must not
## say they do. The board was built with room in the core: the line follows the
## core as it stands this frame.
func test_the_status_label_stops_promising_xp_at_a_full_core() -> void:
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: the core is full")
	assert_false(_technique.cycling_zones.is_empty(), "precondition: the technique has zones")
	ResourceManager.set_madra(CultivationManager.get_max_madra())
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.MADRA_FULL)

func test_the_status_label_says_madra_is_full_for_a_technique_with_no_zones() -> void:
	CyclingManager.equip_technique(FOUNDATION_ID)
	assert_true(_technique.cycling_zones.is_empty(), "precondition: the foundation technique has no zones")
	ResourceManager.set_madra(CultivationManager.get_max_madra())
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.MADRA_FULL)
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE BOARD
#-----------------------------------------------------------------------------

func test_board_layout() -> void:
	assert_eq((_node("Board") as Control).position, Vector2(680.0, 24.0))
	assert_eq((_node("FigureBox") as Control).position, Vector2(698.0, 104.0))
	assert_eq((_node("FigureBox") as Control).size, Vector2(524.0, 872.0))
	assert_eq(_view.position, Vector2.ZERO, "the root fills the screen")
	assert_eq([_view.anchor_left, _view.anchor_top, _view.anchor_right, _view.anchor_bottom], [0.0, 0.0, 1.0, 1.0])
	assert_eq([_view.offset_left, _view.offset_top, _view.offset_right, _view.offset_bottom], [0.0, 0.0, 0.0, 0.0])
	assert_eq((_node("ActionLabel") as Control).position, Vector2(710.0, 40.0))
	# The title is Yatra One, whose line is 33 px tall in Godot where the mock's is 28,
	# so its label stands 3 px above the spec's y 60 to put the glyphs on the mock's
	# rows (the Goals title does the same: y 27 for the mock's 30).
	assert_eq((_node("TitleLabel") as Control).position, Vector2(710.0, 57.0))
	assert_eq((_node("CloseButton") as Control).position, Vector2(1182.0, 40.0))
	assert_eq((_node("CloseButton") as Control).size, Vector2(28.0, 28.0))
	assert_eq((_node("StatusLabel") as Control).position, Vector2(710.0, 990.0))
	assert_eq((_node("StatusLabel") as Control).size.x, 368.0)
	assert_eq((_node("AutoToggle") as Control).position, Vector2(1090.0, 982.0))
	assert_eq((_node("AutoToggle") as Control).size, Vector2(120.0, 36.0))
	assert_eq((_node("Body") as Control).position, Vector2.ZERO)
	assert_eq((_node("Body") as Control).size, Vector2(524.0, 872.0))
	assert_eq(_technique.position, Vector2(-70.0, -24.0), "curve space starts at (-70, -24) in the figure box")

## The figure took the result line's row: it is 1.048x its round-1 size (500 x 832
## to 524 x 872, re-traced from the user's outline), and the technique's path
## scales with it about the figure's top-left corner, (70, 24) in curve space.
func test_the_figure_grows_into_the_freed_row() -> void:
	assert_eq(_technique.path_scale, 524.0 / 500.0)
	assert_eq(_technique.path_pivot, Vector2(70.0, 24.0))
	var box := _node("FigureBox") as Control
	var status := _node("StatusLabel") as Control
	var auto := _node("AutoToggle") as Control
	assert_lt(box.position.y + box.size.y, status.position.y, "the figure ends above the status line")
	assert_lt(box.position.y + box.size.y, auto.position.y, "and above the Auto toggle")
	assert_lte(auto.position.y + auto.size.y + 2.0, 1046.0, "the toggle and its shadow stay inside the board's frame")
	assert_eq(box.position.x - 680.0, 1240.0 - (box.position.x + box.size.x), "the figure is centred on the board's art")
	assert_eq(_technique.get_ball_global_position(), _ready_ball(), "the ball waits at the scaled start of the path")

func test_esc_label_is_right_aligned_before_the_close_button() -> void:
	var esc := _node("EscLabel") as Label
	assert_eq(esc.text, "Esc")
	assert_eq(esc.position, Vector2(1114.0, 45.0))
	assert_eq(esc.size, Vector2(60.0, 18.0))
	assert_eq(esc.position.x + esc.size.x, 1174.0, "it ends at x 1174, 8 px before the close button")
	assert_eq(esc.position.y + esc.size.y, 63.0)
	assert_eq(esc.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)

## A transition scales the view out of the cultivator into the board, so it asks the view
## where the board stands. The fixture's text fits its lines, so the board has its art's size.
func test_board_rect_is_the_board() -> void:
	assert_eq(_view.get_board_rect(), Rect2(680.0, 24.0, 564.0, 1036.0))
	assert_eq(_view.get_board_rect(), (_node("Board") as Control).get_global_rect(), "it is the board's global rect")

func test_board_shows_its_art_at_file_size() -> void:
	var board := _node("Board") as NinePatchRect
	assert_eq(board.texture.get_size(), Vector2(564.0, 1036.0))
	assert_eq(board.size, board.texture.get_size(), "the board and its 4 px shadow, at file size")
	var body := _node("Body") as TextureRect
	assert_eq(body.texture.get_size(), Vector2(524.0, 872.0))
	assert_eq(body.size, body.texture.get_size())
	var close := _node("CloseButton") as TextureButton
	assert_eq(close.texture_normal.resource_path, "res://assets/ui/lacquer/lacquer_close_ai.png")
	assert_eq(close.texture_hover.resource_path, "res://assets/ui/lacquer/lacquer_close_hover_ai.png")
	var auto := _node("AutoToggle") as TextureButton
	assert_eq(auto.texture_normal.resource_path, "res://assets/ui/lacquer/cycling/lacquer_cyc_auto_ai.png")
	assert_eq(auto.texture_pressed.resource_path, "res://assets/ui/lacquer/cycling/lacquer_cyc_auto_on_ai.png")

func test_the_board_grows_by_stretching_only_its_plain_middle() -> void:
	var board := _node("Board") as NinePatchRect
	var height: int = int(board.texture.get_size().y)
	assert_eq(board.patch_margin_top, BOARD_STRETCH_TOP, "the top's corners, frame and grain stay as drawn")
	assert_eq(board.patch_margin_bottom, height - BOARD_STRETCH_BOTTOM - 1, "and so does the bottom")
	assert_eq([board.patch_margin_left, board.patch_margin_right], [0, 0], "it never stretches across")
	var image: Image = board.texture.get_image()
	var first: PackedByteArray = image.get_region(Rect2i(0, BOARD_STRETCH_TOP, image.get_width(), 1)).get_data()
	var differing: Array[int] = []
	for y: int in range(BOARD_STRETCH_TOP + 1, BOARD_STRETCH_BOTTOM + 1):
		if image.get_region(Rect2i(0, y, image.get_width(), 1)).get_data() != first:
			differing.append(y)
	assert_eq(differing, [] as Array[int], "every row of the band is the same, so stretching it shows nothing")

func test_no_board_text_is_cut_off() -> void:
	for unique_name: String in ["ActionLabel", "TitleLabel", "StatusLabel"]:
		var label := _node(unique_name) as Label
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s never ends in an ellipsis" % unique_name)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s wraps instead" % unique_name)

func test_a_long_title_wraps_and_pushes_the_board_down() -> void:
	var data: CyclingTechniqueData = _technique.technique_data.duplicate() as CyclingTechniqueData
	data.technique_name = LONG_TITLE
	_technique.setup(data)
	_view.hide()
	_view.show()
	var title := _node("TitleLabel") as Label
	var figure := _node("FigureBox") as Control
	var board := _node("Board") as Control
	assert_eq(title.text, LONG_TITLE, "the whole name")
	assert_eq(title.get_line_count(), 2, "it wraps")
	assert_eq(title.get_visible_line_count(), 2, "and both lines show")
	assert_eq(title.position, Vector2(710.0, 57.0), "from where one line stands")
	var drop: float = figure.position.y - 104.0
	assert_gt(drop, 0.0, "the figure moves down under the second line")
	assert_eq(figure.position.y, 2.0 * ceilf((title.position.y + title.size.y + 14.0) / 2.0), "14 px under it, on even px")
	assert_eq((_node("StatusLabel") as Control).position.y, 990.0 + drop, "the status line follows")
	assert_eq((_node("AutoToggle") as Control).position.y, 982.0 + drop, "and so does the Auto toggle")
	assert_eq(board.position, Vector2(680.0, 24.0), "the board stays where it stands")
	var auto := _node("AutoToggle") as Control
	assert_eq(board.position.y + board.size.y, auto.position.y + auto.size.y + ROOM_UNDER_FOOTER, "and grows to keep its bottom frame clear of the footer")
	assert_lte(board.position.y + board.size.y, 1080.0, "on screen")
	_technique.advance(FRAME, FAR)
	assert_eq(_technique.get_ball_global_position(), _ready_ball(), "a frame on, the ball waits on the moved figure")
	await _await_queued_frees()

func test_a_long_status_line_wraps_into_the_room_under_the_footer() -> void:
	var status := _node("StatusLabel") as Label
	var auto := _node("AutoToggle") as Control
	status.text = LONG_STATUS
	_view._relayout_board()
	assert_eq(status.get_line_count(), 2, "the line wraps")
	assert_eq(status.get_visible_line_count(), 2, "and both lines show")
	var row: float = status.size.y
	assert_gt(row, auto.size.y, "precondition: two lines stand taller than the toggle")
	assert_eq(status.position, Vector2(710.0, 982.0), "the lines start at the footer's top")
	assert_eq(auto.position.y, 982.0 + (row - auto.size.y) / 2.0, "the toggle centres on them")
	assert_eq((_node("FigureBox") as Control).position.y, 104.0, "the figure stays")
	assert_eq((_node("Board") as Control).size.y, 1036.0, "the footer takes the room over the board's bottom frame, and the board keeps its height")
	assert_lte(status.position.y + status.size.y + ROOM_UNDER_FOOTER, 1060.0, "with the frame still clear")

func test_a_long_name_and_a_long_status_line_still_end_on_screen() -> void:
	var data: CyclingTechniqueData = _technique.technique_data.duplicate() as CyclingTechniqueData
	data.technique_name = LONG_TITLE
	_technique.setup(data)
	_view.hide()
	_view.show()
	var status := _node("StatusLabel") as Label
	status.text = LONG_STATUS
	_view._relayout_board()
	assert_eq((_node("TitleLabel") as Label).get_line_count(), 2, "precondition: the name takes two lines")
	assert_eq(status.get_line_count(), 2, "precondition: and so does the status line")
	var board := _node("Board") as Control
	assert_lte(board.position.y + board.size.y, 1080.0, "the board, its frame and its shadow still end on screen")
	assert_lte(status.position.y + status.size.y + ROOM_UNDER_FOOTER, board.position.y + board.size.y, "with the status line clear of the bottom frame")
	await _await_queued_frees()

func test_board_uses_the_lacquer_theme_and_label_variants() -> void:
	assert_eq(_view.theme.resource_path, "res://assets/themes/lacquer/lacquer_theme.tres")
	assert_eq((_node("ActionLabel") as Label).theme_type_variation, &"LabelLacquerDetail")
	assert_eq((_node("TitleLabel") as Label).theme_type_variation, &"LabelLacquerPanelTitle")
	assert_eq((_node("EscLabel") as Label).theme_type_variation, &"LabelLacquerHotkey")
	assert_eq((_node("StatusLabel") as Label).theme_type_variation, &"LabelLacquerName")
	assert_eq((_node("AutoLabel") as Label).theme_type_variation, &"LabelLacquerDetail")

func test_mouse_filters() -> void:
	assert_eq(_view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the root ignores the mouse")
	assert_eq((_node("Board") as Control).mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq((_node("FigureBox") as Control).mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq((_node("EffectsLayer") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("CloseButton") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq((_node("AutoToggle") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	# Everything else on the board lets the press through to the Area2Ds.
	for unique_name: String in ["Body", "ActionLabel", "TitleLabel", "EscLabel", "StatusLabel", "AutoLabel", "AutoHover"]:
		assert_eq((_node(unique_name) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % unique_name)

func test_draw_order() -> void:
	# The board draws first and the effects last, so pellets and floaters fly over it.
	assert_eq(_node("Board").get_index(), 0)
	assert_eq(_effects.get_index(), _view.get_child_count() - 1)
	# The carved figure draws under the groove, the ball and the zones.
	assert_lt(_node("Body").get_index(), _technique.get_index())
	assert_eq(_technique.get_parent(), _node("FigureBox"))
	assert_eq(_node("Body").get_parent(), _node("FigureBox"))

func test_every_art_position_is_even() -> void:
	var nodes: Array[Node] = _view.find_children("*", "Control", true, false)
	assert_gt(nodes.size(), 20, "precondition: the board's controls and the technique's")
	for node: Node in nodes:
		if node.get_parent() is LacquerFloater and node.name == &"Text":
			# The floater's only odd rect: its own scene sets its text at y 5.
			continue
		if String(node.name) in ODD_TEXT_RECTS:
			continue
		var control := node as Control
		assert_eq(fposmod(control.position.x, 2.0), 0.0, "%s x is even" % control.name)
		assert_eq(fposmod(control.position.y, 2.0), 0.0, "%s y is even" % control.name)
	assert_eq(fposmod(_technique.position.x, 2.0), 0.0)
	assert_eq(fposmod(_technique.position.y, 2.0), 0.0)

func test_the_buttons_show_the_pointing_hand() -> void:
	assert_eq((_node("CloseButton") as Control).mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	assert_eq((_node("AutoToggle") as Control).mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)

#-----------------------------------------------------------------------------
# THE TECHNIQUE
#-----------------------------------------------------------------------------

func test_title_follows_the_equipped_technique() -> void:
	var title := _node("TitleLabel") as Label
	assert_eq(title.text, "Smooth Flow Technique", "the technique equipped when the board was built")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_eq(title.text, "Torrential Flow")
	await _await_queued_frees()

func test_the_technique_follows_the_equipped_technique() -> void:
	assert_eq(_technique.technique_data.id, SMOOTH_ID)
	assert_eq(_technique.cycling_zones.size(), 4)
	assert_eq(_floaters().size(), 4, "one floater for each zone")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_eq(_technique.technique_data.id, TORRENTIAL_ID)
	assert_eq(_technique.cycling_zones.size(), 1)
	assert_eq(_floaters().size(), 1, "the floaters were rebuilt for the new zones")
	await _await_queued_frees()

func test_the_first_unlocked_technique_is_equipped_when_none_is() -> void:
	PersistenceManager.save_game_data.equipped_cycling_technique_id = ""
	var second: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	add_child_autofree(second)
	assert_eq(PersistenceManager.save_game_data.equipped_cycling_technique_id, FOUNDATION_ID, "the fallback equips the first unlocked technique")
	assert_eq((second.get_node("%TitleLabel") as Label).text, "Foundational Technique")
	# The fixture's board follows the equip too.
	await _await_queued_frees()

func test_a_save_with_no_techniques_leaves_the_board_idle() -> void:
	PersistenceManager.save_game_data.unlocked_cycling_technique_ids.clear()
	PersistenceManager.save_game_data.equipped_cycling_technique_id = ""
	var bare: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	add_child_autofree(bare)
	var bare_technique := bare.get_node("%CyclingTechnique") as CyclingTechnique
	bare_technique.set_process(false)
	assert_null(bare_technique.technique_data, "nothing to play")
	bare._process(0.0)
	assert_eq(bare.get_status_text(), CyclingView.READY_FIRST)
	assert_false(bare_technique.start_cycle(), "and no cycle starts")
	bare.hide()
	bare.show()
	assert_eq(_last_line(), "")

func test_switching_technique_ends_the_cycle_without_a_result() -> void:
	watch_signals(LogManager)
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_eq(_last_line(), "", "no result line")
	assert_signal_not_emitted(LogManager, "message_logged")
	await _await_queued_frees()

func test_switching_technique_clears_the_result_line_and_the_ready_text() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_ne(_last_line(), "", "precondition: a cycle left a result line")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	_view._process(0.0)
	assert_eq(_last_line(), "")
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "a new technique has not been cycled yet")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE RESULT LINE AND THE LOG
#-----------------------------------------------------------------------------

func test_the_board_has_no_result_line_of_its_own() -> void:
	assert_null(_view.get_node_or_null("%ResultText"), "the last cycle shows in the chest, under the Now tray")

func test_cycle_end_writes_the_result_and_one_log_line() -> void:
	watch_signals(LogManager)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_eq(_last_line(), "Last cycle · +0 Madra · 0 / 4 zones")
	assert_signal_emit_count(LogManager, "message_logged", 1)
	assert_eq(get_signal_parameters(LogManager, "message_logged", 0), ["[color=cyan]Cycle · +0 Madra · 0 / 4 zones[/color]"])

func test_a_tracked_cycle_reports_the_madra_it_drew() -> void:
	watch_signals(LogManager)
	watch_signals(_technique)
	ResourceManager.set_madra(0.0)
	_technique.start_cycle()
	# Tracking for 6 s keeps the Madra drawn (80) under the 100 cap.
	_run(6.0, 60.0, true)
	_run(CYCLE_SECONDS - 6.0 + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	# 6 s hold 75 whole steps of Madra. The step tolerance pays the 75th even when
	# the float sum of the frames lands a hair under 6 s.
	assert_almost_eq(result.madra_added, 80.0, 0.001, "precondition: the cursor drew Madra")
	assert_eq(_last_line(), result.result_line(), "the cycle's own line goes to the chest")
	assert_true(_last_line().begins_with("Last cycle · +%d Madra · 0 / 4 zones" % roundi(result.madra_added)), "and it names the Madra the cycle drew")
	assert_signal_emit_count(LogManager, "message_logged", 1, "cycling writes no \"Gained N Madra\" lines")
	assert_eq(get_signal_parameters(LogManager, "message_logged", 0), ["[color=cyan]%s[/color]" % result.log_line()])

func test_the_result_line_stays_until_the_next_cycle_ends() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	var first: String = _last_line()
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	assert_eq(_last_line(), first, "a running cycle leaves the last result showing")

#-----------------------------------------------------------------------------
# PELLETS
#-----------------------------------------------------------------------------

func test_effect_constants_are_the_specs() -> void:
	assert_eq(CyclingView.FLOATER_LIFT, 56.0)
	assert_eq(CyclingView.MADRA_PELLET_FLIGHT, 0.6)
	assert_eq(CyclingView.MADRA_PELLET_BOW, 60.0)
	assert_eq(CyclingView.XP_PELLET_FLIGHT, 0.6)
	assert_eq(CyclingView.XP_PELLET_FLIGHT_STEP, 0.04)
	assert_eq(CyclingView.XP_BURST_REACH, 36.0)

func test_madra_pellets_fly_from_the_ball() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	assert_eq(_pellets().size(), 2, "two 0.08 s steps of Madra in 0.2 s")
	for pellet: LacquerPellet in _pellets():
		assert_eq(pellet.get_ramp(), LacquerPellet.Ramp.MADRA, "Madra pellets keep the Madra blue")

func test_madra_pellets_leave_the_drawn_ball() -> void:
	var origins: Array[Vector2] = []
	var starts: Array[Vector2] = []
	# Connected after the view's own handler, so the pellet is already there.
	_technique.madra_particle_requested.connect(func(from_pos: Vector2, _amount: float) -> void:
		origins.append(from_pos)
		starts.append(_pellets().back().global_position))
	_technique.start_cycle()
	_run(0.5, 60.0, true)
	assert_gt(origins.size(), 0, "precondition: the cursor drew Madra")
	assert_eq(starts, origins, "each pellet starts at the drawn ball's centre")

func test_madra_pellets_land_in_the_madra_orb() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var pellet: LacquerPellet = _pellets()[0]
	pellet._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(pellet.global_position, _plate.get_madra_orb_global_position())
	assert_true(pellet.has_landed())
	pellet._process(LacquerPellet.SPARK_SECONDS)
	assert_true(pellet.is_queued_for_deletion(), "it is gone once its spark is over")

func test_madra_pellets_take_their_flight_time() -> void:
	_technique.start_cycle()
	_run(0.1, 60.0, true)
	var pellet: LacquerPellet = _pellets()[0]
	# A Madra pellet flies for 0.6 s.
	pellet._process(0.55)
	assert_false(pellet.has_landed(), "still flying after 0.55 s")
	pellet._process(0.06)
	assert_true(pellet.has_landed(), "landed by 0.61 s")

## The cabinet shows each step's Madra as its pellet lands, not as it leaves.
func test_the_madra_orb_fills_as_the_pellets_land() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var pellets: Array[LacquerPellet] = _pellets()
	assert_eq(pellets.size(), 2, "precondition: two steps in flight")
	var drawn: float = ResourceManager.get_madra()
	assert_gt(drawn, 27.0, "precondition: the cursor drew two steps of Madra")
	assert_eq(_plate_text("MadraValueLabel"), "25", "none of it has landed")
	pellets[0]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), "26", "the first step has landed")
	pellets[1]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), str(floori(drawn)), "and the second")

func test_no_madra_pellets_without_the_cabinet() -> void:
	_view.cultivator_plate = null
	_technique.start_cycle()
	_run(0.5, 60.0, true)
	assert_gt(ResourceManager.get_madra(), 25.0, "precondition: the cursor drew Madra")
	assert_eq(_pellets().size(), 0, "nowhere to send them")

func test_scoring_pops_the_zone_floater_and_pellets() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	watch_signals(_technique)
	assert_true(_technique.try_score_zone(zone))
	var params: Array = get_signal_parameters(_technique, "zone_scored", 0)
	var tier: CyclingRules.Tier = params[1]
	var xp: int = params[2]
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "%s +%d XP" % [CyclingRules.tier_name(tier), xp])
	assert_eq(floater.get_color(), CyclingRules.tier_color(tier))
	assert_eq(_pellets_in(TIER_RAMPS[tier]).size(), CyclingRules.pellet_count(tier), "one pellet in the tier's colour for each XP pellet")
	assert_eq(_pellets().size(), CyclingRules.pellet_count(tier), "and no others")
	for other: LacquerFloater in _floaters().slice(1):
		assert_false(other.visible, "only the scored zone's floater shows")

func test_a_full_core_floater_sends_no_pellets() -> void:
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: the core is full")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "OK · Core full", "the tier and the core's state in place of the XP")
	assert_eq(floater.get_color(), CyclingRules.tier_color(CyclingRules.Tier.OK))
	assert_eq(_pellets().size(), 0, "a full core takes no XP, so none flies to it")

func test_each_tier_pops_its_floater_and_sends_its_pellets() -> void:
	var scored: Array = []
	_technique.zone_scored.connect(func(zone: CyclingZone, tier: CyclingRules.Tier, xp: int) -> void:
		scored.append([zone, tier, xp]))
	# OK just as the zone opens, then GOOD within 14 px and PERFECT within 6.
	var cases: Array = [
		[CyclingRules.Tier.OK, 0.0, "OK", 3],
		[CyclingRules.Tier.GOOD, 14.0, "GOOD", 5],
		[CyclingRules.Tier.PERFECT, 6.0, "PERFECT", 8],
	]
	for case: Array in cases:
		_technique.stop_cycling()
		for pellet: LacquerPellet in _pellets():
			_effects.remove_child(pellet)
			pellet.queue_free()
		var zone: CyclingZone = _approach_zone_0(case[1])
		assert_true(_technique.try_score_zone(zone))
		var hit: Array = scored.back()
		assert_eq(hit[1], case[0], "%s tier" % case[2])
		var floater: LacquerFloater = _floaters()[0]
		assert_eq(floater.get_text(), "%s +%d XP" % [case[2], hit[2]])
		assert_eq(floater.get_color(), CyclingRules.tier_color(case[0]))
		assert_eq(_pellets_in(TIER_RAMPS[case[0]]).size(), case[3], "%s sends %d pellets" % [case[2], case[3]])
		assert_eq(_pellets().size(), case[3])
	await _await_queued_frees()

func test_xp_pellets_burst_from_the_zone_and_land_in_the_core_orb() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	var pellets: Array[LacquerPellet] = _pellets()
	assert_gt(pellets.size(), 0, "precondition: pellets flew")
	for pellet: LacquerPellet in pellets:
		var offset: Vector2 = pellet.global_position - zone.global_position
		assert_true(absf(offset.x) <= 1.0 and absf(offset.y) <= 1.0, "a pellet starts at the zone's centre (on the 2 px grid): %s" % offset)
		assert_eq(fposmod(pellet.global_position.x, 2.0), 0.0)
		assert_eq(fposmod(pellet.global_position.y, 2.0), 0.0)
	var popped: Dictionary = {}
	for pellet: LacquerPellet in pellets:
		pellet._process(PelletFlight.BURST_POP_SECONDS)
		var out: float = pellet.global_position.distance_to(zone.global_position)
		assert_almost_eq(out, CyclingView.XP_BURST_REACH, CyclingView.XP_BURST_REACH * (1.0 - PelletFlight.BURST_SHORT) + 2.0, "it pops out about the burst's reach")
		popped[pellet.global_position] = true
	assert_eq(popped.size(), pellets.size(), "each pellet pops out its own way")
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)
		assert_eq(pellet.global_position, _plate.get_core_orb_global_position(), "XP pellets land in the Core orb")

## The Core row shows the hit's XP as its pellets land: as it stood before the
## hit while they fly, and as the hit left it once the last one is in.
func test_the_core_shows_the_xp_as_its_pellets_land() -> void:
	var before: String = _plate_text("XpLabel")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var pellets: Array[LacquerPellet] = _pellets()
	assert_gt(CultivationManager.get_core_density_xp() + CultivationManager.get_core_density_level(), 0.0, "precondition: the hit paid XP")
	assert_eq(_plate_text("XpLabel"), before, "none of the XP has landed")
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)
	assert_eq(_plate_text("LevelLabel"), "Level %d" % floori(CultivationManager.get_core_density_level()))
	assert_eq(_plate_text("XpLabel"), "%d / %d XP" % [floori(CultivationManager.get_core_density_xp()), floori(CultivationManager.get_xp_for_next_level())], "all of it has landed")

## A hidden board frees its pellets, and what they carried shows at once.
func test_hiding_the_view_shows_what_its_pellets_carried() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	assert_gt(_pellets().size(), 0, "precondition: pellets in flight")
	_view.hide()
	assert_eq(_plate_text("MadraValueLabel"), str(floori(ResourceManager.get_madra())))
	assert_eq(_plate_text("XpLabel"), "%d / %d XP" % [floori(CultivationManager.get_core_density_xp()), floori(CultivationManager.get_xp_for_next_level())])
	await _await_queued_frees()

func test_xp_pellets_arrive_one_after_another() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	var pellets: Array[LacquerPellet] = _pellets()
	assert_eq(pellets.size(), 3, "an OK hit sends three pellets")
	# Their flights are 0.6 s, 0.64 s and 0.68 s.
	for pellet: LacquerPellet in pellets:
		pellet._process(0.62)
	assert_true(pellets[0].has_landed(), "the first takes 0.6 s")
	assert_false(pellets[1].has_landed(), "the second takes 0.64 s")
	assert_false(pellets[2].has_landed(), "the third takes 0.68 s")
	pellets[1]._process(0.04)
	pellets[2]._process(0.04)
	assert_true(pellets[1].has_landed(), "the second landed by 0.66 s")
	assert_false(pellets[2].has_landed(), "the third is still flying at 0.66 s")
	pellets[2]._process(0.04)
	assert_true(pellets[2].has_landed(), "the third landed by 0.7 s")

func test_scoring_still_pops_the_floater_without_the_cabinet() -> void:
	_view.cultivator_plate = null
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	assert_true(_floaters()[0].visible)
	assert_eq(_pellets().size(), 0)

#-----------------------------------------------------------------------------
# FLOATERS
#-----------------------------------------------------------------------------

func test_floaters_start_hidden_inside_the_effects_layer() -> void:
	assert_eq(_floaters().size(), 4)
	for floater: LacquerFloater in _floaters():
		assert_false(floater.visible)
		assert_eq(floater.get_parent(), _effects)

func test_floater_rises_above_the_zone() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	var floater: LacquerFloater = _floaters()[0]
	var half: float = snappedf(floater.get_token_width() / 2.0, 2.0)
	assert_eq(floater.global_position, zone.global_position - Vector2(half, 56.0), "56 px above the zone's centre as it pops")
	floater._process(0.5)
	_view._process(0.0)
	assert_eq(floater.get_rise(), 20)
	assert_eq(floater.global_position, zone.global_position - Vector2(half, 56.0 + 20.0), "and 20 px higher half a second later")
	assert_eq(fposmod(floater.global_position.x, 2.0), 0.0)
	assert_eq(fposmod(floater.global_position.y, 2.0), 0.0)
	floater._process(0.6)
	assert_false(floater.visible, "it hides outright after a second")

func test_each_zone_has_its_own_floater() -> void:
	# Zone 0 scores first, then zone 1: two floaters at once, each over its own zone.
	var first: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(first)
	var second: CyclingZone = _zone(1)
	assert_true(_step_until(func() -> bool: return second.get_state() == CyclingZone.State.ACTIVE), "precondition: the ball reaches zone 1")
	_technique.try_score_zone(second)
	_view._process(0.0)
	var floaters: Array[LacquerFloater] = _floaters()
	assert_true(floaters[0].visible and floaters[1].visible)
	assert_false(floaters[2].visible or floaters[3].visible)
	for index: int in 2:
		var floater: LacquerFloater = floaters[index]
		var half: float = snappedf(floater.get_token_width() / 2.0, 2.0)
		var expected: Vector2 = _zone(index).global_position - Vector2(half, 56.0 + floater.get_rise())
		assert_eq(floater.global_position, expected, "floater %d hangs over zone %d" % [index, index])

func test_every_floater_that_shows_is_placed_each_frame() -> void:
	var floaters: Array[LacquerFloater] = _floaters()
	assert_eq(floaters.size(), 4)
	for index: int in floaters.size():
		floaters[index].pop("OK +5 XP", ThemeConstants.LACQUER_TAN)
	_view._process(0.0)
	for index: int in floaters.size():
		var half: float = snappedf(floaters[index].get_token_width() / 2.0, 2.0)
		assert_eq(floaters[index].global_position, _zone(index).global_position - Vector2(half, 56.0), "floater %d is placed over zone %d" % [index, index])
	# And again once they have risen.
	for floater: LacquerFloater in floaters:
		floater._process(0.5)
	_view._process(0.0)
	for index: int in floaters.size():
		var half: float = snappedf(floaters[index].get_token_width() / 2.0, 2.0)
		assert_eq(floaters[index].global_position, _zone(index).global_position - Vector2(half, 56.0 + 20.0), "floater %d rose with the others" % index)

func test_a_hidden_floater_is_left_where_it_is() -> void:
	var floaters: Array[LacquerFloater] = _floaters()
	floaters[2].global_position = Vector2(123.0, 456.0)
	_view._process(0.0)
	assert_eq(floaters[2].global_position, Vector2(123.0, 456.0), "only the floaters that show are placed")

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

func test_auto_toggle_sets_auto_cycle() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	var label := _node("AutoLabel") as Label
	assert_true(toggle.toggle_mode)
	assert_false(toggle.button_pressed)
	assert_false(_technique.auto_cycle)
	assert_eq(label.text, "Auto · off")
	toggle.button_pressed = true
	assert_true(_technique.auto_cycle)
	assert_eq(label.text, "Auto · on")
	toggle.button_pressed = false
	assert_false(_technique.auto_cycle)
	assert_eq(label.text, "Auto · off")

func test_a_toggle_that_starts_pressed_is_honoured() -> void:
	var built: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	(built.get_node("%AutoToggle") as TextureButton).button_pressed = true
	add_child_autofree(built)
	var built_technique := built.get_node("%CyclingTechnique") as CyclingTechnique
	built_technique.set_process(false)
	assert_true(built_technique.auto_cycle, "the technique follows the toggle from the start")
	assert_eq((built.get_node("%AutoLabel") as Label).text, "Auto · on")
	assert_eq((built.get_node("%AutoLabel") as Label).position, Vector2(0.0, 2.0))

func test_auto_label_is_cream_and_2_px_lower_while_on() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	var label := _node("AutoLabel") as Label
	assert_eq(label.get_theme_color("font_color"), ThemeConstants.LACQUER_TAN, "tan while off")
	assert_eq(label.position, Vector2.ZERO)
	toggle.button_pressed = true
	assert_eq(label.get_theme_color("font_color"), ThemeConstants.LACQUER_CREAM, "cream while on")
	assert_eq(label.position, Vector2(0.0, 2.0), "pressed in")
	toggle.button_pressed = false
	assert_eq(label.get_theme_color("font_color"), ThemeConstants.LACQUER_TAN)
	assert_eq(label.position, Vector2.ZERO)

func test_auto_label_is_centred_across_the_toggle() -> void:
	var label := _node("AutoLabel") as Label
	assert_eq(label.size, Vector2(120.0, 36.0))
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)

func test_the_auto_hover_frame_follows_the_mouse() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	var hover := _node("AutoHover") as LacquerFrameOverlay
	assert_false(hover.visible)
	toggle.mouse_entered.emit()
	assert_true(hover.visible)
	toggle.mouse_exited.emit()
	assert_false(hover.visible)

func test_auto_chains_the_next_cycle() -> void:
	(_node("AutoToggle") as TextureButton).button_pressed = true
	watch_signals(_technique)
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	assert_true(_technique.is_cycling(), "with Auto on the next cycle started at once")
	assert_eq(_last_line(), "Last cycle · +0 Madra · 0 / 4 zones")

#-----------------------------------------------------------------------------
# SHOWING, HIDING AND CLOSING
#-----------------------------------------------------------------------------

func test_the_view_processes_only_while_it_shows() -> void:
	assert_true(_view.is_processing(), "the shown view updates its status, floaters and cursor")
	assert_false(_technique.is_processing(), "precondition: this fixture stopped the technique's processing")
	_view.hide()
	assert_false(_view.is_processing())
	assert_false(_technique.is_processing(), "a hidden view's technique is not processed")
	_view.show()
	assert_true(_view.is_processing())
	assert_true(_technique.is_processing(), "showing the view turns the technique's processing back on")

func test_hiding_the_view_hides_every_floater() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	assert_true(_floaters()[0].visible, "precondition: a floater shows")
	_view.hide()
	for floater: LacquerFloater in _floaters():
		assert_false(floater.visible)
		assert_false(floater.is_processing(), "and a hidden floater is not processed")
	await _await_queued_frees()

func test_hiding_the_view_frees_the_pellets_in_flight() -> void:
	# A pellet left flying under the hidden board would show up mid-flight if the
	# board reopened within its flight.
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var flying: Array[LacquerPellet] = _pellets()
	assert_gt(flying.size(), 0, "precondition: the hit's pellets are in flight")
	_view.hide()
	assert_eq(_pellets().size(), 0, "the effects layer holds no pellet")
	for pellet: LacquerPellet in flying:
		assert_true(pellet.is_queued_for_deletion(), "each pellet is freed, not just left out of the tree")
	assert_eq(_floaters().size(), 4, "the floaters stay for the next cycle")
	await _await_queued_frees()

func test_the_view_hidden_by_its_parent_stops_too() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var nested: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	host.add_child(nested)
	assert_true(nested.is_processing())
	host.hide()
	assert_false(nested.is_processing(), "hiding a parent hides the view in the tree")
	host.show()
	assert_true(nested.is_processing())

func test_a_view_that_starts_hidden_does_not_process() -> void:
	var host := Control.new()
	host.visible = false
	add_child_autofree(host)
	var hidden: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	hidden.visible = false
	host.add_child(hidden)
	assert_false(hidden.is_processing())
	assert_false((hidden.get_node("%CyclingTechnique") as CyclingTechnique).is_processing())

func test_reopening_starts_clean() -> void:
	# A finished cycle leaves its result for the chest's line.
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_ne(_last_line(), "", "precondition: a cycle left a result line")
	# Then a second cycle, closed half way with a zone scored.
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	assert_true(_floaters()[0].visible, "precondition: the floater shows")
	_view._process(0.0)
	assert_true(_view.get_status_text().begins_with("Cycling · "), "precondition: the status line shows the cycle")
	_view.hide()
	_view.show()
	assert_eq(_last_line(), "", "no stale result line")
	for floater: LacquerFloater in _floaters():
		assert_false(floater.visible, "no floater shows")
	for each: CyclingZone in _technique.cycling_zones:
		assert_eq(each.get_state(), CyclingZone.State.IDLE, "%s is idle" % each.name)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_false(CyclingManager.is_cycle_running(), "and its session")
	var groove := _technique.get_node("%CyclingGroove") as CyclingGroove
	assert_eq(groove.get_lit_count(), groove.get_cell_count(), "the groove shows lit, as between cycles")
	assert_eq(_technique.get_ball_global_position(), _ready_ball(), "the ball waits at the start of the path")
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "and the status reads as the first time again")
	await _await_queued_frees()

func test_showing_names_the_action_and_the_technique() -> void:
	var cycling: ZoneActionData = ZoneManager.get_action_by_id(CYCLING_ACTION_ID)
	ActionManager.select_action(cycling)
	_view.hide()
	_view.show()
	assert_eq((_node("ActionLabel") as Label).text, "Wilderness Cycling")
	assert_eq((_node("TitleLabel") as Label).text, "Smooth Flow Technique")

func test_showing_names_whatever_action_runs() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var aura_well: ZoneActionData = ZoneManager.get_action_by_id(AURA_WELL_ID)
	assert_ne(aura_well.action_name, "Wilderness Cycling", "precondition: the label would not read that anyway")
	assert_eq(ActionManager.get_current_action(), aura_well, "precondition: the Aura Well runs")
	_view.hide()
	_view.show()
	assert_eq((_node("ActionLabel") as Label).text, aura_well.action_name)

func test_showing_names_the_technique_that_is_set_up() -> void:
	# Something other than the equipped-technique signal set the technique up.
	_technique.setup(load("res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres"))
	assert_eq((_node("TitleLabel") as Label).text, "Smooth Flow Technique", "precondition: the title still names the old one")
	_view.hide()
	_view.show()
	assert_eq((_node("TitleLabel") as Label).text, "Torrential Flow")
	await _await_queued_frees()

func test_close_stops_the_action() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ACTION_ID))
	assert_eq(ActionManager.get_current_action().action_id, CYCLING_ACTION_ID, "precondition: the cycling action is current")
	_technique.start_cycle()
	(_node("CloseButton") as TextureButton).pressed.emit()
	var current: ZoneActionData = ActionManager.get_current_action()
	assert_not_null(current, "the zone's idle action resumed")
	assert_eq(current.action_id, AURA_WELL_ID)
	assert_false(_technique.is_cycling(), "the running cycle ended")

func test_stopping_the_cycling_action_resets_the_technique() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	ActionManager.stop_cycling.emit()
	assert_false(_technique.is_cycling())
	for each: CyclingZone in _technique.cycling_zones:
		assert_eq(each.get_state(), CyclingZone.State.IDLE)

#-----------------------------------------------------------------------------
# THE CURSOR AND CLICKS
#-----------------------------------------------------------------------------

func test_the_figure_box_shows_a_hand_where_a_click_does_something() -> void:
	var box := _node("FigureBox") as Control
	_view._update_cursor(FAR)
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_ARROW)
	_view._update_cursor(_technique.get_ball_global_position())
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "a click on the ready ball starts a cycle")
	_technique.start_cycle()
	_technique.advance(1.0 / 60.0, FAR)
	_view._update_cursor(_technique.get_ball_global_position())
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_ARROW, "a click on the running ball with no zone active does nothing")
	var zone: CyclingZone = _approach_zone_0(0.0)
	_view._update_cursor(_technique.get_ball_global_position())
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "a click on the ball over an active zone scores it")
	_view._update_cursor(zone.global_position)
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_ARROW, "the zone itself takes no click")
	_view._update_cursor(FAR)
	assert_eq(box.mouse_default_cursor_shape, Control.CURSOR_ARROW)

func test_a_press_on_the_ball_reaches_it_through_the_board() -> void:
	await _press_at(_technique.get_ball_global_position())
	assert_true(_technique.is_cycling(), "the board and the figure box let the press through to the ball")

func test_a_press_beside_the_ball_starts_nothing() -> void:
	await _press_at(_technique.get_ball_global_position() + Vector2(60.0, 0.0))
	assert_false(_technique.is_cycling())

func test_a_press_on_the_ball_over_an_active_zone_scores_through_the_board() -> void:
	_approach_zone_0(0.0)
	watch_signals(_technique)
	await _press_at(_technique.get_ball_global_position())
	assert_signal_emit_count(_technique, "zone_scored", 1)

#-----------------------------------------------------------------------------
# THE SCENE
#-----------------------------------------------------------------------------

func test_the_scene_no_longer_names_the_old_pieces() -> void:
	var text: String = FileAccess.get_file_as_string(VIEW_SCENE_PATH)
	for retired: String in ["cycling_resource_panel", "cycling_tab_panel", "cycling_technique_slot", "flying_particle", "styleboxes/cycling", "pixel_theme", "CyclingTabContainer", "ShaderMaterial", "foundation_cycling_technique"]:
		assert_false(text.contains(retired), "the scene no longer names %s" % retired)
