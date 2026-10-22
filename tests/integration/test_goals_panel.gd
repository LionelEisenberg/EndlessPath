extends GutTest

## Integration tests for the lacquer Goals board (GoalsPanel, lacquer kit
## §5.2): the first active quest's current step with a progress figure only for
## measurable steps, the Breakthrough milestone, and the milestone moving up
## when no quest is active.

const GOALS_SCENE_PATH: String = "res://scenes/ui/goals_panel/goals_panel.tscn"
const QUEST_CATALOG_PATH: String = "res://resources/quests/quest_list.tres"

const FILL_CORE_QUEST_ID: String = "q_fill_core"
const FIRST_STEPS_QUEST_ID: String = "q_first_steps"
const FIRST_STEPS_ENEMY_EVENT: String = "q_first_steps_enemy_defeated"
const FIRST_STEPS_RETURN_EVENT: String = "celestial_intervener_dialogue_3"
const CORE_DENSITY_QUEST_ID: String = "q_reach_core_density_10"

## Board-local top of the milestone name with a quest row above it (kit §5.2:
## screen 408 − 272), and the 70 px it moves up without one.
const MILESTONE_TOP_WITH_QUEST: float = 136.0
const MILESTONE_SHIFT: float = 70.0
## The step line's slot: board-local x 64 to 422 (kit: screen 88 to 446).
const STEP_SLOT_WIDTH: float = 358.0
const MILESTONE_ROD_STEPS: int = 138

var _goals: GoalsPanel = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_restore_quest_catalog()
	_use_fresh_save()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	_restore_quest_catalog()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Unit tests may leave a stub catalog in QuestManager; integration tests run
## on the real quests (as test_beat_3b_merchant_unlock.gd does).
func _restore_quest_catalog() -> void:
	QuestManager._quest_catalog = load(QUEST_CATALOG_PATH)
	QuestManager._build_catalog_index()

func _use_fresh_save(save: SaveGameData = SaveGameData.new()) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

func _add_goals() -> GoalsPanel:
	var scene: PackedScene = load(GOALS_SCENE_PATH)
	_goals = scene.instantiate()
	add_child_autofree(_goals)
	return _goals

func _node(unique_name: String) -> Node:
	return _goals.get_node("%" + unique_name)

func _text(unique_name: String) -> String:
	return (_node(unique_name) as Label).text.strip_edges()

func _is_shown(unique_name: String) -> bool:
	return (_node(unique_name) as CanvasItem).is_visible_in_tree()

## The milestone name's top, local to the board.
func _milestone_top() -> float:
	var name_label: Control = _node("MilestoneNameLabel")
	return name_label.global_position.y - _goals.global_position.y

## A one-quest catalog with a single step, for text the real quests do not
## have. With no conditions the step waits for an event that never fires; with
## conditions it is condition-completed (UnlockManager never latches these, so
## the step stays put).
func _use_single_quest(quest_name: String, step_description: String,
		conditions: Array[UnlockConditionData] = []) -> String:
	var step := QuestStepData.new()
	step.step_id = "only_step"
	step.description = step_description
	if conditions.is_empty():
		step.completion_event_id = "test_goals_never_fires"
	else:
		step.completion_conditions = conditions
	var quest := QuestData.new()
	quest.quest_id = "test_goals_quest"
	quest.quest_name = quest_name
	var steps: Array[QuestStepData] = [step]
	quest.steps = steps
	var catalog := QuestList.new()
	var quests: Array[QuestData] = [quest]
	catalog.quests = quests
	QuestManager._quest_catalog = catalog
	QuestManager._build_catalog_index()
	return quest.quest_id

## Gold >= 50, measured as gold / 50.
func _gold_condition() -> UnlockConditionData:
	var condition := UnlockConditionData.new()
	condition.condition_id = "test_goals_gold_50"
	condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	condition.target_value = 50.0
	condition.optional_params = {"resource_type": "gold"}
	return condition

## Madra >= 100, measured as Madra / 100.
func _madra_condition() -> UnlockConditionData:
	var condition := UnlockConditionData.new()
	condition.condition_id = "test_goals_madra_100"
	condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	condition.target_value = 100.0
	condition.optional_params = {"resource_type": "madra"}
	return condition

#-----------------------------------------------------------------------------
# NO QUEST
#-----------------------------------------------------------------------------

func test_no_quest_shows_milestone_only() -> void:
	_add_goals()
	await wait_process_frames(1)
	assert_false(_is_shown("QuestRow"), "no quest row without an active quest")
	assert_false(_is_shown("Divider"), "no divider without an active quest")
	assert_true(_is_shown("MilestoneRow"))
	assert_eq(_milestone_top(), MILESTONE_TOP_WITH_QUEST - MILESTONE_SHIFT)

