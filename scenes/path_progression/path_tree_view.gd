class_name PathTreeView
extends MenuBookView
## Path book: the path's tree on the left page, one cultivation stage per
## chapter; the node or path you point at and your active benefits on the
## right page, with your points to spend in its corner. Side tabs switch
## chapters with the page turn, and
## a stage the player hasn't reached stays locked. Drag the tree to pan, use
## the wheel to zoom, click a node to buy it.

## The cultivation stages the book holds, one chapter tab each, in tab order.
const STAGES: Array[CultivationManager.AdvancementStage] = [
	CultivationManager.AdvancementStage.FOUNDATION,
	CultivationManager.AdvancementStage.COPPER,
	CultivationManager.AdvancementStage.IRON,
	CultivationManager.AdvancementStage.JADE,
]

## Zoom limits for the tree.
const ZOOM_MIN: float = 0.4
const ZOOM_MAX: float = 1.5
const ZOOM_STEP: float = 0.1
## Space kept between the tree and its card's edge when it is fitted.
const FIT_MARGIN: float = 12.0
## Half the largest node's size, so fitted bounds include whole nodes.
const NODE_HALF_EXTENT: float = 36.0

## Tree layout for each chapter, in STAGES order. A chapter without one is empty.
@export var stage_layouts: Array[PackedScene] = []
@export var path_node_ui_scene: PackedScene

@onready var _stage_tabs: Control = %StageTabs
@onready var _title_banner: Control = %TitleBanner
@onready var _page_layer: Control = %PageLayer
@onready var _path_plaque: Label = %PathPlaque
@onready var _stage_label: Label = %StageLabel
@onready var _tree_area: Control = %TreeArea
@onready var _node_container: PathNodeContainer = %NodeContainer
@onready var _detail_plaque: Label = %DetailPlaque
@onready var _details_card: PathDetailsCard = %DetailsCard
@onready var _benefits_area: BenefitsArea = %BenefitsArea
@onready var _points_label: Label = %PointsLabel

## Maps node_id -> PathNodeUI for refresh
var _node_uis: Dictionary = {}
## Maps node_id -> PathNodeData for the open chapter's nodes
var _node_data_by_id: Dictionary = {}

## The chapter shown, and the one a running page turn is heading to.
var _open_stage_index: int = 0
var _pending_stage_index: int = 0

## The open chapter's node bounds in layout coordinates, for fitting.
var _tree_bounds: Rect2 = Rect2()

## Panning state
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

## Zoom state
var _zoom_level: float = 1.0

#-----------------------------------------------------------------------------
# STATIC METHODS
#-----------------------------------------------------------------------------

## Read layout positions from a scene containing Marker2D children.
## Returns a Dictionary mapping marker name (String) to position (Vector2).
static func read_layout_positions(layout_scene_resource: PackedScene) -> Dictionary:
	var positions: Dictionary = {}
	var root: Node = layout_scene_resource.instantiate()
	for child: Node in root.get_children():
		if child is Marker2D:
			positions[child.name] = child.position
	root.free()
	return positions

## The player-facing name of a cultivation stage.
static func stage_name(stage: CultivationManager.AdvancementStage) -> String:
	return CultivationManager.AdvancementStage.keys()[stage].capitalize()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## True when the player has reached the stage, so its chapter can open.
func is_stage_unlocked(stage: CultivationManager.AdvancementStage) -> bool:
	return CultivationManager.get_current_advancement_stage() >= stage

## The stage whose chapter is open.
func get_open_stage() -> CultivationManager.AdvancementStage:
	return STAGES[_open_stage_index]

## Opens a reached stage's chapter at once, without the page turn.
func open_stage(stage: CultivationManager.AdvancementStage) -> void:
	var index: int = STAGES.find(stage)
	if index < 0 or not is_stage_unlocked(stage):
		return
	_open_stage_index = index
	_stage_tabs.select_tab(index)
	build_tree()

