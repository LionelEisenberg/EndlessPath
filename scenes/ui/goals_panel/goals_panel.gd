class_name GoalsPanel
extends Control

## The Goals board (lacquer kit §5.2), hung on its cords under the cultivator
## cabinet in the zone view, and under the vitals cabinet that stands in its
## place in adventures.
## Row 1 shows the first active quest's name and current step, with a
## current / target figure on the name row when the step can be measured; a step
## measured on Core Density shows the core's stars up to its target instead.
## Row 2 is the Breakthrough milestone over the core's stars (LacquerStarRow), in
## three states: each requirement of the Tribulation still short, a line each
## ("Fill your core" while the core is not full, then each main stat below the
## cap, "Strength Lv 3 / 10"); "Face the Tribulation" once nothing is missing;
## and "<Stage> reached", with no stars, once the stage has no next stage. The milestone waits for the
## stage's breakthrough_goal_condition to latch (Foundation's: NPC 4 talked, the
## end of Beat 3b's chain). With one row hidden the divider hides too and the
## other row takes its place (the Rows container does the move). With neither
## row, on a fresh save before its first quest, the board hides all of itself,
## its cords too, and lets clicks through to the map; its root stays visible,
## since MainView hides and restores the root under the overlays.
## The board hugs its rows (spec: Goals): lacquer_goals_ai.png is cut into a
## top, a tiled middle and a bottom slice, so the board is 220 px tall with both
## rows on one line each, 150 px with the milestone alone and 146 px with the
## quest alone (the least the top and bottom slices take). The cords are their
## own node and texture, which set_cords_visible() can hide; their two brass
## hooks are drawn on the top slice, which then swaps for a hookless copy.
## No text is cut off: the quest's name and step and the milestone's name and
## lines wrap in their 358 px, and the rows grow to hold them (the rows are
## containers, each text stacking under the one before it) and the board with
## them. A name that shares its line with the figure wraps before the figure,
## which stays at the right of the first line. Every row is an even number of px
## tall (a name's lines are 20 px; a detail line's 18, with the 1 px pad of
## wrap_pad.tres), so the board is too.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Board-local space under the last row: the milestone's stars end at 198 and the
## board at 220 (kit §5.2: screen 470 and 492).
const BOTTOM_PADDING: float = 22.0
## The strip at the top of the board's root that the cords hang in; the
## board's body starts under it. The cords (lacquer_goals_cords_ai.png, 24 px)
## also reach 4 px above the root, since each view hangs the board 4 px under
## its cabinet's rings and the cords must still start at them: the zone view
## under the cultivator cabinet grown for the six stats and Health
## (ZoneViewState.GOALS_POSITION), a run under the vitals cabinet
## (AdventureViewState.GOALS_POSITION).
const CORDS_HEIGHT: float = 20.0
## The quest name's line is shared with the figure: the gap between them (the
## name row's separation).
const NAME_FIGURE_GAP: float = 8.0
## The milestone's first line while the core is not full.
const FILL_CORE_LINE: String = "Fill your core"

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
@onready var _board: Control = %Board
@onready var _title_label: Label = %TitleLabel
@onready var _board_top: TextureRect = %BoardTop
@onready var _top_with_hooks: Texture2D = _board_top.texture
@onready var _rows: Control = %Rows
@onready var _quest_row: Control = %QuestRow
@onready var _divider: Control = %Divider
@onready var _quest_name_label: Label = %QuestNameLabel
@onready var _quest_figure: Control = %QuestFigure
@onready var _quest_figure_label: Label = %QuestFigureLabel
@onready var _quest_step_label: Label = %QuestStepLabel
@onready var _milestone_row: Control = %MilestoneRow
@onready var _milestone_text_label: Label = %MilestoneTextLabel
@onready var _quest_stars: LacquerStarRow = %QuestStars
@onready var _milestone_progress: Control = %ProgressMargin
@onready var _milestone_stars: LacquerStarRow = %MilestoneStars

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Whether the view hangs the board on its cords (set_cords_visible()). They
## show only while the board does.
var _cords_wanted: bool = true

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
	CharacterManager.stat_level_changed.connect(_on_stat_level_changed)
	UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
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
	_cords_wanted = cords_visible
	_cords.visible = cords_visible and _board.visible
	var hookless: bool = not cords_visible and top_without_hooks != null
	_board_top.texture = top_without_hooks if hookless else _top_with_hooks

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

