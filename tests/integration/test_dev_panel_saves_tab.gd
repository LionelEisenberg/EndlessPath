extends GutTest

## The dev panel's Saves tab and the restart key, against the real DevManager and
## PersistenceManager. The tab shows the session (what it plays, where it writes, why
## saving is off, the preset its save was built from, and the save's version,
## playtime, stage, Core Density and gold) and the route's beats with the playtime
## each was reached at, or "reached, no time recorded" where a build or a save from
## before play stats kept no time, refreshed as the session changes, when the tab is
## shown, and once a second for the playtime. Restart and
## Back switch the session; a row per preset plays or pins it; "Save this game as a
## preset" writes one; New game and Restore need a second click within 3 s; Keep,
## Save now, Autosave and the backup picker work on your save. A refused or failed
## switch shows its reason, also in a tab built after it. Ctrl+Shift+R restarts a
## preset session from anywhere, and leaves the key alone outside one. Open folder
## opens a real Explorer window, so no test presses it.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it. Nothing here
## touches a real path: the presets are read from and saved into a temp folder
## (preset_dir_override), the pin lives in a temp file (pin_path_override), and the
## tests that need your save point PersistenceManager's main save and backup folder
## at temp paths. Each test binds a fresh in-memory save and gives back everything it
## changed: the save and its paths, autosave, the player's log, DevManager's session
## and panel fields, the preset folder and the pin file.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")

const Kind = DevStepData.Kind
const SessionKind = DevManager.SessionKind

## The size MainView gives the panel in the game.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

## A switch runs on the next frame. Two frames leave it done.
const SWITCH_FRAMES: int = 2

## The prefix of every [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## Every temp file and folder here starts with this. after_each() deletes them.
const TMP_PREFIX: String = "__test_dev_panel_saves_tab_"
## The folder the presets are read from and saved into.
const PRESET_DIR: String = "user://__test_dev_panel_saves_tab_presets/"
## Where the main save's backups go while a test points the main save at its temp file.
const BACKUP_DIR: String = "user://__test_dev_panel_saves_tab_backups/"
## Stands in for the user's own save.
const MAIN_SAVE_PATH: String = "user://__test_dev_panel_saves_tab_main.tres"
## A save file the session plays, standing in for a --save file.
const FILE_PATH: String = "user://__test_dev_panel_saves_tab_file.tres"
## The pin file, in place of the checkout's.
const PIN_PATH: String = "user://__test_dev_panel_saves_tab_pin.cfg"
const MAIN_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
save_version = 1
gold = 42.0
"""

## Locked on a fresh save: it needs Core Density 10. A preset that completes it fails
## midway through its build.
const NPC_4: String = "celestial_intervener_dialogue_4"

## Beat 1's reached_when: the event q_fill_core fires when it completes, which is
## also the id of the unlock condition that latches on that event.
const AWAKENING_EVENT: String = "q_fill_core_completed"

## Beat 2's reached_when: an event no unlock condition shares, the completion event
## of a q_first_steps step.
const FIRST_STEPS_EVENT: String = "celestial_intervener_dialogue_3"

## A save from before play stats existed, as the developer's own save is: the events
## of beats 1 and 2 have fired and beat 1's condition has latched, and no first time
## was kept for any of them.
const PRE_STATS_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]
[ext_resource type="Script" path="res://singletons/persistence_manager/event_progression_data.gd" id="2_events"]
[ext_resource type="Script" path="res://singletons/persistence_manager/unlock_progression_data.gd" id="3_unlocks"]

[sub_resource type="Resource" id="Resource_events"]
script = ExtResource("2_events")
triggered_events = Array[String](["q_fill_core_completed", "celestial_intervener_dialogue_3"])

[sub_resource type="Resource" id="Resource_unlocks"]
script = ExtResource("3_unlocks")
unlocked_condition_ids = Array[String](["q_fill_core_completed"])

[resource]
script = ExtResource("1_save")
save_version = 1
gold = 42.0
event_progression = SubResource("Resource_events")
unlock_progression = SubResource("Resource_unlocks")
"""

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_main_save_path: String
var _original_backup_dir: String
var _original_autosave: bool
var _original_history: Array[String]
var _original_session_kind: DevManager.SessionKind
var _original_session_preset: SavePresetData
var _original_last_switch_failure: String
var _original_preset_dir_override: String
var _original_pin_path_override: String
var _original_panel_open: bool
var _original_panel_position: Vector2
var _original_panel_tab: int

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_main_save_path = PersistenceManager.main_save_path
	_original_backup_dir = PersistenceManager.backup_dir
	_original_autosave = PersistenceManager.autosave_enabled
	_original_history = LogManager._history.duplicate()
	_original_session_kind = DevManager._session_kind
	_original_session_preset = DevManager._session_preset
	_original_last_switch_failure = DevManager._last_switch_failure
	_original_preset_dir_override = DevManager.preset_dir_override
	_original_pin_path_override = LaunchOptions.pin_path_override
	_original_panel_open = DevManager.panel_open
	_original_panel_position = DevManager.panel_position
	_original_panel_tab = DevManager.panel_tab
	_remove_temp_files()
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	DevManager.preset_dir_override = PRESET_DIR
	LaunchOptions.pin_path_override = PIN_PATH
	DevManager._session_kind = SessionKind.YOUR_SAVE
	DevManager._session_preset = null
	DevManager._last_switch_failure = ""
	DevManager.panel_open = false
	DevManager.panel_position = Vector2(24, 24)
	DevManager.panel_tab = 0

