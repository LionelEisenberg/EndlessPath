extends GutTest

## Integration tests for the lacquer Goals board (GoalsPanel, lacquer kit
## §5.2): the first active quest's current step with a progress figure only for
## measurable steps, the Breakthrough milestone in its three states (Core
## Density towards the stage's cap, a full core that faces the Tribulation, a
## stage with no next stage), the milestone alone when no quest is active, the
## milestone waiting for NPC 4 (the end of Beat 3b's chain) in Foundation, and
## the board hiding while it has no goal at all. No text is cut off (the
## developer's rule): a long step wraps and the board grows to hold it.

const GOALS_SCENE_PATH: String = "res://scenes/ui/goals_panel/goals_panel.tscn"
const QUEST_CATALOG_PATH: String = "res://resources/quests/quest_list.tres"

const FILL_CORE_QUEST_ID: String = "q_fill_core"
const FIRST_STEPS_QUEST_ID: String = "q_first_steps"
const FIRST_STEPS_ENEMY_EVENT: String = "q_first_steps_enemy_defeated"
const FIRST_STEPS_RETURN_EVENT: String = "celestial_intervener_dialogue_3"
const CORE_DENSITY_QUEST_ID: String = "q_reach_core_density_10"
## NPC 4's event, and the condition that wraps it: Foundation's Breakthrough
## goes on the board once it latches.
const NPC_4_EVENT: String = "celestial_intervener_dialogue_4"

const MILESTONE_ROD_STEPS: int = 138
## The board's height with both rows of one line each (kit §5.2: 272 to 492).
const FULL_HEIGHT: float = 220.0

var _goals: GoalsPanel = null
var _original_stage_resources: Array[AdvancementStageResource] = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_stage_resources = CultivationManager.advancement_stage_resources
	_restore_quest_catalog()
	_use_fresh_save()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	CultivationManager.advancement_stage_resources = _original_stage_resources
	_restore_quest_catalog()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Unit tests may leave a stub catalog in QuestManager; integration tests run
## on the real quests (as test_beat_3b_merchant_unlock.gd does).
func _restore_quest_catalog() -> void:
	QuestManager._quest_catalog = load(QUEST_CATALOG_PATH)
	QuestManager._build_catalog_index()

## Loads `save`, which has talked to NPC 4 unless `npc_4_talked` is false, so the
## milestone tests find Foundation's Breakthrough on the board.
func _use_fresh_save(save: SaveGameData = SaveGameData.new(), npc_4_talked: bool = true) -> void:
	if npc_4_talked:
		save.unlock_progression.unlocked_condition_ids.append(NPC_4_EVENT)
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## Swaps in a Foundation that fills at `cap`, with a Copper after it. Call it
## before the save loads; after_each() restores the real stages.
func _use_a_short_stage(cap: int) -> void:
	var copper := AdvancementStageResource.new()
	copper.stage_id = CultivationManager.AdvancementStage.COPPER
	copper.stage_name = "Test Copper"
	var short_stage := AdvancementStageResource.new()
	short_stage.stage_id = CultivationManager.AdvancementStage.FOUNDATION
	short_stage.stage_name = "Short Foundation"
	short_stage.max_core_density_level = cap
	short_stage.next_stage = copper
	var stages: Array[AdvancementStageResource] = [short_stage, copper]
	CultivationManager.advancement_stage_resources = stages

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

#-----------------------------------------------------------------------------
# NO QUEST
#-----------------------------------------------------------------------------

func test_no_quest_shows_milestone_only() -> void:
	_add_goals()
	await wait_process_frames(1)
	assert_false(_is_shown("QuestRow"), "no quest row without an active quest")
	assert_false(_is_shown("Divider"), "no divider without an active quest")
	assert_true(_is_shown("MilestoneRow"))

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

