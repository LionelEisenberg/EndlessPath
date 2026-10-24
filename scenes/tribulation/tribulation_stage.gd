class_name TribulationStage
extends Control

## TribulationStage
## The Tribulation board's stage: the aura spheres that breathe about the core, and the
## brass arc that fills while the last breath is held. Both are drawn per art cell, one
## CELL (2) px square, so every pixel stays on the 2 px grid: no glow, no fade, no
## smoothing (docs/STYLE_GUIDE.md).
##
## Everything stands about CENTRE, a grid corner of the stage, and is measured in cells
## from it. One rule places the cells: the cell at offset (x, y) from the centre corner
## lies in the band [inner, outer) when inner <= hypot(x + 0.5, y + 0.5) < outer. The
## ring art is drawn by the same rule (docs/superpowers/mockups/tribulation-lacquer/gen/
## kit_tribulation.py), so a sphere at ratio 1.0, 65 cells out, stands on the ring's middle.
##
## A sphere breathing out is bright: a 2-cell band of Madra with a 1-cell crest of light
## Madra just inside it, the two colours swapped for an Echo's second sphere. A sphere
## breathing in is faint: a 1-cell tan band, dashed. The hold's arc is a brass band
## outside the ring that fills clockwise from 12 o'clock, in 24 whole steps.
##
## The board's scene gives this node two Control children that fill it, %SphereLayer
## (over the ring, under the core) and %ArcLayer (over the core). A CanvasItem may only
## draw during its own draw callback, so each layer's draw signal calls back here. The
## board calls show_frame() every frame of the trial, and clear() when it ends.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## A cell's side in px: one art pixel.
const CELL: int = 2

## The brass ring's radius in px, which is where a sphere of ratio 1.0 stands.
const RING_RADIUS_PX: int = 130

## The centre corner of the spheres and the arc, in the stage's space: a grid corner of
## the 900 x 600 stage.
const CENTRE: Vector2 = Vector2(450, 300)

## The hold arc's band, in cells from the centre corner: [75, 79), or 150 to 158 px.
const HOLD_ARC_INNER: int = 75
const HOLD_ARC_OUTER: int = 79

## The arc fills in this many whole steps, like the technique dock's cooldown sweep.
const HOLD_ARC_STEPS: int = 24

## A faint sphere's dashes: this many cells drawn, then this many skipped.
const DASH_CELLS: int = 4

## One cell's size in px.
const _CELL_SIZE: Vector2 = Vector2(CELL, CELL)

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The stage-space rects of each band's runs, by Vector2i(inner, outer). A frame draws up
## to two spheres and the arc, and a band reaches 165 cells out at the last breath, so
## each band is worked out once, when it is first drawn.
static var _band_rect_cache: Dictionary[Vector2i, Array] = {}

## The stage-space rects of each band's cells in clockwise order, by Vector2i(inner, outer).
static var _clockwise_rect_cache: Dictionary[Vector2i, Array] = {}

## The spheres this frame, as TribulationRun.spheres_at() gives them: {ratio, bright, echo}.
var _spheres: Array[Dictionary] = []

## How far the hold has run this frame, 0 to 1.
var _hold_progress: float = 0.0

@onready var _sphere_layer: Control = %SphereLayer
@onready var _arc_layer: Control = %ArcLayer

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_sphere_layer.draw.connect(_on_sphere_layer_draw)
	_arc_layer.draw.connect(_on_arc_layer_draw)
	# The arc's band is the biggest to sort, about 2000 cells. Have it ready before the hold.
	_clockwise_rects(HOLD_ARC_INNER, HOLD_ARC_OUTER)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns a sphere's radius in cells for its `ratio` of the ring's radius: 65 cells at
## 1.0, rounded.
static func radius_cells(ratio: float) -> int:
	return roundi(ratio * RING_RADIUS_PX / CELL)

