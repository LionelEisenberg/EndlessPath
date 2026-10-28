extends GutTest

## QuestManager.get_quest_id_for_item(): the quest a quest item belongs to, for
## the Journal. First the started quest that needs the item (a step that
## completes on owning it), an active one before a completed one; otherwise the
## started quest that gave it (its completion awards it); otherwise none. A
## quest the player has not started never counts, so the Journal spoils nothing.

const QUEST_CATALOG_PATH: String = "res://resources/quests/quest_list.tres"
const MAP_PATH: String = "res://resources/items/quest_items/refugee_camp_map.tres"

## QuestManager's real state, given back after each test.
var _saved_quests_by_id: Dictionary[String, QuestData] = {}
var _saved_quest_catalog: QuestList = null
var _saved_save_data: SaveGameData = null

var _save: SaveGameData = null
var _item: QuestItemDefinitionData = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func before_each() -> void:
	_saved_quests_by_id = QuestManager._quests_by_id
	_saved_quest_catalog = QuestManager._quest_catalog
	_saved_save_data = QuestManager._live_save_data
	_save = SaveGameData.new()
	QuestManager._live_save_data = _save
	_item = QuestItemDefinitionData.new()
	_item.item_id = "test_link_bell"
	_item.item_name = "Tarnished Shrine Bell"

func after_each() -> void:
	QuestManager._quests_by_id = _saved_quests_by_id
	QuestManager._quest_catalog = _saved_quest_catalog
	QuestManager._live_save_data = _saved_save_data

## A quest of the test's own. With `needs`, its one step completes on owning
## the item; with `gives`, completing it awards the item.
func _quest(quest_id: String, needs: bool, gives: bool) -> QuestData:
	var step: QuestStepData = QuestStepData.new()
	step.step_id = "only_step"
	if needs:
		var condition: UnlockConditionData = UnlockConditionData.new()
		condition.condition_id = "test_link_owns_bell"
		condition.condition_type = UnlockConditionData.ConditionType.ITEM_OWNED
		condition.target_value = _item.item_id
		step.completion_conditions = [condition] as Array[UnlockConditionData]
	else:
		step.completion_event_id = "test_link_never_fires"
	var quest: QuestData = QuestData.new()
	quest.quest_id = quest_id
	quest.quest_name = quest_id
	quest.steps = [step] as Array[QuestStepData]
	if gives:
		var award: AwardItemEffectData = AwardItemEffectData.new()
		award.item = _item
		quest.completion_effects = [award] as Array[EffectData]
	return quest

## Makes `quests` QuestManager's whole catalog, in this order.
func _use_quests(quests: Array[QuestData]) -> void:
	var by_id: Dictionary[String, QuestData] = {}
	for quest: QuestData in quests:
		by_id[quest.quest_id] = quest
	QuestManager._quests_by_id = by_id

func _start(quest_id: String) -> void:
	_save.quest_progression.active_quests[quest_id] = 0

func _complete(quest_id: String) -> void:
	_save.quest_progression.completed_quest_ids.append(quest_id)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_quest_that_gave_it_when_nothing_needs_it() -> void:
	_use_quests([_quest("G", false, true)] as Array[QuestData])
	_complete("G")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "G")

func test_quest_that_needs_it_wins() -> void:
	_use_quests([_quest("G", false, true), _quest("N", true, false)] as Array[QuestData])
	_complete("G")
	_start("N")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "N")

func test_unstarted_quests_are_ignored() -> void:
	_use_quests([_quest("N", true, false), _quest("G", false, true)] as Array[QuestData])
	_complete("G")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "G", "N needs it, but the player has not met N")

func test_an_unstarted_giver_is_ignored_too() -> void:
	_use_quests([_quest("G", false, true)] as Array[QuestData])
	assert_eq(QuestManager.get_quest_id_for_item(_item), "")

func test_active_need_wins_over_completed_need() -> void:
	_use_quests([_quest("N1", true, false), _quest("N2", true, false)] as Array[QuestData])
	_complete("N1")
	_start("N2")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "N2")

func test_a_completed_need_wins_over_the_giver() -> void:
	_use_quests([_quest("G", false, true), _quest("N", true, false)] as Array[QuestData])
	_complete("G")
	_complete("N")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "N")

func test_the_first_match_in_catalog_order_wins() -> void:
	_use_quests([_quest("G1", false, true), _quest("G2", false, true)] as Array[QuestData])
	_complete("G2")
	_complete("G1")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "G1", "the catalog's order, not the order they were done")

func test_no_quest_gives_empty() -> void:
	_use_quests([_quest("Q", false, false)] as Array[QuestData])
	_complete("Q")
	assert_eq(QuestManager.get_quest_id_for_item(_item), "")
	assert_eq(QuestManager.get_quest_id_for_item(null), "")

func test_refugee_camp_map_belongs_to_harden_your_core() -> void:
	# A fresh index, so rebuilding it leaves the saved one as it was.
	var index: Dictionary[String, QuestData] = {}
	QuestManager._quests_by_id = index
	QuestManager._quest_catalog = load(QUEST_CATALOG_PATH) as QuestList
	QuestManager._build_catalog_index()
	_complete("q_reach_core_density_10")
	var map: ItemDefinitionData = load(MAP_PATH) as ItemDefinitionData
	assert_eq(QuestManager.get_quest_id_for_item(map), "q_reach_core_density_10")
