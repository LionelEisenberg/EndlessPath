class_name QuestItemDefinitionData
extends ItemDefinitionData

## QuestItemDefinitionData
## Quest items get one extra field over the base: from_source (free-form
## lore describing where the player obtained this). The Journal renders
## that as the "From:" row.
##
## The "Linked quest" row from the mockup is deferred until a real
## QuestManager exists — every quest item currently renders with the
## active wax seal.

@export var from_source: String = ""

func _init() -> void:
	item_type = ItemType.QUEST_ITEM
