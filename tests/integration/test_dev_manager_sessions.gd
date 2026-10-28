extends GutTest

## DevManager switching sessions while the game runs, against the real managers:
## playing a preset, a jump through a story beat, restarting the preset, going back
## to your save, a new game, keeping a session as your save and restoring a backup.
## A switch runs on the next frame, so the panel button that asks for it has
## returned before the main scene that holds it is freed. It saves the session it
## leaves when autosave is on, tears down what lives outside the save (the running
## action and any dialogue, the cycle, the vitals, a hit-stop's time scale), binds
## the new session and starts the player's log again with one line. A switch that
## is refused changes nothing; a build that fails brings the session back it left.
## A switch asked for while another is pending is refused, so a double click never
## runs two. Under GUT the current scene is the runner, so no scene is unloaded or
## reloaded.
## The time speed, the base time scale a switch keeps, is tested here too.
##
## The tests that need your save point PersistenceManager's main save and backup
## folder at temp paths, so the real save and its backups are never read or
## written. The presets are SavePresetData objects made here; the launch tests read
## theirs from a temp folder (preset_dir_override). Each test binds a fresh
## in-memory save, starts from the real path tree, ability index, quest catalog and
## stages (other files swap in stubs), and gives everything it changed back
## afterwards: the save and its paths, autosave, the time scale, the player's log
## and DevManager's session.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const Kind = DevStepData.Kind
const SessionKind = DevManager.SessionKind

const PURE_MADRA_TREE: String = "res://resources/path_progression/pure_madra/pure_madra_tree.tres"
const QUEST_LIST: String = "res://resources/quests/quest_list.tres"
const FOUNDATION_STAGE: String = "res://resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres"
const COPPER_STAGE: String = "res://resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres"

