extends VBoxContainer

## The dev panel's Saves tab: the session and the saves behind it.
##
## At the top, what the session plays (a preset, your save or a --save file), where it
## writes ("in memory, not saved" when nothing does), why saving is off when it is,
## the preset that built the save when one did (your save after a Keep included, so
## its figures are never taken for a playtest's), and the save's version, playtime,
## stage, Core Density and gold. Under it, each beat of the story route with the
## playtime at which its reached_when first happened, or "reached, no time recorded"
## where it happened with no time kept: a build records no play, and saves from
## before play stats kept none.
## Restart preset (also Ctrl+Shift+R, which DevPanel handles) and Back to my save
## switch the session. Then a row per preset, which plays or pins it, "Save this game
## as a preset", and your save: a new game, Keep as my save, Save now, the autosave
## switch, the backups with Restore, and the save folder. New game, Keep and Restore
## write over your save, so each needs a second click within 3 s (ConfirmTimer, in
## real seconds whatever the time speed), and none takes keyboard focus: Space or
## Enter would otherwise confirm the overwrite.
##
## Why a switch was refused or failed, a pin that would not write, what Save now did
## and a folder that would not open show in a status line that stands under the part
## that scrolls, so it is in view wherever the tab is scrolled to: the tab is taller
## than the panel, and a refusal from its top must not pass for a switch that ran.
##
## A switch runs on the next frame (DevManager), and in a real run it frees the panel
## and builds it again: the tab reads the session when it is built, and shows
## DevManager.get_last_switch_failure(), since a switch that fails midway reports it
## while no tab is there to hear it. The tab refreshes on session_changed (a GUT run
## frees no scene), shows the reason session_switch_failed carries, refreshes when it
## is shown, and refreshes the playtime once a second while it is in view.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const PRESET_ROW_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/rows/dev_preset_row.tscn")

## Where the session line says a session in memory writes.
const _IN_MEMORY: String = "in memory, not saved"

## A beat whose reached_when has not happened in this save.
const _NOT_REACHED: String = "not reached"

## A beat whose reached_when has happened with no first time kept for it.
const _REACHED_UNTIMED: String = "reached, no time recorded"

## A beat with no reached_when: nothing marks it reached.
const _NOT_TRACKED: String = "not tracked (no reached_when)"

## What New game, Keep and Restore read while they wait for their second click.
const _NEW_GAME_ARMED: String = "Click again to start a new game"
const _KEEP_ARMED: String = "Click again to keep"
const _RESTORE_ARMED: String = "Click again to restore"

## What the backup picker shows when your save has no backups.
const _NO_BACKUPS: String = "No backups"

## The stamp in a backup's file name, <stem>.<stamp>.<extension>: the UTC date and
## time, then "-N" for a copy made in the same second as another (SaveFiles.backup()).
const _BACKUP_STAMP_PATTERN: String = "^(\\d{4})(\\d{2})(\\d{2})-(\\d{2})(\\d{2})(\\d{2})(?:-(\\d+))?$"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _session_label: Label = %SessionLabel
@onready var _beats_label: Label = %BeatsLabel
@onready var _restart_button: Button = %RestartButton
@onready var _back_button: Button = %BackButton
@onready var _preset_list: VBoxContainer = %PresetList
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _description_edit: LineEdit = %DescriptionEdit
@onready var _save_preset_button: Button = %SavePresetButton
@onready var _save_preset_status: Label = %SavePresetStatus
@onready var _new_game_button: Button = %NewGameButton
@onready var _keep_button: Button = %KeepButton
@onready var _save_now_button: Button = %SaveNowButton
@onready var _autosave_check: CheckButton = %AutosaveCheck
@onready var _backup_option: OptionButton = %BackupOption
@onready var _restore_button: Button = %RestoreButton
@onready var _open_folder_button: Button = %OpenFolderButton
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _saves_status: Label = %SavesStatus
@onready var _confirm_timer: Timer = %ConfirmTimer
@onready var _refresh_timer: Timer = %RefreshTimer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The button waiting for its second click, New game, Keep or Restore, or null.
var _armed_button: Button = null

