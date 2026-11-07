extends GutTest

## The Celestial Intervener's chain, in play order NPC 1, 2, 3, 5, 4 (NPC 5 is
## dialogue_5, the body refining beat #109 added before NPC 4). Each return visit
## shows only after the talk before it, even when its own goal (Madra 100, the
## first win, Strength Lv 2, two stars of the core) is met first; each talk
## completes one quest and starts the next, and no talk refills Madra or Health.
## Played through DevCommands on the real managers and quests, as the story route
## plays them. Saves written before a talk's condition was registered, or before
## NPC 5 existed, load and play on.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Attribute := CharacterAttributesData.AttributeType

const ZONE_ID: String = "SpiritValley"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

## The NPC actions, by number. Each one's event, and the condition that wraps it,
## share its id.
const NPCS: Dictionary[int, String] = {
	1: "celestial_intervener_dialogue_1",
	2: "celestial_intervener_dialogue_2",
	3: "celestial_intervener_dialogue_3",
	4: "celestial_intervener_dialogue_4",
	5: "celestial_intervener_dialogue_5",
}
## The order the talks play in.
const CHAIN: Array[int] = [1, 2, 3, 5, 4]

## Fired by the first won fight: NPC 3's own gate.
const ENEMY_DEFEATED_EVENT: String = "q_first_steps_enemy_defeated"
const AWAKEN_YOUR_SPIRIT: String = "q_fill_core"
const FIRST_STEPS_OUT: String = "q_first_steps"
## "Temper Your Body", which NPC 3 starts and NPC 5's talk completes.
const TEMPER_YOUR_BODY: String = "q_temper_body"
## "Harden Your Core", which NPC 5 starts and NPC 4's talk completes.
const HARDEN_YOUR_CORE: String = "q_reach_core_density_10"
## "Find the Camp", which NPC 4 starts and approaching the refugee camp completes.
const FIND_THE_CAMP: String = "q_find_the_camp"
## Fired by the camp's "Approach the camp": the Traveling Merchant comes home.
const MERCHANT_DISCOVERED_EVENT: String = "merchant_discovered"
## Find the Camp's reward (#146: a starting value, #111 is paused).
const FIND_THE_CAMP_GOLD: float = 50.0
## Harden Your Core's goal, two stars: its id is older than its target.
const TWO_STARS_CONDITION: String = "q_reach_cd_10"
const RETURN_TO_NPC_STEP: int = 1
const HORSE_STANCE: String = "horse_stance"
const MAP_ITEM_ID: String = "refugee_camp_map"

## The old-save tests write this file. after_each() deletes it.
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
## first win for NPC 3, Strength Lv 2 for NPC 5, two stars for NPC 4. NPC 1 has
## none.
func _meet_own_gate(npc: int) -> void:
	var reason: String = ""
	match npc:
		2:
			reason = DevCommands.set_madra(100.0)
		3:
			reason = DevCommands.trigger_event(ENEMY_DEFEATED_EVENT)
		5:
			reason = DevCommands.set_stat_level(&"strength", 2)
		4:
			reason = DevCommands.reach_core_density(20)
	assert_eq(reason, "", "precondition: NPC %d's own gate is met" % npc)

func _talk_to(npc: int) -> void:
	assert_eq(DevCommands.complete_action(NPCS[npc]), "", "precondition: NPC %d is talked to" % npc)

## Talks to each NPC of the chain up to and including `last`, meeting each one's
## own gate first. 0 talks to none.
func _play_through(last: int) -> void:
	if last == 0:
		return
	for npc: int in CHAIN:
		_meet_own_gate(npc)
		_talk_to(npc)
		if npc == last:
			return

## The NPC whose talk comes right before this one's.
func _previous(npc: int) -> int:
	return CHAIN[CHAIN.find(npc) - 1]

## The NPC whose talk comes two before this one's, or 0 when there is none.
func _two_before(npc: int) -> int:
	var index: int = CHAIN.find(npc) - 2
	return CHAIN[index] if index >= 0 else 0

## Writes the live save to OLD_SAVE_PATH as `edit` leaves a copy of it, then loads
## it through PersistenceManager as a save of an older build would load.
func _reload_as_old_save(edit: Callable) -> void:
	var old_save: SaveGameData = PersistenceManager.save_game_data.duplicate(true)
	edit.call(old_save)
	assert_eq(ResourceSaver.save(old_save, OLD_SAVE_PATH), OK, "precondition: the old save is written")
	_use_fresh_save()
	PersistenceManager.open_save_file(OLD_SAVE_PATH)

#-----------------------------------------------------------------------------
# ORDER
#-----------------------------------------------------------------------------

## NPC 4 used to open at Core Density 10 alone, beside NPC 3 once kills pay Core
## Density (ZONES.md's bug "Dialogue 4 can appear out of order"); NPC 5 joins the
## chain between NPC 3 and NPC 4.
func test_no_return_npc_shows_before_the_one_before_it() -> void:
	for npc: int in CHAIN.slice(1):
		_use_fresh_save()
		var previous: int = _previous(npc)
		_play_through(_two_before(npc))
		_meet_own_gate(previous)
		_meet_own_gate(npc)
		assert_true(_is_available(previous), "NPC %d: the NPC before it is available" % npc)
		assert_false(_is_available(npc), "NPC %d stays hidden until NPC %d's talk, its own gate met" % [npc, previous])
		_talk_to(previous)
		assert_true(_is_available(npc), "NPC %d shows after NPC %d's talk" % [npc, previous])