func after_each() -> void:
	ActionManager.cancel_current_action()
	PersistenceManager.autosave_enabled = _original_autosave
	PersistenceManager.main_save_path = _original_main_save_path
	PersistenceManager.backup_dir = _original_backup_dir
	PersistenceManager.use_save(_original_save, _original_save_path)
	LogManager._history = _original_history
	DevManager._session_kind = _original_session_kind
	DevManager._session_preset = _original_session_preset
	DevManager._last_switch_failure = _original_last_switch_failure
	DevManager.preset_dir_override = _original_preset_dir_override
	LaunchOptions.pin_path_override = _original_pin_path_override
	DevManager.panel_open = _original_panel_open
	DevManager.panel_position = _original_panel_position
	DevManager.panel_tab = _original_panel_tab
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()
	_remove_temp_files()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the panel inside a Control the size of the screen, as MainView holds it.
## It starts closed, as a launch's does.
func _add_panel() -> DevPanel:
	var host := Control.new()
	host.size = SCREEN_SIZE
	add_child_autofree(host)
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	host.add_child(panel)
	return panel

## Opens the panel on the Saves tab and returns the tab.
func _show_saves_tab(panel: DevPanel) -> Control:
	panel.set_open(true)
	var tab: Control = panel.get_node("%SavesTab")
	var tabs: TabContainer = panel.get_node("%Tabs")
	tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	return tab

## Builds the panel and opens it on the Saves tab, as a developer finds it.
func _open_saves_tab() -> Control:
	return _show_saves_tab(_add_panel())

## Presses a button the way a click does: it says it was pressed.
func _press(node: Node, button_name: String) -> void:
	(node.get_node("%" + button_name) as BaseButton).pressed.emit()

func _label(node: Node, label_name: String) -> Label:
	return node.get_node("%" + label_name) as Label

func _button(node: Node, button_name: String) -> Button:
	return node.get_node("%" + button_name) as Button

func _status(tab: Node) -> Label:
	return _label(tab, "SavesStatus")

## The preset rows, in the order the tab lists them.
func _rows(tab: Node) -> Array[Node]:
	return (tab.get_node("%PresetList") as Node).get_children()

func _row_titles(tab: Node) -> Array[String]:
	var titles: Array[String] = []
	for row: Node in _rows(tab):
		titles.append(_label(row, "TitleLabel").text)
	return titles

## The picker's item texts, in order.
func _item_texts(option: OptionButton) -> Array[String]:
	var texts: Array[String] = []
	for index: int in option.item_count:
		texts.append(option.get_item_text(index))
	return texts

## The picker's item metadata, in order, as strings.
func _item_metadata(option: OptionButton) -> Array[String]:
	var values: Array[String] = []
	for index: int in option.item_count:
		values.append(str(option.get_item_metadata(index)))
	return values

func _strings(packed: PackedStringArray) -> Array[String]:
	var strings: Array[String] = []
	strings.assign(packed)
	return strings

func _step(kind: DevStepData.Kind, target_id: String = "", amount: float = 0.0) -> DevStepData:
	var step := DevStepData.new()
	step.kind = kind
	step.target_id = target_id
	step.amount = amount
	return step

## A preset with no beat and these steps.
func _preset(preset_id: String, title: String, steps: Array[DevStepData] = []) -> SavePresetData:
	var preset := SavePresetData.new()
	preset.preset_id = preset_id
	preset.title = title
	preset.steps = steps
	return preset

## Writes the preset into PRESET_DIR, where get_presets() finds it. Each test names
## its own files: the resource cache keeps a loaded preset by its path.
func _write_preset(preset: SavePresetData, file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_DIR))
	assert_eq(ResourceSaver.save(preset, PRESET_DIR + file_name), OK, "precondition: %s is written" % file_name)

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

## Starts the session on a temp file holding `text` (gold 42), standing in for your
## save: the main save and its backup folder point at temp paths, and the file is
## opened as a launch on your save opens it.
func _start_on_temp_main_save(text: String = MAIN_SAVE_TEXT) -> void:
	_write_text(MAIN_SAVE_PATH, text)
	PersistenceManager.main_save_path = MAIN_SAVE_PATH
	PersistenceManager.backup_dir = BACKUP_DIR
	PersistenceManager.open_save_file(MAIN_SAVE_PATH)
	DevManager._session_kind = SessionKind.YOUR_SAVE
	DevManager._session_preset = null
	assert_eq(ResourceManager.get_gold(), 42.0, "precondition: the session plays the temp main save")

## The gold of the save on disk at `path`, read again from the file, or -1.0 when
## nothing there loads.
func _gold_in_file(path: String) -> float:
	var loaded: SaveGameData = SaveFiles.load_save(path)
	return -1.0 if loaded == null else loaded.gold