## What New game, Keep and Restore read when they are not waiting for a second click.
var _resting_texts: Dictionary[Button, String] = {}

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_resting_texts = {_new_game_button: _new_game_button.text, _keep_button: _keep_button.text, _restore_button: _restore_button.text}
	_restart_button.pressed.connect(DevManager.restart_preset)
	_back_button.pressed.connect(DevManager.back_to_my_save)
	_save_preset_button.pressed.connect(_on_save_preset_pressed)
	_new_game_button.pressed.connect(_on_confirm_pressed.bind(_new_game_button, _NEW_GAME_ARMED, DevManager.new_game))
	_keep_button.pressed.connect(_on_confirm_pressed.bind(_keep_button, _KEEP_ARMED, DevManager.keep_as_my_save))
	_save_now_button.pressed.connect(_on_save_now_pressed)
	_autosave_check.toggled.connect(_on_autosave_toggled)
	_restore_button.pressed.connect(_on_confirm_pressed.bind(_restore_button, _RESTORE_ARMED, _restore_picked_backup))
	_open_folder_button.pressed.connect(_on_open_folder_pressed)
	_confirm_timer.timeout.connect(_disarm)
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	visibility_changed.connect(_on_visibility_changed)
	DevManager.session_changed.connect(_on_session_changed)
	DevManager.session_switch_failed.connect(_on_session_switch_failed)
	_refresh()
	_show_status(DevManager.get_last_switch_failure())

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A switch has run: the tab shows the session it brought, and why the switch failed
## if it did ("" once one works, which clears the line).
func _on_session_changed() -> void:
	_refresh()
	_show_status(DevManager.get_last_switch_failure())

## A switch was refused or failed: the tab shows why, and the session as it stands (a
## failure midway brings back the session it left, and session_changed follows). The
## rows are left as they are: a row's own Play can be what was refused, and a row
## freed inside its press would leave the click without its button.
func _on_session_switch_failed(reason: String) -> void:
	_show_status(reason)
	_show_session()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()

## The playtime goes on while the game runs, so the session line follows it while the
## tab is in view.
func _on_refresh_timer_timeout() -> void:
	if is_visible_in_tree():
		_show_session()

## A first click arms the button: it asks for a second, which runs `action` if it
## comes before ConfirmTimer runs out. Arming one button disarms the others.
func _on_confirm_pressed(button: Button, armed_text: String, action: Callable) -> void:
	if _armed_button == button:
		_disarm()
		action.call()
		return
	_disarm()
	_armed_button = button
	button.text = armed_text
	_confirm_timer.start()

## Pins the row's preset, or unpins it when it is the pinned one, and shows the pin on
## every row.
func _on_pin_pressed(preset: SavePresetData) -> void:
	var pinned: bool = DevManager.get_pinned_preset_id() == preset.preset_id
	var error: Error = DevManager.pin_preset("" if pinned else preset.preset_id)
	if error != OK:
		_show_status("Could not write the pin to %s (error %d)" % [LaunchOptions.pin_file_path(), error])
	_show_pins()

## Saves this game as a preset, and lists it, or says why it was not saved.
func _on_save_preset_pressed() -> void:
	var title: String = _title_edit.text.strip_edges()
	var refusal: String = DevManager.save_as_preset(_title_edit.text, _description_edit.text)
	if refusal != "":
		_show_message(_save_preset_status, refusal)
		return
	_title_edit.clear()
	_description_edit.clear()
	_show_message(_save_preset_status, "Saved this game as the preset '%s'" % title)
	_fill_presets()

func _on_save_now_pressed() -> void:
	_show_status(_save_now())

## Turns autosave on or off for the session, and logs a [DEV] line.
func _on_autosave_toggled(pressed: bool) -> void:
	PersistenceManager.autosave_enabled = pressed
	DevCommands.log_dev_line("Autosave: %s" % ("ON" if pressed else "OFF"))

func _on_open_folder_pressed() -> void:
	var folder: String = ProjectSettings.globalize_path("user://")
	var error: Error = OS.shell_open(folder)
	if error != OK:
		_show_status("Could not open %s (error %d)" % [folder, error])

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Shows the session and everything that follows from it as it is now, and disarms a
## button waiting for its second click.
func _refresh() -> void:
	_disarm()
	_show_session()
	var kind: DevManager.SessionKind = DevManager.get_session_kind()
	_restart_button.disabled = kind != DevManager.SessionKind.PRESET
	_back_button.disabled = kind == DevManager.SessionKind.YOUR_SAVE
	_keep_button.disabled = kind == DevManager.SessionKind.YOUR_SAVE
	_autosave_check.set_pressed_no_signal(PersistenceManager.autosave_enabled)
	_fill_presets()
	_fill_backups()

