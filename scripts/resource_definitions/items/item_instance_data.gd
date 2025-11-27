class_name ItemInstanceData
extends Resource

## Definition for a single inventory item instance.
@export var item_definition: ItemDefinitionData

## Quantity held for this instance (supports stacking).
@export var quantity: int = 1

## Optional unique identifier for referencing this instance (e.g., quests, equipment).
@export var instance_id: String = ""

## Metadata hook for future RPG systems (enchantments, durability, etc.).
@export var metadata: Dictionary = {}

func _to_string() -> String:
	return "ITEM_DEFINITION %s" % item_definition

func _to_description_box() -> String:
	if not item_definition:
		return "No Item Definition"
	
	var text = ""
			
	# Specific Details from Definition
	var effects = item_definition._get_item_effects()
	if not effects.is_empty():
		text += "\n"
		for effect in effects:
			text += "%s\n" % effect
		
	return text
