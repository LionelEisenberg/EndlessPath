class_name QuestToast
extends PanelContainer
## Single-line toast popup for quest updates. Anchored top-center. Plays a
## fade+slide animation on each message. Queues messages when busy so multiple
## rapid updates don't clobber each other. Independent of QuestWindow state.
##
## Preview: set `preview_message` to any string and launch this scene (F6) to
## see the animation play once. Preview mode skips QuestManager signal wiring.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const FADE_IN_DURATION: float = 0.2
const HOLD_DURATION: float = 2.5
const FADE_OUT_DURATION: float = 0.4
const SLIDE_OFFSET_PX: float = 20.0

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

## When non-empty, plays this message once on _ready and skips signal wiring.
@export var preview_message: String = ""

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _label: Label = %MessageLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _queue: Array[String] = []
var _is_playing: bool = false
var _base_position_y: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	modulate.a = 0.0
	_base_position_y = position.y

	if not preview_message.is_empty():
		show_message(preview_message)
		return

	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_started)
		QuestManager.quest_step_advanced.connect(_on_quest_step_advanced)
		QuestManager.quest_completed.connect(_on_quest_completed)
	else:
		Log.critical("QuestToast: QuestManager not available on ready!")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Queues a toast message. If no toast is currently playing, starts immediately.
func show_message(text: String) -> void:
	_queue.append(text)
	if not _is_playing:
		_play_next()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _play_next() -> void:
	if _queue.is_empty():
		_is_playing = false
		return
	_is_playing = true
	var message: String = _queue.pop_front()
	_label.text = message
	modulate.a = 0.0
	position.y = _base_position_y - SLIDE_OFFSET_PX
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_property(self, "position:y", _base_position_y, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(_play_next)

func _on_quest_started(quest_id: String) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	var display_name: String = quest.quest_name if quest else quest_id
	show_message("Quest Started: %s" % display_name)

func _on_quest_step_advanced(quest_id: String, new_step_index: int) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	if quest == null or new_step_index < 0 or new_step_index >= quest.steps.size():
		show_message("Quest Updated")
		return
	show_message("Quest Updated: %s" % quest.steps[new_step_index].description)

func _on_quest_completed(quest_id: String) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	var display_name: String = quest.quest_name if quest else quest_id
	show_message("Quest Complete: %s" % display_name)
