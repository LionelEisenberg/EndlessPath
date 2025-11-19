class_name CombatAbilityInstance
extends Node

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

func _process(_delta: float) -> void:
	if not cooldown_timer.is_stopped():
		cooldown_updated.emit(cooldown_timer.time_left)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

func is_ready() -> bool:
	return cooldown_timer.is_stopped()

func use(target: CombatantNode) -> void:
	if not is_ready():
		return
		
	# Start Cooldown
	use_count += 1
	if ability_data.base_cooldown > 0:
		cooldown_timer.start(ability_data.base_cooldown)
		cooldown_started.emit(ability_data.base_cooldown)
	
	# Apply Effects
	for effect in ability_data.effects:
		if target.has_method("receive_effect"):
			target.receive_effect(effect, source_attributes)

#-----------------------------------------------------------------------------
# INTERNAL LOGIC
#-----------------------------------------------------------------------------

func _on_cooldown_timeout() -> void:
	cooldown_ready.emit()
