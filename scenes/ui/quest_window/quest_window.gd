class_name QuestWindow
extends PanelContainer
## Floating collapsible quest panel. Non-draggable — positioned via anchor in
## main_game.tscn. Subscribes to QuestManager signals to rebuild its list and
## flash a badge dot on update. Badge clears when the panel is expanded.
##
## Preview: drop QuestData resources into `preview_active_quests` and/or
## `preview_completed_quests`, then launch this scene (F6) to render the panel
## populated. Preview mode skips QuestManager signal wiring so live events do
## not overwrite the preview list.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const QUEST_ENTRY_SCENE: PackedScene = preload("res://scenes/ui/quest_window/quest_entry/quest_entry.tscn")

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

## When non-empty, QuestWindow renders these as active quests (all at step 0)
## and skips live QuestManager wiring.
@export var preview_active_quests: Array[QuestData] = []
## When non-empty, QuestWindow renders these as completed quests.
@export var preview_completed_quests: Array[QuestData] = []
## When true, the panel starts expanded — useful for preview and for testing
## the content layout without clicking.
@export var preview_start_expanded: bool = false

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _collapse_button: Button = %CollapseButton
@onready var _entries_container: VBoxContainer = %EntriesContainer
@onready var _badge_dot: ColorRect = %BadgeDot
@onready var _empty_label: Label = %EmptyLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_collapsed: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_collapse_button.pressed.connect(_on_collapse_pressed)
	_badge_dot.visible = false
	_is_collapsed = not preview_start_expanded
	_content_panel.visible = not _is_collapsed
	_collapse_button.text = "▲" if not _is_collapsed else "▼"

	if _has_preview_data():
		_rebuild_from_preview()
		return

	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_changed)
		QuestManager.quest_step_advanced.connect(_on_quest_step_advanced)
		QuestManager.quest_completed.connect(_on_quest_changed)
	else:
		Log.critical("QuestWindow: QuestManager not available on ready!")
	_rebuild_list()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Toggles the quest list panel visibility. Clears the badge when opening.
func toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	_content_panel.visible = not _is_collapsed
	_collapse_button.text = "▲" if not _is_collapsed else "▼"
	if not _is_collapsed:
		_badge_dot.visible = false

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _has_preview_data() -> bool:
	return not preview_active_quests.is_empty() or not preview_completed_quests.is_empty()

func _rebuild_from_preview() -> void:
	_clear_entries()
	_empty_label.visible = false
	for quest: QuestData in preview_active_quests:
		if quest != null:
			_add_entry(quest, QuestEntry.State.ACTIVE, 0)
	for quest: QuestData in preview_completed_quests:
		if quest != null:
			_add_entry(quest, QuestEntry.State.COMPLETED, -1)

## Rebuilds the entry list from QuestManager state. Active quests first,
## completed quests below. Shows an empty-state label if both lists are empty.
func _rebuild_list() -> void:
	_clear_entries()
	if QuestManager == null:
		_empty_label.visible = true
		return
	var active_ids: Array[String] = QuestManager.get_active_quest_ids()
	var completed_ids: Array[String] = QuestManager.get_completed_quest_ids()
	var total: int = active_ids.size() + completed_ids.size()
	_empty_label.visible = total == 0
	for quest_id: String in active_ids:
		var quest: QuestData = QuestManager.get_quest_data(quest_id)
		if quest == null:
			continue
		var step_index: int = QuestManager.get_current_step_index(quest_id)
		_add_entry(quest, QuestEntry.State.ACTIVE, step_index)
	for quest_id: String in completed_ids:
		var quest: QuestData = QuestManager.get_quest_data(quest_id)
		if quest == null:
			continue
		_add_entry(quest, QuestEntry.State.COMPLETED, -1)

func _clear_entries() -> void:
	for child in _entries_container.get_children():
		if child == _empty_label:
			continue
		child.queue_free()

func _add_entry(quest: QuestData, state: QuestEntry.State, step_index: int) -> void:
	var entry: QuestEntry = QUEST_ENTRY_SCENE.instantiate()
	_entries_container.add_child(entry)
	entry.populate(quest, state, step_index)

func _on_collapse_pressed() -> void:
	toggle_collapse()

## Handles quest_started and quest_completed (both use (quest_id: String)).
func _on_quest_changed(_quest_id: String) -> void:
	_rebuild_list()
	_flash_badge_if_collapsed()

## Separate handler for quest_step_advanced (extra new_step_index arg).
func _on_quest_step_advanced(_quest_id: String, _new_step_index: int) -> void:
	_rebuild_list()
	_flash_badge_if_collapsed()

func _flash_badge_if_collapsed() -> void:
	if _is_collapsed:
		_badge_dot.visible = true
