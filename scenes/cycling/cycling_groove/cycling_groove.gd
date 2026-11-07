class_name CyclingGroove
extends Node2D

## CyclingGroove
## The carved channel along a cycling technique's path, drawn per art pixel: a
## cell is CELL (2) screen px square, so every pixel stays on the 2 px grid
## however the path turns, which a rotated line texture could not do.
## setup() rasterises the technique's curve once. Each point of the path covers
## a 2 x 2 block of cells, so the channel is about two cells (4 px) thick, and
## the cell under each of its bottom-edge cells is its lip. Cells are ink, or lit
## in the Madra ramp. The trail decides which: set_lit_spans() lights every cell
## whose path length falls in one of the stretches the ball paid along, so a slip
## leaves a dark gap, and set_lit_length() lights one stretch from the start.
## As a new cycle starts, hold_light() keeps what shows as the last cycle's light
## and set_swept_length() is the sweep that clears it: a cell is lit while the
## trail covers it, or while it held light the sweep has not reached yet.
## light_all() shows the whole groove lit.
## The node draws in its own space, which is the curve's space. Place it on an
## even screen px (a multiple of CELL), or its cells leave the 2 px grid.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## A cell's side in px: one art pixel.
const CELL: float = 2.0

## The cells a point covers, as offsets from the top-left cell of its block.
const _BLOCK: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

## Px along the curve between two samples of it.
const _SAMPLE_SPACING: float = 1.0

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The top-left corner of each cell in the node's space, by ascending path
## length. The arrays below run parallel to it.
var _cell_origins: PackedVector2Array = PackedVector2Array()
## The path length at which each cell lights, ascending.
var _cell_lengths: PackedFloat64Array = PackedFloat64Array()
## The Madra colour each cell takes once lit.
var _lit_colors: PackedColorArray = PackedColorArray()
## The top-left corner of each lip cell.
var _lip_origins: PackedVector2Array = PackedVector2Array()
## The ball's trail, as runs of cells: each pair of entries is the first cell a
## lit span covers and the cell after its last, ascending.
var _trail: PackedInt32Array = PackedInt32Array()
## 1 for each cell the trail lights, 0 for the others.
var _lit: PackedByteArray = PackedByteArray()
## 1 for each cell that showed lit as the last cycle ended, which the sweep
## clears, 0 for the others.
var _held: PackedByteArray = PackedByteArray()
## How many cells, counting from the start of the path, the sweep has cleared of
## the last cycle's light. The cells past them still show it.
var _swept_count: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _draw() -> void:
	var cell_size: Vector2 = Vector2(CELL, CELL)
	for origin: Vector2 in _lip_origins:
		draw_rect(Rect2(origin, cell_size), ThemeConstants.LACQUER_RIM)
	for index: int in _cell_origins.size():
		draw_rect(Rect2(_cell_origins[index], cell_size), _lit_colors[index] if _shows_lit(index) else ThemeConstants.LACQUER_INK)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the cells `points` cover, as a Dictionary of Vector2i cell to float
## path length: the shortest distance along `points` (the sum of the distances
## between consecutive points) at which a point covers the cell. Point p covers
## the 2 x 2 block whose top-left cell is floor(p / CELL - 0.5).
static func build_cells(points: PackedVector2Array) -> Dictionary:
	var cells: Dictionary[Vector2i, float] = {}
	var length: float = 0.0
	for index: int in points.size():
		if index > 0:
			length += points[index - 1].distance_to(points[index])
		var top_left: Vector2i = Vector2i(floori(points[index].x / CELL - 0.5), floori(points[index].y / CELL - 0.5))
		for offset: Vector2i in _BLOCK:
			var cell: Vector2i = top_left + offset
			# The length only grows along the points, so a cell's first cover
			# is its shortest: a crossing lights on the first pass.
			if not cells.has(cell):
				cells[cell] = length
	return cells

## Returns the lip cells of `cells`, a Dictionary as build_cells() returns: for
## every cell with no cell below it, that cell below.
static func lip_cells(cells: Dictionary) -> Array[Vector2i]:
	var lips: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var below: Vector2i = cell + Vector2i.DOWN
		if not cells.has(below):
			lips.append(below)
	return lips

## Rasterises `curve`, the technique's path in this node's space, and leaves the
## groove dark: no trail, and the whole path swept. A null curve, or one with no
## points, leaves it without cells.
func setup(curve: Curve2D) -> void:
	_cell_origins = PackedVector2Array()
	_cell_lengths = PackedFloat64Array()
	_lit_colors = PackedColorArray()
	_lip_origins = PackedVector2Array()
	if curve != null and curve.point_count > 0:
		_store(build_cells(_sample_points(curve)))
	_trail = PackedInt32Array()
	_lit = PackedByteArray()
	_lit.resize(_cell_lengths.size())
	_held = PackedByteArray()
	_held.resize(_cell_lengths.size())
	_swept_count = _cell_lengths.size()
	queue_redraw()