## Returns the cells of the band [inner, outer) as horizontal runs one cell tall, in cell
## offsets from the centre corner, row by row from the top and left to right. The cells
## are those the band rule names (see the class comment). An inner edge at or below 0 makes
## a disc, and an outer edge not past the inner leaves no runs.
static func band_runs(inner: int, outer: int) -> Array[Rect2i]:
	# Twice a cell's offsets are odd whole numbers, so working in half cells keeps the rule
	# exact: the cell (x, y) is in the band when (2x + 1)^2 + (2y + 1)^2 lies in
	# [4 inner^2, 4 outer^2). The sum is never a multiple of 4, so no cell sits on an edge.
	var runs: Array[Rect2i] = []
	var inner_limit: int = 4 * maxi(inner, 0) * maxi(inner, 0)
	var outer_limit: int = 4 * outer * outer
	for y: int in range(-outer, outer):
		var row: int = (2 * y + 1) * (2 * y + 1)
		# From the middle outward, the row's cells in x = 0 to x_start - 1 lie inside the
		# hole and those in x_start to x_end - 1 inside the band. The row is symmetric about
		# the centre corner, so its left half mirrors the right (x to -1 - x).
		var x_end: int = _cells_below(outer_limit - row)
		if x_end == 0:
			continue
		var x_start: int = _cells_below(inner_limit - row)
		if x_start == 0:
			runs.append(Rect2i(-x_end, y, 2 * x_end, 1))
		elif x_start < x_end:
			runs.append(Rect2i(-x_end, y, x_end - x_start, 1))
			runs.append(Rect2i(x_start, y, x_end - x_start, 1))
	return runs

## Returns the cells of the band [inner, outer) in cell offsets from the centre corner,
## sorted by fposmod(atan2(x + 0.5, -(y + 0.5)), TAU): their angle clockwise from 12 o'clock.
## The first cell is the highest in column 0. Cells on one ray from the corner tie, and come
## in no particular order.
static func band_cells_clockwise(inner: int, outer: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for run: Rect2i in band_runs(inner, outer):
		for x: int in range(run.position.x, run.end.x):
			cells.append(Vector2i(x, run.position.y))
	var angles: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in cells:
		angles[cell] = fposmod(atan2(cell.x + 0.5, -(cell.y + 0.5)), TAU)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return angles[a] < angles[b])
	return cells

## Keeps this frame's spheres and hold progress from `run` at `t` seconds, and redraws
## the sphere and arc layers.
func show_frame(run: TribulationRun, t: float) -> void:
	_spheres = run.spheres_at(t)
	_hold_progress = run.hold_progress(t)
	_redraw_layers()

## Shows nothing: no spheres, and the arc empty.
func clear() -> void:
	_spheres = []
	_hold_progress = 0.0
	_redraw_layers()

## Returns the centre corner in global coordinates: where the core sits.
func centre_global() -> Vector2:
	return get_global_transform() * CENTRE

#-----------------------------------------------------------------------------
# DRAWING
#-----------------------------------------------------------------------------

## Draws the faint spheres, then the bright ones over them, so a bright sphere is never
## dashed over where two cross.
func _on_sphere_layer_draw() -> void:
	for sphere: Dictionary in _spheres:
		if not sphere["bright"]:
			_draw_faint_sphere(radius_cells(sphere["ratio"]))
	for sphere: Dictionary in _spheres:
		if sphere["bright"]:
			_draw_bright_sphere(radius_cells(sphere["ratio"]), sphere["echo"])

## Draws the hold's arc in brass: the first cells * steps / 24 cells of its band, where
## steps is the whole 24ths of the hold that have run.
func _on_arc_layer_draw() -> void:
	var cells: Array = _clockwise_rects(HOLD_ARC_INNER, HOLD_ARC_OUTER)
	for index: int in _arc_cell_count(cells.size(), _hold_progress):
		_arc_layer.draw_rect(cells[index], ThemeConstants.LACQUER_BRASS)