func test_completed_quest_falls_back_to_milestone() -> void:
	_add_goals()
	QuestManager.start_quest(FIRST_STEPS_QUEST_ID)
	EventManager.trigger_event(FIRST_STEPS_ENEMY_EVENT)
	EventManager.trigger_event(FIRST_STEPS_RETURN_EVENT)
	assert_true(QuestManager.has_completed_quest(FIRST_STEPS_QUEST_ID), "precondition: the quest completed")
	await wait_process_frames(1)
	assert_false(_is_shown("QuestRow"))

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

## Core Density has a cap: a save past it loads at it, and the full core asks to
## face the Tribulation.
func test_milestone_at_the_cap_asks_for_the_tribulation() -> void:
	var save := SaveGameData.new()
	save.core_density_level = 120.0
	_use_fresh_save(save)
	assert_eq(CultivationManager.get_core_density_level(), 100.0, "precondition: the save loaded at the cap")
	_add_goals()
	assert_eq(_text("MilestoneTextLabel"), "Face the Tribulation")
	assert_true(_is_shown("MilestoneFigureLabel"))
	assert_eq(_text("MilestoneFigureLabel"), "100 / 100")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), MILESTONE_ROD_STEPS)

## A stage with no next stage has no Tribulation to face, even with its core full.
func test_a_full_copper_core_still_reads_reached() -> void:
	var save := SaveGameData.new()
	save.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	save.core_density_level = 100.0
	_use_fresh_save(save)
	_add_goals()
	assert_true(CultivationManager.is_core_full(), "precondition: the Copper core is full")
	assert_eq(_text("MilestoneTextLabel"), "Copper reached")
	assert_false(_is_shown("MilestoneFigureLabel"))

func test_milestone_follows_level_up() -> void:
	_add_goals()
	var save: SaveGameData = PersistenceManager.save_game_data
	save.core_density_level = 50.0
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)
	assert_eq(_text("MilestoneFigureLabel"), "50 / 100")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), 69)

## The stage changes under a board that is already up, and only
## advancement_stage_changed says so.
func test_milestone_follows_the_stage_change() -> void:
	_add_goals()
	assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to 100", "precondition: Foundation")
	var save: SaveGameData = PersistenceManager.save_game_data
	save.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	CultivationManager.advancement_stage_changed.emit(save.current_advancement_stage)
	assert_eq(_text("MilestoneTextLabel"), "Copper reached")

## A new save under a board that stood on Copper brings the figure back.
func test_the_figure_returns_with_a_new_save() -> void:
	var copper_save := SaveGameData.new()
	copper_save.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	_use_fresh_save(copper_save)
	_add_goals()
	assert_false(_is_shown("MilestoneFigureLabel"), "precondition: no figure on Copper")
	_use_fresh_save()
	assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to 100")
	assert_true(_is_shown("MilestoneFigureLabel"))
	assert_eq(_text("MilestoneFigureLabel"), "0 / 100")

## The cap is the stage's own: a stage that fills at 40 asks for 40, and its full
## core reads 40 / 40.
func test_milestone_reads_the_stages_cap() -> void:
	_use_a_short_stage(40)
	var save := SaveGameData.new()
	save.core_density_level = 20.0
	_use_fresh_save(save)
	_add_goals()
	assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to 40")
	assert_eq(_text("MilestoneFigureLabel"), "20 / 40")
	assert_eq((_node("MilestoneRod") as LacquerRod).get_step(), roundi(0.5 * MILESTONE_ROD_STEPS))
	save.core_density_level = 40.0
	CultivationManager.core_density_level_updated.emit(save.core_density_xp, save.core_density_level)
	assert_eq(_text("MilestoneTextLabel"), "Face the Tribulation")
	assert_eq(_text("MilestoneFigureLabel"), "40 / 40")

#-----------------------------------------------------------------------------
# THE BREAKTHROUGH WAITS FOR NPC 4
#-----------------------------------------------------------------------------