## A key press of R with the modifiers given.
func _r_key(ctrl: bool, shift: bool, echo: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	key.echo = echo
	return key

func _remove_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

## Deletes every temp file (the saves, their temp files, locks and backups, the
## presets and the pin) and every temp folder.
func _remove_temp_files() -> void:
	for folder_name: String in DirAccess.get_directories_at("user://"):
		if folder_name.begins_with(TMP_PREFIX):
			_remove_folder("user://" + folder_name)
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(TMP_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))

#-----------------------------------------------------------------------------
# THE TAB
#-----------------------------------------------------------------------------

func test_the_saves_tab_comes_first() -> void:
	var panel: DevPanel = _add_panel()
	var tabs: TabContainer = panel.get_node("%Tabs")
	var index: int = tabs.get_tab_idx_from_control(panel.get_node("%SavesTab"))
	assert_eq(index, 0, "Saves is the first tab")
	assert_eq(tabs.get_tab_title(index), "Saves")

## No text is cut off: every label that can run long wraps, and is told how wide it
## may be.
func test_the_long_labels_wrap() -> void:
	_write_preset(_preset("wrap_row", "Wrap"), "wrap_row.tres")
	var tab: Control = _open_saves_tab()
	var row: Node = _rows(tab)[0]
	var labels: Array[Label] = [
		_label(tab, "SessionLabel"), _label(tab, "BeatsLabel"), _label(tab, "SavePresetStatus"), _status(tab),
		_label(row, "TitleLabel"), _label(row, "DescriptionLabel"), _label(row, "PinnedLabel"),
	]
	for label: Label in labels:
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s wraps by word" % label.name)
		assert_gt(label.custom_minimum_size.x, 0.0, "%s has a width to wrap in" % label.name)

#-----------------------------------------------------------------------------
# THE SESSION
#-----------------------------------------------------------------------------

func test_the_session_line_says_in_memory() -> void:
	var tab: Control = _open_saves_tab()
	DevManager.play_preset(_preset("line_memory", "Line test"))
	await wait_process_frames(SWITCH_FRAMES)
	var line: String = _label(tab, "SessionLabel").text
	assert_true(line.begins_with("Preset: Line test · in memory, not saved\n"), "the line names the preset and says nothing writes it: %s" % line)

func test_the_session_line_names_your_save_and_what_it_holds() -> void:
	_start_on_temp_main_save()
	assert_eq(DevCommands.reach_core_density(42), "", "precondition: Core Density 42")
	assert_eq(DevCommands.set_gold(120.0), "", "precondition: 120 gold")
	PersistenceManager.save_game_data.stats.add_play_time(754.0)
	var tab: Control = _open_saves_tab()
	assert_eq(_label(tab, "SessionLabel").text, "Your save · %s\nVersion 1 · Playtime 12:34 · Foundation, Core Density 42 / 100 · 120 gold" % MAIN_SAVE_PATH)

## A save a newer build wrote is played with saving off, and the line says why.
func test_the_session_line_names_a_file_and_why_saving_is_off() -> void:
	_write_text(FILE_PATH, MAIN_SAVE_TEXT.replace("save_version = 1", "save_version = 99"))
	PersistenceManager.open_save_file(FILE_PATH)
	DevManager.start_from_launch_options(LaunchOptions.parse(PackedStringArray(["--save=" + FILE_PATH])))
	assert_true(PersistenceManager.is_save_blocked(), "precondition: saving is off for a newer build's save")
	var tab: Control = _open_saves_tab()
	var lines: PackedStringArray = _label(tab, "SessionLabel").text.split("\n")
	assert_eq(lines.size(), 3, "where it writes, why saving is off, and the save: %s" % [lines])
	if lines.size() == 3:
		assert_eq(lines[0], "File · " + FILE_PATH)
		assert_eq(lines[1], "Saving is off: " + PersistenceManager.get_block_reason())
		assert_string_contains(lines[1], "newer build")
		assert_true(lines[2].begins_with("Version 99 · Playtime 0:00 · "), lines[2])

## In real play a beat's event fires, or its condition latches, and the stats keep
## the playtime it happened at: the line shows that time.
func test_the_beats_show_when_each_was_reached() -> void:
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	stats.add_play_time(161.0)
	EventManager.trigger_event(AWAKENING_EVENT)
	stats.add_play_time(3725.0 - 161.0)
	UnlockManager.force_unlock_condition("core_density_full")
	var tab: Control = _open_saves_tab()
	var lines: PackedStringArray = _label(tab, "BeatsLabel").text.split("\n")
	assert_eq(lines.size(), DevManager.get_route().beats.size(), "one line per beat of the route")
	assert_has(lines, "Awakening — 2:41", "beat 1's event fired at 2:41")
	assert_has(lines, "Tribulation ready — 1:02:05", "an hour on, the clock shows hours")
	assert_has(lines, "First Steps Out — not reached", "a beat whose event never fired")
	assert_has(lines, "Copper — not tracked (no reached_when)", "a beat with nothing to mark it reached")

