class_name EnemyNameplate
extends VBoxContainer

## EnemyNameplate
## Compact HUD that floats above the enemy: name, health, active buffs and
## a prominent intent bar showing what the enemy is about to cast.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _name_label: Label = %NameLabel
@onready var _health_bar: ResourceBar = %HealthBar
@onready var _buff_bar: BuffBar = %BuffBar
@onready var _cast_bar: CastBar = %IntentBar

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _vitals_manager: VitalsManager

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Binds the nameplate to an enemy combatant.
func setup(combatant: CombatantNode) -> void:
	reset()
	_name_label.text = combatant.combatant_data.character_name
	_vitals_manager = combatant.vitals_manager
	_vitals_manager.health_changed.connect(_on_health_changed)
	_health_bar.reset_values(_vitals_manager.current_health, _vitals_manager.max_health)
	_buff_bar.bind(combatant.buff_manager)
	_cast_bar.bind(combatant.ability_manager)

## Unbinds from the current combatant.
func reset() -> void:
	if _vitals_manager and is_instance_valid(_vitals_manager):
		if _vitals_manager.health_changed.is_connected(_on_health_changed):
			_vitals_manager.health_changed.disconnect(_on_health_changed)
	_vitals_manager = null
	_buff_bar.unbind()
	_cast_bar.unbind()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_health_changed(_health: float) -> void:
	_health_bar.update_values(_vitals_manager.current_health, _vitals_manager.max_health, _vitals_manager.health_regen)