## A fresh save has no goal before its first talk: the board hides all of
## itself, its cords too, and lets clicks through to the map. Its root stays
## visible, since MainView hides and restores the root under the overlays.
func test_a_board_with_no_goal_hides() -> void:
	_use_fresh_save(SaveGameData.new(), false)
	_add_goals()
	assert_false(_is_shown("QuestRow"))
	assert_false(_is_shown("MilestoneRow"), "the Breakthrough waits for NPC 4")
	for piece: String in ["Board", "TitleLabel", "Cords"]:
		assert_false(_is_shown(piece), "%s hides" % piece)
	_goals.set_cords_visible(true)
	assert_false(_is_shown("Cords"), "no cords hang to an empty board")
	assert_true(_goals.visible, "the root is MainView's to hide")
	assert_eq(_goals.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks reach the map")

## Before NPC 4 a quest stands alone: no divider under it and no milestone.
func test_a_quest_before_npc_4_stands_alone() -> void:
	_use_fresh_save(SaveGameData.new(), false)
	_add_goals()
	QuestManager.start_quest(FILL_CORE_QUEST_ID)
	await wait_process_frames(1)
	assert_true(_is_shown("QuestRow"))
	assert_false(_is_shown("Divider"), "no divider under a lone row")
	assert_false(_is_shown("MilestoneRow"))
	for piece: String in ["Board", "TitleLabel", "Cords"]:
		assert_true(_is_shown(piece), "%s shows with the first goal" % piece)
	assert_eq(_goals.mouse_filter, Control.MOUSE_FILTER_STOP)

## NPC 4 completes Harden Your Core, the last quest, and its talk puts the
## Breakthrough on the board in the quest's place, for the climb to the cap.
func test_npc_4_hands_the_board_to_the_breakthrough() -> void:
	var save := SaveGameData.new()
	save.quest_progression.active_quests[CORE_DENSITY_QUEST_ID] = 1
	_use_fresh_save(save, false)
	_add_goals()
	assert_eq(_text("QuestStepLabel"), "Return to the Celestial [INTERVENER]", "precondition: NPC 4 is next")
	assert_false(_is_shown("MilestoneRow"), "precondition: no Breakthrough yet")
	EventManager.trigger_event(NPC_4_EVENT)
	await wait_process_frames(1)
	assert_true(QuestManager.has_completed_quest(CORE_DENSITY_QUEST_ID), "precondition: the quest completed")
	assert_false(_is_shown("QuestRow"))
	assert_true(_is_shown("MilestoneRow"))
	assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to 100")

## The wait is Foundation's: Copper has no condition, so its line shows on a save
## that never talked to NPC 4.
func test_copper_shows_its_milestone_without_npc_4() -> void:
	var save := SaveGameData.new()
	save.current_advancement_stage = CultivationManager.AdvancementStage.COPPER
	_use_fresh_save(save, false)
	_add_goals()
	assert_true(_is_shown("MilestoneRow"))
	assert_eq(_text("MilestoneTextLabel"), "Copper reached")

#-----------------------------------------------------------------------------
# LONG TEXT (Review Focus 4)
#-----------------------------------------------------------------------------

func test_long_step_text_wraps_and_does_not_widen_board() -> void:
	var long_text: String = "Walk the long road ".repeat(16).substr(0, 300)
	assert_eq(long_text.length(), 300, "precondition: a 300-character step")
	var quest_id: String = _use_single_quest("A Quest Whose Name Runs Far Past The Board's Edge", long_text)
	_add_goals()
	QuestManager.start_quest(quest_id)
	await wait_process_frames(2)
	assert_eq(_goals.size.x, 440.0, "the board keeps its width")
	var step_label: Label = _node("QuestStepLabel")
	assert_eq(step_label.text, long_text, "the full text is kept: the label wraps it, never trims it")
	assert_gt(step_label.get_line_count(), 3, "precondition: the step takes many lines")
	assert_gt(_goals.size.y, FULL_HEIGHT, "and the board grows")
