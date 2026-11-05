extends GutTest

## The Celestial Intervener's chain stays in order: each return visit (NPCs 2, 3
## and 4) shows only after the talk before it, even when its own goal (Madra 100,
## the first win, Core Density 10) is met first. Played through DevCommands on the
## real managers and quests, as the story route plays them. A save written before
## the talks' conditions were registered latches them when it loads.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const ZONE_ID: String = "SpiritValley"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

## The NPC actions, by their place in the chain. Each one's event, and the
## condition that wraps it, share its id.
const NPCS: Dictionary[int, String] = {
	1: "celestial_intervener_dialogue_1",
	2: "celestial_intervener_dialogue_2",
	3: "celestial_intervener_dialogue_3",
	4: "celestial_intervener_dialogue_4",
}

## Fired by the first won fight: NPC 3's own gate.
const ENEMY_DEFEATED_EVENT: String = "q_first_steps_enemy_defeated"
## "Harden Your Core", which NPC 3 starts and NPC 4's talk completes.
const HARDEN_YOUR_CORE: String = "q_reach_core_density_10"
const RETURN_TO_NPC_STEP: int = 1

## The old-save test writes this file. after_each() deletes it.
const OLD_SAVE_PATH: String = "user://__test_foundation_quest_chain_old_save.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_stages: Array[AdvancementStageResource]

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_stages = CultivationManager.advancement_stage_resources
	# The real quests and stages, whatever an earlier file swapped in.
	QuestManager._quest_catalog = load(QUEST_LIST)
	QuestManager._build_catalog_index()
	var stages: Array[AdvancementStageResource] = []
	stages.append(load(FOUNDATION_STAGE))
	stages.append(load(COPPER_STAGE))
	CultivationManager.advancement_stage_resources = stages
	_use_fresh_save()

func after_each() -> void:
	ActionManager.cancel_current_action()
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.use_save(_original_save, _original_save_path)
	# Binding the original save again resumes its idle action, if it has one.
	ActionManager.cancel_current_action()
	if FileAccess.file_exists(OLD_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH))

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _use_fresh_save() -> void:
	# Talking to NPC 1 opens Wilderness Cycling, which starts on its own, so stop
	# whatever an earlier case left running before the save goes.
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")

func _is_available(npc: int) -> bool:
	for action: ZoneActionData in ZoneManager.get_available_actions(ZONE_ID):
		if action.action_id == NPCS[npc]:
			return true
	return false

## Meets the NPC's own gate, beside the talk before it: Madra 100 for NPC 2, the
## first win for NPC 3, Core Density 10 for NPC 4. NPC 1 has none.
func _meet_own_gate(npc: int) -> void:
	var reason: String = ""
	match npc:
		2:
			reason = DevCommands.set_madra(100.0)
		3:
			reason = DevCommands.trigger_event(ENEMY_DEFEATED_EVENT)
		4:
			reason = DevCommands.reach_core_density(10)
	assert_eq(reason, "", "precondition: NPC %d's own gate is met" % npc)

func _talk_to(npc: int) -> void:
	assert_eq(DevCommands.complete_action(NPCS[npc]), "", "precondition: NPC %d is talked to" % npc)

## Talks to NPCs 1 to `last`, meeting each one's own gate first.
func _play_through(last: int) -> void:
	for npc: int in range(1, last + 1):
		_meet_own_gate(npc)
		_talk_to(npc)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

## NPC 4 used to open at Core Density 10 alone, beside NPC 3 once kills pay Core
## Density (ZONES.md's bug "Dialogue 4 can appear out of order").
func test_no_return_npc_shows_before_the_one_before_it() -> void:
	var return_npcs: Array[int] = [2, 3, 4]
	for npc: int in return_npcs:
		_use_fresh_save()
		var previous: int = npc - 1
		_play_through(previous - 1)
		_meet_own_gate(previous)
		_meet_own_gate(npc)
		assert_true(_is_available(previous), "NPC %d: the NPC before it is available" % npc)
		assert_false(_is_available(npc), "NPC %d stays hidden until NPC %d's talk, its own gate met" % [npc, previous])
		_talk_to(previous)
		assert_true(_is_available(npc), "NPC %d shows after NPC %d's talk" % [npc, previous])

## NPC 3 starts "Harden Your Core", which skips the steps already met. With NPC 4
## talked to first, both counted and the quest completed the moment it started.
func test_harden_your_core_started_at_core_density_10_waits_on_npc_4() -> void:
	_play_through(2)
	_meet_own_gate(3)
	_meet_own_gate(4)
	assert_string_contains(DevCommands.complete_action(NPCS[4]), "not available", "NPC 4 can't be talked to before NPC 3")
	_talk_to(3)
	assert_true(QuestManager.has_active_quest(HARDEN_YOUR_CORE), "the quest waits")
	assert_eq(QuestManager.get_current_step_index(HARDEN_YOUR_CORE), RETURN_TO_NPC_STEP, "on the talk with NPC 4")
	assert_true(_is_available(4), "and NPC 4 shows")

## A save written before NPC 2's and NPC 3's conditions were registered holds
## their events but not the conditions. Loading it latches them on the sweep that
## follows every save binding, so NPC 4 shows at once.
func test_an_old_save_past_npc_3_shows_npc_4_on_load() -> void:
	_play_through(3)
	_meet_own_gate(4)
	var old_save: SaveGameData = PersistenceManager.save_game_data.duplicate(true)
	for npc: int in [2, 3]:
		old_save.unlock_progression.unlocked_condition_ids.erase(NPCS[npc])
	assert_true(old_save.event_progression.triggered_events.has(NPCS[3]), "precondition: the old save is past NPC 3's talk")
	assert_false(old_save.unlock_progression.unlocked_condition_ids.has(NPCS[3]), "precondition: it never latched NPC 3's condition")
	assert_eq(ResourceSaver.save(old_save, OLD_SAVE_PATH), OK, "precondition: the old save is written")
	_use_fresh_save()

	PersistenceManager.open_save_file(OLD_SAVE_PATH)

	assert_true(UnlockManager.is_condition_unlocked(NPCS[2]), "NPC 2's condition latches at load")
	assert_true(UnlockManager.is_condition_unlocked(NPCS[3]), "NPC 3's condition latches at load")
	assert_true(_is_available(4), "NPC 4 shows as soon as the save loads")