## A build records no play, so the beats it passed keep no time. Their events fired
## and their conditions latched, so they read as reached, and the session line names
## the preset the save was built from: its figures are not a playtest's.
func test_a_preset_build_shows_its_beats_reached_and_names_the_preset() -> void:
	var tab: Control = _open_saves_tab()
	DevManager.play_preset(_preset("built_beats", "Built beats", [
		_step(Kind.TRIGGER_EVENT, AWAKENING_EVENT),
		_step(Kind.TRIGGER_EVENT, FIRST_STEPS_EVENT),
		_step(Kind.REACH_CORE_DENSITY, "", 100.0),
	]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET, "precondition: the preset was built")
	var beats: PackedStringArray = _label(tab, "BeatsLabel").text.split("\n")
	assert_has(beats, "Awakening — reached, no time recorded", "the build fired the beat's event: %s" % [beats])
	assert_has(beats, "First Steps Out — reached, no time recorded", "an event no condition shares")
	assert_has(beats, "Tribulation ready — reached, no time recorded", "and latched the beat's condition")
	assert_has(beats, "Aura Well — not reached", "a beat the build did not pass")
	var lines: PackedStringArray = _label(tab, "SessionLabel").text.split("\n")
	assert_has(lines, "Built from preset 'built_beats'", "the line names the preset: %s" % [lines])

## A save from before play stats existed has the events it fired but no times for
## them. Its beats read as reached, not as not reached, and nothing says a preset
## built it.
func test_a_save_from_before_play_stats_shows_its_beats_reached() -> void:
	_start_on_temp_main_save(PRE_STATS_SAVE_TEXT)
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	for event_id: String in [AWAKENING_EVENT, FIRST_STEPS_EVENT]:
		assert_true(EventManager.has_event_triggered(event_id), "precondition: the save fired %s" % event_id)
		assert_eq(stats.first_time_of(event_id), -1.0, "precondition: and kept no time for it")
	var tab: Control = _open_saves_tab()
	var beats: PackedStringArray = _label(tab, "BeatsLabel").text.split("\n")
	assert_has(beats, "Awakening — reached, no time recorded", "%s" % [beats])
	assert_has(beats, "First Steps Out — reached, no time recorded", "an event no condition shares")
	assert_has(beats, "Aura Well — not reached")
	assert_false(_label(tab, "SessionLabel").text.contains("Built from preset"), "no preset built this save")

## The playtime goes on while the tab is in view, so the line follows it once a
## second, in real seconds whatever the time speed.
func test_the_playtime_line_refreshes_once_a_second() -> void:
	var panel: DevPanel = _add_panel()
	var tab: Control = _show_saves_tab(panel)
	var timer: Timer = tab.get_node("%RefreshTimer")
	assert_eq(timer.wait_time, 1.0, "once a second")
	assert_true(timer.ignore_time_scale, "in real seconds")
	assert_false(timer.is_stopped(), "the tick runs")
	assert_string_contains(_label(tab, "SessionLabel").text, "Playtime 0:00", "precondition")
	PersistenceManager.save_game_data.stats.add_play_time(65.0)
	timer.timeout.emit()
	assert_string_contains(_label(tab, "SessionLabel").text, "Playtime 1:05", "the tick shows the playtime")
	panel.set_open(false)
	PersistenceManager.save_game_data.stats.add_play_time(60.0)
	timer.timeout.emit()
	assert_string_contains(_label(tab, "SessionLabel").text, "Playtime 1:05", "a closed panel's tab does not tick")

## Built while the panel is closed, the tab shows what has changed since when it is
## opened.
func test_the_tab_refreshes_when_shown() -> void:
	var panel: DevPanel = _add_panel()
	var tab: Control = panel.get_node("%SavesTab")
	_write_preset(_preset("shown_row", "Shown"), "shown_row.tres")
	PersistenceManager.autosave_enabled = true
	_show_saves_tab(panel)
	assert_eq(_row_titles(tab), ["Shown"] as Array[String], "the preset written since is listed")
	assert_true((tab.get_node("%AutosaveCheck") as CheckButton).button_pressed, "and the check shows autosave on")

#-----------------------------------------------------------------------------
# RESTART AND BACK
#-----------------------------------------------------------------------------

func test_restart_is_disabled_outside_a_preset() -> void:
	var tab: Control = _open_saves_tab()
	var restart: Button = _button(tab, "RestartButton")
	assert_eq(restart.text, "Restart preset (Ctrl+Shift+R)")
	assert_true(restart.disabled, "your save has no preset to restart")
	assert_true(_button(tab, "BackButton").disabled, "and is your save already")
	assert_true(_button(tab, "KeepButton").disabled, "so there is nothing to keep as it")
	DevManager.play_preset(_preset("restart_button", "Restart test", [_step(Kind.SET_GOLD, "", 321.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_false(restart.disabled, "a preset session can restart")
	assert_false(_button(tab, "BackButton").disabled, "go back to your save")
	assert_false(_button(tab, "KeepButton").disabled, "and be kept as it")
	ResourceManager.set_gold(5.0)
	_press(tab, "RestartButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "Restart builds the preset again")

## A test run has no main save, so going back to it is refused at once.
func test_a_refused_switch_shows_its_reason() -> void:
	var tab: Control = _open_saves_tab()
	DevManager.play_preset(_preset("back_refused", "Back test"))
	await wait_process_frames(SWITCH_FRAMES)
	assert_false(_status(tab).visible, "precondition: nothing to say yet")
	_press(tab, "BackButton")
	assert_true(_status(tab).visible, "the refusal shows")
	assert_eq(_status(tab).text, "This run has no main save")

## In a real run a switch frees the panel and builds it again, and a failure midway
## is emitted while no panel is there to hear it: the tab built next shows it.
func test_a_failed_switch_shows_in_the_tab_built_after_it() -> void:
	var panel: DevPanel = _add_panel()
	var tab: Control = _show_saves_tab(panel)
	DevManager.play_preset(_preset("fails_midway", "Failing", [_step(Kind.COMPLETE_ACTION, NPC_4)]))
	await wait_process_frames(SWITCH_FRAMES)
	var failure: String = DevManager.get_last_switch_failure()
	assert_string_contains(failure, NPC_4, "precondition: the build failed midway")
	assert_eq(_status(tab).text, failure, "the tab shows why")
	panel.free()
	var rebuilt: Control = _open_saves_tab()
	assert_true(_status(rebuilt).visible, "a tab built after the failure shows it")
	assert_eq(_status(rebuilt).text, failure)
	DevManager.play_preset(_preset("works_after", "Works"))
	await wait_process_frames(SWITCH_FRAMES)
	assert_false(_status(rebuilt).visible, "a switch that works clears it")

#-----------------------------------------------------------------------------
# PRESETS
#-----------------------------------------------------------------------------

func test_every_preset_has_a_row() -> void:
	_write_preset(_preset("rows_gamma", "Gamma"), "rows_gamma.tres")
	var alpha: SavePresetData = _preset("rows_alpha", "Alpha")
	alpha.description = "The first preset, with a description long enough to wrap onto a second line of its row."
	_write_preset(alpha, "rows_alpha.tres")
	_write_preset(_preset("rows_beta", "Beta"), "rows_beta.tres")
	assert_eq(DevManager.pin_preset("rows_gamma"), OK, "precondition: Gamma is pinned")
	var tab: Control = _open_saves_tab()
	var rows: Array[Node] = _rows(tab)
	assert_eq(rows.size(), DevManager.get_presets().size(), "one row per preset")
	assert_eq(_row_titles(tab), ["Alpha", "Beta", "Gamma"] as Array[String], "in the order get_presets() lists them")
	if rows.size() != 3:
		return
	assert_eq(_label(rows[0], "DescriptionLabel").text, alpha.description, "a row shows its preset's description")
	assert_true(_label(rows[0], "DescriptionLabel").visible)
	assert_false(_label(rows[1], "DescriptionLabel").visible, "and none when it has none")
	assert_false(_label(rows[0], "PinnedLabel").visible, "only the pinned preset says it is pinned")
	assert_true(_label(rows[2], "PinnedLabel").visible)
	assert_eq(_label(rows[2], "PinnedLabel").text, "Pinned · plain launches start here")
	assert_eq(_button(rows[0], "PinButton").text, "Pin")
	assert_eq(_button(rows[2], "PinButton").text, "Unpin", "the pinned one offers to unpin")
	assert_eq(_button(rows[0], "PlayButton").text, "Play")

func test_play_on_a_row_plays_its_preset() -> void:
	_write_preset(_preset("rows_play", "Play test", [_step(Kind.SET_GOLD, "", 321.0)]), "rows_play.tres")
	var tab: Control = _open_saves_tab()
	_press(_rows(tab)[0], "PlayButton")
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "the switch waits for the next frame")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.PRESET)
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset)
	if session_preset != null:
		assert_eq(session_preset.preset_id, "rows_play", "the row's preset is the session")
	assert_eq(ResourceManager.get_gold(), 321.0, "built")
	assert_true(_label(tab, "SessionLabel").text.begins_with("Preset: Play test · "), "and the tab shows it")

func test_pin_pins_and_unpins_the_preset() -> void:
	_write_preset(_preset("pin_alpha", "Alpha"), "pin_alpha.tres")
	_write_preset(_preset("pin_beta", "Beta"), "pin_beta.tres")
	var tab: Control = _open_saves_tab()
	var alpha: Node = _rows(tab)[0]
	var beta: Node = _rows(tab)[1]
	assert_eq(DevManager.get_pinned_preset_id(), "", "precondition: nothing is pinned")
	_press(alpha, "PinButton")
	assert_eq(DevManager.get_pinned_preset_id(), "pin_alpha", "Pin pins the row's preset")
	assert_true(_label(alpha, "PinnedLabel").visible, "and its row says so")
	assert_eq(_button(alpha, "PinButton").text, "Unpin")
	_press(beta, "PinButton")
	assert_eq(DevManager.get_pinned_preset_id(), "pin_beta", "pinning another moves the pin")
	assert_false(_label(alpha, "PinnedLabel").visible, "off the first row")
	assert_eq(_button(alpha, "PinButton").text, "Pin")
	_press(beta, "PinButton")
	assert_eq(DevManager.get_pinned_preset_id(), "", "Unpin unpins")
	assert_false(_label(beta, "PinnedLabel").visible)
	assert_true(FileAccess.file_exists(PIN_PATH), "the pin was written to the temp pin file")

#-----------------------------------------------------------------------------
# SAVE THIS GAME AS A PRESET
#-----------------------------------------------------------------------------

func test_save_as_preset_shows_a_refusal() -> void:
	var tab: Control = _open_saves_tab()
	var status: Label = _label(tab, "SavePresetStatus")
	assert_false(status.visible, "precondition: nothing to say yet")
	(tab.get_node("%TitleEdit") as LineEdit).text = ""
	_press(tab, "SavePresetButton")
	assert_true(status.visible, "the refusal shows")
	assert_eq(status.text, "The title is empty")
	assert_eq(DevManager.get_presets().size(), 0, "and nothing was written")

func test_save_as_preset_writes_the_preset_and_lists_it() -> void:
	_write_preset(_preset("saved_beside", "Alpha"), "saved_beside.tres")
	ResourceManager.set_gold(77.0)
	var tab: Control = _open_saves_tab()
	assert_eq(_row_titles(tab), ["Alpha"] as Array[String], "precondition: one preset is listed")
	var title_edit: LineEdit = tab.get_node("%TitleEdit")
	var description_edit: LineEdit = tab.get_node("%DescriptionEdit")
	title_edit.text = "Weird state #2!"
	description_edit.text = "Gold 77"
	_press(tab, "SavePresetButton")
	assert_eq(_label(tab, "SavePresetStatus").text, "Saved this game as the preset 'Weird state #2!'", "the tab names the new preset")
	assert_true(FileAccess.file_exists(PRESET_DIR + "weird_state_2.tres"), "written to the preset folder")
	assert_eq(_row_titles(tab), ["Alpha", "Weird state #2!"] as Array[String], "and listed with the others")
	assert_eq(title_edit.text, "", "the fields are cleared for the next one")
	assert_eq(description_edit.text, "")
	var saved: SavePresetData = DevManager.find_preset("weird_state_2")
	assert_not_null(saved)
	if saved != null:
		assert_eq(saved.description, "Gold 77")
		assert_eq(saved.snapshot.gold, 77.0, "holding this game")

#-----------------------------------------------------------------------------
# YOUR SAVE
#-----------------------------------------------------------------------------

func test_new_game_needs_a_second_click() -> void:
	_start_on_temp_main_save()
	var tab: Control = _open_saves_tab()
	var button: Button = _button(tab, "NewGameButton")
	assert_eq(button.text, "New game on my save", "precondition")
	watch_signals(DevManager)
	_press(tab, "NewGameButton")
	assert_eq(button.text, "Click again to start a new game", "the first click asks for a second")
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_not_emitted(DevManager, "session_changed", "and starts nothing")
	assert_eq(ResourceManager.get_gold(), 42.0)
	assert_eq(PersistenceManager.list_backups().size(), 0)
	_press(tab, "NewGameButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_emit_count(DevManager, "session_changed", 1, "the second click starts the new game")
	assert_eq(ResourceManager.get_gold(), 0.0, "a new game")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 0.0, "on your save, written at once")
	assert_eq(PersistenceManager.list_backups().size(), 1, "after a backup of the old one")
	assert_eq(button.text, "New game on my save", "and the button reads as before")

## The 3 s run in real time, so a fast time speed does not shorten them. Only one
## button waits for its second click at a time.
func test_the_second_click_must_come_within_3_s() -> void:
	_start_on_temp_main_save()
	assert_ne(PersistenceManager.backup_main_save(), "", "precondition: a backup to restore")
	var tab: Control = _open_saves_tab()
	var new_game: Button = _button(tab, "NewGameButton")
	var restore: Button = _button(tab, "RestoreButton")
	var timer: Timer = tab.get_node("%ConfirmTimer")
	assert_eq(timer.wait_time, 3.0)
	assert_true(timer.one_shot)
	assert_true(timer.ignore_time_scale, "in real seconds")
	watch_signals(DevManager)
	_press(tab, "NewGameButton")
	assert_false(timer.is_stopped(), "the first click starts the 3 s")
	timer.stop()
	timer.timeout.emit()
	assert_eq(new_game.text, "New game on my save", "once they run out, the button reads as before")
	_press(tab, "NewGameButton")
	assert_eq(new_game.text, "Click again to start a new game", "so the next click is a first click again")
	assert_false(restore.disabled, "precondition: there is a backup to restore")
	_press(tab, "RestoreButton")
	assert_eq(restore.text, "Click again to restore", "a first click on Restore")
	assert_eq(new_game.text, "New game on my save", "takes the second click away from New game")
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_not_emitted(DevManager, "session_changed", "no click was a second one, so nothing switched")
	assert_signal_not_emitted(DevManager, "session_switch_failed")
	assert_eq(ResourceManager.get_gold(), 42.0, "your save plays on")

func test_restore_needs_a_second_click() -> void:
	_start_on_temp_main_save()
	var backup: String = PersistenceManager.backup_main_save()
	assert_ne(backup, "", "precondition: a backup of the save with gold 42")
	ResourceManager.set_gold(5.0)
	assert_eq(PersistenceManager.save_data(), OK, "precondition: your save now holds gold 5")
	var tab: Control = _open_saves_tab()
	var option: OptionButton = tab.get_node("%BackupOption")
	assert_eq(_item_metadata(option), [backup] as Array[String], "precondition: the picker offers the backup")
	var restore: Button = _button(tab, "RestoreButton")
	_press(tab, "RestoreButton")
	assert_eq(restore.text, "Click again to restore", "the first click asks for a second")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 5.0, "and restores nothing")
	_press(tab, "RestoreButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 42.0, "the second click restores the backup")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 42.0, "as your save")
	assert_eq(restore.text, "Restore", "and the button reads as before")

## Backup names carry a UTC timestamp, and a second copy made in the same second
## carries "-2". The picker shows them newest first, each with its path.
func test_backups_are_listed_newest_first_with_their_utc_time() -> void:
	_start_on_temp_main_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var stem: String = MAIN_SAVE_PATH.get_file().get_basename()
	for stamp: String in ["20261024-090000", "20261025-111715", "20261025-111715-2"]:
		_write_text(BACKUP_DIR + "%s.%s.tres" % [stem, stamp], MAIN_SAVE_TEXT)
	var tab: Control = _open_saves_tab()
	var option: OptionButton = tab.get_node("%BackupOption")
	assert_eq(_item_texts(option), [
		"%s · 2026-10-25 11:17:15 #2 (UTC)" % stem,
		"%s · 2026-10-25 11:17:15 (UTC)" % stem,
		"%s · 2026-10-24 09:00:00 (UTC)" % stem,
	] as Array[String])
	assert_eq(_item_metadata(option), _strings(PersistenceManager.list_backups()), "each item's metadata is its path")
	assert_eq(option.selected, 0, "the newest is picked")
	assert_false(option.disabled)
	assert_false(_button(tab, "RestoreButton").disabled)

## Showing the tab again refreshes the picker and keeps the backup picked in it, and
## Restore puts back the picked one, not the newest.
func test_restore_puts_back_the_picked_backup_after_a_refresh() -> void:
	_start_on_temp_main_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var stem: String = MAIN_SAVE_PATH.get_file().get_basename()
	_write_text(BACKUP_DIR + "%s.20261024-090000.tres" % stem, MAIN_SAVE_TEXT.replace("gold = 42.0", "gold = 100.0"))
	_write_text(BACKUP_DIR + "%s.20261025-111715.tres" % stem, MAIN_SAVE_TEXT.replace("gold = 42.0", "gold = 200.0"))
	var panel: DevPanel = _add_panel()
	var tab: Control = _show_saves_tab(panel)
	var option: OptionButton = tab.get_node("%BackupOption")
	option.select(1)
	var picked: String = str(option.get_item_metadata(1))
	assert_eq(_gold_in_file(picked), 100.0, "precondition: the older backup, with gold 100, is picked")
	panel.set_open(false)
	_show_saves_tab(panel)
	assert_eq(option.selected, 1, "the picker keeps it")
	assert_eq(str(option.get_item_metadata(option.selected)), picked)
	_press(tab, "RestoreButton")
	_press(tab, "RestoreButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 100.0, "Restore put back the picked backup")

func test_without_backups_restore_is_off() -> void:
	var tab: Control = _open_saves_tab()
	var option: OptionButton = tab.get_node("%BackupOption")
	assert_eq(_item_texts(option), ["No backups"] as Array[String])
	assert_true(option.disabled)
	assert_true(_button(tab, "RestoreButton").disabled)

func test_keep_makes_the_session_your_save() -> void:
	_start_on_temp_main_save()
	var tab: Control = _open_saves_tab()
	DevManager.play_preset(_preset("keep_press", "Keep test", [_step(Kind.SET_GOLD, "", 700.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(_button(tab, "KeepButton").text, "Keep as my save")
	_press(tab, "KeepButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "one click keeps the session")
	assert_eq(_gold_in_file(MAIN_SAVE_PATH), 700.0, "as your save")
	assert_true(_button(tab, "KeepButton").disabled, "which has nothing left to keep")
	assert_true(_label(tab, "SessionLabel").text.begins_with("Your save · %s\n" % MAIN_SAVE_PATH), "and the tab shows it")

## Keep copies the session's save onto yours, its play stats included, so your save
## still says which preset built it, and the beats the build passed still read as
## reached with no time.
func test_your_save_kept_from_a_preset_still_names_the_preset() -> void:
	_start_on_temp_main_save()
	var tab: Control = _open_saves_tab()
	DevManager.play_preset(_preset("kept_build", "Kept build", [_step(Kind.TRIGGER_EVENT, AWAKENING_EVENT)]))
	await wait_process_frames(SWITCH_FRAMES)
	_press(tab, "KeepButton")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(DevManager.get_session_kind(), SessionKind.YOUR_SAVE, "precondition: the session was kept as your save")
	var lines: PackedStringArray = _label(tab, "SessionLabel").text.split("\n")
	assert_eq(lines[0], "Your save · " + MAIN_SAVE_PATH)
	assert_has(lines, "Built from preset 'kept_build'", "your save still says what built it: %s" % [lines])
	assert_has(_label(tab, "BeatsLabel").text.split("\n"), "Awakening — reached, no time recorded")

func test_save_now_says_what_happened() -> void:
	var tab: Control = _open_saves_tab()
	_press(tab, "SaveNowButton")
	assert_eq(_status(tab).text, "Not saved: this session lives in memory, so there is no file to write")
	PersistenceManager.use_save(SaveGameData.new_current(), FILE_PATH)
	ResourceManager.set_gold(33.0)
	LogManager.clear_history()
	_press(tab, "SaveNowButton")
	assert_eq(_status(tab).text, "Saved to " + FILE_PATH)
	assert_eq(_gold_in_file(FILE_PATH), 33.0, "the file holds the session")
	assert_eq(LogManager.get_history(), [DEV_LINE + "Saved the game to " + FILE_PATH] as Array[String])

func test_save_now_names_why_saving_is_off() -> void:
	var newer: String = MAIN_SAVE_TEXT.replace("save_version = 1", "save_version = 99")
	_write_text(FILE_PATH, newer)
	PersistenceManager.open_save_file(FILE_PATH)
	var tab: Control = _open_saves_tab()
	_press(tab, "SaveNowButton")
	assert_eq(_status(tab).text, "Not saved. Saving is off: " + PersistenceManager.get_block_reason())
	assert_eq(FileAccess.get_file_as_string(FILE_PATH), newer, "the file is left as the newer build wrote it")

func test_save_now_names_a_write_error() -> void:
	PersistenceManager.use_save(SaveGameData.new_current(), FILE_PATH)
	# A folder where the temp file goes makes the write fail, as in test_save_files.gd.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveFiles.temp_path_for(FILE_PATH)))
	var tab: Control = _open_saves_tab()
	_press(tab, "SaveNowButton")
	assert_engine_error("Cannot save file", "the engine reports the file it could not write")
	var text: String = _status(tab).text
	assert_true(text.begins_with("Could not write %s: " % FILE_PATH), text)
	assert_string_contains(text, "(error ")

func test_the_autosave_check_turns_autosave_on_and_off() -> void:
	PersistenceManager.autosave_enabled = false
	var tab: Control = _open_saves_tab()
	var check: CheckButton = tab.get_node("%AutosaveCheck")
	assert_false(check.button_pressed, "the check shows autosave off")
	LogManager.clear_history()
	check.button_pressed = true
	assert_true(PersistenceManager.autosave_enabled, "pressing it turns autosave on")
	check.button_pressed = false
	assert_false(PersistenceManager.autosave_enabled, "and off")
	assert_eq(LogManager.get_history(), [DEV_LINE + "Autosave: ON", DEV_LINE + "Autosave: OFF"] as Array[String])

#-----------------------------------------------------------------------------
# CTRL+SHIFT+R
#-----------------------------------------------------------------------------

## The key restarts the preset from anywhere, with the panel closed too. Plain R is
## the fourth ability slot (TechniqueDock, in _unhandled_input), which a key the
## panel handled never reaches.
func test_ctrl_shift_r_restarts_a_preset() -> void:
	var panel: DevPanel = _add_panel()
	DevManager.play_preset(_preset("restart_key", "Key test", [_step(Kind.SET_GOLD, "", 321.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	ResourceManager.set_gold(5.0)
	assert_false(panel.is_open(), "precondition: the panel is closed")
	var viewport: Viewport = panel.get_viewport()
	viewport.push_input(_r_key(true, true))
	assert_true(viewport.is_input_handled(), "the key is the panel's")
	await wait_process_frames(SWITCH_FRAMES)
	assert_eq(ResourceManager.get_gold(), 321.0, "the preset was built again")
	var session_preset: SavePresetData = DevManager.get_session_preset()
	assert_not_null(session_preset)
	if session_preset != null:
		assert_eq(session_preset.preset_id, "restart_key")

func test_ctrl_shift_r_leaves_the_key_alone_outside_a_preset() -> void:
	var panel: DevPanel = _add_panel()
	ResourceManager.set_gold(7.0)
	watch_signals(DevManager)
	var viewport: Viewport = panel.get_viewport()
	viewport.push_input(_r_key(true, true))
	assert_false(viewport.is_input_handled(), "outside a preset the key goes on, to ability slot 4")
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_not_emitted(DevManager, "session_changed", "and nothing restarts")
	assert_signal_not_emitted(DevManager, "session_switch_failed")
	assert_eq(ResourceManager.get_gold(), 7.0)

func test_only_ctrl_shift_r_restarts() -> void:
	var panel: DevPanel = _add_panel()
	DevManager.play_preset(_preset("near_misses", "Near misses", [_step(Kind.SET_GOLD, "", 321.0)]))
	await wait_process_frames(SWITCH_FRAMES)
	ResourceManager.set_gold(5.0)
	watch_signals(DevManager)
	var viewport: Viewport = panel.get_viewport()
	for key: InputEventKey in [_r_key(true, false), _r_key(false, true), _r_key(true, true, true)]:
		viewport.push_input(key)
		assert_false(viewport.is_input_handled(), "the panel leaves %s alone" % key.as_text())
	await wait_process_frames(SWITCH_FRAMES)
	assert_signal_not_emitted(DevManager, "session_changed", "Ctrl+R, Shift+R and a held key's echo restart nothing")
	assert_eq(ResourceManager.get_gold(), 5.0)