## Rebuild the open chapter's tree from the current PathManager state.
func build_tree() -> void:
	_clear_tree()
	var stage: CultivationManager.AdvancementStage = get_open_stage()
	_stage_label.text = "%s · stage %d of %d" % [stage_name(stage), _open_stage_index + 1, STAGES.size()]

	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		_update_points_display()
		return

	# Wire path theme into the node container for connection colors
	var path_theme: PathThemeData = tree.theme
	_node_container.set_theme_data(path_theme)

	var positions: Dictionary = {}
	if _open_stage_index < stage_layouts.size() and stage_layouts[_open_stage_index]:
		positions = read_layout_positions(stage_layouts[_open_stage_index])

	var stage_nodes: Array[PathNodeData] = tree.get_nodes_for_stage(stage)
	for node_data: PathNodeData in stage_nodes:
		_create_node_ui(node_data, positions, path_theme)

	# Register connections based on prerequisites; links to other chapters'
	# nodes are skipped by the container.
	for node_data: PathNodeData in stage_nodes:
		for prereq: PathNodeData in node_data.prerequisites:
			_node_container.add_connection(prereq.id, node_data.id)

	_tree_bounds = _bounds_of(stage_nodes, positions)
	_refresh_all_nodes()
	_benefits_area.rebuild()
	_update_points_display()
	_fit_tree()

## Describe a path node on the right page.
func show_node_details(node_data: PathNodeData) -> void:
	_detail_plaque.text = node_data.display_name
	_details_card.show_node(node_data, PathManager.get_node_purchase_count(node_data.id))

## Describe the path itself on the right page.
func show_path_info() -> void:
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return
	_detail_plaque.text = tree.path_name
	_details_card.show_path(tree)

#-----------------------------------------------------------------------------
# HOOKS
#-----------------------------------------------------------------------------

func _before_open() -> void:
	_refresh_stage_tabs()
	_update_header()
	open_stage(_highest_unlocked_stage())
	show_path_info()

func _after_open() -> void:
	# The tree card only has its final size once the pages are shown.
	_fit_tree.call_deferred()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _ready() -> void:
	super._ready()
	PathManager.node_purchased.connect(_on_node_purchased)
	PathManager.points_changed.connect(_on_points_changed)
	PathManager.path_set.connect(_on_path_set)

	_stage_tabs.tab_changed.connect(_on_stage_tab_changed)
	book_frame.page_turned.connect(_on_page_turned)
	_path_plaque.mouse_entered.connect(show_path_info)
	_tree_area.gui_input.connect(_on_tree_area_gui_input)
	_tree_area.resized.connect(_fit_tree)

	_refresh_stage_tabs()
	_update_header()
	build_tree()
	show_path_info()

func _refresh_stage_tabs() -> void:
	for i: int in range(STAGES.size()):
		var tab: Control = _stage_tabs.tab_buttons[i]
		var unlocked: bool = is_stage_unlocked(STAGES[i])
		tab.set_locked(not unlocked, "Reach %s to open this chapter." % stage_name(STAGES[i]))

func _highest_unlocked_stage() -> CultivationManager.AdvancementStage:
	var highest: CultivationManager.AdvancementStage = STAGES[0]
	for stage: CultivationManager.AdvancementStage in STAGES:
		if is_stage_unlocked(stage):
			highest = stage
	return highest

func _on_stage_tab_changed(index: int) -> void:
	_set_chapter_visible(false)
	_pending_stage_index = index
	book_frame.turn_page(index > _open_stage_index)

func _on_page_turned() -> void:
	_open_stage_index = _pending_stage_index
	build_tree()
	_set_chapter_visible(true)
	_fit_tree.call_deferred()

## Hides the pages and the title ribbon while a page turns over them.
func _set_chapter_visible(is_shown: bool) -> void:
	_page_layer.visible = is_shown
	_title_banner.visible = is_shown

