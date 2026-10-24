class_name TechniqueList
extends Control

## The zone chest's list of technique drawers while the player cycles (lacquer
## kit §5.5): one TechniqueDrawer per unlocked cycling technique, in unlock
## order, a drawer (72, taller while its text takes more lines) and a gap (8)
## apart. It neither scrolls nor folds: the zone panel places it under the
## header and the chest hugs it.
## It rebuilds when a technique unlocks, shown or not, so it is current the
## moment the chest turns to it. It refreshes every drawer when the equipped
## technique changes, because the drawers do not listen to CyclingManager.

## Emitted when the drawers are rebuilt or one of them changes height, which
## changes the list's height.
signal layout_changed

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DRAWER_SCENE: PackedScene = preload("res://scenes/cycling/technique_drawer/technique_drawer.tscn")

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
var _drawers: Array[TechniqueDrawer] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	CyclingManager.technique_unlocked.connect(_on_technique_unlocked)
	CyclingManager.equipped_technique_changed.connect(_on_equipped_technique_changed)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Replaces the drawers with one per unlocked technique, in unlock order.
func build() -> void:
	_clear()
	for technique: CyclingTechniqueData in CyclingManager.get_unlocked_techniques():
		var drawer: TechniqueDrawer = DRAWER_SCENE.instantiate() as TechniqueDrawer
		drawer.setup(technique)
		_column.add_child(drawer)
		drawer.height_changed.connect(_on_drawer_height_changed)
		_drawers.append(drawer)
	layout_changed.emit()

## Returns the height of the drawers and the gaps between them: each drawer's
## height (72 for one line of name and one of detail) plus (n - 1) x 8, or 0
## for none.
func get_content_height() -> float:
	if _drawers.is_empty():
		return 0.0
	var height: float = (_drawers.size() - 1) * DRAWER_GAP
	for drawer: TechniqueDrawer in _drawers:
		height += drawer.custom_minimum_size.y
	return height

## Returns the drawer of the technique, or null when the list has none.
func get_drawer(technique_id: String) -> TechniqueDrawer:
	for drawer: TechniqueDrawer in _drawers:
		if drawer.technique.id == technique_id:
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
	for drawer: TechniqueDrawer in _drawers:
		_column.remove_child(drawer)
		drawer.queue_free()
	_drawers.clear()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_technique_unlocked(_technique: CyclingTechniqueData) -> void:
	build()

func _on_drawer_height_changed() -> void:
	layout_changed.emit()

func _on_equipped_technique_changed(_technique: CyclingTechniqueData) -> void:
	for drawer: TechniqueDrawer in _drawers:
		drawer.refresh()