## Row 1 from the first active quest, or hidden when there is none.
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
	if has_quest:
		_quest_name_label.text = quest.quest_name
		_quest_step_label.text = step.description
		var figure: String = step.get_progress_text()
		var core_target: int = _core_density_target(step)
		_quest_figure.visible = not figure.is_empty()
		_quest_figure_label.visible = core_target <= 0
		_quest_stars.visible = core_target > 0
		if _quest_stars.visible:
			_quest_stars.set_fills(_stars_up_to(core_target))
		elif _quest_figure.visible:
			_quest_figure_label.text = figure
		_fit_quest_name()
	_fit_rows()

## The milestone row, hidden until the stage's breakthrough_goal_condition has
## latched, then in one of three states. A stage with no next stage reads
## "<Stage> reached", with no stars: nothing is left to fill toward. With nothing
## missing it reads "Face the Tribulation" over the full stars. Otherwise it lists
## what is still missing, a line each: "Fill your core" while the core is not
## full, then each main stat below the cap, over the core's stars.
func _update_milestone() -> void:
	var condition: UnlockConditionData = CultivationManager.get_breakthrough_goal_condition()
	_milestone_row.visible = condition == null or UnlockManager.is_condition_unlocked(condition.condition_id)
	var reached: bool = not CultivationManager.has_next_stage()
	if reached:
		_milestone_text_label.text = "%s reached" % CultivationManager.get_current_advancement_stage_name()
	elif TribulationActionData.get_missing_requirements().is_empty():
		_milestone_text_label.text = "Face the Tribulation"
	else:
		var lines: Array[String] = []
		if not CultivationManager.is_core_full():
			lines.append(FILL_CORE_LINE)
		lines.append_array(TribulationActionData.get_missing_requirements(false))
		_milestone_text_label.text = "
".join(lines)
	_milestone_progress.visible = not reached
	_milestone_stars.set_fills(CultivationManager.get_star_fills_at(floori(CultivationManager.get_core_density_level())))
	_fit_rows()

## The Core Density level a quest step's figure measures, or 0 when it measures
## something else.
static func _core_density_target(step: QuestStepData) -> int:
	var condition: UnlockConditionData = step.get_measured_condition()
	if condition == null or condition.condition_type != UnlockConditionData.ConditionType.CULTIVATION_LEVEL:
		return 0
	return floori(condition.get_target_value())

## The core's stars as far as `target` levels reach: as many as the target needs
## (a level-10 step, one of Foundation's ten-level stars), filled as the core
## stands.
static func _stars_up_to(target: int) -> Array[float]:
	var cap: int = CultivationManager.get_core_density_cap()
	var fills: Array[float] = CultivationManager.get_star_fills_at(floori(CultivationManager.get_core_density_level()))
	if cap <= 0:
		return fills
	var count: int = ceili(float(mini(target, cap)) * fills.size() / cap)
	return fills.slice(0, count)

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

## The divider stands only between two rows. With neither row the board has no
## goal to show and hides all of itself but its root, and lets clicks through.
## Then the board fits its rows.
func _fit_rows() -> void:
	_divider.visible = _quest_row.visible and _milestone_row.visible
	var has_goal: bool = _quest_row.visible or _milestone_row.visible
	_board.visible = has_goal
	_title_label.visible = has_goal
	_cords.visible = has_goal and _cords_wanted
	mouse_filter = MOUSE_FILTER_STOP if has_goal else MOUSE_FILTER_IGNORE
	_fit_height()

## Sizes the board to its visible rows, an even height; the board art's slices
## follow. The top and bottom slices are the least it can be, which the quest row
## alone needs 4 px short of.
func _fit_height() -> void:
	var rows_height: float = ceilf(_rows.get_combined_minimum_size().y / 2.0) * 2.0
	_rows.size = Vector2(_rows.size.x, rows_height)
	var art_height: float = _board.get_combined_minimum_size().y + _board.offset_top - _board.offset_bottom
	size = Vector2(size.x, maxf(_rows.position.y + rows_height + BOTTOM_PADDING, art_height))

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

## A stat's new level moves a stat step's figure, and changes what the milestone
## still asks for.
func _on_stat_level_changed(_stat: CharacterAttributesData.AttributeType, _level: int) -> void:
	refresh()

## The stage's breakthrough_goal_condition latching puts the milestone on the
## board.
func _on_condition_unlocked(_condition_id: String) -> void:
	_update_milestone()

## Madra and gold feed the figure of a RESOURCE_AMOUNT step.
func _on_resource_changed(_amount: float) -> void:
	_update_quest()
