class_name LacquerStarRow
extends HBoxContainer

## A row of up to ten Core Density stars on a frame strip (lacquer kit §4.3):
## lacquer_core_stars_strip_ai.png for the large star, or its small twin. Each
## star shows its fill in tenths: column 0 empty, 1 to 9 filled from its feet,
## 10 lit. set_fills() shows as many stars as it is handed fills and hides the
## rest. Handed the fills from before a run as well, a star that rose since shows
## on the jade row, with the part it had before drawn in brass over it (the
## strip's fill-only row). With `paper` the stars take the strip's parchment rows,
## for the end card's scroll. The scene holds the ten slots; this script only
## picks their frames.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The strip's columns: a star's fill in tenths, 0 to 10.
const STEPS: int = 10
## The strip's rows: brass, jade (a run's gain), the same two on parchment, and
## the brass fill alone, drawn over a jade star.
const ROW_BRASS: int = 0
const ROW_JADE: int = 1
const PAPER_ROWS: int = 2
const ROW_FILL_ONLY: int = 4
## A fill is a float share of a star: this much is read as the next tenth up, so
## 0.4 (from 34 levels of 100) shows four tenths and not three.
const STEP_EPSILON: float = 0.0001

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The star strip: frames of frame_size, STEPS + 1 columns, five rows.
@export var strip: Texture2D = null:
	set(value):
		strip = value
		_apply_strip()

## The size of one star's frame in the strip.
@export var frame_size: Vector2i = Vector2i(18, 18):
	set(value):
		frame_size = value
		_apply_strip()

## Takes the strip's parchment rows, for a star row on paper.
@export var paper: bool = false

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Each shown star's fill step and the step it had before, -1 with no before.
var _steps: Array[int] = []
var _before_steps: Array[int] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply_strip()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows one star per fill (0 to 1, as CultivationManager.get_star_fills_at()
## gives them) and hides the slots past them. With `before`, the fills from
## before a run, a star that rose since shows jade over its old part in brass.
func set_fills(fills: Array[float], before: Array[float] = []) -> void:
	_steps.clear()
	_before_steps.clear()
	var slots: Array[Node] = get_children()
	for index: int in slots.size():
		var slot: Control = slots[index] as Control
		slot.visible = index < fills.size()
		if not slot.visible:
			continue
		var step: int = step_of(fills[index])
		var before_step: int = step_of(before[index]) if index < before.size() else -1
		_steps.append(step)
		_before_steps.append(before_step)
		var gained: bool = before_step >= 0 and step > before_step
		var row: int = ROW_JADE if gained else ROW_BRASS
		if paper:
			row += PAPER_ROWS
		var base: LacquerStripRect = slot.get_child(0) as LacquerStripRect
		var over: LacquerStripRect = slot.get_child(1) as LacquerStripRect
		base.set_frame(step, row)
		over.visible = gained and before_step > 0
		if over.visible:
			over.set_frame(before_step, ROW_FILL_ONLY)

## How many stars the row shows.
func get_star_count() -> int:
	return _steps.size()

## The fill step star `index` shows, 0 (empty) to STEPS (lit).
func get_star_step(index: int) -> int:
	return _steps[index]

## True when star `index` rose since the fills handed as `before`: it shows jade.
func is_star_gained(index: int) -> bool:
	return _before_steps[index] >= 0 and _steps[index] > _before_steps[index]

## The step a fill shows as: its tenths, rounded down, 0 to STEPS.
static func step_of(fill: float) -> int:
	return clampi(floori(fill * STEPS + STEP_EPSILON), 0, STEPS)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Hands every slot's two rects the strip, and sizes the slots to a frame.
func _apply_strip() -> void:
	if not is_node_ready():
		return
	for slot: Node in get_children():
		(slot as Control).custom_minimum_size = Vector2(frame_size)
		for rect: Node in slot.get_children():
			(rect as LacquerStripRect).frame_size = frame_size
			(rect as LacquerStripRect).strip = strip
