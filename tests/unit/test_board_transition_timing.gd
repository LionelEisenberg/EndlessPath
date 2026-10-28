extends GutTest

## Unit tests for BoardTransitionTiming, the board open and close transition's
## timing: each part's progress and offset at a given millisecond, the
## chest swap's staggers, and where the camera goes so the cultivator lands
## under the board.

#-----------------------------------------------------------------------------
# DURATION AND BOARD
#-----------------------------------------------------------------------------

func test_durations() -> void:
	assert_eq(BoardTransitionTiming.duration_ms(true), 540.0)
	assert_eq(BoardTransitionTiming.duration_ms(false), 520.0)

func test_board_scale() -> void:
	assert_false(BoardTransitionTiming.is_board_shown(199.0))
	assert_true(BoardTransitionTiming.is_board_shown(200.0))
	assert_almost_eq(BoardTransitionTiming.board_scale(200.0), 0.03, 0.0001)
	assert_almost_eq(BoardTransitionTiming.board_scale(360.0), 0.87875, 0.0001)
	assert_eq(BoardTransitionTiming.board_scale(520.0), 1.0)

#-----------------------------------------------------------------------------
# CAMERA AND DOCK
#-----------------------------------------------------------------------------

func test_camera_weight() -> void:
	assert_eq(BoardTransitionTiming.camera_weight(0.0), 0.0)
	assert_almost_eq(BoardTransitionTiming.camera_weight(240.0), 0.5, 0.0001)
	assert_eq(BoardTransitionTiming.camera_weight(480.0), 1.0)

func test_dock_offset_is_even() -> void:
	assert_eq(BoardTransitionTiming.dock_offset(70.0, 104.0), 52.0)
	assert_eq(BoardTransitionTiming.dock_offset(10.0, 105.0), 8.0)
	assert_eq(BoardTransitionTiming.dock_offset(140.0, 104.0), 104.0)

#-----------------------------------------------------------------------------
# CHEST SWAP
#-----------------------------------------------------------------------------

func test_staggers_keep_each_phase_inside_its_window() -> void:
	assert_eq(BoardTransitionTiming.out_stagger(1), 0.0)
	assert_eq(BoardTransitionTiming.out_stagger(10), 20.0)
	assert_eq(BoardTransitionTiming.out_stagger(11), 18.0)
	assert_eq(BoardTransitionTiming.in_stagger(5), 25.0)
	assert_eq(BoardTransitionTiming.in_stagger(6), 20.0)

func test_row_out_offsets() -> void:
	assert_eq(BoardTransitionTiming.row_out_offset(0.0, 0, 10, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_out_offset(60.0, 0, 10, 444.0), 222.0)
	assert_eq(BoardTransitionTiming.row_out_offset(180.0, 9, 10, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_out_offset(300.0, 9, 10, 444.0), 444.0)

func test_row_in_offsets() -> void:
	assert_eq(BoardTransitionTiming.row_in_offset(300.0, 0, 5, 444.0), 444.0)
	assert_eq(BoardTransitionTiming.row_in_offset(370.0, 0, 5, 444.0), 222.0)
	assert_eq(BoardTransitionTiming.row_in_offset(440.0, 0, 5, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_in_offset(540.0, 4, 5, 444.0), 0.0)

func test_chest_height() -> void:
	assert_eq(BoardTransitionTiming.chest_height(300.0, 746.0, 468.0), 746.0)
	assert_eq(BoardTransitionTiming.chest_height(420.0, 746.0, 468.0), 608.0)
	assert_eq(BoardTransitionTiming.chest_height(540.0, 746.0, 468.0), 468.0)

#-----------------------------------------------------------------------------
# HUD AND FRAMING
#-----------------------------------------------------------------------------

func test_hud_offsets() -> void:
	assert_eq(BoardTransitionTiming.hud_offset(160.0, 0, 470.0), 470.0)
	assert_eq(BoardTransitionTiming.hud_offset(40.0, 1, 470.0), 0.0)
	assert_eq(BoardTransitionTiming.hud_offset(200.0, 1, 470.0), 470.0)

func test_cultivator_target_and_camera_position() -> void:
	assert_eq(BoardTransitionTiming.cultivator_target(Rect2(680, 24, 564, 1036)), Vector2(962, 612))
	var position: Vector2 = BoardTransitionTiming.push_camera_position(Vector2(100, 100), Vector2(962, 612), 3.0)
	assert_eq(ZoneMapMath.world_to_screen(Vector2(100, 100), position, 3.0), Vector2(962, 612))
