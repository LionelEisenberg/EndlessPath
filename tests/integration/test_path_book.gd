extends GutTest

## Integration tests for the Path book: its stage chapters, the tree of the
## open chapter, the right page's node and path details, the benefits list and
## the points badge. PathManager and CultivationManager run on a test save,
## swapped in and restored around each test.

const PathTreeViewScene := preload("res://scenes/path_progression/path_tree_view.tscn")
const PURE_MADRA: PathTreeData = preload("res://resources/path_progression/pure_madra/pure_madra_tree.tres")
const ANIMATION_TIMEOUT: float = 2.0
const Stage := CultivationManager.AdvancementStage

var _view: PathTreeView
var _save: SaveGameData
var _previous_path_save: SaveGameData
var _previous_tree: PathTreeData
var _previous_cultivation_save: SaveGameData

func before_each() -> void:
	_previous_path_save = PathManager._live_save_data
	_previous_tree = PathManager._current_tree
	_previous_cultivation_save = CultivationManager.live_save_data
	_save = SaveGameData.new()
	PathManager._live_save_data = _save
	PathManager._current_tree = PURE_MADRA
	CultivationManager.live_save_data = _save
	_view = PathTreeViewScene.instantiate() as PathTreeView
	add_child_autofree(_view)

func after_each() -> void:
	PathManager._live_save_data = _previous_path_save
	PathManager._current_tree = _previous_tree
	CultivationManager.live_save_data = _previous_cultivation_save

func _tab(index: int) -> Control:
	return (_view.find_child("StageTabs", true, false) as Control).tab_buttons[index]

func _label(label_name: String) -> Label:
	return _view.find_child(label_name, true, false) as Label

## Pure Madra plus one Copper-stage node, as a later stage will add.
func _tree_with_copper_node() -> PathTreeData:
	var copper_node := PathNodeData.new()
	copper_node.id = "test_copper_node"
	copper_node.display_name = "Copper Node"
	copper_node.required_stage = Stage.COPPER
	var tree: PathTreeData = PURE_MADRA.duplicate() as PathTreeData
	var nodes: Array[PathNodeData] = PURE_MADRA.nodes.duplicate()
	nodes.append(copper_node)
	tree.nodes = nodes
	return tree

#-----------------------------------------------------------------------------
# CHAPTERS
#-----------------------------------------------------------------------------

func test_only_reached_stages_unlock() -> void:
	assert_true(_view.is_stage_unlocked(Stage.FOUNDATION))
	assert_false(_view.is_stage_unlocked(Stage.COPPER))
	assert_false(_tab(0).is_locked(), "Foundation's tab opens")
	for i: int in [1, 2, 3]:
		assert_true(_tab(i).is_locked(), "stage tab %d stays locked at Foundation" % i)

func test_locked_tab_explains_itself() -> void:
	var button: Button = _tab(1).find_child("Button", true, false) as Button
	assert_eq(button.tooltip_text, "Reach Copper to open this chapter.")

func test_locked_tab_does_not_switch() -> void:
	var tabs: Control = _view.find_child("StageTabs", true, false) as Control
	watch_signals(tabs)
	(_tab(1).find_child("Button", true, false) as Button).pressed.emit()
	assert_signal_not_emitted(tabs, "tab_changed")
	assert_eq(_view.get_open_stage(), Stage.FOUNDATION)

func test_tabs_relock_on_open() -> void:
	# A breakthrough between openings unlocks the next chapter, which opens.
	_save.current_advancement_stage = Stage.COPPER
	_view.animate_open()
	assert_false(_tab(1).is_locked())
	assert_true(_tab(2).is_locked())
	assert_eq(_view.get_open_stage(), Stage.COPPER, "the book opens at the highest reached stage")

func test_open_stage_shows_only_its_nodes() -> void:
	PathManager._current_tree = _tree_with_copper_node()
	_view.build_tree()
	assert_eq(_view._node_uis.size(), PURE_MADRA.nodes.size(), "every Foundation node, nothing more")
	assert_false(_view._node_uis.has("test_copper_node"))

func test_stage_label_names_the_chapter() -> void:
	assert_eq(_label("StageLabel").text, "Foundation · stage 1 of 4")

#-----------------------------------------------------------------------------
# RIGHT PAGE
#-----------------------------------------------------------------------------

func test_opening_shows_path_info() -> void:
	var node_ui: PathNodeUI = _view._node_uis["power_font"]
	node_ui.node_hovered.emit(PURE_MADRA.get_node_by_id("power_font"), node_ui)
	_view.animate_open()
	assert_eq(_label("DetailPlaque").text, PURE_MADRA.path_name)
	assert_eq(_label("DetailType").text, "Path")

func test_hover_shows_node_details() -> void:
	var data: PathNodeData = PURE_MADRA.get_node_by_id("focused_strike")
	var node_ui: PathNodeUI = _view._node_uis["focused_strike"]
	node_ui.node_hovered.emit(data, node_ui)
	assert_eq(_label("DetailPlaque").text, data.display_name)
	assert_eq(_label("DetailName").text, data.display_name)
	assert_eq(_label("DetailType").text, "Major node")
	assert_eq(_label("DetailDescription").text, data.description)

