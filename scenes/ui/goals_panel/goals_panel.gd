class_name GoalsPanel
extends Control

## The Goals board (lacquer kit §5.2), hung on its cords under the cultivator
## cabinet in the zone view and moved to the top right in adventures.
## Row 1 shows the first active quest's name and current step, with a
## current / target figure on the name row when the step can be measured.
## Row 2 is the Breakthrough milestone: Core Density towards level 100 on a jade
## rod. With no active quest, row 1 and the divider hide and the milestone row
## moves up into their place (the Rows container does the move).
## The board hugs its rows (spec: Goals): lacquer_goals_ai.png is cut into its
## cords and a top, a tiled middle and a bottom slice, so the board is 220 px
## tall with a quest and 150 px with the milestone alone. The cords are their
## own node, which the adventure view hides (set_cords_visible).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Board-local space under the last row: the milestone rod ends at 198 and the
## board at 220 (kit §5.2: screen 470 and 492).
const BOTTOM_PADDING: float = 22.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _cords: Control = %Cords
@onready var _rows: Control = %Rows
@onready var _quest_row: Control = %QuestRow
@onready var _divider: Control = %Divider
@onready var _quest_name_label: Label = %QuestNameLabel
@onready var _quest_figure: Control = %QuestFigure
@onready var _quest_figure_label: Label = %QuestFigureLabel
@onready var _quest_step_label: Label = %QuestStepLabel
@onready var _milestone_text_label: Label = %MilestoneTextLabel
@onready var _milestone_rod: LacquerRod = %MilestoneRod
@onready var _milestone_figure_label: Label = %MilestoneFigureLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_changed)
	QuestManager.quest_step_advanced.connect(_on_quest_step_advanced)
	QuestManager.quest_completed.connect(_on_quest_changed)
	PersistenceManager.save_data_reset.connect(_on_save_data_reset)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	ResourceManager.madra_changed.connect(_on_resource_changed)
	ResourceManager.gold_changed.connect(_on_resource_changed)
	refresh()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Re-reads the first active quest's current step and the Breakthrough
## milestone. Does nothing before the board is ready; _ready refreshes it.
func refresh() -> void:
	if not is_node_ready():
		return
	_update_quest()
	_update_milestone()

## Shows or hides the two cords the board hangs from. The zone view hangs the
## board under the cultivator cabinet; the adventure view puts it at the top
## right, where the cords would hang from nothing.
func set_cords_visible(cords_visible: bool) -> void:
	if not is_node_ready():
		return
	_cords.visible = cords_visible

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

## Row 1 from the first active quest, or hidden (with the divider) when there
## is none.
func _update_quest() -> void:
	var quest: QuestData = null
	var step: QuestStepData = null
	var quest_ids: Array[String] = QuestManager.get_active_quest_ids()
	if not quest_ids.is_empty():
		quest = QuestManager.get_quest_data(quest_ids[0])
		var step_index: int = QuestManager.get_current_step_index(quest_ids[0])
		if quest != null and step_index >= 0 and step_index < quest.steps.size():
			step = quest.steps[step_index]
	var has_quest: bool = step != null
	_quest_row.visible = has_quest
	_divider.visible = has_quest
	_fit_height()
	if not has_quest:
		return
	_quest_name_label.text = quest.quest_name
	_quest_step_label.text = step.description
	var condition: UnlockConditionData = _get_measured_condition(step)
	_quest_figure.visible = condition != null
	if condition != null:
		_quest_figure_label.text = "%d / %d" % [floori(condition.get_current_value()), floori(condition.get_target_value())]

## "Raise Core Density to 100", the rod at min(level, 100) / 100 and the
## min(level, 100) / 100 figure: Core Density has no cap in code, the
## milestone does.
func _update_milestone() -> void:
	var level: int = floori(CultivationManager.get_core_density_level())
	var breakthrough_level: int = CultivationManager.BREAKTHROUGH_LEVEL
	_milestone_text_label.text = "Raise Core Density to %d" % breakthrough_level
	_milestone_rod.set_fraction(float(level) / breakthrough_level)
	_milestone_figure_label.text = "%d / %d" % [mini(level, breakthrough_level), breakthrough_level]

## Sizes the board to its visible rows; the board art's slices follow.
func _fit_height() -> void:
	var rows_height: float = _rows.get_combined_minimum_size().y
	_rows.size = Vector2(_rows.size.x, rows_height)
	size = Vector2(size.x, _rows.position.y + rows_height + BOTTOM_PADDING)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The condition the step's figure measures: the first completion condition,
## when the step completes on conditions alone (an event id takes precedence
## in QuestManager) and every one of them is measurable. Null otherwise.
func _get_measured_condition(step: QuestStepData) -> UnlockConditionData:
	if not step.completion_event_id.is_empty() or step.completion_conditions.is_empty():
		return null
	for condition: UnlockConditionData in step.completion_conditions:
		if condition == null or not condition.is_measurable():
			return null
	return step.completion_conditions[0]

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## Handles quest_started and quest_completed.
func _on_quest_changed(_quest_id: String) -> void:
	_update_quest()

func _on_quest_step_advanced(_quest_id: String, _new_step_index: int) -> void:
	_update_quest()

func _on_save_data_reset() -> void:
	refresh()

## A level-up moves the milestone and any Core Density figure.
func _on_core_density_level_updated(_xp: float, _level: float) -> void:
	refresh()

## Madra and gold feed the figure of a RESOURCE_AMOUNT step.
func _on_resource_changed(_amount: float) -> void:
	_update_quest()
