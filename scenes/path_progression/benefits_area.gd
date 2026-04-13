class_name BenefitsArea
extends PanelContainer

## Sidebar panel showing active benefits from purchased path nodes.
## Manages the list of BenefitCard instances and summary stats.

@export var benefit_card_scene: PackedScene

@onready var _benefits_list: VBoxContainer = %BenefitsList
@onready var _node_count_label: Label = %NodeCountLabel
@onready var _points_spent_label: Label = %PointsSpentLabel

## Tracks total points spent and purchased node count
var _total_spent: int = 0
var _purchased_count: int = 0

## Benefit descriptions for sidebar display
const BENEFIT_DESCRIPTIONS: Dictionary = {
	"pure_core_awakening": ["Pure Core Awakening", "Empty Palm + Smooth Flow"],
	"cycling_focus": ["Cycling Focus", "+15 Cycling Accuracy"],
	"expanded_core": ["Expanded Core", "+25 Max Madra"],
	"madra_surge": ["Madra Surge", "+10% Madra Gen"],
	"lingering_silence": ["Lingering Silence", "+2s Silence Duration"],
	"efficient_palm": ["Efficient Palm", "-20% Palm Cost"],
	"madra_strike": ["Madra Strike", "Madra Strike unlocked"],
	"focused_strike": ["Focused Strike", "+40% Strike Damage"],
	"strike_efficiency": ["Strike Efficiency", "-15% Stamina Cost"],
	"torrent_flow": ["Torrent Flow", "Torrent Flow unlocked"],
	"iron_will": ["Iron Will", "+20% Stamina Recovery"],
	"dedicated_cultivation": ["Dedicated Cultivation", "+10% Core Density XP"],
	"breakthrough_surge": ["Breakthrough Surge", "+10 Madra on Level Up"],
	"madra_reclamation": ["Madra Reclamation", "+10% Madra Return"],
}

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
			_add_benefit(node_data.id)

	_node_count_label.text = "%d" % _purchased_count
	_points_spent_label.text = "%d" % _total_spent


## Clear all benefit cards and reset counters.
func clear() -> void:
	_clear()

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _add_benefit(node_id: String) -> void:
	var benefit_info: Array = BENEFIT_DESCRIPTIONS.get(node_id, []) as Array
	if benefit_info.size() < 2:
		return
	if benefit_card_scene == null:
		return

	var card: BenefitCard = benefit_card_scene.instantiate() as BenefitCard
	_benefits_list.add_child(card)
	card.setup(benefit_info[0], benefit_info[1])


func _clear() -> void:
	for child: Node in _benefits_list.get_children():
		child.queue_free()
	_total_spent = 0
	_purchased_count = 0
	_node_count_label.text = "0"
	_points_spent_label.text = "0"
