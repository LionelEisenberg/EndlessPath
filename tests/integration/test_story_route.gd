extends GutTest

## The story route (resources/dev/story_route.tres) played on a fresh save through the
## real DevCommands: the route validates, each step applies and does what its kind says,
## and the route as a whole reaches the Foundation content. The coverage test is the
## guard that fails when someone adds a quest or a zone action that the route neither
## reaches nor lists as left out (optional_quest_ids, excluded_action_ids).
##
## Each test binds a fresh in-memory save and gives the original back. The route makes
## foraging start on its own (q_fill_core_completed unlocks it), so the running action is
## cancelled before and after. Other files swap in stubs of the path tree, the ability
## index, the quest catalog and the advancement stages, so each test starts from the real
## ones.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Kind = DevStepData.Kind
const Stage := CultivationManager.AdvancementStage

const ROUTE_PATH: String = "res://resources/dev/story_route.tres"
const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

## The route, or null when its file is missing or is not a StoryRouteData.
var _route: StoryRouteData
var _original_save: SaveGameData
var _original_save_path: String
var _original_tree: PathTreeData
var _original_stage_override: int
var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_tree = PathManager.get_current_tree()
	_original_stage_override = PathManager._test_stage_override
	_original_stages = CultivationManager.advancement_stage_resources
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	# The real state, whatever an earlier file left behind. The tree comes after the
	# save, since binding a save drops the tree and picks it up again from the trees
	# PathManager holds. The override at -1 makes PathManager read the player's stage.
	PathManager._current_tree = load(PURE_MADRA_TREE)
	PathManager._test_stage_override = -1
	AbilityManager._build_catalog_index()
	QuestManager._quest_catalog = load(QUEST_LIST)
	QuestManager._build_catalog_index()
	var stages: Array[AdvancementStageResource] = []
	stages.append(load(FOUNDATION_STAGE))
	stages.append(load(COPPER_STAGE))
	CultivationManager.advancement_stage_resources = stages
	_route = null
	if ResourceLoader.exists(ROUTE_PATH):
		_route = load(ROUTE_PATH) as StoryRouteData

func after_each() -> void:
	ActionManager.cancel_current_action()
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.use_save(_original_save, _original_save_path)
	PathManager._current_tree = _original_tree
	PathManager._test_stage_override = _original_stage_override
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## True when the route file loaded. Asserts it, so a missing file fails the test
## with its path.
func _route_loaded() -> bool:
	assert_not_null(_route, "%s loads as a StoryRouteData" % ROUTE_PATH)
	return _route != null

## How many times the current zone counts the action as completed.
func _completions(action_id: String) -> int:
	return ZoneManager.get_zone_progression().action_completion_count.get(action_id, 0)

## True when the event has fired or the unlock condition has latched: the two things a
## beat's reached_when can name.
func _is_reached(id: String) -> bool:
	return EventManager.has_event_triggered(id) or UnlockManager.is_condition_unlocked(id)

## Adds the id of every action any zone offers right now to `seen`.
func _record_available_actions(seen: Dictionary) -> void:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			seen[action.action_id] = true

