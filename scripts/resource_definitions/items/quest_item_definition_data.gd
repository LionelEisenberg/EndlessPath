class_name QuestItemDefinitionData
extends ItemDefinitionData

## QuestItemDefinitionData
## Quest items get one extra field over the base: from_source (free-form
## lore describing where the player obtained this). The Journal prints it as
## "From …" in the item's panel, and under the item's name when no quest
## needs or gave the item (QuestManager.get_quest_id_for_item()).

@export var from_source: String = ""

func _init() -> void:
	item_type = ItemType.QUEST_ITEM
