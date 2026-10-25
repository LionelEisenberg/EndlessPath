extends GutTest

## DevManager building save presets against the real managers: a preset plays the
## story route through its beat on a fresh save, then its own steps; a snapshot is
## copied, never shared; a built save records its preset and no play, and shows no
## NEW seals; nothing is written. A launch that names a preset builds it, and one
## whose preset is unknown or fails falls back to a fresh save in memory, never the
## user's save. Boot equivalence: the built state comes back whole from the save
## alone, as a launch on it would read it.
##
## The presets are SavePresetData objects made here. The tests that launch read them
## from a temp folder (preset_dir_override), so no shipped or exported preset is
## read. Each test binds a fresh in-memory save, starts from the real path tree,
## ability index, quest catalog and stages (other files swap in stubs), and gives
## everything it changed back afterwards, DevManager's session and the player's log
## included.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Kind = DevStepData.Kind
const SessionKind = DevManager.SessionKind

const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

## Every temp file and folder here starts with this. after_each() deletes them.
const TMP_PREFIX: String = "__test_dev_manager_build_"
## The folder the launch tests read their presets from.
const PRESET_DIR: String = "user://__test_dev_manager_build_presets/"
## Stands in for the user's own save in the fallback tests.
const MAIN_SAVE_PATH: String = "user://__test_dev_manager_build_main.tres"
const MAIN_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
save_version = 1
gold = 42.0
"""

const DEV_LINE: String = "[color=magenta][DEV][/color] "

## Opens once merchant_discovered fires, the last step of beat_3b.
const MERCHANT_ACTION: String = "spirit_valley_merchant"
## Locked on a fresh save: it needs Core Density 10.
const NPC_4: String = "celestial_intervener_dialogue_4"
## A technique no beat unlocks or equips.
const TORRENTIAL_FLOW: String = "torrential_flow"
## Latches at Core Density 10.
const REACH_CD_10: String = "q_reach_cd_10"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_main_save_path: String
var _original_tree: PathTreeData
var _original_stage_override: int
var _original_stages: Array[AdvancementStageResource]
var _original_history: Array[String]
var _original_session_kind: DevManager.SessionKind
var _original_session_preset: SavePresetData
var _original_preset_dir_override: String

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_main_save_path = PersistenceManager.main_save_path
	_original_tree = PathManager.get_current_tree()
	_original_stage_override = PathManager._test_stage_override
	_original_stages = CultivationManager.advancement_stage_resources
	_original_history = LogManager._history.duplicate()
	_original_session_kind = DevManager._session_kind
	_original_session_preset = DevManager._session_preset
	_original_preset_dir_override = DevManager.preset_dir_override
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	# The real state, whatever an earlier file left behind (as test_story_route.gd
	# does). The tree comes after the save, since binding a save drops the tree and
	# picks it up again from the trees PathManager holds. The override at -1 makes
	# PathManager read the player's stage.
	PathManager._current_tree = load(PURE_MADRA_TREE)
	PathManager._test_stage_override = -1
	AbilityManager._build_catalog_index()
	QuestManager._quest_catalog = load(QUEST_LIST)
	QuestManager._build_catalog_index()
	var stages: Array[AdvancementStageResource] = []
	stages.append(load(FOUNDATION_STAGE))
	stages.append(load(COPPER_STAGE))
	CultivationManager.advancement_stage_resources = stages
	DevManager.preset_dir_override = PRESET_DIR

func after_each() -> void:
	ActionManager.cancel_current_action()
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.main_save_path = _original_main_save_path
	PersistenceManager.use_save(_original_save, _original_save_path)
	PathManager._current_tree = _original_tree
	PathManager._test_stage_override = _original_stage_override
	LogManager._history = _original_history
	DevManager._session_kind = _original_session_kind
	DevManager._session_preset = _original_session_preset
	DevManager.preset_dir_override = _original_preset_dir_override
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()
	_remove_temp_files()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _step(kind: DevStepData.Kind, target_id: String = "", amount: float = 0.0) -> DevStepData:
	var step := DevStepData.new()
	step.kind = kind
	step.target_id = target_id
	step.amount = amount
	return step

## A preset that plays the route through `story_through` ("" for none), then `steps`.
func _preset(preset_id: String, story_through: String, steps: Array[DevStepData] = []) -> SavePresetData:
	var preset := SavePresetData.new()
	preset.preset_id = preset_id
	preset.title = "Test %s" % preset_id
	preset.story_through = story_through
	preset.steps = steps
	return preset

## Writes the preset into PRESET_DIR, where the launch tests find it.
func _write_preset(preset: SavePresetData, file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_DIR))
	assert_eq(ResourceSaver.save(preset, PRESET_DIR + file_name), OK, "precondition: %s is written" % file_name)

func _remove_temp_files() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PRESET_DIR)):
		for file_name: String in DirAccess.get_files_at(PRESET_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PRESET_DIR + file_name))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PRESET_DIR))
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(TMP_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))

## Points the session's main save at a temp file holding gold 42, standing in for
## the user's own save.
func _use_temp_main_save() -> void:
	var file := FileAccess.open(MAIN_SAVE_PATH, FileAccess.WRITE)
	file.store_string(MAIN_SAVE_TEXT)
	file.close()
	PersistenceManager.main_save_path = MAIN_SAVE_PATH

## True when some zone offers the action right now.
func _is_available(action_id: String) -> bool:
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			if action.action_id == action_id:
				return true
	return false

## The inventory as item id → how many: stacks of materials, quest items and
## consumables, and one per piece of equipment, in the grid or worn.
func _inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	var inventory: InventoryData = InventoryManager.get_inventory()
	for stacks: Dictionary in [inventory.materials, inventory.quest_items, inventory.consumables]:
		for item: ItemDefinitionData in stacks:
			counts[item.item_id] = counts.get(item.item_id, 0) + int(stacks[item])
	for pieces: Dictionary in [inventory.equipment, inventory.equipped_gear, inventory.equipped_accessories]:
		for key: Variant in pieces:
			var piece: ItemInstanceData = pieces[key]
			if piece != null and piece.item_definition != null:
				counts[piece.item_definition.item_id] = counts.get(piece.item_definition.item_id, 0) + 1
	return counts

## What the managers hold for the session, read through their public functions:
## the state a launch on the save comes up in.
func _digest() -> Dictionary:
	var purchases: Dictionary = {}
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree != null:
		for node: PathNodeData in tree.nodes:
			purchases[node.id] = PathManager.get_node_purchase_count(node.id)
	var active_quests: Dictionary = {}
	for quest_id: String in QuestManager.get_active_quest_ids():
		active_quests[quest_id] = QuestManager.get_current_step_index(quest_id)
	var available: Array[String] = []
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			available.append("%s/%s" % [zone.zone_id, action.action_id])
	var unlocked_abilities: Array[String] = []
	for ability: AbilityData in AbilityManager.get_unlocked_abilities():
		unlocked_abilities.append(ability.ability_id)
	var equipped_abilities: Array[String] = []
	for slot: int in AbilityManager.get_max_slots():
		equipped_abilities.append(AbilityManager.get_ability_at_slot(slot))
	var unlocked_techniques: Array[String] = []
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		unlocked_techniques.append(technique.id)
	var equipped_technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	var current_action: ZoneActionData = ActionManager.get_current_action()
	return {
		"core_density_level": CultivationManager.get_core_density_level(),
		"core_density_xp": CultivationManager.get_core_density_xp(),
		"stage": CultivationManager.get_current_advancement_stage(),
		"madra": ResourceManager.get_madra(),
		"gold": ResourceManager.get_gold(),
		"path_points": PathManager.get_point_balance(),
		"path_purchases": purchases,
		"active_quests": active_quests,
		"completed_quests": QuestManager.get_completed_quest_ids(),
		"triggered_events": EventManager.get_triggered_events(),
		"latched_conditions": UnlockManager.get_unlocked_condition_ids(),
		"available_actions": available,
		"unlocked_abilities": unlocked_abilities,
		"equipped_abilities": equipped_abilities,
		"unlocked_techniques": unlocked_techniques,
		"equipped_technique": equipped_technique.id if equipped_technique != null else "",
		"inventory": _inventory_counts(),
		"zone": ZoneManager.get_current_zone().zone_id,
		"action": current_action.action_id if current_action != null else "",
	}

#-----------------------------------------------------------------------------
# BUILDING
#-----------------------------------------------------------------------------

## The preset's own steps run after the route's: beat_1 sets Madra to 100, so
## Madra 5 shows the preset's step ran last.
func test_build_applies_the_route_then_the_steps() -> void:
	var preset := _preset("test_merchant", "beat_3b", [_step(Kind.SET_GOLD, "", 700.0), _step(Kind.SET_MADRA, "", 5.0)])
	assert_eq(DevManager.build_preset(preset), "", "the preset builds")
	assert_gte(CultivationManager.get_core_density_level(), 10.0, "beat_3b reached Core Density 10")
	assert_true(_is_available(MERCHANT_ACTION), "beat_3b opened the merchant")
	assert_eq(ResourceManager.get_gold(), 700.0, "the preset's own step set the gold")
	assert_eq(ResourceManager.get_madra(), 5.0, "the preset's steps ran after the route's")

func test_a_built_save_records_its_preset_and_no_play() -> void:
	var preset := _preset("test_merchant", "beat_3b", [_step(Kind.SET_GOLD, "", 700.0)])
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds")
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	assert_eq(stats.built_from_preset, "test_merchant", "the save names the preset it was built from")
	assert_eq(stats.play_time, 0.0)
	assert_eq(stats.cycles_finished, 0)
	assert_eq(stats.adventures_started, 0)
	assert_eq(stats.adventures_won, 0)
	assert_eq(stats.adventures_lost, 0)
	assert_eq(stats.adventures_timed_out, 0)
	assert_eq(stats.fights_won, 0)
	assert_eq(stats.gold_earned, 0.0)
	assert_true(stats.event_first_times.is_empty(), "no event counts as fired in play: %s" % [stats.event_first_times])
	assert_true(stats.condition_first_times.is_empty(), "no condition counts as latched in play: %s" % [stats.condition_first_times])
	assert_false(stats.recording_paused, "play after the build is recorded")

## A technique the preset unlocks and nothing equips, and every action the route
## opened, would each show NEW without the build marking them seen.
func test_a_built_save_shows_no_new_seals() -> void:
	var preset := _preset("test_seals", "beat_3b", [_step(Kind.UNLOCK_TECHNIQUE, TORRENTIAL_FLOW)])
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds")
	assert_true(CyclingManager.is_technique_unlocked(TORRENTIAL_FLOW), "precondition: the technique is unlocked")
	assert_ne(CyclingManager.get_equipped_technique().id, TORRENTIAL_FLOW, "precondition: and not equipped")
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			assert_true(ZoneManager.is_action_seen(action.action_id), "%s shows no NEW seal" % action.action_id)
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		assert_true(CyclingManager.is_technique_seen(technique.id), "%s shows no NEW seal" % technique.id)

func test_a_failing_step_names_itself() -> void:
	var preset := _preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)])
	var failure: String = DevManager.build_preset(preset)
	assert_string_contains(failure, NPC_4)
	assert_string_contains(failure, "not available")

## validate() runs first: steps_through() gives no steps for a beat the route does
## not have, which would otherwise build a fresh game without a word.
func test_a_preset_that_does_not_validate_is_refused() -> void:
	var save_before: SaveGameData = PersistenceManager.save_game_data
	var refusal: String = DevManager.build_preset(_preset("test_unknown_beat", "no_such_beat"))
	assert_string_contains(refusal, "no_such_beat")
	assert_same(PersistenceManager.save_game_data, save_before, "nothing is built: the session keeps its save")

func test_a_snapshot_is_copied_not_shared() -> void:
	var snapshot := SaveGameData.new_current()
	snapshot.gold = 5.0
	var preset := _preset("test_snapshot", "")
	preset.snapshot = snapshot
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds")
	assert_eq(ResourceManager.get_gold(), 5.0, "the session starts from the snapshot")
	assert_not_same(PersistenceManager.save_game_data, snapshot, "the session plays a copy")
	ResourceManager.set_gold(99.0)
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds again")
	assert_eq(ResourceManager.get_gold(), 5.0, "a second build starts from the snapshot as it was")
	assert_eq(snapshot.gold, 5.0, "the preset's snapshot is never changed")
	assert_eq(snapshot.stats.built_from_preset, "", "its sub-resources are copied too, not shared")

## A snapshot can meet a condition it never latched: one added to the game after
## it was saved, say. Binding the copy latches it, which is the build's doing, not
## a first time of play.
func test_binding_a_snapshot_records_no_first_time() -> void:
	var snapshot := SaveGameData.new_current()
	snapshot.core_density_level = 10.0
	var preset := _preset("test_unlatched_snapshot", "")
	preset.snapshot = snapshot
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds")
	assert_true(UnlockManager.is_condition_unlocked(REACH_CD_10), "precondition: binding the copy latched the condition")
	var first_times: Dictionary[String, float] = PersistenceManager.save_game_data.stats.condition_first_times
	assert_true(first_times.is_empty(), "the latch is not recorded as play: %s" % [first_times])

func test_a_snapshot_is_migrated() -> void:
	var snapshot := SaveGameData.new()
	snapshot.current_selected_zone_id = "TestZone"
	assert_eq(snapshot.save_version, 0, "precondition: an old save's version")
	var preset := _preset("test_old_snapshot", "")
	preset.snapshot = snapshot
	assert_eq(DevManager.build_preset(preset), "", "precondition: the preset builds")
	assert_eq(PersistenceManager.save_game_data.save_version, SaveGameData.CURRENT_VERSION, "the copy is migrated, which stamps it")
	assert_eq(ZoneManager.get_current_zone().zone_id, "SpiritValley", "migrate() moves it off the hidden Test Zone")
	assert_eq(snapshot.save_version, 0, "the snapshot itself is left as it was")

func test_building_writes_nothing() -> void:
	assert_eq(DevManager.build_preset(_preset("test_in_memory", "beat_1")), "", "precondition: the preset builds")
	assert_true(PersistenceManager.is_in_memory(), "a preset built with no save path lives in memory")
	assert_eq(PersistenceManager.save_data(), ERR_UNAVAILABLE, "there is no file to write")

#-----------------------------------------------------------------------------
# PRESET FOLDERS
#-----------------------------------------------------------------------------

func test_presets_come_from_the_folder_sorted_by_title() -> void:
	var zeta := _preset("zeta", "")
	zeta.title = "Zeta"
	var alpha := _preset("alpha", "")
	alpha.title = "Alpha"
	# Named in the other order, so only a sort by title puts Alpha first.
	_write_preset(zeta, "a_zeta.tres")
	_write_preset(alpha, "b_alpha.tres")
	assert_eq(ResourceSaver.save(SaveGameData.new_current(), PRESET_DIR + "c_not_a_preset.tres"), OK, "precondition: a resource that is no preset")
	var titles: Array[String] = []
	for preset: SavePresetData in DevManager.get_presets():
		titles.append(preset.title)
	assert_eq(titles, ["Alpha", "Zeta"] as Array[String], "every preset file, sorted by title, and nothing else")
	var found: SavePresetData = DevManager.find_preset("zeta")
	assert_not_null(found)
	if found != null:
		assert_eq(found.title, "Zeta")
	assert_null(DevManager.find_preset("no_such_preset"))

#-----------------------------------------------------------------------------
# LAUNCHING
#-----------------------------------------------------------------------------

func test_a_preset_launch_starts_the_preset() -> void:
	var preset := _preset("test_launch", "", [_step(Kind.SET_GOLD, "", 321.0)])
	preset.title = "Launch test"
	_write_preset(preset, "launch_test.tres")
	watch_signals(DevManager)
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--preset=test_launch"])))
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset, "the session knows its preset")
	if session_preset != null:
		assert_eq(session_preset.preset_id, "test_launch")
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset was built")
	assert_true(PersistenceManager.is_in_memory(), "with no --save the session lives in memory")
	assert_eq(LogManager.get_history(), [DEV_LINE + "Started preset 'Launch test'"] as Array[String],
		"the log starts clean, with one line naming the preset")
	assert_signal_emit_count(DevManager, "session_changed", 1)

func test_a_pinned_launch_says_so() -> void:
	var preset := _preset("test_pinned", "")
	preset.title = "Pinned test"
	_write_preset(preset, "pinned_test.tres")
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(), "test_pinned"))
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	assert_eq(LogManager.get_history(), [DEV_LINE + "Started preset 'Pinned test' (pinned)"] as Array[String])

## PersistenceManager.boot() already opened the session's file; DevManager only
## names the kind.
func test_a_launch_without_a_preset_builds_nothing() -> void:
	var save_before: SaveGameData = PersistenceManager.save_game_data
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--save=user://%sfile.tres" % TMP_PREFIX])))
	assert_eq(DevManager.get_session_kind(), SessionKind.FILE, "--save alone is a file session")
	assert_null(DevManager.get_session_preset())
	DevManager.start_from_launch_options(LaunchOptions.new())
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "no option plays your save")
	assert_null(DevManager.get_session_preset())
	assert_same(PersistenceManager.save_game_data, save_before, "the session keeps the save boot opened")

func test_an_unknown_preset_falls_back_to_a_fresh_save_in_memory() -> void:
	_use_temp_main_save()
	PersistenceManager.save_game_data.gold = 7.0
	var options := LaunchOptions.new()
	options.preset_id = "no_such_preset"
	DevManager.start_from_launch_options(options)
	assert_true(PersistenceManager.is_in_memory(), "the session lives in memory")
	assert_eq(ResourceManager.get_gold(), 0.0, "on a fresh save, with the default gold")
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "the main save is never read or written")
	assert_null(DevManager.get_session_preset(), "there is no preset to restart")
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "the log starts clean, with one line")
	if history.size() == 1:
		assert_string_contains(history[0], "no_such_preset", "the line names the preset that did not start")

func test_a_failed_build_falls_back_to_a_fresh_save_in_memory() -> void:
	_use_temp_main_save()
	var preset := _preset("test_failing_launch", "", [_step(Kind.SET_GOLD, "", 700.0), _step(Kind.COMPLETE_ACTION, NPC_4)])
	_write_preset(preset, "failing_launch.tres")
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--preset=test_failing_launch"])))
	assert_true(PersistenceManager.is_in_memory(), "the session lives in memory")
	assert_eq(ResourceManager.get_gold(), 0.0, "the half-built save gives way to a fresh one")
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "the main save is never read or written")
	assert_null(DevManager.get_session_preset(), "there is no preset to restart")
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "the half build's lines are cleared, and one line says why")
	if history.size() == 1:
		assert_string_contains(history[0], "test_failing_launch")
		assert_string_contains(history[0], "not available")

#-----------------------------------------------------------------------------
# BOOT EQUIVALENCE
#-----------------------------------------------------------------------------

## A restart builds the preset in place; a launch on the save would read it back
## from the file. Both must leave the managers in the same state, so nothing the
## build sets lives outside the save.
func test_a_restart_matches_a_launch() -> void:
	assert_eq(DevManager.build_preset(_preset("test_restart", "beat_3b")), "", "precondition: the preset builds")
	var built: Dictionary = _digest()
	var path: String = "user://%srestart.tres" % TMP_PREFIX
	assert_eq(SaveFiles.write_atomically(PersistenceManager.save_game_data, path), OK, "precondition: the built save is written")
	var loaded: SaveGameData = SaveFiles.load_save(path)
	assert_not_null(loaded, "precondition: the written save loads")
	if loaded == null:
		return
	PersistenceManager.use_save(loaded, "")
	assert_same(PersistenceManager.save_game_data, loaded, "precondition: the session plays the loaded save")
	assert_eq_deep(_digest(), built)
