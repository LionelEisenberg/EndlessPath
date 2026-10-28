class_name GoalsPanel
extends Control

## The Goals board (lacquer kit §5.2), hung on its cords under the cultivator
## cabinet in the zone view, and under the vitals cabinet that stands in its
## place in adventures.
## Row 1 shows the first active quest's name and current step, with a
## current / target figure on the name row when the step can be measured.
## Row 2 is the Breakthrough milestone on a jade rod, in three states: Core
## Density towards the stage's cap (level / cap), "Face the Tribulation" once the
## core is full, and "<Stage> reached" on a full rod, with no figure, once the
## stage has no next stage. With no active quest, row 1 and the divider hide and
## the milestone row moves up into their place (the Rows container does the move).
## The board hugs its rows (spec: Goals): lacquer_goals_ai.png is cut into a
## top, a tiled middle and a bottom slice, so the board is 220 px tall with a
## quest and 150 px with the milestone alone. The cords are their own node and
## texture, which set_cords_visible() can hide; their two brass hooks are drawn
## on the top slice, which then swaps for a hookless copy.
## No text is cut off: the quest's name and step and the milestone's name and
## line wrap in their 358 px, and the rows grow to hold them (the rows are
## containers, each text stacking under the one before it) and the board with
## them. A name that shares its line with the figure wraps before the figure,
## which stays at the right of the first line. Every row is an even number of px
## tall (a name's lines are 20 px; a detail line's 18, with the 1 px pad of
## wrap_pad.tres), so the board is too.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Board-local space under the last row: the milestone rod ends at 198 and the
## board at 220 (kit §5.2: screen 470 and 492).
const BOTTOM_PADDING: float = 22.0
## The strip at the top of the board's root that the cords hang in; the
## board's body starts under it. The cords (lacquer_goals_cords_ai.png, 24 px)
## also reach 4 px above the root, since the zone view hangs the board 4 px
## lower than the kit's 272 and they must still start at the cabinet's rings.
const CORDS_HEIGHT: float = 20.0
## The quest name's line is shared with the figure: the gap between them (the
## name row's separation).
const NAME_FIGURE_GAP: float = 8.0

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The board's top slice without the cords' two brass hooks, shown while the
## cords are hidden so no hook is left leading nowhere.
@export var top_without_hooks: Texture2D = null

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _cords: Control = %Cords
@onready var _board_top: TextureRect = %BoardTop
@onready var _top_with_hooks: Texture2D = _board_top.texture
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
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
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

## Shows or hides the two cords the board hangs from, and the brass hooks they
## end in, for a place where they would hang from nothing. Both the zone view
## and the adventure hang the board under a cabinet, cords on.
func set_cords_visible(cords_visible: bool) -> void:
	if not is_node_ready():
		return
	_cords.visible = cords_visible
	var hookless: bool = not cords_visible and top_without_hooks != null
	_board_top.texture = top_without_hooks if hookless else _top_with_hooks

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
	if has_quest:
		_quest_name_label.text = quest.quest_name
		_quest_step_label.text = step.description
		var condition: UnlockConditionData = _get_measured_condition(step)
		_quest_figure.visible = condition != null
		if condition != null:
			_quest_figure_label.text = "%d / %d" % [floori(condition.get_current_value()), floori(condition.get_target_value())]
		_fit_quest_name()
	_fit_height()

## The milestone row, in one of three states. A stage with no next stage reads
## "<Stage> reached" on a full rod, with no figure. A full core reads "Face the
## Tribulation" on a full rod, with the figure at cap / cap. Otherwise it asks to
## "Raise Core Density to <cap>", with the rod and the figure at level / cap.
func _update_milestone() -> void:
	var cap: int = CultivationManager.get_core_density_cap()
	var reached: bool = not CultivationManager.has_next_stage()
	if reached:
		_milestone_text_label.text = "%s reached" % CultivationManager.get_current_advancement_stage_name()
		_milestone_rod.set_fraction(1.0)
	elif CultivationManager.is_core_full():
		_milestone_text_label.text = "Face the Tribulation"
		_milestone_rod.set_fraction(1.0)
		_milestone_figure_label.text = "%d / %d" % [cap, cap]
	else:
		var level: int = floori(CultivationManager.get_core_density_level())
		_milestone_text_label.text = "Raise Core Density to %d" % cap
		_milestone_rod.set_fraction(float(level) / cap)
		_milestone_figure_label.text = "%d / %d" % [level, cap]
	_milestone_figure_label.visible = not reached
	_fit_height()

## The quest name wraps in the row's 358 px, less the figure and its gap while the
## figure shows. The width is set as a minimum and as the size, so the name's lines
## are counted at it at once (a change of width otherwise leaves the last height
## cached for the boxes above).
func _fit_quest_name() -> void:
	var room: float = _quest_step_label.custom_minimum_size.x
	if _quest_figure.visible:
		room -= NAME_FIGURE_GAP + _quest_figure.get_combined_minimum_size().x
	room = maxf(room, 1.0)
	_quest_name_label.custom_minimum_size.x = room
	_quest_name_label.size.x = room
	_quest_name_label.update_minimum_size()

## Sizes the board to its visible rows, an even height; the board art's slices
## follow.
func _fit_height() -> void:
	var rows_height: float = ceilf(_rows.get_combined_minimum_size().y / 2.0) * 2.0
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

## The breakthrough changes the stage: the milestone reads the new stage's cap,
## or that it has been reached.
func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	refresh()

## Madra and gold feed the figure of a RESOURCE_AMOUNT step.
func _on_resource_changed(_amount: float) -> void:
	_update_quest()