func _on_tree_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse = mb.global_position
				_pan_start_offset = _node_container.position
			else:
				_is_panning = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(ZOOM_STEP, mb.global_position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(-ZOOM_STEP, mb.global_position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _pan_start_mouse
		_node_container.position = _pan_start_offset + delta


func _create_node_ui(node_data: PathNodeData, positions: Dictionary, path_theme: PathThemeData = null) -> void:
	if path_node_ui_scene == null:
		return

	var node_ui: PathNodeUI = path_node_ui_scene.instantiate() as PathNodeUI
	_node_container.add_child(node_ui)

	var current_level: int = PathManager.get_node_purchase_count(node_data.id)
	node_ui.setup(node_data, current_level, path_theme)

	# Position from layout — adjust for variable node sizes after setup
	if positions.has(node_data.id):
		var layout_pos: Vector2 = positions[node_data.id]
		node_ui.position = layout_pos - node_ui.size / 2.0
	else:
		node_ui.position = Vector2.ZERO

	node_ui.node_clicked.connect(_on_node_clicked)
	node_ui.node_hovered.connect(_on_node_hovered)

	# Use the actual drawn shape radius, not bounding box
	var node_radius: float = 20.0
	match node_data.node_type:
		PathNodeData.NodeType.KEYSTONE:
			node_radius = 34.0
		PathNodeData.NodeType.MAJOR:
			node_radius = 23.0
		_:
			node_radius = 18.0
	_node_uis[node_data.id] = node_ui
	_node_data_by_id[node_data.id] = node_data
	_node_container.register_node_ui(node_data.id, node_ui, node_radius)


func _bounds_of(nodes: Array[PathNodeData], positions: Dictionary) -> Rect2:
	var bounds: Rect2 = Rect2()
	var has_point: bool = false
	for node_data: PathNodeData in nodes:
		if not positions.has(node_data.id):
			continue
		var point: Rect2 = Rect2(positions[node_data.id] - Vector2.ONE * NODE_HALF_EXTENT, Vector2.ONE * NODE_HALF_EXTENT * 2.0)
		bounds = point if not has_point else bounds.merge(point)
		has_point = true
	return bounds


## Zoom and centre the open chapter's tree so it fits its card.
func _fit_tree() -> void:
	var area: Vector2 = _tree_area.size
	if area.x <= 0.0 or area.y <= 0.0 or _tree_bounds.size == Vector2.ZERO:
		return
	var fit: float = minf(
		(area.x - FIT_MARGIN * 2.0) / _tree_bounds.size.x,
		(area.y - FIT_MARGIN * 2.0) / _tree_bounds.size.y)
	_zoom_level = clampf(fit, ZOOM_MIN, ZOOM_MAX)
	_node_container.scale = Vector2(_zoom_level, _zoom_level)
	_node_container.position = area / 2.0 - _tree_bounds.get_center() * _zoom_level
	_node_container.queue_redraw()


func _refresh_all_nodes() -> void:
	_update_points_display()

	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		var current_level: int = PathManager.get_node_purchase_count(node_id)
		var can_afford: bool = PathManager.can_purchase_node(node_id)
		node_ui.refresh(current_level, can_afford)

	_node_container.queue_redraw()
	_node_container.rebuild_energy_lines()


func _apply_zoom(delta: float, mouse_global: Vector2) -> void:
	var old_zoom: float = _zoom_level
	_zoom_level = clampf(_zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, _zoom_level):
		return

	# Zoom toward mouse position so the point under the cursor stays fixed.
	# The tree area sits inside the book's scaled page layer, so convert the
	# global mouse position to the area's local space first.
	var mouse_local: Vector2 = _tree_area.get_global_transform().affine_inverse() * mouse_global
	var before: Vector2 = (mouse_local - _node_container.position) / old_zoom
	var after: Vector2 = before * _zoom_level
	_node_container.position = mouse_local - after

	_node_container.scale = Vector2(_zoom_level, _zoom_level)
	_node_container.queue_redraw()


func _clear_tree() -> void:
	_node_container.clear_all()
	for node_id: String in _node_uis:
		var node_ui: PathNodeUI = _node_uis[node_id] as PathNodeUI
		_node_container.remove_child(node_ui)
		node_ui.free()
	_node_uis.clear()
	_node_data_by_id.clear()
	_tree_bounds = Rect2()


func _update_points_display() -> void:
	_points_label.text = str(PathManager.get_point_balance())


func _update_header() -> void:
	var tree: PathTreeData = PathManager.get_current_tree()
	_path_plaque.text = tree.path_name if tree else "No path"


func _on_node_clicked(node_id: String) -> void:
	PathManager.purchase_node(node_id)


func _on_node_hovered(node_data: PathNodeData, _node_ui: PathNodeUI) -> void:
	show_node_details(node_data)


func _on_node_purchased(node_id: String, _new_level: int) -> void:
	_benefits_area.rebuild()
	_refresh_all_nodes()
	if _node_data_by_id.has(node_id):
		show_node_details(_node_data_by_id[node_id] as PathNodeData)


func _on_points_changed(_new_balance: int) -> void:
	_refresh_all_nodes()


func _on_path_set(_path_tree: PathTreeData) -> void:
	_update_header()
	build_tree()
	show_path_info()
