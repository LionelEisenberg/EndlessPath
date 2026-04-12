class_name PathNodeData
extends Resource

## Defines a single node in a path progression tree.
## Nodes can be keystones, major, minor, or repeatable.
## Prerequisites are tracked by ID strings referencing other nodes in the same tree.

enum NodeType {
	KEYSTONE,    ## Game-changers: new abilities, cycling techniques, mechanic shifts (~20%)
	MAJOR,       ## Significant upgrades, meaningful new options (~30%)
	MINOR,       ## Stat bonuses, small QoL, connective tissue (~25%)
	REPEATABLE,  ## Stackable bonuses with a cap, point sinks (~25%)
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var node_type: NodeType = NodeType.MINOR
@export var icon: Texture2D = null

@export_group("Requirements")
## IDs of nodes that must be purchased (level >= 1) before this node can be purchased.
@export var prerequisites: Array[String] = []
## The cultivation stage required to purchase this node (tier gate).
@export var required_stage: CultivationManager.AdvancementStage = CultivationManager.AdvancementStage.FOUNDATION

@export_group("Cost & Limits")
## Cost in path points per purchase.
@export var point_cost: int = 1
## Maximum number of times this node can be purchased. 1 for non-repeatable, >1 for repeatable.
@export var max_purchases: int = 1

@export_group("Effects")
## Effects granted per purchase of this node. For repeatable nodes, effects stack per level.
@export var effects: Array[PathNodeEffectData] = []

## Returns true if this node's data is valid (has required fields).
func validate() -> bool:
	if id.is_empty():
		push_error("PathNodeData: id is empty")
		return false
	if display_name.is_empty():
		push_error("PathNodeData: display_name is empty for node '%s'" % id)
		return false
	if point_cost < 1:
		push_error("PathNodeData: point_cost must be >= 1 for node '%s'" % id)
		return false
	if max_purchases < 1:
		push_error("PathNodeData: max_purchases must be >= 1 for node '%s'" % id)
		return false
	return true

## Returns true if this node supports multiple purchases.
func is_repeatable() -> bool:
	return max_purchases > 1