func _show_session() -> void:
	_session_label.text = _session_text()
	_beats_label.text = _beats_text()

## "Preset: Tribulation ready · in memory, not saved", "Your save · user://save.tres"
## or "File · <path>"; then "Saving is off: <why>" when it is; then "Built from preset
## '<id>'" when the save's play stats name the preset that built it; then the save's
## "Version 1 · Playtime 12:34 · Foundation, Core Density 42 / 100 · 120 gold".
func _session_text() -> String:
	var where: String = _IN_MEMORY if PersistenceManager.is_in_memory() else PersistenceManager.save_path
	var lines := PackedStringArray(["%s · %s" % [_session_name(), where]])
	if PersistenceManager.is_save_blocked():
		lines.append("Saving is off: %s" % PersistenceManager.get_block_reason())
	var save: SaveGameData = PersistenceManager.save_game_data
	if save.stats.built_from_preset != "":
		lines.append("Built from preset '%s'" % save.stats.built_from_preset)
	lines.append("Version %d · Playtime %s · %s, Core Density %d / %d · %d gold" % [
		save.save_version,
		_clock(save.stats.play_time),
		CultivationManager.get_current_advancement_stage_name(),
		int(CultivationManager.get_core_density_level()),
		CultivationManager.get_core_density_cap(),
		floori(ResourceManager.get_gold()),
	])
	return "\n".join(lines)

func _session_name() -> String:
	var kind: DevManager.SessionKind = DevManager.get_session_kind()
	if kind == DevManager.SessionKind.PRESET:
		var preset: SavePresetData = DevManager.get_session_preset()
		return "Preset: %s" % (preset.title if preset != null else "")
	if kind == DevManager.SessionKind.FILE:
		return "File"
	return "Your save"

## One line per beat of the route, "<title> — <how far>" (_beat_progress()).
func _beats_text() -> String:
	var route: StoryRouteData = DevManager.get_route()
	if route == null:
		return ""
	var stats: PlayStatsData = PersistenceManager.save_game_data.stats
	var lines := PackedStringArray()
	for beat: StoryBeatData in route.beats:
		lines.append("%s — %s" % [beat.title, _beat_progress(beat.reached_when, stats)])
	return "\n".join(lines)

## How far the save has come to a beat, read from the event or unlock condition that
## marks it reached (its reached_when): the playtime it first happened at ("2:41");
## "reached, no time recorded" when it has happened (the event fired, or the condition
## latched) and the stats keep no time for it, as after a preset build, which records
## no play, or in a save from before play stats; "not reached"; or "not tracked (no
## reached_when)" when nothing marks the beat.
func _beat_progress(reached_when: String, stats: PlayStatsData) -> String:
	if reached_when == "":
		return _NOT_TRACKED
	var at: float = stats.first_time_of(reached_when)
	if at >= 0.0:
		return _clock(at)
	if EventManager.has_event_triggered(reached_when) or UnlockManager.is_condition_unlocked(reached_when):
		return _REACHED_UNTIMED
	return _NOT_REACHED

## Seconds of playtime as a clock: "2:41", and "1:02:05" from an hour on.
func _clock(seconds: float) -> String:
	var total: int = floori(seconds)
	var hours: int = floori(total / 3600.0)
	var minutes: int = floori((total % 3600) / 60.0)
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, total % 60]
	return "%d:%02d" % [minutes, total % 60]

## Shows a row per preset, in get_presets()'s order, each with its pin. The rows
## already there are kept and given the presets in order; a row is added for each
## preset the list gained and removed for each it lost, so showing the tab again
## builds nothing.
func _fill_presets() -> void:
	var presets: Array[SavePresetData] = DevManager.get_presets()
	while _preset_list.get_child_count() > presets.size():
		var extra: Node = _preset_list.get_child(_preset_list.get_child_count() - 1)
		_preset_list.remove_child(extra)
		extra.queue_free()
	while _preset_list.get_child_count() < presets.size():
		var row: DevPresetRow = PRESET_ROW_SCENE.instantiate()
		_preset_list.add_child(row)
		row.play_pressed.connect(DevManager.play_preset)
		row.pin_pressed.connect(_on_pin_pressed)
	var pinned: String = DevManager.get_pinned_preset_id()
	for index: int in presets.size():
		var row: DevPresetRow = _preset_list.get_child(index)
		row.set_preset(presets[index], presets[index].preset_id == pinned)