## Asserts the step did what its kind says, read from the step's own target and amount,
## right after it applied. A step that returns "" has not necessarily done anything: a
## kind wired to the wrong command would return "" too, so each kind the route uses is
## checked here. A kind this test has no check for fails, so a step is never left
## unchecked.
func _assert_took_effect(beat: StoryBeatData, step: DevStepData, completions_before: int) -> void:
	var what: String = "%s: %s" % [beat.beat_id, step.describe()]
	match step.kind:
		Kind.COMPLETE_ACTION:
			assert_eq(_completions(step.target_id), completions_before + 1, "%s: counted one completion" % what)
		Kind.TRIGGER_EVENT:
			assert_true(EventManager.has_event_triggered(step.target_id), "%s: the event fired" % what)
		Kind.REACH_CORE_DENSITY:
			assert_gte(CultivationManager.get_core_density_level(), step.amount, "%s: the level was reached" % what)
		Kind.SET_MADRA:
			assert_eq(ResourceManager.get_madra(), step.amount, "%s: Madra was set" % what)
		Kind.BUY_PATH_NODE:
			assert_eq(PathManager.get_node_purchase_count(step.target_id), 1, "%s: the node was bought" % what)
		Kind.EQUIP_TECHNIQUE:
			var equipped: CyclingTechniqueData = CyclingManager.get_equipped_technique()
			assert_not_null(equipped, "%s: a technique is equipped" % what)
			if equipped != null:
				assert_eq(equipped.id, step.target_id, "%s: the technique was equipped" % what)
		Kind.EQUIP_ABILITY:
			# The step counts slots from 1, as the player sees them; the manager from 0.
			assert_eq(AbilityManager.get_ability_at_slot(int(step.amount) - 1), step.target_id, "%s: the ability is in its slot" % what)
		Kind.ADVANCE_STAGE:
			assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER, "%s: the stage is Copper" % what)
		_:
			fail_test("%s: this test has no check for step kind %d. Add one." % [what, step.kind])

## Every quest of the catalog is completed, unless the route lists it as left out.
func _assert_every_quest_completed() -> void:
	for quest: QuestData in QuestManager.get_all_quests():
		if _route.optional_quest_ids.has(quest.quest_id):
			continue
		assert_true(QuestManager.has_completed_quest(quest.quest_id),
			"the route completes quest %s, or lists it in optional_quest_ids" % quest.quest_id)

## Every action of every zone was offered after some step, unless the route lists it
## as left out. `seen` holds the ids recorded along the way.
func _assert_every_action_offered(seen: Dictionary) -> void:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in zone.all_actions:
			if _route.excluded_action_ids.has(action.action_id):
				continue
			assert_true(seen.has(action.action_id),
				"the route makes action %s available, or lists it in excluded_action_ids" % action.action_id)

## Every limited NPC dialogue is used up, unless the route lists it as left out: the
## route plays the dialogues, since their effects drive the quests.
func _assert_every_dialogue_used_up() -> void:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in zone.all_actions:
			if action.action_type != ZoneActionData.ActionType.NPC_DIALOGUE or action.max_completions <= 0:
				continue
			if _route.excluded_action_ids.has(action.action_id):
				continue
			assert_true(ZoneManager.is_action_used_up(action, zone.zone_id),
				"the route plays dialogue %s to its end, or lists it in excluded_action_ids" % action.action_id)

#-----------------------------------------------------------------------------
# THE ROUTE
#-----------------------------------------------------------------------------

func test_the_route_validates() -> void:
	if not _route_loaded():
		return
	assert_eq(_route.validate(), PackedStringArray(), "every id the route names exists in this build")

## Plays every step in order on a fresh save, then holds the route to the content: each
## quest completed, each action offered, each NPC dialogue played, each beat reached,
## and the stage Copper.
func test_the_route_covers_the_story() -> void:
	if not _route_loaded():
		return
	var seen: Dictionary = {}
	_record_available_actions(seen)
	for beat: StoryBeatData in _route.beats:
		for step: DevStepData in beat.steps:
			var completions_before: int = 0
			if step.kind == Kind.COMPLETE_ACTION:
				completions_before = _completions(step.target_id)
			var refusal: String = step.apply()
			assert_eq(refusal, "", "%s: %s" % [beat.beat_id, step.describe()])
			if refusal != "":
				return
			_assert_took_effect(beat, step, completions_before)
			_record_available_actions(seen)
		if beat.reached_when != "":
			assert_true(_is_reached(beat.reached_when), "%s: %s was reached" % [beat.beat_id, beat.reached_when])
	_assert_every_quest_completed()
	_assert_every_action_offered(seen)
	_assert_every_dialogue_used_up()
	assert_eq(CultivationManager.get_current_advancement_stage(), Stage.COPPER, "the route ends at Copper")