## NPC 3 starts Temper Your Body, which skips the steps already met: a player who
## trained before NPC 3 finds it on its return step, and NPC 5 waits for NPC 3.
func test_temper_your_body_started_at_strength_2_waits_on_npc_5() -> void:
	_play_through(2)
	_meet_own_gate(3)
	_meet_own_gate(5)
	assert_string_contains(DevCommands.complete_action(NPCS[5]), "not available", "NPC 5 can't be talked to before NPC 3")
	_talk_to(3)
	assert_true(QuestManager.has_active_quest(TEMPER_YOUR_BODY), "the quest waits")
	assert_eq(QuestManager.get_current_step_index(TEMPER_YOUR_BODY), RETURN_TO_NPC_STEP, "on the talk with NPC 5")
	assert_true(_is_available(5), "and NPC 5 shows")

## NPC 5 starts Harden Your Core the same way: two stars filled before NPC 5 leave
## it on its return step, and NPC 4 waits for NPC 5's talk.
func test_harden_your_core_started_at_two_stars_waits_on_npc_4() -> void:
	_play_through(3)
	_meet_own_gate(5)
	_meet_own_gate(4)
	assert_string_contains(DevCommands.complete_action(NPCS[4]), "not available", "NPC 4 can't be talked to before NPC 5")
	_talk_to(5)
	assert_true(QuestManager.has_active_quest(HARDEN_YOUR_CORE), "the quest waits")
	assert_eq(QuestManager.get_current_step_index(HARDEN_YOUR_CORE), RETURN_TO_NPC_STEP, "on the talk with NPC 4")
	assert_true(_is_available(4), "and NPC 4 shows")

#-----------------------------------------------------------------------------
# WHAT EACH TALK DOES
#-----------------------------------------------------------------------------

## Pattern B, talk by talk: each talk completes the quest the talk before it
## started and starts the next, one quest at a time. The rewards come at their
## talks, and none refills Madra or Health.
func test_each_npc_completes_one_quest_and_starts_the_next() -> void:
	var cases: Array[Dictionary] = [
		{"npc": 1, "completes": "", "starts": AWAKEN_YOUR_SPIRIT, "path_points": 0},
		{"npc": 2, "completes": AWAKEN_YOUR_SPIRIT, "starts": FIRST_STEPS_OUT, "path_points": 0},
		{"npc": 3, "completes": FIRST_STEPS_OUT, "starts": TEMPER_YOUR_BODY, "path_points": 1},
		{"npc": 5, "completes": TEMPER_YOUR_BODY, "starts": HARDEN_YOUR_CORE, "path_points": 0},
		{"npc": 4, "completes": HARDEN_YOUR_CORE, "starts": FIND_THE_CAMP, "path_points": 0},
	]
	for case: Dictionary in cases:
		var npc: int = case.npc
		_meet_own_gate(npc)
		var madra: float = ResourceManager.get_madra()
		var health: float = ResourceManager.get_health()
		var points: int = PathManager.get_point_balance()
		_talk_to(npc)
		if case.completes != "":
			assert_true(QuestManager.has_completed_quest(case.completes), "NPC %d completes %s" % [npc, case.completes])
		var active: Array[String] = []
		if case.starts != "":
			active.append(case.starts)
		assert_eq(QuestManager.get_active_quest_ids(), active, "NPC %d leaves only %s running" % [npc, active])
		assert_eq(PathManager.get_point_balance() - points, case.path_points, "NPC %d pays %d path points" % [npc, case.path_points])
		assert_eq(ResourceManager.get_madra(), madra, "NPC %d refills no Madra" % npc)
		assert_eq(ResourceManager.get_health(), health, "NPC %d refills no Health" % npc)
		if npc == 5:
			assert_true(BodyRefiningManager.is_drill_unlocked(HORSE_STANCE), "Temper Your Body teaches Horse Stance")
		if npc == 4:
			assert_true(InventoryManager.has_item(MAP_ITEM_ID), "Harden Your Core gives the map")

## Find the Camp opens on its one step, the map in hand, and approaching the camp
## completes it: 50 gold, and no Madra or Health.
func test_approaching_the_camp_completes_find_the_camp() -> void:
	_play_through(4)
	assert_eq(QuestManager.get_current_step_index(FIND_THE_CAMP), 0, "Find the Camp waits on the camp")
	var gold: float = ResourceManager.get_gold()
	var madra: float = ResourceManager.get_madra()
	var health: float = ResourceManager.get_health()
	EventManager.trigger_event(MERCHANT_DISCOVERED_EVENT)
	assert_true(QuestManager.has_completed_quest(FIND_THE_CAMP), "the camp completes it")
	assert_eq(ResourceManager.get_gold() - gold, FIND_THE_CAMP_GOLD, "it pays its gold")
	assert_eq(ResourceManager.get_madra(), madra, "it refills no Madra")
	assert_eq(ResourceManager.get_health(), health, "it refills no Health")