## The prefix of a [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## Every temp file and folder here starts with this. after_each() deletes them.
const TMP_PREFIX: String = "__test_dev_manager_sessions_"
## The folder the launch tests read their presets from.
const PRESET_DIR: String = "user://__test_dev_manager_sessions_presets/"
## Where the main save's backups go while a test points the main save at its temp file.
const BACKUP_DIR: String = "user://__test_dev_manager_sessions_backups/"
## Stands in for the user's own save.
const MAIN_SAVE_PATH: String = "user://__test_dev_manager_sessions_main.tres"
## The --save path the launch tests start with.
const SAVE_OPTION_PATH: String = "user://__test_dev_manager_sessions_option.tres"
## A file where a folder would go: a backup folder under it cannot be made.
const BLOCKER_PATH: String = "user://__test_dev_manager_sessions_blocker"
## A backup to restore that lives outside the backup folder.
const SPARE_BACKUP_PATH: String = "user://__test_dev_manager_sessions_spare.tres"
const MAIN_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
save_version = 1
gold = 42.0
"""

## A switch runs on the next frame. Two frames leave it done.
const SWITCH_FRAMES: int = 2
## Why a switch asked for while another is pending is refused.
const SWITCH_UNDER_WAY: String = "A session switch is already under way"

const ZONE_ID: String = "SpiritValley"
const FORAGING_ID: String = "sprint_forest_foraging_action"
## Fired when q_fill_core completes. It unlocks foraging, which then starts on its
## own (the first idle action to unlock does).
const FORAGING_EVENT: String = "q_fill_core_completed"
## NPC 1, available on a fresh save: a dialogue used up after one completion.
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
## The event NPC 1's success effects fire.
const DIALOGUE_EVENT: String = "celestial_intervener_dialogue_1"
## Locked on a fresh save: it needs Core Density 10.
const NPC_4: String = "celestial_intervener_dialogue_4"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_main_save_path: String
var _original_backup_dir: String
var _original_autosave: bool
var _original_tree: PathTreeData
var _original_stage_override: int
var _original_stages: Array[AdvancementStageResource]
var _original_history: Array[String]
var _original_session_kind: DevManager.SessionKind
var _original_session_preset: SavePresetData
var _original_preset_dir_override: String
var _original_last_switch_failure: String

## The pid of the helper process standing in for another run, or 0.
var _helper_pid: int = 0

## What get_last_switch_failure() returned each time session_switch_failed was
## emitted, while _on_switch_failed() is connected.
var _failures_when_emitted: Array[String] = []

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_main_save_path = PersistenceManager.main_save_path
	_original_backup_dir = PersistenceManager.backup_dir
	_original_autosave = PersistenceManager.autosave_enabled
	_original_tree = PathManager.get_current_tree()
	_original_stage_override = PathManager._test_stage_override
	_original_stages = CultivationManager.advancement_stage_resources
	_original_history = LogManager._history.duplicate()
	_original_session_kind = DevManager._session_kind
	_original_session_preset = DevManager._session_preset
	_original_preset_dir_override = DevManager.preset_dir_override
	_original_last_switch_failure = DevManager._last_switch_failure
	_failures_when_emitted.clear()
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
	DevManager._session_kind = SessionKind.YOUR_SAVE
	DevManager._session_preset = null
	DevManager._last_switch_failure = ""

func after_each() -> void:
	if _helper_pid > 0:
		OS.kill(_helper_pid)
		_helper_pid = 0
	if DevManager.session_switch_failed.is_connected(_on_switch_failed):
		DevManager.session_switch_failed.disconnect(_on_switch_failed)
	ActionManager.cancel_current_action()
	DialogueManager.end_dialogue_now()
	GameSpeed.set_base_scale(1.0)
	CultivationManager.advancement_stage_resources = _original_stages
	PersistenceManager.autosave_enabled = _original_autosave
	PersistenceManager.main_save_path = _original_main_save_path
	PersistenceManager.backup_dir = _original_backup_dir
	PersistenceManager.use_save(_original_save, _original_save_path)
	PathManager._current_tree = _original_tree
	PathManager._test_stage_override = _original_stage_override
	LogManager._history = _original_history
	DevManager._session_kind = _original_session_kind
	DevManager._session_preset = _original_session_preset
	DevManager.preset_dir_override = _original_preset_dir_override
	DevManager._last_switch_failure = _original_last_switch_failure
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

func _remove_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + file_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

## Deletes every temp file (the saves, their temp files and locks) and both folders.
func _remove_temp_files() -> void:
	_remove_folder(PRESET_DIR)
	_remove_folder(BACKUP_DIR)
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(TMP_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))

## Starts the session on a temp file holding gold 42, standing in for your save:
## the main save and its backup folder point at temp paths, and the file is opened
## as a launch on your save opens it.
func _start_on_temp_main_save() -> void:
	var file := FileAccess.open(MAIN_SAVE_PATH, FileAccess.WRITE)
	file.store_string(MAIN_SAVE_TEXT)
	file.close()
	PersistenceManager.main_save_path = MAIN_SAVE_PATH
	PersistenceManager.backup_dir = BACKUP_DIR
	PersistenceManager.open_save_file(MAIN_SAVE_PATH)
	DevManager._session_kind = SessionKind.YOUR_SAVE
	DevManager._session_preset = null
	assert_eq(ResourceManager.get_gold(), 42.0, "precondition: the session plays the temp main save")

## Writes the temp main save's file again, holding this gold. The session keeps
## what it loaded.
func _write_main_save_with_gold(gold: float) -> void:
	var file := FileAccess.open(MAIN_SAVE_PATH, FileAccess.WRITE)
	file.store_string(MAIN_SAVE_TEXT.replace("gold = 42.0", "gold = %.1f" % gold))
	file.close()

## Points the backups at a folder that cannot be made, because a file has its
## parent's name, so backing up your save fails.
func _block_backups() -> void:
	var file := FileAccess.open(BLOCKER_PATH, FileAccess.WRITE)
	file.store_string("A file, not a folder")
	file.close()
	PersistenceManager.backup_dir = BLOCKER_PATH + "/backups/"

## Starts a helper process that lives for about five seconds, as another run does,
## and writes the lock it holds on the save at `path`. after_each() kills it.
func _lock_as_another_run(path: String) -> void:
	if OS.get_name() == "Windows":
		_helper_pid = OS.create_process("ping", ["-n", "6", "127.0.0.1"])
	else:
		_helper_pid = OS.create_process("sleep", ["5"])
	assert_gt(_helper_pid, 0, "precondition: the helper process started")
	var file := FileAccess.open(SaveLock.lock_path_for(path), FileAccess.WRITE)
	file.store_string("pid=%d\ntime=%d\n" % [_helper_pid, int(Time.get_unix_time_from_system())])
	file.close()

## The gold of the save on disk at `path`, read again from the file, or -1.0 when
## nothing there loads.
func _gold_in_file(path: String) -> float:
	var loaded: SaveGameData = SaveFiles.load_save(path)
	return -1.0 if loaded == null else loaded.gold

func _current_action_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current != null else ""

func _completions_in(save: SaveGameData, action_id: String) -> int:
	return save.get_zone_progression_data(ZONE_ID).action_completion_count.get(action_id, 0)

## The reason the last session_switch_failed carried, or "" when it was not emitted.
func _failure_reason() -> String:
	var parameters: Variant = get_signal_parameters(DevManager, "session_switch_failed")
	return String(parameters[0]) if parameters != null else ""

func _on_switch_failed(_reason: String) -> void:
	_failures_when_emitted.append(DevManager.get_last_switch_failure())

## Waits until Dialogic's late timeline_ended has reached DialogueManager (watched),
## or a second has passed.
func _wait_for_the_dialogue_end() -> void:
	await wait_until(func() -> bool: return get_signal_emit_count(DialogueManager, "dialogue_ended") > 0, 1.0)

#-----------------------------------------------------------------------------
# PLAYING AND RESTARTING A PRESET
#-----------------------------------------------------------------------------

## Review Focus 1: a panel button's handler lives in the scene a switch frees, so
## nothing switches until the caller has returned.
func test_play_preset_switches_on_the_next_frame() -> void:
	ResourceManager.set_gold(7.0)
	var save_before: SaveGameData = PersistenceManager.save_game_data
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_play", "", [_step(Kind.SET_GOLD, "", 321.0)]))
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "nothing switches while the caller still runs")
	assert_eq(ResourceManager.get_gold(), 7.0, "the session keeps its gold until the switch runs")
	assert_same(PersistenceManager.save_game_data, save_before, "and its save")
	assert_signal_not_emitted(DevManager, "session_changed")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "the preset is the session on the next frame")
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset, "the session knows its preset")
	if session_preset != null:
		assert_eq(session_preset.preset_id, "test_play")
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset was built")
	assert_true(PersistenceManager.is_in_memory(), "a preset played in game lives in memory")
	assert_signal_emit_count(DevManager, "session_changed", 1)
	assert_signal_not_emitted(DevManager, "session_switch_failed")

func test_play_story_through_plays_an_unnamed_preset() -> void:
	DevManager.play_story_through("beat_1")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset, "the jump is a preset session, so a restart replays it")
	if session_preset != null:
		assert_eq(session_preset.preset_id, "story_through_beat_1")
		assert_eq(session_preset.title, "Story through Awakening", "named after the beat's title")
		assert_eq(session_preset.story_through, "beat_1")
	assert_true(EventManager.has_event_triggered(FORAGING_EVENT), "the route ran through beat_1")
	assert_eq(_current_action_id(), FORAGING_ID, "and the foraging it opens runs, as after a launch")

func test_restart_rebuilds_the_preset() -> void:
	var preset := _preset("test_restart", "", [_step(Kind.SET_GOLD, "", 321.0)])
	DevManager.play_preset(preset)
	await wait_process_frames(SWITCH_FRAMES)
	var first_save: SaveGameData = PersistenceManager.save_game_data
	ResourceManager.set_gold(5.0)
	DevManager.restart_preset()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset is built again from the start")
	assert_not_same(PersistenceManager.save_game_data, first_save, "on a new save")
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	assert_same(DevManager.get_session_preset(), preset, "the same preset")
	assert_true(PersistenceManager.is_in_memory(), "a preset played in game restarts in memory")

func test_restart_outside_a_preset_does_nothing() -> void:
	ResourceManager.set_gold(7.0)
	var save_before: SaveGameData = PersistenceManager.save_game_data
	watch_signals(DevManager)
	DevManager.restart_preset()
	await wait_process_frames(SWITCH_FRAMES)
	assert_same(PersistenceManager.save_game_data, save_before, "the session keeps its save")
	assert_eq(ResourceManager.get_gold(), 7.0)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_signal_not_emitted(DevManager, "session_changed")
	assert_signal_not_emitted(DevManager, "session_switch_failed", "doing nothing is not a failure")

## A preset launched with --save writes that file, and its restart keeps writing it.
func test_a_restart_keeps_the_sessions_save_path() -> void:
	_write_preset(_preset("test_launch_restart", "", [_step(Kind.SET_GOLD, "", 321.0)]), "launch_restart.tres")
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--preset=test_launch_restart", "--save=" + SAVE_OPTION_PATH])))
	assert_eq(PersistenceManager.save_path, SAVE_OPTION_PATH, "precondition: the launch plays the preset on its --save file")
	ResourceManager.set_gold(5.0)
	DevManager.restart_preset()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset is built again")
	assert_eq(PersistenceManager.save_path, SAVE_OPTION_PATH, "on the --save file the session writes")

## The fallback a failed launch plays lives in memory, whatever --save named, and
## so does its restart.
func test_the_fallback_restarts_in_memory() -> void:
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--preset=no_such_preset", "--save=" + SAVE_OPTION_PATH])))
	assert_true(PersistenceManager.is_in_memory(), "precondition: the fallback lives in memory")
	DevManager.restart_preset()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset)
	if session_preset != null:
		assert_eq(session_preset.preset_id, DevManager.FALLBACK_PRESET_ID, "the fallback was restarted")
	assert_true(PersistenceManager.is_in_memory(), "still in memory")
	assert_false(FileAccess.file_exists(SAVE_OPTION_PATH), "the --save file is never written")

#-----------------------------------------------------------------------------
# TEARDOWN
#-----------------------------------------------------------------------------

## Unlocking foraging starts it, so the test switches during that run: a
## select_action() of its own would stop it first and count that stop.
func test_switching_cancels_the_running_action_without_counting() -> void:
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_action_id(), FORAGING_ID, "precondition: unlocking foraging starts it")
	var left_save: SaveGameData = PersistenceManager.save_game_data
	watch_signals(ActionManager)
	DevManager.play_preset(_preset("test_cancel", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(ActionManager, "stop_foraging", 1, "foraging stops")
	assert_eq(_completions_in(left_save, FORAGING_ID), 0, "and counts no completion in the save it left")
	assert_eq(_current_action_id(), "", "nothing runs on a fresh build")
	assert_true(ActionManager.action_timer.is_stopped(), "the forage timer stopped")

## Review Focus 2 across a switch: Dialogic's timeline_ended for the dialogue the
## switch cancelled arrives a frame late, once the next session runs. It must not
## stop that session's action, nor count anything.
func test_switching_mid_dialogue_leaves_the_next_session_running() -> void:
	ActionManager.select_action(ZoneManager.get_action_by_id(DIALOGUE_ID))
	assert_eq(_current_action_id(), DIALOGUE_ID, "precondition: the dialogue runs")
	var begun: bool = await wait_until(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	assert_true(begun, "precondition: Dialogic plays the dialogue's timeline")
	var left_save: SaveGameData = PersistenceManager.save_game_data
	watch_signals(DialogueManager)
	DevManager.play_preset(_preset("test_after_dialogue", "beat_1"))
	await wait_process_frames(SWITCH_FRAMES)
	await _wait_for_the_dialogue_end()
	assert_signal_emitted(DialogueManager, "dialogue_ended", "Dialogic's timeline_ended came after the switch")
	assert_eq(_current_action_id(), FORAGING_ID, "the new session's foraging still runs")
	assert_eq(_completions_in(PersistenceManager.save_game_data, FORAGING_ID), 0, "and counts nothing")
	assert_eq(_completions_in(left_save, DIALOGUE_ID), 0, "the dialogue counts no completion in the save it left")
	assert_false(left_save.event_progression.triggered_events.has(DIALOGUE_EVENT), "and runs none of its effects there")
	assert_null(Dialogic.current_timeline, "the dialogue does not play on")

## A dialogue an adventure encounter starts belongs to no action, so cancelling the
## action does not end it. The switch ends it, or it would play on over the new
## session.
func test_switching_ends_a_dialogue_no_action_started() -> void:
	var dialogue: NpcDialogueActionData = ZoneManager.get_action_by_id(DIALOGUE_ID) as NpcDialogueActionData
	DialogueManager.start_timeline(dialogue.dialogue_timeline_name)
	var begun: bool = await wait_until(func() -> bool: return Dialogic.current_timeline != null, 1.0)
	assert_true(begun, "precondition: Dialogic plays the timeline")
	assert_null(ActionManager.get_current_action(), "precondition: no action started it")
	watch_signals(DialogueManager)
	DevManager.play_preset(_preset("test_encounter_dialogue", ""))
	await wait_process_frames(SWITCH_FRAMES)
	await _wait_for_the_dialogue_end()
	assert_eq(DialogueManager.current_timeline_name, "", "the dialogue is forgotten")
	assert_null(Dialogic.current_timeline, "and does not play on into the new session")

func test_teardown_clears_the_runtime_state() -> void:
	CyclingManager.start_cycle_session(10.0)
	CyclingManager.set_last_cycle_result(CycleResult.new())
	var old_vitals: VitalsManager = PlayerManager.vitals_manager
	DevManager.play_preset(_preset("test_runtime", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_false(CyclingManager.is_cycle_running(), "the cycle session ended")
	assert_null(CyclingManager.get_last_cycle_result(), "and the last cycle's result is forgotten")
	assert_not_same(PlayerManager.vitals_manager, old_vitals, "the player gets fresh vitals")

## Review Focus 3: a boss hit-stop sets the time scale to 0.25 and restores it from
## the adventure tilemap, which a switch frees mid-way.
func test_teardown_restores_the_time_scale() -> void:
	Engine.time_scale = 0.25
	DevManager.play_preset(_preset("test_time", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(Engine.time_scale, 1.0, "time runs at full speed again")

## It goes back to the game's base speed, not to 1.0.
func test_teardown_returns_to_the_base_scale() -> void:
	GameSpeed.set_base_scale(2.0)
	assert_eq(Engine.time_scale, 2.0, "precondition: the engine runs at the base scale")
	Engine.time_scale = 0.5
	DevManager.play_preset(_preset("test_base_scale", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(Engine.time_scale, 2.0, "time runs at the base speed again")

func test_the_log_starts_clean() -> void:
	LogManager.log_message("A line from before the switch")
	var preset := _preset("test_log", "", [_step(Kind.SET_GOLD, "", 321.0)])
	preset.title = "Log test"
	DevManager.play_preset(preset)
	await wait_process_frames(SWITCH_FRAMES)
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "the log holds one line: %s" % [history])
	if history.size() == 1:
		assert_string_contains(history[0], "Log test", "naming the preset")

#-----------------------------------------------------------------------------
# YOUR SAVE
#-----------------------------------------------------------------------------

## Autosave is off here, as in every test run, so what was never saved is gone.
func test_back_to_my_save_reopens_it() -> void:
	_start_on_temp_main_save()
	ResourceManager.set_gold(55.0)
	DevManager.play_preset(_preset("test_away", "", [_step(Kind.SET_GOLD, "", 321.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "precondition: the preset is the session")
	DevManager.back_to_my_save()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_null(DevManager.get_session_preset())
	assert_eq(ResourceManager.get_gold(), 42.0, "your save comes back from disk")
	assert_eq(PersistenceManager.save_path, MAIN_SAVE_PATH, "and is the file the session writes")

## Test runs turn autosave off, so only this test reaches the save a switch makes
## on its way out.
func test_leaving_your_save_saves_it_first() -> void:
	_start_on_temp_main_save()
	PersistenceManager.autosave_enabled = true
	ResourceManager.set_gold(55.0)
	DevManager.play_preset(_preset("test_leave", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "precondition: the switch happened")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 55.0, "your save was written on the way out")

## Review Focus 4: the session returns to your save, which holds what it held.
func test_a_failed_build_returns_to_your_save_untouched() -> void:
	_start_on_temp_main_save()
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1)
	assert_string_contains(_failure_reason(), NPC_4, "the reason names the step")
	assert_string_contains(_failure_reason(), "not available")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "the session is your save again")
	assert_eq(ResourceManager.get_gold(), 42.0, "holding what it held")
	assert_eq(PersistenceManager.save_path, MAIN_SAVE_PATH)
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 42.0, "the file too")
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "which was never written")
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "the half build's lines are cleared, and one line says what happened: %s" % [history])
	if history.size() == 1:
		assert_string_contains(history[0], "not available")
		assert_string_contains(history[0], "your save")
	assert_signal_emit_count(DevManager, "session_changed", 1)

func test_a_failed_build_rebuilds_the_preset_it_left() -> void:
	var left_preset := _preset("test_left", "", [_step(Kind.SET_GOLD, "", 321.0)])
	left_preset.title = "Left behind"
	DevManager.play_preset(left_preset)
	await wait_process_frames(SWITCH_FRAMES)
	ResourceManager.set_gold(5.0)
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	assert_same(DevManager.get_session_preset(), left_preset, "the preset it left is the session again")
	assert_eq(ResourceManager.get_gold(), 321.0, "built again from the start")
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "one line says what happened: %s" % [history])
	if history.size() == 1:
		assert_string_contains(history[0], "Left behind")

## In a real run a failed switch emits session_switch_failed while the main scene,
## and the dev panel in it, is freed, so the panel built next reads the reason.
func test_the_last_failure_is_kept_for_the_panel() -> void:
	DevManager.session_switch_failed.connect(_on_switch_failed)
	DevManager.play_preset(_preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_string_contains(DevManager.get_last_switch_failure(), NPC_4, "the failed build's reason is kept")
	assert_string_contains(DevManager.get_last_switch_failure(), "not available")
	assert_eq(_failures_when_emitted.size(), 1, "precondition: the failure was emitted")
	if _failures_when_emitted.size() == 1:
		assert_string_contains(_failures_when_emitted[0], NPC_4, "it is kept before the signal goes out")
	DevManager.play_preset(_preset("test_works", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "precondition: the next switch worked")
	assert_eq(DevManager.get_last_switch_failure(), "", "a switch that works clears it")

func test_a_failed_build_reopens_the_file_it_left() -> void:
	var file := FileAccess.open(SAVE_OPTION_PATH, FileAccess.WRITE)
	file.store_string(MAIN_SAVE_TEXT)
	file.close()
	PersistenceManager.open_save_file(SAVE_OPTION_PATH)
	DevManager._session_kind = SessionKind.FILE
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1)
	assert_eq(DevManager.get_session_kind(), SessionKind.FILE, "the file is the session again")
	assert_eq(PersistenceManager.save_path, SAVE_OPTION_PATH)
	assert_eq(ResourceManager.get_gold(), 42.0, "opened again from disk")

## A test run's own save lives in memory, with no main save to open again.
func test_a_failed_build_with_no_way_back_plays_a_fresh_game() -> void:
	ResourceManager.set_gold(7.0)
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_failing", "", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1, "once, for the build")
	assert_string_contains(_failure_reason(), NPC_4)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset)
	if session_preset != null:
		assert_eq(session_preset.preset_id, DevManager.FALLBACK_PRESET_ID, "the fresh fallback preset")
	assert_true(PersistenceManager.is_in_memory(), "in memory")
	assert_eq(ResourceManager.get_gold(), 0.0, "a fresh game")
	var history: Array[String] = LogManager.get_history()
	assert_eq(history.size(), 1, "one line says what happened: %s" % [history])
	if history.size() == 1:
		assert_string_contains(history[0], "fresh game")

func test_new_game_backs_up_first() -> void:
	_start_on_temp_main_save()
	DevManager.new_game()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_eq(ResourceManager.get_gold(), 0.0, "a new game")
	assert_eq(PersistenceManager.save_path, MAIN_SAVE_PATH, "on your save")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 0.0, "written at once")
	var backups: PackedStringArray = PersistenceManager.list_backups()
	assert_eq(backups.size(), 1, "the old save was backed up")
	if backups.size() == 1:
		assert_eq(_gold_in_file(backups[0]), 42.0, "the backup holds the old save")

func test_keep_as_my_save_writes_the_session() -> void:
	_start_on_temp_main_save()
	DevManager.play_preset(_preset("test_keep", "", [_step(Kind.SET_GOLD, "", 700.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	var preset_save: SaveGameData = PersistenceManager.save_game_data
	DevManager.keep_as_my_save()
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_null(DevManager.get_session_preset())
	assert_eq(ResourceManager.get_gold(), 700.0, "the session plays on")
	assert_not_same(PersistenceManager.save_game_data, preset_save, "on a copy of the preset's save")
	assert_eq(PersistenceManager.save_path, MAIN_SAVE_PATH, "which is your save")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 700.0, "written at once")
	var backups: PackedStringArray = PersistenceManager.list_backups()
	assert_eq(backups.size(), 1, "the old save was backed up")
	if backups.size() == 1:
		assert_eq(_gold_in_file(backups[0]), 42.0, "the backup holds the old save")

func test_restore_backup_brings_it_back() -> void:
	_start_on_temp_main_save()
	var backup: String = PersistenceManager.backup_main_save()
	assert_ne(backup, "", "precondition: a backup of the save with gold 42")
	ResourceManager.set_gold(5.0)
	assert_eq(PersistenceManager.save_data(), OK, "precondition: your save now holds gold 5")
	DevManager.restore_backup(backup)
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_eq(ResourceManager.get_gold(), 42.0, "the session plays the backup")
	assert_eq(PersistenceManager.save_path, MAIN_SAVE_PATH, "as your save")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 42.0, "which is on disk again")
	var backups: PackedStringArray = PersistenceManager.list_backups()
	assert_eq(backups.size(), 2, "the save it replaced was backed up first")
	if backups.size() == 2:
		assert_eq(_gold_in_file(backups[0]), 5.0, "the newest backup holds the save it replaced")
	assert_eq(_gold_in_file(backup), 42.0, "the restored backup stays as it was")

## Backing up your save rotates the oldest backups away once BACKUPS_KEPT are kept,
## which is the steady state, and the oldest is the one being restored.
func test_restoring_the_oldest_of_a_full_backup_folder() -> void:
	_start_on_temp_main_save()
	for gold: int in range(100, 100 + PersistenceManager.BACKUPS_KEPT):
		_write_main_save_with_gold(gold)
		assert_ne(PersistenceManager.backup_main_save(), "", "precondition: a backup with gold %d" % gold)
	_write_main_save_with_gold(42.0)
	var backups: PackedStringArray = PersistenceManager.list_backups()
	assert_eq(backups.size(), PersistenceManager.BACKUPS_KEPT, "precondition: the backup folder is full")
	var oldest: String = backups[backups.size() - 1]
	assert_eq(_gold_in_file(oldest), 100.0, "precondition: the oldest backup holds gold 100")
	watch_signals(DevManager)
	DevManager.restore_backup(oldest)
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_not_emitted(DevManager, "session_switch_failed")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_eq(ResourceManager.get_gold(), 100.0, "the session plays the oldest backup")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 100.0, "which is your save on disk")
	var after: PackedStringArray = PersistenceManager.list_backups()
	assert_eq(after.size(), PersistenceManager.BACKUPS_KEPT, "the folder keeps its newest backups")
	if not after.is_empty():
		assert_eq(_gold_in_file(after[0]), 42.0, "the newest holds the save the restore replaced")

## A switch that writes your save takes its lock when it is asked for. One that
## fails before it binds your save gives the lock back, or the lock would keep the
## user's other runs off the save for up to a minute.
func test_a_switch_that_fails_before_binding_your_save_gives_its_lock_back() -> void:
	_start_on_temp_main_save()
	var spare := FileAccess.open(SPARE_BACKUP_PATH, FileAccess.WRITE)
	spare.store_string(MAIN_SAVE_TEXT)
	spare.close()
	DevManager.play_preset(_preset("test_lock_back", "", [_step(Kind.SET_GOLD, "", 700.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "precondition: a preset in memory holds no lock on your save")
	_block_backups()
	watch_signals(DevManager)
	DevManager.keep_as_my_save()
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), OS.get_process_id(), "precondition: keep takes your save's lock when asked")
	await wait_process_frames(SWITCH_FRAMES)
	assert_engine_error("Could not create directory", "the backup folder cannot be made")
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "the failed keep gave the lock back")
	DevManager.new_game()
	await wait_process_frames(SWITCH_FRAMES)
	assert_engine_error("Could not create directory")
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "so did the failed new game")
	DevManager.restore_backup(SPARE_BACKUP_PATH)
	await wait_process_frames(SWITCH_FRAMES)
	assert_engine_error("Could not create directory")
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "and the failed restore")
	assert_signal_emit_count(DevManager, "session_switch_failed", 3, "each failed in the deferred switch")
	assert_string_contains(_failure_reason(), "back up", "your save could not be backed up")
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "so it was never written")
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "the preset came back each time")

#-----------------------------------------------------------------------------
# REFUSALS
#-----------------------------------------------------------------------------

## A test run has no main save, unless the test sets one. A refused switch changes
## nothing: the running action runs on.
func test_main_save_functions_refuse_without_a_main_save() -> void:
	PersistenceManager.main_save_path = ""
	EventManager.trigger_event(FORAGING_EVENT)
	assert_eq(_current_action_id(), FORAGING_ID, "precondition: foraging runs")
	var save_before: SaveGameData = PersistenceManager.save_game_data
	watch_signals(DevManager)
	DevManager.back_to_my_save()
	DevManager.new_game()
	DevManager.keep_as_my_save()
	DevManager.restore_backup("user://%sbackup.tres" % TMP_PREFIX)
	assert_signal_emit_count(DevManager, "session_switch_failed", 4, "each one refuses")
	assert_string_contains(_failure_reason(), "main save")
	await wait_process_frames(SWITCH_FRAMES)
	assert_same(PersistenceManager.save_game_data, save_before, "the session keeps its save")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_eq(_current_action_id(), FORAGING_ID, "nothing was torn down")
	assert_signal_not_emitted(DevManager, "session_changed")

## A switch that would write your save while another live run holds its lock is
## refused before anything changes, so the session plays on as it was.
func test_writing_your_save_is_refused_while_another_run_holds_it() -> void:
	_start_on_temp_main_save()
	var backup: String = PersistenceManager.backup_main_save()
	assert_ne(backup, "", "precondition: a backup to restore")
	DevManager.play_preset(_preset("test_locked", "", [_step(Kind.SET_GOLD, "", 700.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	ResourceManager.set_gold(5.0)
	var preset_save: SaveGameData = PersistenceManager.save_game_data
	_lock_as_another_run(MAIN_SAVE_PATH)
	watch_signals(DevManager)
	DevManager.keep_as_my_save()
	assert_string_contains(_failure_reason(), "in use by another run", "keep is refused")
	DevManager.new_game()
	DevManager.restore_backup(backup)
	assert_signal_emit_count(DevManager, "session_switch_failed", 3, "so are a new game and a restore")
	await wait_process_frames(SWITCH_FRAMES)
	assert_same(PersistenceManager.save_game_data, preset_save, "the preset session plays on")
	assert_eq(ResourceManager.get_gold(), 5.0, "with what was played in it")
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "your save is left as it was")
	assert_eq(PersistenceManager.list_backups().size(), 1, "and no backup was taken")
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), _helper_pid, "the other run keeps its lock")
	assert_signal_not_emitted(DevManager, "session_changed")

func test_restoring_a_missing_backup_is_refused_at_once() -> void:
	_start_on_temp_main_save()
	var save_before: SaveGameData = PersistenceManager.save_game_data
	var missing: String = BACKUP_DIR + "no_such_backup.tres"
	watch_signals(DevManager)
	DevManager.restore_backup(missing)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1)
	assert_string_contains(_failure_reason(), missing, "the reason names the missing backup")
	await wait_process_frames(SWITCH_FRAMES)
	assert_same(PersistenceManager.save_game_data, save_before, "the session keeps its save")
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "your save is left as it was")
	assert_eq(PersistenceManager.list_backups().size(), 0, "and nothing was backed up")
	assert_signal_not_emitted(DevManager, "session_changed")

## validate() refuses a beat the route does not have before anything changes.
func test_a_preset_that_does_not_validate_is_refused_at_once() -> void:
	var save_before: SaveGameData = PersistenceManager.save_game_data
	watch_signals(DevManager)
	DevManager.play_story_through("no_such_beat")
	assert_signal_emit_count(DevManager, "session_switch_failed", 1)
	assert_string_contains(_failure_reason(), "no_such_beat")
	assert_string_contains(DevManager.get_last_switch_failure(), "no_such_beat", "a refusal is kept for the panel too")
	await wait_process_frames(SWITCH_FRAMES)
	assert_same(PersistenceManager.save_game_data, save_before, "the session keeps its save")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE)
	assert_signal_not_emitted(DevManager, "session_changed")

#-----------------------------------------------------------------------------
# ONE SWITCH AT A TIME
#-----------------------------------------------------------------------------
# A double click on a panel button asks for two switches in one frame. The second
# is refused at call time, before any other check, and the first still runs.

func test_a_second_switch_asked_for_in_the_same_frame_is_refused() -> void:
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_first", "", [_step(Kind.SET_GOLD, "", 321.0)]))
	DevManager.play_preset(_preset("test_second", "", [_step(Kind.SET_GOLD, "", 654.0)]))
	assert_signal_emit_count(DevManager, "session_switch_failed", 1, "the second request is refused at once")
	assert_eq(_failure_reason(), SWITCH_UNDER_WAY)
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset)
	if session_preset != null:
		assert_eq(session_preset.preset_id, "test_first", "the first request ran")
	assert_eq(ResourceManager.get_gold(), 321.0, "and only the first")
	assert_signal_emit_count(DevManager, "session_changed", 1, "one switch ran")
	assert_eq(DevManager.get_last_switch_failure(), "", "the switch that ran worked, which clears the refusal")
	DevManager.restart_preset()
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_switch_failed", 1, "once the switch has run, the next request is not refused")
	assert_signal_emit_count(DevManager, "session_changed", 2, "and runs")

## The refusal comes before every other check, so a request refused while a switch
## is pending never takes your save's lock.
func test_a_request_refused_while_a_switch_is_pending_takes_no_lock() -> void:
	_start_on_temp_main_save()
	DevManager.play_preset(_preset("test_in_memory", ""))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "precondition: a preset in memory holds no lock on your save")
	watch_signals(DevManager)
	DevManager.play_preset(_preset("test_pending", "", [_step(Kind.SET_GOLD, "", 321.0)]))
	DevManager.keep_as_my_save()
	DevManager.new_game()
	DevManager.back_to_my_save()
	assert_signal_emit_count(DevManager, "session_switch_failed", 3, "each request after the first is refused")
	assert_eq(_failure_reason(), SWITCH_UNDER_WAY)
	assert_eq(SaveLock.holder_pid(MAIN_SAVE_PATH), 0, "and none took your save's lock")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset asked for first is the session")
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	assert_eq(FileAccess.get_file_as_string(MAIN_SAVE_PATH), MAIN_SAVE_TEXT, "your save was never written")
	assert_eq(PersistenceManager.list_backups().size(), 0, "nor backed up")

## A double click on Keep took two backups of your save.
func test_a_double_keep_backs_your_save_up_once() -> void:
	_start_on_temp_main_save()
	DevManager.play_preset(_preset("test_double_keep", "", [_step(Kind.SET_GOLD, "", 700.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	watch_signals(DevManager)
	DevManager.keep_as_my_save()
	DevManager.keep_as_my_save()
	assert_signal_emit_count(DevManager, "session_switch_failed", 1, "the second keep is refused")
	assert_eq(_failure_reason(), SWITCH_UNDER_WAY)
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "the first keep ran")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 700.0, "and wrote your save")
	assert_eq(PersistenceManager.list_backups().size(), 1, "after one backup, not two")
	assert_signal_emit_count(DevManager, "session_changed", 1)

#-----------------------------------------------------------------------------
# TIME SPEED
#-----------------------------------------------------------------------------
# The time speed is the game's base Engine.time_scale, kept in GameSpeed. after_each()
# sets it back to 1.0, so no test leaves a speed for the next file.

func test_set_time_speed_scales_the_engine() -> void:
	assert_eq(DevManager.get_time_speed(), 1.0, "precondition: the game runs at normal speed")
	watch_signals(DevManager)
	assert_eq(DevManager.set_time_speed(5.0), "", "a listed speed is set")
	assert_eq(Engine.time_scale, 5.0, "the engine runs at ×5")
	assert_eq(GameSpeed.base_scale, 5.0, "it is the base speed a slowed moment comes back to")
	assert_eq(DevManager.get_time_speed(), 5.0, "and the speed reads back")
	assert_signal_emit_count(DevManager, "time_speed_changed", 1)
	assert_signal_emitted_with_parameters(DevManager, "time_speed_changed", [5.0])

func test_set_time_speed_logs_a_dev_line() -> void:
	LogManager.clear_history()
	DevManager.set_time_speed(5.0)
	assert_eq(LogManager.get_history(), [DEV_LINE + "Time speed ×5"] as Array[String], "one [DEV] line names the speed")

func test_every_listed_time_speed_can_be_set() -> void:
	assert_eq(DevManager.TIME_SPEEDS, [1.0, 2.0, 5.0, 10.0] as Array[float], "the four speeds the spec lists")
	for speed: float in DevManager.TIME_SPEEDS:
		assert_eq(DevManager.set_time_speed(speed), "", "speed %s is accepted" % speed)
		assert_eq(Engine.time_scale, speed, "and the engine runs at it")

## A speed that is not listed is refused with a reason that names it and the speeds
## that are allowed, and nothing changes. 0.0 would freeze the game; the others are
## no speed the panel offers.
func test_an_unlisted_time_speed_is_refused() -> void:
	var as_written: Dictionary[float, String] = {0.0: "×0", -1.0: "×-1", 3.0: "×3", 20.0: "×20"}
	DevManager.set_time_speed(2.0)
	LogManager.clear_history()
	watch_signals(DevManager)
	for speed: float in as_written:
		var reason: String = DevManager.set_time_speed(speed)
		assert_ne(reason, "", "%s is refused" % as_written[speed])
		assert_string_contains(reason, as_written[speed], "the reason names the speed asked for")
		assert_string_contains(reason, "×1, ×2, ×5, ×10", "and the speeds that are allowed")
	assert_eq(Engine.time_scale, 2.0, "the engine keeps its speed")
	assert_eq(DevManager.get_time_speed(), 2.0, "and so does the base speed")
	assert_signal_not_emitted(DevManager, "time_speed_changed")
	assert_eq(LogManager.get_history().size(), 0, "and nothing is logged")
