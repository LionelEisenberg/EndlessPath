class_name QuestEntry
extends VBoxContainer

## One row in the QuestWindow quest list. Displays a quest's name + either
## the current step description (active) or "✓ Complete" (completed).
##
## Preview: drop a QuestData into `preview_quest`, set `preview_state` and
## `preview_step_index`, then launch this scene (F6) to render the row
## standalone. When preview_quest is null, the row waits for a parent to call
## populate() at runtime.

enum State { ACTIVE, COMPLETED }

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

@export var preview_quest: QuestData
@export var preview_state: State = State.ACTIVE
@export var preview_step_index: int = 0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel
@onready var _detail_label: Label = %DetailLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if preview_quest != null:
		populate(preview_quest, preview_state, preview_step_index)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Populates the entry from quest data. For ACTIVE state, `step_index` must be
## a valid index into `quest.steps`. For COMPLETED state, `step_index` is unused.
func populate(quest: QuestData, state: State, step_index: int) -> void:
	if quest == null:
		_title_label.text = "(unknown quest)"
		_detail_label.text = ""
		return
	_title_label.text = quest.quest_name
	match state:
		State.ACTIVE:
			self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			if step_index >= 0 and step_index < quest.steps.size():
				_detail_label.text = quest.steps[step_index].description
			else:
				_detail_label.text = ""
		State.COMPLETED:
			self_modulate = Color(1.0, 1.0, 1.0, 0.55)
			_detail_label.text = "✓ Complete"
