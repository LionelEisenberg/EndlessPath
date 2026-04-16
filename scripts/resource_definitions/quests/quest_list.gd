class_name QuestList
extends Resource

## Catalog container for all QuestData in the project. QuestManager preloads
## this at boot and indexes by quest_id.
@export var quests: Array[QuestData] = []
