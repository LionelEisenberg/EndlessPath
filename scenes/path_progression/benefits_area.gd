class_name BenefitsArea
extends ScrollContainer

## The path book's Active Benefits: what each purchased path node grants, from
## every stage, as marked lines in one card. Scrolls with the wheel; its
## scrollbar is hidden.

## Marks each benefit line, like the effect lines elsewhere in the books.
const _MARK: String = "▲ "

@onready var _benefits_label: Label = %BenefitsLabel
@onready var _empty_label: Label = %BenefitsEmpty

## How many purchased nodes the list shows.
var _purchased_count: int = 0

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Rebuild the list from the current PathManager state.
func rebuild() -> void:
	var lines: PackedStringArray = []
	var tree: PathTreeData = PathManager.get_current_tree()
	if tree:
		for node_data: PathNodeData in tree.nodes:
			if PathManager.get_node_purchase_count(node_data.id) >= 1:
				var summary: String = node_data.benefit_summary
				if summary.is_empty():
					summary = node_data.description
				lines.append(_MARK + summary)
	_show_lines(lines)


## Clear the list.
func clear() -> void:
	_show_lines(PackedStringArray())


## How many nodes have been purchased.
func get_purchased_count() -> int:
	return _purchased_count

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _show_lines(lines: PackedStringArray) -> void:
	_purchased_count = lines.size()
	_benefits_label.text = "\n".join(lines)
	_benefits_label.visible = not lines.is_empty()
	_empty_label.visible = lines.is_empty()
