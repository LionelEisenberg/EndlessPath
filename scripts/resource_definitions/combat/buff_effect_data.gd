class_name BuffEffectData
extends CombatEffectData

## BuffEffectData
## Defines buff and debuff effects that can be applied to combatants.
## Extends CombatEffectData to integrate with the existing effect system.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum BuffType {
	ATTRIBUTE_MODIFIER_MULTIPLICATIVE, ## Multiplies attributes (e.g., 2x STR)
	DAMAGE_OVER_TIME, ## Deals damage each tick (poison, burn)
	OUTGOING_DAMAGE_MODIFIER, ## Modifies outgoing damage
	INCOMING_DAMAGE_MODIFIER ## Modifies incoming damage
}

#-----------------------------------------------------------------------------
# BUFF IDENTITY
#-----------------------------------------------------------------------------

@export var buff_id: String = ""
@export var buff_icon: Texture2D = null
@export var duration: float = 5.0
@export var buff_type: BuffType = BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE

#-----------------------------------------------------------------------------
# ATTRIBUTE MODIFIER
#-----------------------------------------------------------------------------

@export_group("Attribute Modifier")
## Dictionary mapping AttributeType to multiplier value
## Example: {STRENGTH: 2.0, SPIRIT: 2.0} for 2x STR and SPI
@export var attribute_modifiers: Dictionary[CharacterAttributesData.AttributeType, float] = {}

#-----------------------------------------------------------------------------
# DAMAGE OVER TIME
#-----------------------------------------------------------------------------

@export_group("Damage Over Time")
## Damage dealt per tick (1 second intervals)
@export var dot_damage_per_tick: float = 0.0
## Type of DoT damage
@export var dot_damage_type: DamageType = DamageType.TRUE

#-----------------------------------------------------------------------------
# DAMAGE MODIFIER
#-----------------------------------------------------------------------------

@export_group("Damage Modifier")
## Multiplier for damage (outgoing or incoming based on buff_type)
@export var damage_multiplier: float = 1.0
## If true, buff is consumed after one use
@export var consume_on_use: bool = false

#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

func _init() -> void:
	# Set effect_type to BUFF for routing in CombatEffectManager
	effect_type = EffectType.BUFF

func validate() -> bool:
	if buff_id.is_empty():
		Log.error("BuffEffectData: buff_id is empty")
		return false
	
	if duration <= 0.0:
		Log.error("BuffEffectData[%s]: duration must be positive" % buff_id)
		return false
	
	return true

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	return "BuffEffectData[%s] '%s' (Type: %s, Duration: %.1fs)" % [
		buff_id,
		effect_name,
		BuffType.keys()[buff_type],
		duration
	]
