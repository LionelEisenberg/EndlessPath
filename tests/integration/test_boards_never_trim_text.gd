extends GutTest

## The developer's rule: "at no point in this game should text get cut off. Always
## increase the size, go to the next line." Every Label on the boards below wraps
## where it could run long, so none trims its text with an ellipsis or clips it,
## and the board it stands on grows instead (each board's own test file tests the
## growing: test_expedition_page.gd, test_technique_dock.gd, test_goals_panel.gd,
## test_zone_panel.gd, test_adventure_chest.gd). This walk instances each board's
## scene, nested scenes included, and looks at every Label in it.
## The rule holds for every scene and script under res://scenes, not just those
## boards: a second walk reads each .tscn for a trimming overrun behaviour or
## clip_text, and each .gd for code that sets either, and fails for any file that
## is not on KNOWN_TRIMMERS, the files that have not been swept yet (the style
## guide's "Where text still trims"). It fails the other way too, for a listed file
## that no longer trims, so the list is exact and only ever shrinks.

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

## Where the whole-scene walk reads.
const SCENES_ROOT: String = "res://scenes"

## The files that still trim or clip text, each waiting for the sweep that makes its
## text wrap and its board grow. The sweep empties this list one file at a time (a
## file comes off it when it stops trimming, and the second test insists), and no
## file joins it: new text wraps. Style guide, "Where text still trims".
const KNOWN_TRIMMERS: Array[String] = [
	# The player's log: its five lines.
	"res://scenes/ui/log_window/log_window.tscn",
	# The zone chest's title.
	"res://scenes/zones/zone_panel/zone_panel.tscn",
	# The zone cards: the card, the presenters that fill it and the code that fits their text.
	"res://scenes/zones/zone_action_button/zone_action_button.tscn",
	"res://scenes/zones/zone_action_button/zone_action_button.gd",
	"res://scenes/zones/zone_action_button/presenters/adventure_presenter.tscn",
	"res://scenes/zones/zone_action_button/presenters/cycling_presenter.tscn",
	"res://scenes/zones/zone_action_button/presenters/default_presenter.tscn",
	"res://scenes/zones/zone_action_button/presenters/merchant_presenter.tscn",
	# The zone map's name plates and popovers.
	"res://scenes/zones/map_markers/zone_map_label/zone_map_label.tscn",
	"res://scenes/zones/map_markers/zone_map_popover/zone_map_popover.tscn",
	# The Abilities view.
	"res://scenes/abilities/abilities_view.tscn",
]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every file under `folder` that ends with `extension`, subfolders included.
func _files_under(folder: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	for subfolder: String in DirAccess.get_directories_at(folder):
		found.append_array(_files_under(folder.path_join(subfolder), extension))
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(extension):
			found.append(folder.path_join(file))
	return found

## True when a line of a .tscn sets a trimming overrun behaviour (anything but 0,
## no trimming) or clips text.
func _scene_line_trims(line: String) -> bool:
	if line.begins_with("clip_text = true"):
		return true
	if line.begins_with("text_overrun_behavior = "):
		return line.trim_prefix("text_overrun_behavior = ").strip_edges() != "0"
	return false

## True when a line of a script sets a trimming overrun behaviour (anything but
## OVERRUN_NO_TRIMMING) or clips text. A comment sets nothing.
func _code_line_trims(line: String) -> bool:
	var code: String = line.strip_edges()
	if code.begins_with("#"):
		return false
	code = code.get_slice(" #", 0)
	if code.contains("clip_text = true"):
		return true
	var at: int = code.find("text_overrun_behavior =")
	if at == -1:
		return false
	var value: String = code.substr(at + "text_overrun_behavior =".length()).strip_edges()
	return not value in ["TextServer.OVERRUN_NO_TRIMMING", "0"]

## The files under res://scenes that trim or clip text: scenes that save it and
## scripts that set it.
func _trimming_files() -> Array[String]:
	var found: Array[String] = []
	for path: String in _files_under(SCENES_ROOT, ".tscn"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if _scene_line_trims(line):
				found.append(path)
				break
	for path: String in _files_under(SCENES_ROOT, ".gd"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if _code_line_trims(line):
				found.append(path)
				break
	return found

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

## The rule holds under res://scenes, not just on the boards above: no scene saves a
## trimming overrun behaviour or clip_text, and no script sets one, except the
## files that have not been swept yet. A file that trims and is not listed is new
## text that does not wrap: make it wrap and its board grow.
func test_no_scene_or_script_trims_text_but_the_known_trimmers() -> void:
	assert_gt(_files_under(SCENES_ROOT, ".tscn").size(), 100, "precondition: the walk finds the scenes")
	for path: String in _trimming_files():
		assert_true(KNOWN_TRIMMERS.has(path), "%s trims or clips text and is not on KNOWN_TRIMMERS: let it wrap and its board grow" % path)

## The list is exact: every file on it exists and still trims. A file that has been
## swept comes off the list, so the list only ever shrinks.
func test_every_known_trimmer_still_trims() -> void:
	var trimming: Array[String] = _trimming_files()
	for path: String in KNOWN_TRIMMERS:
		assert_true(FileAccess.file_exists(path), "%s is on KNOWN_TRIMMERS and exists" % path)
		assert_true(trimming.has(path), "%s no longer trims: take it off KNOWN_TRIMMERS" % path)

## What the walk takes for trimming: a saved overrun behaviour that is not 0, saved
## clipping, and code that sets either (a comment sets nothing).
func test_the_walk_recognises_what_trims() -> void:
	assert_true(_scene_line_trims("text_overrun_behavior = 3"), "a saved ellipsis")
	assert_true(_scene_line_trims("text_overrun_behavior = 1"), "a saved trim of another kind")
	assert_true(_scene_line_trims("clip_text = true"), "saved clipping")
	assert_false(_scene_line_trims("text_overrun_behavior = 0"), "no trimming")
	assert_false(_scene_line_trims("clip_text = false"), "no clipping")
	assert_false(_scene_line_trims("autowrap_mode = 3"), "wrapping is what the rule asks for")
	assert_true(_code_line_trims("\tlabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS"), "an ellipsis set in code")
	assert_true(_code_line_trims("label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR"), "another trim")
	assert_true(_code_line_trims("label.clip_text = true"), "clipping set in code")
	assert_false(_code_line_trims("label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING"), "no trimming in code")
	assert_false(_code_line_trims("label.clip_text = false"), "no clipping in code")
	assert_false(_code_line_trims("## RichTextLabel has no text_overrun_behavior: it wraps, clip_text = true is for Labels"), "a doc comment")
	assert_false(_code_line_trims("\tvar room: float = 1.0  # label.clip_text = true would cut it"), "a trailing comment")