## Draws a bright sphere of `radius` cells: a 2-cell band with a 1-cell crest just inside
## it, the colours swapped for an `echo`.
func _draw_bright_sphere(radius: int, echo: bool) -> void:
	var band: Color = ThemeConstants.LACQUER_MADRA_HI if echo else ThemeConstants.LACQUER_MADRA
	var crest: Color = ThemeConstants.LACQUER_MADRA if echo else ThemeConstants.LACQUER_MADRA_HI
	for rect: Rect2 in _band_rects(radius - 2, radius):
		_sphere_layer.draw_rect(rect, band)
	for rect: Rect2 in _band_rects(radius - 3, radius - 2):
		_sphere_layer.draw_rect(rect, crest)

## Draws a faint sphere of `radius` cells: the 1-cell band [radius - 1, radius) in tan, with
## the cells whose index / DASH_CELLS is even kept, counting clockwise from 12 o'clock.
func _draw_faint_sphere(radius: int) -> void:
	var cells: Array = _clockwise_rects(radius - 1, radius)
	for index: int in cells.size():
		if _is_dash_cell(index):
			_sphere_layer.draw_rect(cells[index], ThemeConstants.LACQUER_TAN)

## Redraws both layers.
func _redraw_layers() -> void:
	_sphere_layer.queue_redraw()
	_arc_layer.queue_redraw()

#-----------------------------------------------------------------------------
# DRAWING RULES
#-----------------------------------------------------------------------------

## Returns how many of the arc band's `cell_count` cells show once the hold has run
## `hold_progress` (0 to 1): the first cell_count * steps / 24, where steps is the whole
## 24ths run.
static func _arc_cell_count(cell_count: int, hold_progress: float) -> int:
	var steps: int = clampi(floori(hold_progress * HOLD_ARC_STEPS), 0, HOLD_ARC_STEPS)
	@warning_ignore("integer_division")
	return cell_count * steps / HOLD_ARC_STEPS

## Returns whether the faint band's cell at `index`, counting clockwise from 12 o'clock, is
## drawn: the cells whose index / DASH_CELLS is even, so DASH_CELLS drawn and DASH_CELLS skipped.
static func _is_dash_cell(index: int) -> bool:
	return index % (2 * DASH_CELLS) < DASH_CELLS

#-----------------------------------------------------------------------------
# GEOMETRY
#-----------------------------------------------------------------------------

## Returns how many cells x = 0, 1, 2, ... have (2x + 1)^2 below `limit`: the cells of a
## row that lie inside an edge, counting from the centre corner outward.
static func _cells_below(limit: int) -> int:
	if limit <= 1:
		return 0
	# The count is a whole number only where the root is an odd whole number, and there sqrt()
	# is exact. Any other limit's root lies over 0.001 from one at these sizes (limits reach
	# 4 x 165^2), so rounding cannot tip the count.
	return ceili((sqrt(limit) - 1.0) / 2.0)

## Returns the stage-space rects of the runs of the band [inner, outer), worked out once.
static func _band_rects(inner: int, outer: int) -> Array:
	var key := Vector2i(inner, outer)
	if not _band_rect_cache.has(key):
		var rects: Array[Rect2] = []
		for run: Rect2i in band_runs(inner, outer):
			rects.append(Rect2(CENTRE + Vector2(run.position) * CELL, Vector2(run.size) * CELL))
		_band_rect_cache[key] = rects
	return _band_rect_cache[key]

## Returns the stage-space rects of the cells of the band [inner, outer) in clockwise
## order, worked out once.
static func _clockwise_rects(inner: int, outer: int) -> Array:
	var key := Vector2i(inner, outer)
	if not _clockwise_rect_cache.has(key):
		var rects: Array[Rect2] = []
		for cell: Vector2i in band_cells_clockwise(inner, outer):
			rects.append(Rect2(CENTRE + Vector2(cell) * CELL, _CELL_SIZE))
		_clockwise_rect_cache[key] = rects
	return _clockwise_rect_cache[key]