#-----------------------------------------------------------------------------
# QUEST ROW
#-----------------------------------------------------------------------------

func test_quest_row_shows_current_step() -> void:
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	await wait_process_frames(1)
	assert_true(_is_shown("QuestRow"))
	assert_true(_is_shown("Divider"))
	assert_eq(_text("QuestNameLabel"), "Awaken Your Core")
	assert_eq(_text("QuestStepLabel"), "Fill your Madra by cycling")
	assert_eq(_milestone_top(), MILESTONE_TOP_WITH_QUEST)

func test_reads_active_quest_on_ready() -> void:
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	_add_goals()
	assert_true(_is_shown("QuestRow"))
	assert_eq(_text("QuestNameLabel"), "Awaken Your Core")

func test_shows_the_first_active_quest() -> void:
	QuestManager.start_quest(FIRST_STEPS_QUEST_ID)
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	_add_goals()
	assert_eq(_text("QuestNameLabel"), "First Steps Out")

func test_measurable_step_shows_figure() -> void:
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	assert_true(_is_shown("QuestFigureLabel"))
	assert_eq(_text("QuestFigureLabel"), "25 / 100")

func test_figure_follows_madra() -> void:
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	ResourceManager.set_madra(60.0)
	assert_eq(_text("QuestFigureLabel"), "60 / 100")

func test_event_step_has_no_figure() -> void:
	_add_goals()
	QuestManager.start_quest(FIRST_STEPS_QUEST_ID)
	assert_eq(_text("QuestStepLabel"), "Defeat an enemy in combat")
	assert_false(_is_shown("QuestFigureLabel"))

func test_refreshes_on_step_advance() -> void:
	_add_goals()
	QuestManager.start_quest(FIRST_STEPS_QUEST_ID)
	EventManager.trigger_event(FIRST_STEPS_ENEMY_EVENT)
	assert_eq(QuestManager.get_current_step_index(FIRST_STEPS_QUEST_ID), 1, "precondition: the step advanced")
	assert_eq(_text("QuestStepLabel"), "Return to the Celestial [INTERVENER]")

func test_figure_hides_when_the_step_turns_to_an_event() -> void:
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	ResourceManager.set_madra(100.0)
	assert_eq(QuestManager.get_current_step_index(FILL_CORE_QUEST_ID), 1, "precondition: full Madra ends step 1")
	assert_false(_is_shown("QuestFigureLabel"))

func test_completed_quest_falls_back_to_milestone() -> void:
	_add_goals()
	QuestManager.start_quest(FIRST_STEPS_QUEST_ID)
	EventManager.trigger_event(FIRST_STEPS_ENEMY_EVENT)
	EventManager.trigger_event(FIRST_STEPS_RETURN_EVENT)
	assert_true(QuestManager.has_completed_quest(FIRST_STEPS_QUEST_ID), "precondition: the quest completed")
	await wait_process_frames(1)
	assert_false(_is_shown("QuestRow"))
	assert_eq(_milestone_top(), MILESTONE_TOP_WITH_QUEST - MILESTONE_SHIFT)

func test_core_density_step_figure_follows_level() -> void:
	_add_goals()
	QuestManager.start_quest(CORE_DENSITY_QUEST_ID)
	assert_eq(_text("QuestFigureLabel"), "0 / 10")
	var save: SaveGameData = PersistenceManager.save_game_data
	save.core_density_level = 3.0
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)
	assert_eq(_text("QuestFigureLabel"), "3 / 10")

func test_gold_step_figure_follows_gold() -> void:
	var conditions: Array[UnlockConditionData] = [_gold_condition()]
	var quest_id: String = _use_single_quest("Fill Your Purse", "Save up 50 gold", conditions)
	_add_goals()
	QuestManager.start_quest(quest_id)
	assert_eq(_text("QuestFigureLabel"), "0 / 50", "precondition: a fresh save has no gold")
	ResourceManager.add_gold(20.0)
	assert_eq(_text("QuestFigureLabel"), "20 / 50")

func test_refreshes_on_save_reset() -> void:
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	assert_true(_is_shown("QuestRow"), "precondition: the quest shows")
	_use_fresh_save()
	assert_false(_is_shown("QuestRow"), "a fresh save has no active quest")

	var save := SaveGameData.new()
	save.quest_progression.active_quests[FIRST_STEPS_QUEST_ID] = 0
	_use_fresh_save(save)
	assert_true(_is_shown("QuestRow"))
	assert_eq(_text("QuestNameLabel"), "First Steps Out")

