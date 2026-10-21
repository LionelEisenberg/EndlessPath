class_name PlayerHud
extends VBoxContainer

## PlayerHud
## The adventure dock, bottom-center: Health orb, Madra orb, stamina bar and
## the four technique slots, with the player's cast bar and statuses above.
## It stays up for the whole adventure; entering combat activates the slots
## rather than spawning new UI, so nothing moves between exploration and combat.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_selected(instance: CombatAbilityInstance)

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _cast_bar: CastBar = %CastBar
@onready var _buff_bar: BuffBar = %BuffBar
@onready var _health_orb: ResourceOrb = %HealthOrb
@onready var _madra_orb: ResourceOrb = %MadraOrb
@onready var _stamina_bar: ResourceBar = %StaminaBar
@onready var _abilities_panel: AbilitiesPanel = %AbilitiesPanel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _vitals_manager: VitalsManager

func _ready() -> void:
	_abilities_panel.ability_selected.connect(_on_ability_selected)
	_abilities_panel.ability_hovered.connect(_on_ability_hovered)
	_abilities_panel.ability_unhovered.connect(_on_ability_unhovered)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Binds the orbs and stamina bar to the player's vitals (safe to call repeatedly).
func setup_vitals(vitals_manager: VitalsManager) -> void:
	_disconnect_vitals()
	_vitals_manager = vitals_manager
	if not _vitals_manager:
		return
	_vitals_manager.health_changed.connect(_on_vitals_changed)
	_vitals_manager.madra_changed.connect(_on_vitals_changed)
	_vitals_manager.stamina_changed.connect(_on_vitals_changed)
	var vm: VitalsManager = _vitals_manager
	_health_orb.reset_values(vm.current_health, vm.max_health, vm.health_regen)
	_madra_orb.reset_values(vm.current_madra, vm.max_madra, vm.madra_regen)
	_stamina_bar.reset_values(vm.current_stamina, vm.max_stamina)
	_on_vitals_changed(0.0)

## Shows the equipped techniques in their slots (out of combat).
func show_loadout() -> void:
	_abilities_panel.show_loadout()

## Activates the slots, cast bar and statuses for the player's combatant.
func setup_combatant(combatant: CombatantNode) -> void:
	reset_combat()
	_buff_bar.bind(combatant.buff_manager)
	_cast_bar.bind(combatant.ability_manager)
	_abilities_panel.bind(combatant.ability_manager, _vitals_manager)
	# Damage numbers pop over the sprite during combat; avoid doubling them on the orb.
	_health_orb.show_floating_text = false

## Returns the dock to its exploration state.
func reset_combat() -> void:
	_buff_bar.unbind()
	_cast_bar.unbind()
	_abilities_panel.reset()
	_health_orb.show_floating_text = true

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_ability_selected(instance: CombatAbilityInstance) -> void:
	ability_selected.emit(instance)

## Shows what the hovered technique would cost on each resource.
func _on_ability_hovered(ability_data: AbilityData) -> void:
	_health_orb.preview_cost(ability_data.health_cost)
	_madra_orb.preview_cost(ability_data.madra_cost)
	_stamina_bar.preview_cost(ability_data.stamina_cost)

func _on_ability_unhovered() -> void:
	_health_orb.preview_cost(0.0)
	_madra_orb.preview_cost(0.0)
	_stamina_bar.preview_cost(0.0)

func _on_vitals_changed(_value: float) -> void:
	var vm: VitalsManager = _vitals_manager
	_health_orb.update_values(vm.current_health, vm.max_health, vm.health_regen)
	_madra_orb.update_values(vm.current_madra, vm.max_madra, vm.madra_regen)
	_stamina_bar.update_values(vm.current_stamina, vm.max_stamina, vm.stamina_regen)

func _disconnect_vitals() -> void:
	if not _vitals_manager or not is_instance_valid(_vitals_manager):
		return
	for sig: Signal in [_vitals_manager.health_changed, _vitals_manager.madra_changed, _vitals_manager.stamina_changed]:
		if sig.is_connected(_on_vitals_changed):
			sig.disconnect(_on_vitals_changed)
