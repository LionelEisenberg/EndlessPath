class_name CombatantNode
extends Node2D

## CombatantNode
## Main node for a character in combat.
## Orchestrates Resource, Ability, and Effect components.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

# We create these in code or get them from children if they exist
@onready var vitals_manager: VitalsManager = %VitalsManager
@onready var ability_manager: CombatAbilityManager = %CombatAbilityManager
@onready var consumable_manager: CombatConsumableManager = %CombatConsumableManager
@onready var effect_manager: CombatEffectManager = %CombatEffectManager
@onready var buff_manager: CombatBuffManager = %CombatBuffManager
@onready var visual: CombatantVisual = %CombatantVisual

# Data
var combatant_data: CombatantData
var is_player: bool = false

var _last_health: float = 0.0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	pass

## Sets up the combatant with data and optional external resources.
func setup(
	data: CombatantData,
	external_vitals_manager: VitalsManager = null,
	p_is_player: bool = false
) -> void:
	is_player = p_is_player
	combatant_data = data
	
	# Setup Managers - Resource, Ability, Consumable, Effect
	if external_vitals_manager:
		vitals_manager = external_vitals_manager
	else:
		vitals_manager = %VitalsManager
		vitals_manager.character_attributes_data = combatant_data.attributes
		vitals_manager.initialize_current_values()

	buff_manager.setup(self)
	ability_manager.setup(self)
	consumable_manager.setup(self)
	effect_manager.setup(self)

	_update_visuals()

	Log.info("CombatantNode: Setup complete for " + combatant_data.character_name)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Called by other combatants/abilities to apply effects.
## `outgoing_modifier` carries the source's outgoing-damage buff multiplier
## (already consumed on the source side). Defaults to 1.0 for non-damage
## effects or callers that don't need to scale damage.
func receive_effect(effect: CombatEffectData, source_attributes: CharacterAttributesData, outgoing_modifier: float = 1.0) -> void:
	effect_manager.process_effect(effect, source_attributes, outgoing_modifier)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

## Minimum health delta that triggers hit/heal feedback (filters out regen ticks).
const HIT_THRESHOLD: float = 0.5
const HEAL_THRESHOLD: float = 1.0

func _update_visuals() -> void:
	# Player art faces right; enemies stand on the right and face left.
	visual.setup(combatant_data.texture, combatant_data.scale, combatant_data.offset, not is_player, is_player)

	_last_health = vitals_manager.current_health
	if not vitals_manager.health_changed.is_connected(_on_health_changed):
		vitals_manager.health_changed.connect(_on_health_changed)

	for instance: CombatAbilityInstance in ability_manager.abilities:
		instance.executed.connect(_on_ability_executed)

func _on_health_changed(new_health: float) -> void:
	var diff: float = new_health - _last_health
	_last_health = new_health
	if diff <= -HIT_THRESHOLD:
		visual.play_hit(-diff)
	elif diff >= HEAL_THRESHOLD:
		visual.play_heal(diff)

func _on_ability_executed(instance: CombatAbilityInstance) -> void:
	if not instance.ability_data.effects_on_target.is_empty():
		visual.play_attack()
	elif not instance.ability_data.effects_on_self.is_empty():
		visual.play_buff()