#-----------------------------------------------------------------------------
# MILESTONE
#-----------------------------------------------------------------------------

func test_milestone_text() -> void:
	_add_goals()
	assert_eq(_text("MilestoneNameLabel"), "Breakthrough")
	assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to 100")
	assert_eq(_text("MilestoneFigureLabel"), "0 / 100")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), 0)

func test_milestone_figure_and_rod() -> void:
	var save := SaveGameData.new()
	save.core_density_level = 32.0
	_use_fresh_save(save)
	_add_goals()
	assert_eq(_text("MilestoneFigureLabel"), "32 / 100")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), roundi(0.32 * MILESTONE_ROD_STEPS))

func test_milestone_figure_caps_at_breakthrough() -> void:
	var save := SaveGameData.new()
	save.core_density_level = 120.0
	_use_fresh_save(save)
	_add_goals()
	assert_eq(_text("MilestoneFigureLabel"), "100 / 100", "Core Density has no cap, the milestone does")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), MILESTONE_ROD_STEPS)

func test_milestone_follows_level_up() -> void:
	_add_goals()
	var save: SaveGameData = PersistenceManager.save_game_data
	save.core_density_level = 50.0
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)
	assert_eq(_text("MilestoneFigureLabel"), "50 / 100")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), 69)

#-----------------------------------------------------------------------------
# LONG TEXT (Review Focus 4)
#-----------------------------------------------------------------------------

func test_long_step_text_does_not_widen_board() -> void:
	var long_text: String = "Walk the long road ".repeat(16).substr(0, 300)
	assert_eq(long_text.length(), 300, "precondition: a 300-character step")
	var quest_id: String = _use_single_quest("A Quest Whose Name Runs Far Past The Board's Edge", long_text)
	_add_goals()
	QuestManager.start_quest(quest_id)
	await wait_process_frames(1)
	assert_eq(_goals.size, Vector2(440.0, 220.0), "the board keeps its size")
	var step_label: Label = _node("QuestStepLabel")
	assert_eq(step_label.text, long_text, "the full text is kept; the label trims it")
	assert_lte(step_label.size.x, STEP_SLOT_WIDTH, "the step line stays in its slot")
	var name_label: Label = _node("QuestNameLabel")
	assert_lte(name_label.size.x, STEP_SLOT_WIDTH, "the name stays in its slot")

func test_long_name_leaves_room_for_the_figure() -> void:
	var conditions: Array[UnlockConditionData] = [_madra_condition()]
	var quest_id: String = _use_single_quest("Awaken Your Core ".repeat(10), "Fill your Madra", conditions)
	_add_goals()
	QuestManager.start_quest(quest_id)
	await wait_process_frames(1)
	assert_eq(_text("QuestFigureLabel"), "25 / 100", "precondition: the figure shows")
	var name_rect: Rect2 = (_node("QuestNameLabel") as Control).get_global_rect()
	var figure_rect: Rect2 = (_node("QuestFigureLabel") as Control).get_global_rect()
	assert_lte(name_rect.end.x, figure_rect.position.x, "the name ends before the figure")
	assert_eq(figure_rect.end.x, _goals.global_position.x + 422.0, "the figure stays right-aligned at 446")

func test_step_with_an_unmeasurable_condition_has_no_figure() -> void:
	var event_condition := UnlockConditionData.new()
	event_condition.condition_id = "test_goals_event"
	event_condition.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	event_condition.target_value = "test_goals_never_fires"
	var conditions: Array[UnlockConditionData] = [_madra_condition(), event_condition]
	var quest_id: String = _use_single_quest("Mixed", "Fill your Madra, then wait", conditions)
	_add_goals()
	QuestManager.start_quest(quest_id)
	assert_true(_is_shown("QuestRow"), "precondition: the quest shows")
	assert_false(_is_shown("QuestFigureLabel"), "every condition must be measurable")

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_is_the_board_and_stops_clicks() -> void:
	_add_goals()
	assert_eq(_goals.size, Vector2(440.0, 220.0))
	assert_eq(_goals.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_goals.theme, load("res://assets/themes/lacquer/lacquer_theme.tres"))

## refresh() is public, so a caller can reach it before the board enters the
## tree. It then waits for _ready, which refreshes anyway.
func test_refresh_before_ready_does_nothing() -> void:
	var scene: PackedScene = load(GOALS_SCENE_PATH)
	var goals: GoalsPanel = autofree(scene.instantiate())
	goals.refresh()
	assert_false(goals.is_node_ready(), "precondition: never entered the tree")
