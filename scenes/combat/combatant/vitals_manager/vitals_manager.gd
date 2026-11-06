class_name VitalsManager
extends Node
## A combatant's Health, Stamina and Madra, each with its max and its regen.
## The player's Madra is ResourceManager's saved pool: its reads, writes and
## changes go through ResourceManager, so a run spends from and refills the one
## pool. An enemy keeps Madra of its own, from its character_attributes_data.

#-----------------------------------------------------------------------------
# TYPE ALIASES
#-----------------------------------------------------------------------------

const Stat = StatModifierData.Stat

#-----------------------------------------------------------------------------
# CHARACTER ADVENTURE DATA REFERENCES
#-----------------------------------------------------------------------------
@export var character_attributes_data: CharacterAttributesData:
	set(value):
		character_attributes_data = value
		_update_combat_max()

@export var is_player: bool = false

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal health_changed(new_health: float)
signal madra_changed(new_madra: float)
signal stamina_changed(new_stamina: float)

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var max_health: float = 100.0
var health_regen: float = 0.0 # Amount per second
var current_health: float:
	set(value):
		current_health = value
		health_changed.emit(current_health)
	
## The most Madra this combatant holds. The player's is the pool's max
## (ResourceManager.get_max_madra()).
var max_madra: float = 100.0:
	get:
		return ResourceManager.get_max_madra() if is_player else max_madra
var madra_regen: float = 0.0 # Amount per second
## This combatant's Madra. The player's is the saved pool: writing it sets the
## pool, and the pool's own signal announces the change.
var current_madra: float:
	get:
		return ResourceManager.get_madra() if is_player else current_madra
	set(value):
		if is_player:
			ResourceManager.set_madra(value)
			return
		current_madra = value
		madra_changed.emit(current_madra)
	
var max_stamina: float = 100.0
var stamina_regen: float = 0.0 # Amount per second
var current_stamina: float:
	set(value):
		current_stamina = value
		stamina_changed.emit(current_stamina)


#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if is_player and character_attributes_data:
		Log.warn("VitalsManager: is_player and character_attributes_data should never be set at the same time")
	
	if is_player:
		CharacterManager.stats_changed.connect(_on_stats_changed)
		ResourceManager.madra_changed.connect(_on_pool_changed)
		_on_stats_changed()

func _process(delta: float) -> void:
	if health_regen != 0:
		_apply_health_change(health_regen * delta)
	if stamina_regen != 0:
		_apply_stamina_change(stamina_regen * delta)
	if madra_regen != 0:
		_apply_madra_change(madra_regen * delta)

func _update_combat_max() -> void:
	max_health = character_attributes_data.get_max_health()
	max_stamina = character_attributes_data.get_max_stamina()
	max_madra = character_attributes_data.get_max_madra()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Fills Health and Stamina to their maxima, and an enemy's Madra to its max.
## The player's Madra is the saved pool, which this never touches.
func initialize_current_values() -> void:
	current_health = max_health
	current_stamina = max_stamina
	if not is_player:
		current_madra = max_madra

## Adds each amount (negative to spend), held to [0, max]. The player's Madra
## change lands in the saved pool quietly, with no log line; a zero change
## leaves the pool alone.
func apply_vitals_change(health_amount: float = 0.0, stamina_amount: float = 0.0, madra_amount: float = 0.0) -> void:
	_apply_health_change(health_amount)
	_apply_stamina_change(stamina_amount)
	_apply_madra_change(madra_amount)


#-----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS
#-----------------------------------------------------------------------------

## The player's maxima are CharacterManager's derived vitals, so gear and any
## other modifier source count as well as the base. An enemy's come from its
## own character_attributes_data instead.
func _on_stats_changed() -> void:
	max_health = CharacterManager.get_stat(Stat.MAX_HEALTH)
	max_stamina = CharacterManager.get_stat(Stat.MAX_STAMINA)

## Announces each change to the saved pool as the player's Madra change.
func _on_pool_changed(new_amount: float) -> void:
	madra_changed.emit(new_amount)

## Adds or subtracts health, clamping to 0 and max health
func _apply_health_change(amount: float) -> void:
	var new_health = min(max_health, max(0.0, current_health + amount))
	if is_player:
		if abs(current_health - new_health) > 1.0:
			Log.info("VitalsManager: Health changed by %.1f from %.1f to %.1f" % [amount, current_health, new_health])
	current_health = new_health

## Adds or subtracts stamina, clamping to 0 and max stamina
func _apply_stamina_change(amount: float) -> void:
	var new_stamina = min(max_stamina, max(0.0, current_stamina + amount))
	if is_player:
		if abs(current_stamina - new_stamina) > 1.0:
			Log.info("VitalsManager: Stamina changed by %.1f from %.1f to %.1f" % [amount, current_stamina, new_stamina])
	current_stamina = new_stamina

## Adds or subtracts madra, clamping to 0 and max madra. The player's goes to
## the saved pool, quietly.
func _apply_madra_change(amount: float) -> void:
	if is_player:
		if amount != 0.0:
			ResourceManager.add_madra(amount, true)
		return
	current_madra = min(max_madra, max(0.0, current_madra + amount))
