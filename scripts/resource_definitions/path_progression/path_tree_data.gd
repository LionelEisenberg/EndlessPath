class_name PathTreeData
extends Resource

## Defines a complete path progression tree for a single Madra path.
## Contains all nodes across all tiers. The tree is displayed as a freeform
## node graph with tier gates at cultivation stage boundaries.

@export var path_id: String = ""
@export var path_name: String = ""
@export_multiline var path_description: String = ""

## All nodes in this tree, across all tiers.
@export var nodes: Array[PathNodeData] = []

## Returns the node with the given ID, or null if not found.
func get_node_by_id(node_id: String) -> PathNodeData:
	for node: PathNodeData in nodes:
		if node.id == node_id:
			return node
	return null

## Returns all nodes that require the given cultivation stage.
func get_nodes_for_stage(stage: CultivationManager.AdvancementStage) -> Array[PathNodeData]:
	var result: Array[PathNodeData] = []
	for node: PathNodeData in nodes:
		if node.required_stage == stage:
			result.append(node)
	return result

## Returns the total point cost to purchase every node at max level.
func get_total_tree_cost() -> int:
	var total: int = 0
	for node: PathNodeData in nodes:
		total += node.point_cost * node.max_purchases
	return total

## Validates all nodes in the tree. Returns true if all are valid.
func validate() -> bool:
	if path_id.is_empty():
		push_error("PathTreeData: path_id is empty")
		return false
	var ids: Array[String] = []
	for node: PathNodeData in nodes:
		if not node.validate():
			return false
		if ids.has(node.id):
			push_error("PathTreeData: duplicate node id '%s'" % node.id)
			return false
		ids.append(node.id)
	# Validate prerequisite references
	for node: PathNodeData in nodes:
		for prereq_id: String in node.prerequisites:
			if not ids.has(prereq_id):
				push_error("PathTreeData: node '%s' references unknown prerequisite '%s'" % [node.id, prereq_id])
				return false
	return true
