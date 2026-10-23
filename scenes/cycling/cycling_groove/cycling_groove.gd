class_name CyclingGroove
extends Node2D

## CyclingGroove
## The carved channel along a cycling technique's path, drawn per art pixel: a
## cell is CELL (2) screen px square, so every pixel stays on the 2 px grid
## however the path turns, which a rotated line texture could not do.
## setup() rasterises the technique's curve once. Each point of the path covers
## a 2 x 2 block of cells, so the channel is about two cells (4 px) thick, and
## the cell under each of its bottom-edge cells is its lip. Cells are ink, or lit
## in the Madra ramp. Two lengths along the path decide which: set_lit_length()
## is the ball's trail, every cell within the length the ball has travelled, and
## set_swept_length() is the sweep that clears the last cycle's light as a new
## cycle starts. A cell is lit while the trail covers it or the sweep has not
## reached it yet. light_all() shows the whole groove lit, as a full cycle leaves
## it.
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
## How many cells, counting from the start of the path, the ball's trail lights.
var _lit_count: int = 0
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
		var lit: bool = index < _lit_count or index >= _swept_count
		draw_rect(Rect2(_cell_origins[index], cell_size), _lit_colors[index] if lit else ThemeConstants.LACQUER_INK)

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
	_lit_count = 0
	_swept_count = _cell_lengths.size()
	queue_redraw()

## Lights the ball's trail: every cell whose path length is at or under `length`,
## the distance the ball has travelled along the path. A negative length lights
## none. It only redraws when the trail's cell count changes.
func set_lit_length(length: float) -> void:
	var count: int = _cell_lengths.bsearch(length, false)
	if count == _lit_count:
		return
	_lit_count = count
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

## Returns how many cells show lit: those the trail covers and those past the
## sweep.
func get_lit_count() -> int:
	return _lit_count + maxi(0, _cell_lengths.size() - maxi(_swept_count, _lit_count))

## Returns how many cells the path has, lit or not. The lips are not counted.
func get_cell_count() -> int:
	return _cell_lengths.size()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

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
## set_lit_length() and set_swept_length() each cover a prefix of the cells.
func _store(cells: Dictionary) -> void:
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return cells[a] < cells[b])
	for cell: Vector2i in ordered:
		_cell_origins.append(Vector2(cell) * CELL)
		_cell_lengths.append(cells[cell])
		_lit_colors.append(_lit_color(cells, cell))
	for lip: Vector2i in lip_cells(cells):
		_lip_origins.append(Vector2(lip) * CELL)
