class_name AwardCoreDensityXpEffectData
extends EffectData

## Pays Core Density XP when it runs. A fight carries it in its combat choice's
## success effects, as it carries its loot; any other choice can carry it too, such
## as an event that grants Core Density for free. A full core takes none
## (CultivationManager.add_core_density_xp()).

@export var amount: float = 0.0


func _init() -> void:
	effect_type = EffectType.AWARD_CORE_DENSITY_XP


func _to_string() -> String:
	return "AwardCoreDensityXpEffectData { amount: %s }" % amount


## Pays `amount` Core Density XP through CultivationManager. A zero or negative
## amount (a malformed .tres) does nothing.
func process() -> void:
	if amount <= 0.0:
		return
	if CultivationManager == null:
		Log.error("AwardCoreDensityXpEffectData: CultivationManager not available")
		return
	Log.info("AwardCoreDensityXpEffectData: Awarding %s Core Density XP" % amount)
	CultivationManager.add_core_density_xp(amount)
