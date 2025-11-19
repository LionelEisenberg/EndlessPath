class_name CombatantData
extends Resource


## CombatantData
## Defines the data for a character in combat (Player or Enemy)
## Holds attributes, abilities, and visual assets

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

@export_group("Stats")
@export var character_name: String = "Combatant"
@export var attributes: CharacterAttributesData

@export_group("Abilities")
@export var abilities: Array[AbilityData] = []

@export_group("Visuals")
@export var texture: Texture2D
@export var scale: float = 1.0
@export var offset: Vector2 = Vector2.ZERO

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init() -> void:
	if attributes == null:
		attributes = CharacterAttributesData.new()
