extends GutTest

## Unit tests for StatCell, one stat on the cultivator cabinet: the frame its
## XP ring shows at the edges of set_stat(), called directly with values
## CharacterManager does not send today (no cost to the next level, XP at or
## past it, negative XP). test_cultivator_plate.gd covers the cells following
## CharacterManager.

const CELL_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/stat_cell/stat_cell.tscn")

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

## At the cap the ring shows its capped frame, whatever the XP.
func test_a_capped_ring_is_full_whatever_the_xp() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no XP", "xp": 0.0, "xp_to_next": 100.0},
		{"name": "half the next level's cost", "xp": 50.0, "xp_to_next": 100.0},
		{"name": "negative XP", "xp": -10.0, "xp_to_next": 100.0},
		{"name": "no cost to the next level", "xp": 0.0, "xp_to_next": 0.0},
	]
	for case: Dictionary in cases:
		_start_from_a_half_ring()
		_cell.set_stat(10, case.xp, case.xp_to_next, true)
		assert_eq(_ring(), Vector2i(StatCell.RING_CAPPED_FRAME, 0), "capped, %s" % case.name)
