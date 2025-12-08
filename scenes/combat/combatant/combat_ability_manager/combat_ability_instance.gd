class_name CombatAbilityInstance
extends Node

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const INITIAL_COOLDOWN: float = 1.5

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal cooldown_started(duration: float)
signal cooldown_updated(time_left: float)
signal cooldown_ready()

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

var ability_data: AbilityData
var source_attributes: CharacterAttributesData
var cooldown_timer: Timer
var use_count: int = 0

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init(data: AbilityData, attributes: CharacterAttributesData) -> void:
	ability_data = data
	source_attributes = attributes
	name = "AbilityInstance_%s" % data.ability_name

func _ready() -> void:
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	cooldown_timer.wait_time = ability_data.base_cooldown
	_start_cooldown(INITIAL_COOLDOWN)

func _process(_delta: float) -> void:
	if not cooldown_timer.is_stopped():
		cooldown_updated.emit(cooldown_timer.time_left)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Checks if the ability is ready to be used (not on cooldown).
func is_ready() -> bool:
	return cooldown_timer.is_stopped()

## Uses the ability on the given target.
func use(target: CombatantNode) -> void:
	if not is_ready():
		return
		
	use_count += 1
	
	# Start Cooldown
	var cooldown = ability_data.base_cooldown
	_start_cooldown(cooldown)
	
	# Apply Effects
	for effect in ability_data.effects:
		if target.has_method("receive_effect"):
			target.receive_effect(effect, source_attributes)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _start_cooldown(cooldown: float):
	if ability_data.base_cooldown > 0:
		cooldown_timer.start(cooldown)
		cooldown_started.emit(ability_data.base_cooldown)

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()
