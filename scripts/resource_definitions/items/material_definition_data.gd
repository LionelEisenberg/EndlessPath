class_name MaterialDefinitionData
extends ItemDefinitionData

@export var source_zone_ids : Array[String] = []

func _get_item_effects() -> Array[String]:
	if source_zone_ids.is_empty():
		return []
	return ["Source Zones: %s" % ", ".join(source_zone_ids)]