## Shows on every row whether its preset is the pinned one.
func _show_pins() -> void:
	var pinned: String = DevManager.get_pinned_preset_id()
	for row: DevPresetRow in _preset_list.get_children():
		row.set_preset(row.get_preset(), row.get_preset().preset_id == pinned)

## Lists your save's backups, newest first, each item's metadata its path, and keeps
## the one picked before when it is still there. With none, the picker says so and
## Restore is off.
func _fill_backups() -> void:
	var picked: String = _picked_backup()
	_backup_option.clear()
	var backups: PackedStringArray = _list_backups()
	for path: String in backups:
		_backup_option.add_item(_backup_label(path))
		_backup_option.set_item_metadata(_backup_option.item_count - 1, path)
		if path == picked:
			_backup_option.select(_backup_option.item_count - 1)
	if backups.is_empty():
		_backup_option.add_item(_NO_BACKUPS)
	_backup_option.disabled = backups.is_empty()
	_restore_button.disabled = backups.is_empty()

## Your save's backups, newest first, or none in a run with no main save (every GUT
## run), which has no save to back up.
func _list_backups() -> PackedStringArray:
	if PersistenceManager.main_save_path == "":
		return PackedStringArray()
	return PersistenceManager.list_backups()

## How the picker names a backup: "save · 2026-10-25 11:17:15 (UTC)", read from its
## file name, with "#2" after the time for the second copy made in that second. A
## file named any other way shows its file name.
func _backup_label(path: String) -> String:
	var base_name: String = path.get_file().get_basename()
	var stamp: RegExMatch = RegEx.create_from_string(_BACKUP_STAMP_PATTERN).search(base_name.get_extension())
	if stamp == null:
		return path.get_file()
	var copy: String = "" if stamp.get_string(7) == "" else " #" + stamp.get_string(7)
	return "%s · %s-%s-%s %s:%s:%s%s (UTC)" % [
		base_name.get_basename(),
		stamp.get_string(1), stamp.get_string(2), stamp.get_string(3),
		stamp.get_string(4), stamp.get_string(5), stamp.get_string(6),
		copy,
	]

## The path of the backup the picker shows, or "" when it shows none.
func _picked_backup() -> String:
	if _backup_option.selected < 0:
		return ""
	var path: Variant = _backup_option.get_item_metadata(_backup_option.selected)
	return path if path is String else ""

func _restore_picked_backup() -> void:
	var path: String = _picked_backup()
	if path != "":
		DevManager.restore_backup(path)

## Writes the session's save (PersistenceManager.save_data()), and says what
## happened: saved, or why not, which it names from the session: it lives in memory
## and has no file, saving is off (and why), or the write failed. A save is logged as
## a [DEV] line.
func _save_now() -> String:
	var error: Error = PersistenceManager.save_data()
	if error == OK:
		DevCommands.log_dev_line("Saved the game to %s" % PersistenceManager.save_path)
		return "Saved to %s" % PersistenceManager.save_path
	if PersistenceManager.is_in_memory():
		return "Not saved: this session lives in memory, so there is no file to write"
	if PersistenceManager.is_save_blocked():
		return "Not saved. Saving is off: %s" % PersistenceManager.get_block_reason()
	return "Could not write %s: %s (error %d)" % [PersistenceManager.save_path, error_string(error), error]

## Puts the waiting button back as it reads at rest, if one waits.
func _disarm() -> void:
	_confirm_timer.stop()
	if _armed_button == null:
		return
	_armed_button.text = _resting_texts[_armed_button]
	_armed_button = null

## Shows the text in the status line under the tab, and hides the line, and the panel
## it stands in, while the text is empty.
func _show_status(text: String) -> void:
	_show_message(_saves_status, text)
	_status_panel.visible = text != ""

## Shows the text in the label, and hides the label while the text is empty.
func _show_message(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""
