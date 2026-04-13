class_name BenefitsArea
extends PanelContainer

## Sidebar panel showing active benefits from purchased path nodes.
## Manages the list of BenefitCard instances and summary stats.

@export var benefit_card_scene: PackedScene

## Icon textures per node type. Assign in the Inspector.
@export_group("Node Type Icons")
@export var keystone_icon: Texture2D
@export var major_icon: Texture2D
@export var minor_icon: Texture2D
@export var repeatable_icon: Texture2D

@onready var _benefits_list: VBoxContainer = %BenefitsList
@onready var _node_count_label: Label = %NodeCountLabel
@onready var _points_spent_label: Label = %PointsSpentLabel

## Tracks total points spent and purchased node count
var _total_spent: int = 0
var _purchased_count: int = 0

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Rebuild the entire benefits list from the current PathManager state.
func rebuild() -> void:
	_clear()

	var tree: PathTreeData = PathManager.get_current_tree()
	if tree == null:
		return

	for node_data: PathNodeData in tree.nodes:
		var level: int = PathManager.get_node_purchase_count(node_data.id)
		if level >= 1:
			_purchased_count += 1
			_total_spent += node_data.point_cost * level
			_add_benefit(node_data)

	_node_count_label.text = "%d" % _purchased_count
	_points_spent_label.text = "%d" % _total_spent


## Clear all benefit cards and reset counters.
func clear() -> void:
	_clear()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _add_benefit(node_data: PathNodeData) -> void:
	if benefit_card_scene == null:
		return

	var summary: String = node_data.benefit_summary
	if summary.is_empty():
		summary = node_data.description

	var icon: Texture2D = _get_icon_for_type(node_data.node_type)
	var card: BenefitCard = benefit_card_scene.instantiate() as BenefitCard
	_benefits_list.add_child(card)
	card.setup(node_data.display_name, summary, icon)


func _get_icon_for_type(node_type: PathNodeData.NodeType) -> Texture2D:
	match node_type:
		PathNodeData.NodeType.KEYSTONE:
			return keystone_icon
		PathNodeData.NodeType.MAJOR:
			return major_icon
		PathNodeData.NodeType.REPEATABLE:
			return repeatable_icon
		_:
			return minor_icon


func _clear() -> void:
	for child: Node in _benefits_list.get_children():
		child.queue_free()
	_total_spent = 0
	_purchased_count = 0
	_node_count_label.text = "0"
	_points_spent_label.text = "0"