## Lights the ball's trail: every cell whose path length is within one of
## `spans`, each from its x to its y path length. The cells of a crossing light
## by their first pass. It only redraws when the lit cells change.
func set_lit_spans(spans: Array[Vector2]) -> void:
	var trail: PackedInt32Array = PackedInt32Array()
	for span: Vector2 in spans:
		var first: int = _cell_lengths.bsearch(span.x, true)
		var end: int = _cell_lengths.bsearch(span.y, false)
		if end > first:
			trail.append(first)
			trail.append(end)
	if trail == _trail:
		return
	var last: int = trail.size() - 1
	if trail.size() == _trail.size() and last > 0 and trail.slice(0, last) == _trail.slice(0, last) and trail[last] > _trail[last]:
		# The newest span grew with the ball, the usual frame: light its new cells.
		_light_run(_trail[last], trail[last])
	else:
		_lit.fill(0)
		for pair: int in range(0, trail.size(), 2):
			_light_run(trail[pair], trail[pair + 1])
	_trail = trail
	queue_redraw()

## Lights the trail as one span from the start: every cell whose path length is
## at or under `length`. A negative length lights none.
func set_lit_length(length: float) -> void:
	var spans: Array[Vector2] = []
	if length >= 0.0:
		spans.append(Vector2(-INF, length))
	set_lit_spans(spans)

## Keeps every cell that shows lit as the light the sweep will clear, and puts
## the trail out, as a new cycle starts.
func hold_light() -> void:
	for index: int in _held.size():
		_held[index] = 1 if _shows_lit(index) else 0
	set_lit_spans([] as Array[Vector2])
	queue_redraw()

## Clears the last cycle's light from every cell whose path length is at or under
## `length`, how far the sweep has run. The cells past it keep their light, and
## the trail still lights the cells it covers. A negative length clears none, so
## every cell past the trail shows lit. It only redraws when the swept cell count
## changes.
func set_swept_length(length: float) -> void:
	var count: int = _cell_lengths.bsearch(length, false)
	if count == _swept_count:
		return
	_swept_count = count
	queue_redraw()

## Shows every cell lit, as a full cycle leaves the groove.
func light_all() -> void:
	set_lit_length(INF)

## Returns how many cells show lit: those the trail covers and those still
## holding the last cycle's light past the sweep.
func get_lit_count() -> int:
	var count: int = 0
	for index: int in _cell_lengths.size():
		if _shows_lit(index):
			count += 1
	return count

## Returns whether the cell at `path_length` along the path, the first cell
## there, shows lit.
func is_lit_at(path_length: float) -> bool:
	var index: int = _cell_lengths.bsearch(path_length, true)
	return index < _cell_lengths.size() and _shows_lit(index)

## Returns how many cells the path has, lit or not. The lips are not counted.
func get_cell_count() -> int:
	return _cell_lengths.size()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Lights the trail's cells from `first` up to but not including `end`.
func _light_run(first: int, end: int) -> void:
	for index: int in range(first, end):
		_lit[index] = 1

## Returns whether the cell at `index` shows lit: the trail covers it, or it
## holds the last cycle's light and the sweep has not reached it.
func _shows_lit(index: int) -> bool:
	return _lit[index] == 1 or (index >= _swept_count and _held[index] == 1)

## Returns the Madra colour of `cell` once lit: the ramp's light top edge when
## no cell is above it, its deep bottom edge when no cell is below it, and its
## body otherwise. The top takes priority for a cell with neither.
static func _lit_color(cells: Dictionary, cell: Vector2i) -> Color:
	if not cells.has(cell + Vector2i.UP):
		return ThemeConstants.LACQUER_MADRA_HI
	if not cells.has(cell + Vector2i.DOWN):
		return ThemeConstants.LACQUER_MADRA_MID
	return ThemeConstants.LACQUER_MADRA

## Returns the points of `curve`: one per _SAMPLE_SPACING along its baked
## length, then its end point. The cubic sampling puts them where the ball,
## which follows the same curve, travels.
static func _sample_points(curve: Curve2D) -> PackedVector2Array:
	var path_length: float = curve.get_baked_length()
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in ceili(path_length / _SAMPLE_SPACING):
		points.append(curve.sample_baked(step * _SAMPLE_SPACING, true))
	points.append(curve.sample_baked(path_length, true))
	return points

## Stores `cells`, as build_cells() returns them, sorted by path length with
## each cell's lit colour, and stores their lips. Sorting once here is what lets
## a span and the sweep each cover a run of the cells.
func _store(cells: Dictionary) -> void:
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return cells[a] < cells[b])
	for cell: Vector2i in ordered:
		_cell_origins.append(Vector2(cell) * CELL)
		_cell_lengths.append(cells[cell])
		_lit_colors.append(_lit_color(cells, cell))
	for lip: Vector2i in lip_cells(cells):
		_lip_origins.append(Vector2(lip) * CELL)
