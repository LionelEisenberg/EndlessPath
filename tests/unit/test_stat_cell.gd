extends GutTest

## Unit tests for StatCell, one stat on the cultivator cabinet: the frame its
## XP ring shows at the edges of set_stat(), called directly with values
## CharacterManager does not send today (no cost to the next level, XP at or
## past it, negative XP); the capped look; the level-up flash; the hop.
## test_cultivator_plate.gd covers the cells following CharacterManager and when
## the cabinet plays the looks.

const CELL_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/stat_cell/stat_cell.tscn")
const BEADS_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_ring_strip_ai.png")
const CAPPED_STRIP: Texture2D = preload("res://assets/ui/lacquer/lacquer_stat_ring_capped_strip_ai.png")

var _cell: StatCell = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_cell = CELL_SCENE.instantiate() as StatCell
	add_child_autofree(_cell)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The frame the ring shows: column n lights n beads.
func _ring() -> Vector2i:
	return (_cell.get_node("%XpRing") as LacquerStripRect).get_frame()

## The strip the ring draws from.
func _ring_strip() -> Texture2D:
	return (_cell.get_node("%XpRing") as LacquerStripRect).strip

func _level_colour() -> Color:
	return (_cell.get_node("%LevelLabel") as Label).get_theme_color(&"font_color")

func _flash_shows() -> bool:
	return (_cell.get_node("%FlashRing") as CanvasItem).visible and (_cell.get_node("%LevelFrame") as CanvasItem).visible

func _flash_hidden() -> bool:
	return not (_cell.get_node("%FlashRing") as CanvasItem).visible and not (_cell.get_node("%LevelFrame") as CanvasItem).visible

func _ring_y() -> float:
	return (_cell.get_node("%XpRing") as Control).position.y

## Puts the ring at half its beads, so a case whose set_stat() changed nothing
## would show.
func _start_from_a_half_ring() -> void:
	_cell.set_stat(1, 50.0, 100.0, false)

#-----------------------------------------------------------------------------
# THE RING
#-----------------------------------------------------------------------------

## Under the cap the ring lights floor(xp × RING_BEADS / xp_to_next) beads,
## never fewer than none and never more than all of them.
func test_an_uncapped_ring_stays_within_its_beads() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cost to the next level lights no bead", "xp": 50.0, "xp_to_next": 0.0, "frame": 0},
		{"name": "XP at the next level's cost lights every bead", "xp": 100.0, "xp_to_next": 100.0, "frame": StatCell.RING_BEADS},
		{"name": "XP past the next level's cost lights every bead, no more", "xp": 250.0, "xp_to_next": 100.0, "frame": StatCell.RING_BEADS},
		{"name": "negative XP lights no bead", "xp": -10.0, "xp_to_next": 100.0, "frame": 0},
	]
	for case: Dictionary in cases:
		_start_from_a_half_ring()
		_cell.set_stat(3, case.xp, case.xp_to_next, false)
		assert_eq(_ring(), Vector2i(case.frame, 0), case.name)

## At the cap the ring shows the capped strip from its first frame, whatever
## the XP.
func test_a_capped_ring_shows_the_capped_strip_whatever_the_xp() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no XP", "xp": 0.0, "xp_to_next": 100.0},
		{"name": "half the next level's cost", "xp": 50.0, "xp_to_next": 100.0},
		{"name": "negative XP", "xp": -10.0, "xp_to_next": 100.0},
		{"name": "no cost to the next level", "xp": 0.0, "xp_to_next": 0.0},
	]
	for case: Dictionary in cases:
		_start_from_a_half_ring()
		_cell.set_stat(10, case.xp, case.xp_to_next, true)
		assert_eq(_ring_strip(), CAPPED_STRIP, "capped, %s: the flowing channel" % case.name)
		assert_eq(_ring(), Vector2i(0, 0), "capped, %s: its first frame" % case.name)
		_cell.set_stat(3, 50.0, 100.0, false)

## Under the cap the ring draws from the bead strip again, and the level is cream;
## at the cap it is brass.
func test_the_cap_turns_the_level_brass_and_back() -> void:
	_cell.set_stat(10, 0.0, 100.0, true)
	assert_eq(_level_colour(), ThemeConstants.LACQUER_BRASS, "the level in brass at the cap")
	_cell.set_stat(10, 0.0, 100.0, false)
	assert_eq(_ring_strip(), BEADS_STRIP, "under the cap the beads come back")
	assert_eq(_level_colour(), ThemeConstants.LACQUER_CREAM, "the level in cream under the cap")

