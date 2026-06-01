class_name MaterialDefinitionData
extends ItemDefinitionData

@export var source_zone_ids : Array[String] = []

## Free-form lore string describing where this material is found.
## Shown on the material detail card under "Source".
@export var source_description: String = ""

## Comma-separated names of items/recipes that consume this material.
## Free-form for now; can graph from recipe data once crafting lands.
@export var used_in: String = ""

func _get_item_effects() -> Array[String]:
	if source_zone_ids.is_empty():
		return []
	return ["Source Zones: %s" % ", ".join(source_zone_ids)]