func test_plaque_hover_shows_path_info_again() -> void:
	var node_ui: PathNodeUI = _view._node_uis["focused_strike"]
	node_ui.node_hovered.emit(PURE_MADRA.get_node_by_id("focused_strike"), node_ui)
	_label("PathPlaque").mouse_entered.emit()
	assert_eq(_label("DetailPlaque").text, PURE_MADRA.path_name)

func test_benefits_list_every_purchased_node() -> void:
	PathManager._current_tree = _tree_with_copper_node()
	_save.path_node_purchases = {"pure_core_awakening": 1, "power_font": 1, "test_copper_node": 1}
	_view.build_tree()
	var benefits: BenefitsArea = _view.find_child("BenefitsArea", true, false) as BenefitsArea
	assert_eq(benefits.get_purchased_count(), 3, "benefits from every stage, not just the open chapter")

func test_points_badge_shows_only_the_balance() -> void:
	# A small corner badge: points to spend, without the spend.
	_save.path_points = 3
	_save.path_node_purchases = {"pure_core_awakening": 1, "power_font": 1}
	_view.build_tree()
	assert_eq(_label("PointsLabel").text, "3")

func test_benefits_scroll_without_a_scrollbar() -> void:
	var benefits: ScrollContainer = _view.find_child("BenefitsArea", true, false) as ScrollContainer
	assert_eq(benefits.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER)

func test_benefits_are_marked_lines_in_one_card() -> void:
	_save.path_node_purchases = {"pure_core_awakening": 1, "expanded_core": 1}
	_view.build_tree()
	var text: String = _label("BenefitsLabel").text
	for node_id: String in ["pure_core_awakening", "expanded_core"]:
		assert_string_contains(text, "▲ " + PURE_MADRA.get_node_by_id(node_id).benefit_summary)
	assert_false(_label("BenefitsEmpty").visible)

func test_no_benefits_says_so() -> void:
	_view.build_tree()
	assert_true(_label("BenefitsEmpty").visible)
	assert_false(_label("BenefitsLabel").visible)

func test_benefits_have_no_tooltips() -> void:
	_save.path_node_purchases = {"pure_core_awakening": 1}
	_view.build_tree()
	for node_name: String in ["BenefitsCard", "BenefitsArea", "BenefitsLabel"]:
		assert_eq((_view.find_child(node_name, true, false) as Control).tooltip_text, "", node_name)

func test_right_page_stays_put_between_nodes() -> void:
	# Pointing at another node (or the path) must not move the benefits section.
	_save.path_node_purchases = {"pure_core_awakening": 1}
	_view.animate_open()
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	var plaque: Control = _view.find_child("BenefitsPlaque", true, false) as Control
	var card: Control = _view.find_child("DetailsCard", true, false) as Control
	await wait_frames(3)
	var plaque_y: float = plaque.get_global_rect().position.y
	var card_height: float = card.size.y
	for node_id: String in _view._node_uis:
		var node_ui: PathNodeUI = _view._node_uis[node_id]
		node_ui.node_hovered.emit(PURE_MADRA.get_node_by_id(node_id), node_ui)
		await wait_frames(2)
		assert_eq(plaque.get_global_rect().position.y, plaque_y, "benefits moved for %s" % node_id)
		assert_eq(card.size.y, card_height, "details card resized for %s" % node_id)

#-----------------------------------------------------------------------------
# TREE CARD
#-----------------------------------------------------------------------------

func test_level_labels_sit_centred_under_their_node() -> void:
	_view.build_tree()
	var checked: int = 0
	for node_id: String in _view._node_uis:
		var node_ui: PathNodeUI = _view._node_uis[node_id]
		var level_label: Label = node_ui.find_child("LevelLabel", true, false) as Label
		if not level_label.visible:
			continue
		checked += 1
		assert_eq(level_label.anchor_left, 0.5, node_id)
		assert_eq(level_label.anchor_right, 0.5, node_id)
		assert_eq(level_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, node_id)
		assert_gte(level_label.position.y, node_ui.size.y, "%s's label sits below the node" % node_id)
	assert_gt(checked, 0, "the tree has repeatable nodes with a level label")

func test_tree_fits_its_card() -> void:
	_view.animate_open()
	await wait_for_signal(_view.book_frame.opened, ANIMATION_TIMEOUT)
	await wait_frames(3)
	var area: Control = _view.find_child("TreeArea", true, false) as Control
	var area_rect: Rect2 = area.get_global_rect().grow(1.0)
	for node_id: String in _view._node_uis:
		var node_ui: PathNodeUI = _view._node_uis[node_id]
		assert_true(area_rect.encloses(node_ui.get_global_rect()), "%s sits inside the tree card" % node_id)
