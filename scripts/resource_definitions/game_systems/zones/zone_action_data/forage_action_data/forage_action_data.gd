class_name ForageActionData
extends ZoneActionData

@export var forage_resources: Array[ForageResourceData] = []
@export var madra_cost_per_second: float = 0.0
@export var foraging_interval_in_sec: float = 5.0

func _init():
	call_deferred("ready")

func ready():
	assert(_verify_foraging_distribution())

#-----------------------------------------------------------------------------
# VERIFICATION FUNCTIONS
#-----------------------------------------------------------------------------

## Verify that the forage resources distributions are normalized to 1.0 and do not exceed 1
func _verify_foraging_distribution() -> bool:
	var total_distribution = 0.0

	for resource in forage_resources:
		total_distribution += resource.drop_chance
	
	return total_distribution == 1.0
