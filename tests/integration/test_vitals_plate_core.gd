extends GutTest

## The run cabinet's Core row (VitalsPlate): the core's stars as CultivationManager
## has the core, less the XP a kill's beads still carry to it (hold_core_xp() and
## release_core_xp()). Each test starts on
## a save at Core Density 6 with 3 XP, where level 7 costs 10 x 1.02^6 = 11.26.

const VitalsPlateScene := preload("res://scenes/adventure/vitals_plate/vitals_plate.tscn")
const CoreCurve := preload("res://tests/helpers/core_curve.gd")

var _plate: VitalsPlate
var _original_save: SaveGameData
## The real stages, put back after each test (CoreCurve).
var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_stages = CoreCurve.use_fixed_curve()
	_original_save = PersistenceManager.save_game_data
	var save := SaveGameData.new()
	save.core_density_level = 6.0
	save.core_density_xp = 3.0
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()
	_plate = VitalsPlateScene.instantiate()
	add_child_autofree(_plate)

func after_each() -> void:
	CoreCurve.restore(_original_stages)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# A save reset starts the zone's idle action: stop what it started.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

## The steps the Core row's stars show, 0 (empty) to 10 (lit).
func _star_steps() -> Array[int]:
	var row: LacquerStarRow = _plate.get_node("%CoreStars") as LacquerStarRow
	var steps: Array[int] = []
	for index: int in row.get_star_count():
		steps.append(row.get_star_step(index))
	return steps

## The first star's step: the save's six levels are its tenths.
func _first_star() -> int:
	return _star_steps()[0]

func test_the_core_row_shows_the_core() -> void:
	assert_eq(_first_star(), 6, "Core Density 6: the first star six tenths up")
	assert_eq(_star_steps().size(), 10, "the stage's ten stars")

## 23 XP pays level 7's 11.26 and level 8's 11.49, leaving 0.25.
func test_the_core_row_follows_the_core() -> void:
	CultivationManager.add_core_density_xp(20.0)
	assert_eq(_first_star(), 8)

func test_held_xp_stays_out_of_the_row_until_it_lands() -> void:
	CultivationManager.add_core_density_xp(20.0)

	_plate.hold_core_xp(20.0)
	assert_eq(_first_star(), 6, "the core as it stood before the beads' XP")

	_plate.release_core_xp(5.0)
	assert_eq(_first_star(), 6, "8 XP has landed, short of level 7")

	_plate.release_core_xp(10.0)
	assert_eq(_first_star(), 7, "18 XP has landed: level 7")

	_plate.release_core_xp(5.0)
	assert_eq(_first_star(), 8, "every bead landed")

func test_a_full_core_lights_every_star() -> void:
	PersistenceManager.save_game_data.core_density_level = CultivationManager.get_core_density_cap()
	PersistenceManager.save_game_data.core_density_xp = 0.0
	CultivationManager.add_core_density_xp(0.0)
	assert_eq(_star_steps(), [10, 10, 10, 10, 10, 10, 10, 10, 10, 10] as Array[int])
