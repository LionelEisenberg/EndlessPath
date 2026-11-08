extends GutTest

## The style rule for the training boards' footers (#144): every instruction line
## the cycling and body refining boards ship, on every technique and drill and in
## every state (before a cycle or set, during one, and under Auto), lays out as
## one line at the footer's width beside the Auto toggle. The line still wraps
## rather than trim; this checks the shipped copy is short enough not to.

const CYCLING_SCENE: PackedScene = preload("res://scenes/cycling/cycling_view/cycling_view.tscn")
const BODY_REFINING_SCENE: PackedScene = preload("res://scenes/body_refining/body_refining_view/body_refining_view.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")
const BODY_REFINING_ACTION_ID: String = "riverbank_training_action"

## Long enough to wrap at either footer's width: proves the count can see two.
const TWO_LINES: String = "Follow the ball for Madra and Spirit. Open each seal with W A S D for Mind XP."

var _original_save: SaveGameData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	BodyRefiningManager.end_set_session()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _cycling_view() -> CyclingView:
	var view := CYCLING_SCENE.instantiate() as CyclingView
	view.cultivator_plate = add_child_autofree(PLATE_SCENE.instantiate()) as CultivatorPlate
	add_child_autofree(view)
	view.show()
	view.set_process(false)
	return view

func _body_refining_view() -> BodyRefiningView:
	var view := BODY_REFINING_SCENE.instantiate() as BodyRefiningView
	view.cultivator_plate = add_child_autofree(PLATE_SCENE.instantiate()) as CultivatorPlate
	add_child_autofree(view)
	view.show()
	view.setup(ZoneManager.get_action_by_id(BODY_REFINING_ACTION_ID))
	view.set_process(false)
	return view

## The lines the cycling footer shows for `technique`: waiting, running with and
## without its other stat capped, and under Auto.
func _cycling_lines(technique: CyclingTechniqueData) -> PackedStringArray:
	var lines := PackedStringArray()
	for running: bool in [false, true]:
		for capped: bool in [false, true]:
			for auto: bool in [false, true]:
				var line: String = CyclingView.status_line(running, technique, capped, auto)
				if not lines.has(line):
					lines.append(line)
	return lines

## How many lines the cycling footer takes for `line`.
func _cycling_line_count(view: CyclingView, line: String) -> int:
	var label := view.get_node("%StatusLabel") as Label
	label.text = line
	view._relayout_board()
	return label.get_line_count()

## How many lines the drill footer takes for `line`.
func _drill_line_count(view: BodyRefiningView, line: String) -> int:
	view._show_status(line)
	return (view.get_node("%StatusText") as RichTextLabel).get_line_count()

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_every_cycling_line_is_one_line() -> void:
	var view: CyclingView = _cycling_view()
	assert_eq(_cycling_line_count(view, TWO_LINES), 2, "precondition: a long line wraps")
	var techniques: Array[CyclingTechniqueData] = CyclingManager.get_all_techniques()
	assert_gt(techniques.size(), 0, "precondition: the catalog has techniques")
	for technique: CyclingTechniqueData in techniques:
		for line: String in _cycling_lines(technique):
			assert_eq(_cycling_line_count(view, line), 1, "%s: \"%s\"" % [technique.technique_name, line])

func test_every_drill_line_is_one_line() -> void:
	var view: BodyRefiningView = _body_refining_view()
	assert_eq(_drill_line_count(view, TWO_LINES), 2, "precondition: a long line wraps")
	var drills: Array[DrillData] = BodyRefiningManager.get_all_drills()
	assert_gt(drills.size(), 0, "precondition: the catalog has drills")
	for drill: DrillData in drills:
		for line: String in [drill.ready_line, drill.play_line]:
			assert_ne(line, "", "%s has its line" % drill.drill_name)
			assert_eq(_drill_line_count(view, line), 1, "%s: \"%s\"" % [drill.drill_name, line])
	var auto: String = BodyRefiningView.AUTO_LINE % roundi(DrillRules.AUTO_RATE * 100.0)
	assert_eq(_drill_line_count(view, auto), 1, "Auto: \"%s\"" % auto)