## A Ravenous Dreadbeast can drop Horse Stance's manual before NPC 5 pays it: the
## talk still completes the quest, and the manual says the drill is known.
func test_a_known_horse_stance_still_completes_temper_your_body() -> void:
	_play_through(3)
	assert_eq(DevCommands.unlock_drill(HORSE_STANCE), "", "precondition: Horse Stance is learned")
	_meet_own_gate(5)
	# The lines the talk logs, heard as they go out: the log's history is capped,
	# so once it is full its size no longer counts new lines.
	var logged: Array[String] = []
	var hear := func(line: String) -> void: logged.append(line)
	LogManager.message_logged.connect(hear)
	_talk_to(5)
	LogManager.message_logged.disconnect(hear)
	assert_true(QuestManager.has_completed_quest(TEMPER_YOUR_BODY))
	var known_line: bool = logged.any(func(line: String) -> bool: return line.contains("You know Horse Stance already"))
	assert_true(known_line, "the manual says the drill is known: %s" % [logged])

## Every condition a quest step or a Spirit Valley action waits on is registered,
## so it latches and re-checks the step or shows the action.
func test_every_condition_a_step_or_npc_uses_is_registered() -> void:
	var registered: Array[String] = []
	for condition: UnlockConditionData in UnlockManager.unlock_condition_list.list:
		registered.append(condition.condition_id)
	for quest: QuestData in QuestManager.get_all_quests():
		for step: QuestStepData in quest.steps:
			for condition: UnlockConditionData in step.completion_conditions:
				assert_has(registered, condition.condition_id, "%s's step %s" % [quest.quest_id, step.step_id])
	for action: ZoneActionData in ZoneManager.get_zone_by_id(ZONE_ID).all_actions:
		for condition: UnlockConditionData in action.unlock_conditions:
			assert_has(registered, condition.condition_id, "%s's gate" % action.action_id)

#-----------------------------------------------------------------------------
# OLD SAVES
#-----------------------------------------------------------------------------

## A save written before NPC 2's, NPC 3's and NPC 5's conditions were registered
## holds their events but not the conditions. Loading it latches them on the sweep
## that follows every save binding, so NPC 4 shows at once.
func test_an_old_save_latches_the_talks_it_holds_on_load() -> void:
	_play_through(5)
	_meet_own_gate(4)
	var forget_the_talks := func(save: SaveGameData) -> void:
		for npc: int in [2, 3, 5]:
			save.unlock_progression.unlocked_condition_ids.erase(NPCS[npc])
	_reload_as_old_save(forget_the_talks)
	for npc: int in [2, 3, 5]:
		assert_true(UnlockManager.is_condition_unlocked(NPCS[npc]), "NPC %d's condition latches at load" % npc)
	assert_true(_is_available(4), "NPC 4 shows as soon as the save loads")

## A save from before NPC 5 existed, between NPC 3 and NPC 4: NPC 3 started Harden
## Your Core, whose goal latched at Core Density 10, and Temper Your Body never
## ran. It loads on Harden Your Core's return step. NPC 4 now waits for NPC 5,
## who shows at Strength Lv 2; that talk starts nothing new, and NPC 4 then
## completes the quest.
func test_an_old_save_between_npc_3_and_npc_4_meets_npc_5() -> void:
	_play_through(3)
	var as_before_npc_5 := func(save: SaveGameData) -> void:
		save.quest_progression.active_quests.erase(TEMPER_YOUR_BODY)
		save.quest_progression.active_quests[HARDEN_YOUR_CORE] = RETURN_TO_NPC_STEP
		save.core_density_level = 12.0
		save.unlock_progression.unlocked_condition_ids.append(TWO_STARS_CONDITION)
	_reload_as_old_save(as_before_npc_5)
	assert_eq(QuestManager.get_current_step_index(HARDEN_YOUR_CORE), RETURN_TO_NPC_STEP, "it loads on its step")
	assert_false(_is_available(5), "NPC 5 waits for Strength Lv 2")
	assert_false(_is_available(4), "NPC 4 waits for NPC 5's talk")
	assert_eq(DevCommands.set_stat_level(&"strength", 2), "", "precondition: Strength reaches Lv 2")
	assert_true(_is_available(5), "NPC 5 shows at Strength Lv 2")
	_talk_to(5)
	assert_eq(QuestManager.get_current_step_index(HARDEN_YOUR_CORE), RETURN_TO_NPC_STEP, "the talk leaves the quest where it was")
	assert_false(QuestManager.has_active_quest(TEMPER_YOUR_BODY), "and starts nothing")
	assert_false(QuestManager.has_completed_quest(TEMPER_YOUR_BODY))
	assert_true(_is_available(4), "NPC 4 shows")
	_talk_to(4)
	assert_true(QuestManager.has_completed_quest(HARDEN_YOUR_CORE), "NPC 4 completes it")
	assert_true(InventoryManager.has_item(MAP_ITEM_ID), "and gives the map")
