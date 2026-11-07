class_name StatTooltip
extends PanelContainer

## StatTooltip
## The figure a hovered stat cell shows beside the cultivator cabinet: the plain
## board (board9.tres, 208 wide at least, as tall as its text) holding the stat
## and its level ("Spirit Lv 4") over its XP toward the next level ("105 / 196 XP
## to Lv 5"), or, at the stage's cap, "Lv 10 is Foundation's cap." and, when a
## stage follows, "Break through to train it further." It names no trainer. The
## XP floors and the cost rounds up, as the cabinet's core figure does, so an
## unmet cost never reads as met. A long line wraps and the board grows; its
## height is rounded up to even so its 2x art stays on the 2 px grid. It is
## top-level and never takes the pointer, so its owner places it by screen
## position (show_at()) and hides it. set_text() fills it with any two lines,
## so other screens reuse the piece.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const TITLE_FORMAT: String = "%s Lv %d"
const NEXT_LEVEL_FORMAT: String = "%d / %d XP to Lv %d"
const CAP_FORMAT: String = "Lv %d is %s's cap."
const BREAK_THROUGH: String = "Break through to train it further."

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel
@onready var _figure_label: Label = %FigureLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	resized.connect(_fit)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Fills the board with the stat as a cell shows it: its level, its XP toward the
## next level and that level's cost, or the cap of `stage_name` when capped.
func set_figure(stat: CharacterAttributesData.AttributeType, level: int, xp: float, xp_to_next: float, capped: bool, stage_name: String, has_next_stage: bool) -> void:
	_title_label.text = TITLE_FORMAT % [StatDisplay.name_of(stat), level]
	_figure_label.text = figure_text(level, xp, xp_to_next, capped, stage_name, has_next_stage)
	_fit()

## Fills the board with any title and figure line, for an owner other than a
## stat cell (the cycling board's locked Auto toggle).
func set_text(title: String, figure: String) -> void:
	_title_label.text = title
	_figure_label.text = figure
	_fit()

## Shows the board with its top-left corner at `top_left` (screen px).
func show_at(top_left: Vector2) -> void:
	global_position = top_left
	show()

## The figure line: the XP toward the next level, or the cap and what lifts it.
static func figure_text(level: int, xp: float, xp_to_next: float, capped: bool, stage_name: String, has_next_stage: bool) -> String:
	if capped:
		var cap_line: String = CAP_FORMAT % [level, stage_name]
		return "%s %s" % [cap_line, BREAK_THROUGH] if has_next_stage else cap_line
	return NEXT_LEVEL_FORMAT % [floori(xp), ceili(xp_to_next), level + 1]

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Hugs the content, the height rounded up to an even number of px. Runs again
## whenever the board resizes (its content grew).
func _fit() -> void:
	var minimum: Vector2 = get_combined_minimum_size()
	size = Vector2(minimum.x, ceilf(minimum.y / 2.0) * 2.0)
