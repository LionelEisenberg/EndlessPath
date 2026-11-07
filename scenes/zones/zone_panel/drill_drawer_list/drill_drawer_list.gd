class_name DrillDrawerList
extends Control

## The zone chest's list of drill drawers while the body refining board is up
## (lacquer kit §5.5): one DrillDrawer per learned drill, in the order they were
## learned, a drawer (92, taller while its text takes more lines) and a gap (8)
## apart. It neither scrolls nor folds: the zone panel places it under the header
## and the chest hugs it. It rebuilds when a drill is learned, shown or not, so it
## is current the moment the chest turns to it, and it refreshes every drawer when
## the equipped drill changes, because the drawers do not listen to
## BodyRefiningManager.

## Emitted when the drawers are rebuilt or one of them changes height, which
## changes the list's height.
signal layout_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DRAWER_SCENE: PackedScene = preload("res://scenes/body_refining/drill_drawer/drill_drawer.tscn")

## The gap between two drawers (kit §5.5).
const DRAWER_GAP: float = 8.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _column: VBoxContainer = %Drawers

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The drawers, top to bottom.
var _drawers: Array[DrillDrawer] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	BodyRefiningManager.drill_unlocked.connect(_on_drill_unlocked)
	BodyRefiningManager.equipped_drill_changed.connect(_on_equipped_drill_changed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Replaces the drawers with one per learned drill, in the order they were learned.
func build() -> void:
	_clear()
	for drill: DrillData in BodyRefiningManager.get_unlocked_drills():
		var drawer: DrillDrawer = DRAWER_SCENE.instantiate() as DrillDrawer
		drawer.setup(drill)
		_column.add_child(drawer)
		drawer.height_changed.connect(_on_drawer_height_changed)
		_drawers.append(drawer)
	layout_changed.emit()

## Returns the height of the drawers and the gaps between them: each drawer's
## height (92 for a line of name and one of each line under it) plus (n - 1) x 8,
## or 0 for none.
func get_content_height() -> float:
	if _drawers.is_empty():
		return 0.0
	var height: float = (_drawers.size() - 1) * DRAWER_GAP
	for drawer: DrillDrawer in _drawers:
		height += drawer.custom_minimum_size.y
	return height

## Returns the rows the board transition slides: the drawers, top to bottom. A
## drawer slides by its position.x, which the column sets only when it sorts.
func get_slide_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for drawer: DrillDrawer in _drawers:
		rows.append(drawer)
	return rows

## Returns the drawer of the drill, or null when the list has none.
func get_drawer(drill_id: String) -> DrillDrawer:
	for drawer: DrillDrawer in _drawers:
		if drawer.drill.id == drill_id:
			return drawer
	return null

## Returns the number of drawers.
func get_drawer_count() -> int:
	return _drawers.size()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Takes the drawers out of the column at once, so it measures without them
## before they are freed at the end of the frame.
func _clear() -> void:
	for drawer: DrillDrawer in _drawers:
		_column.remove_child(drawer)
		drawer.queue_free()
	_drawers.clear()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_drill_unlocked(_drill: DrillData) -> void:
	build()

func _on_drawer_height_changed() -> void:
	layout_changed.emit()

func _on_equipped_drill_changed(_drill: DrillData) -> void:
	for drawer: DrillDrawer in _drawers:
		drawer.refresh()