## The capped channel steps CAPPED_FPS frames a second and loops.
func test_the_capped_channel_flows_in_whole_frames() -> void:
	var cases: Array[Dictionary] = [
		{"elapsed": 0.0, "frame": 0},
		{"elapsed": 0.09, "frame": 0},
		{"elapsed": 0.1, "frame": 1},
		{"elapsed": 2.35, "frame": 23},
		{"elapsed": 2.4, "frame": 0},
	]
	for case: Dictionary in cases:
		assert_eq(StatCell.capped_frame_at(case.elapsed), case.frame, "%s s in" % case.elapsed)
	_cell.set_stat(10, 0.0, 100.0, true)
	_cell._process(0.35)
	assert_eq(_ring(), Vector2i(3, 0), "the cell steps its own frames")

#-----------------------------------------------------------------------------
# LEVEL-UP FLASH
#-----------------------------------------------------------------------------

## On for a phase, off for a phase, twice, then off.
func test_the_flash_is_on_and_off_in_phases() -> void:
	var phase: float = StatCell.FLASH_PHASE_SECONDS
	var cases: Array[Dictionary] = [
		{"elapsed": -0.1, "on": false},
		{"elapsed": 0.0, "on": true},
		{"elapsed": phase * 0.99, "on": true},
		{"elapsed": phase, "on": false},
		{"elapsed": phase * 2.0, "on": true},
		{"elapsed": phase * 3.0, "on": false},
		{"elapsed": phase * 4.0, "on": false},
	]
	for case: Dictionary in cases:
		assert_eq(StatCell.is_flash_on_at(case.elapsed), case.on, "%s s in" % case.elapsed)

## The brass beads and the brass frame show together, the level in brass, and
## the look ends on the plain cell.
func test_a_level_up_flashes_the_ring_and_the_frame_together() -> void:
	_cell.set_stat(5, 0.0, 100.0, false)
	assert_true(_flash_hidden(), "precondition: no flash before the level-up")
	_cell.play_level_up()
	assert_true(_flash_shows(), "the brass beads and frame show at once")
	assert_eq(_level_colour(), ThemeConstants.LACQUER_BRASS, "the level in brass while on")
	_cell._process(StatCell.FLASH_PHASE_SECONDS)
	assert_true(_flash_hidden(), "off for the second phase")
	assert_eq(_level_colour(), ThemeConstants.LACQUER_CREAM, "the level back in cream while off")
	_cell._process(StatCell.FLASH_PHASE_SECONDS)
	assert_true(_flash_shows(), "on again")
	_cell._process(StatCell.FLASH_PHASE_SECONDS * 2.0)
	assert_true(_flash_hidden(), "it ends hidden")
	assert_false(_cell.is_flashing(), "and stops")

#-----------------------------------------------------------------------------
# HOP
#-----------------------------------------------------------------------------

func test_the_hop_steps_up_and_back_in_whole_steps() -> void:
	var step: float = StatCell.HOP_STEP_SECONDS
	var cases: Array[Dictionary] = [
		{"elapsed": 0.0, "y": 0},
		{"elapsed": step, "y": -2},
		{"elapsed": step * 2.0, "y": -4},
		{"elapsed": step * 3.0, "y": -2},
		{"elapsed": step * 4.0, "y": 0},
		{"elapsed": step * 10.0, "y": 0},
	]
	for case: Dictionary in cases:
		assert_eq(StatCell.hop_offset_at(case.elapsed), case.y, "%s s in" % case.elapsed)

## The ring moves with the hop and rests at 0 once it is over.
func test_a_hop_lifts_the_ring_and_settles() -> void:
	_cell.hop()
	_cell._process(StatCell.HOP_STEP_SECONDS * 2.0)
	assert_eq(_ring_y(), -4.0, "at the top of the hop")
	_cell._process(StatCell.HOP_STEP_SECONDS * 3.0)
	assert_eq(_ring_y(), 0.0, "settled")
	assert_false(_cell.is_hopping(), "and stopped")

## A landing during a hop leaves it running: a burst bobs the ring, it never
## holds it at the top.
func test_a_hop_is_not_restarted() -> void:
	_cell.hop()
	_cell._process(StatCell.HOP_STEP_SECONDS * 3.0)
	_cell.hop()
	_cell._process(StatCell.HOP_STEP_SECONDS)
	assert_eq(_ring_y(), 0.0, "the first hop ran on to its last keyframe")

