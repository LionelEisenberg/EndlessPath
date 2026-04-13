class_name AbilityListData
extends Resource

## Registry of all ability definitions.
## AbilityManager preloads this and builds an ID-indexed lookup dictionary.

@export var abilities: Array[AbilityData] = []
