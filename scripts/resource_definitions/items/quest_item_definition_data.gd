class_name QuestItemDefinitionData
extends ItemDefinitionData

## QuestItemDefinitionData
## Quest items get two extra fields over the base. from_source is free-form
## lore describing where the player obtained this: the Journal prints it as
## "From …" in the item's panel, and under the item's name when no quest needs
## or gave the item (QuestManager.get_quest_id_for_item()). zone_id names the
## zone the item belongs to: the Journal prints that zone's name on a tag at
## the top right of the item's panel.

@export var from_source: String = ""
## The id of the zone the item belongs to ("SpiritValley"); empty for none.
@export var zone_id: String = ""

func _init() -> void:
	item_type = ItemType.QUEST_ITEM
