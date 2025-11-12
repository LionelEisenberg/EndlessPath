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
