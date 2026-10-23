extends GutTest

## The developer's rule: "at no point in this game should text get cut off. Always
## increase the size, go to the next line." Every Label on the boards below wraps
## where it could run long, so none trims its text with an ellipsis or clips it,
## and the board it stands on grows instead (each board's own test file tests the
## growing: test_expedition_page.gd, test_technique_dock.gd, test_goals_panel.gd,
## test_zone_panel.gd, test_adventure_chest.gd). This walk instances each board's
## scene, nested scenes included, and looks at every Label in it.
## The player's log and the zone chest's own cards still ellipsize (they are not
## among these boards), so they are not walked.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The adventure's chest (its title, its expedition page with its Here tray, hint
## row and choice drawers), the technique dock's cast tray and tooltip, the Goals
## board and the zone chest's Now strip.
const BOARD_SCENES: Array[String] = [
	"res://scenes/adventure/adventure_chest/adventure_chest.tscn",
	"res://scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn",
	"res://scenes/adventure/adventure_chest/choice_drawer/choice_drawer.tscn",
	"res://scenes/ui/combat/technique_dock/technique_dock.tscn",
	"res://scenes/ui/combat/technique_dock/cast_tray/cast_tray.tscn",
	"res://scenes/ui/combat/technique_dock/technique_tooltip/technique_tooltip.tscn",
	"res://scenes/ui/goals_panel/goals_panel.tscn",
	"res://scenes/zones/zone_panel/now_strip/now_strip.tscn",
]

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_no_label_of_a_board_ellipsizes_or_clips() -> void:
	var walked: int = 0
	for path: String in BOARD_SCENES:
		var board: Node = (load(path) as PackedScene).instantiate()
		add_child_autofree(board)
		var labels: Array[Node] = board.find_children("*", "Label", true, false)
		assert_gt(labels.size(), 0, "precondition: %s holds Labels" % path)
		for node: Node in labels:
			var label := node as Label
			assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s in %s does not trim its text" % [label.name, path.get_file()])
			assert_false(label.clip_text, "%s in %s does not clip its text" % [label.name, path.get_file()])
			walked += 1
	assert_gt(walked, 40, "precondition: the walk met the boards' labels")

## A board's scene file says so too: no Label in it is saved with an ellipsis.
func test_no_board_scene_file_sets_an_ellipsis() -> void:
	for path: String in BOARD_SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "precondition: %s reads" % path)
		assert_false(text.contains("text_overrun_behavior"), "%s sets no overrun behaviour" % path.get_file())
		assert_false(text.contains("clip_text"), "%s clips no text" % path.get_file())

## A Label that holds a name, a line or a hint wraps by word where it could run past
## its board: the wrapping ones are the labels of the two rows that carry long
## texts, and each is told how wide it may be.
func test_the_labels_that_can_run_long_wrap() -> void:
	var wrapping: Dictionary[String, Array] = {
		"res://scenes/adventure/adventure_chest/adventure_chest.tscn": ["TitleLabel"],
		"res://scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn": ["NameLabel", "LineLabel", "LoreLabel", "WalkHint", "LockLine"],
		"res://scenes/adventure/adventure_chest/choice_drawer/choice_drawer.tscn": ["Title", "Detail"],
		"res://scenes/ui/combat/technique_dock/cast_tray/cast_tray.tscn": ["NameLabel"],
		"res://scenes/ui/combat/technique_dock/technique_tooltip/technique_tooltip.tscn": ["NameLabel", "DescriptionLabel"],
		"res://scenes/ui/goals_panel/goals_panel.tscn": ["QuestNameLabel", "QuestStepLabel", "MilestoneNameLabel", "MilestoneTextLabel"],
		"res://scenes/zones/zone_panel/now_strip/now_strip.tscn": ["TrainingName", "LevelLabel", "ForageName", "EmptyLabel"],
	}
	for path: String in wrapping:
		var board: Node = (load(path) as PackedScene).instantiate()
		add_child_autofree(board)
		for label_name: String in wrapping[path]:
			var label := board.get_node("%" + label_name) as Label
			assert_not_null(label, "%s has %s" % [path.get_file(), label_name])
			if label != null:
				assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s in %s wraps by word" % [label_name, path.get_file()])
