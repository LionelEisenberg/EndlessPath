extends ScrollContainer

## The dev panel's Player tab: the player's resources and progress, each set through
## DevCommands, which logs the change and says why it refused. Madra, the saved Health
## pool and gold are set to a value, and a line shows Health over its max as both
## change: until runs read the pool, it is the only place the pool shows. Core Density is reached through real XP, so the milestones pay, and the
## stage shows next to it with a button to break through to the next. Path Points are
## added to. A stat is set to a level, past the stage's cap too, and to XP toward the
## next level. A cycling technique, a body refining drill or a combat ability is
## unlocked, or equipped (an ability in the slot picked), or all of them are
## unlocked. A refusal shows above the controls until a command works.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _status: Label = %PlayerStatus
@onready var _madra_spin: SpinBox = %MadraSpin
@onready var _madra_set: Button = %MadraSet
@onready var _health_spin: SpinBox = %HealthSpin
@onready var _health_set: Button = %HealthSet
@onready var _health_label: Label = %HealthLabel
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _gold_set: Button = %GoldSet
@onready var _level_spin: SpinBox = %LevelSpin
@onready var _level_reach: Button = %LevelReach
@onready var _stage_label: Label = %StageLabel
@onready var _advance_stage: Button = %AdvanceStage
@onready var _points_spin: SpinBox = %PointsSpin
@onready var _points_add: Button = %PointsAdd
@onready var _stat_option: OptionButton = %StatOption
@onready var _stat_level_spin: SpinBox = %StatLevelSpin
@onready var _stat_xp_spin: SpinBox = %StatXpSpin
@onready var _stat_set: Button = %StatSet
@onready var _technique_option: OptionButton = %TechniqueOption
@onready var _technique_unlock: Button = %TechniqueUnlock
@onready var _technique_equip: Button = %TechniqueEquip
@onready var _unlock_all_techniques: Button = %UnlockAllTechniques
@onready var _drill_option: OptionButton = %DrillOption
@onready var _drill_unlock: Button = %DrillUnlock
@onready var _drill_equip: Button = %DrillEquip
@onready var _unlock_all_drills: Button = %UnlockAllDrills
@onready var _ability_option: OptionButton = %AbilityOption
@onready var _ability_unlock: Button = %AbilityUnlock
@onready var _ability_equip: Button = %AbilityEquip
@onready var _ability_slot_spin: SpinBox = %AbilitySlotSpin
@onready var _unlock_all_abilities: Button = %UnlockAllAbilities

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Lists the stats, the techniques, the drills and the abilities in their pickers,
## each item's metadata what its command takes (the stat's key, the others' ids),
## shows the stage and Health, and keeps them showing as the core, the stage, Health
## and its max change.
func _ready() -> void:
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		_stat_option.add_item(CharacterManager.get_attribute_display_name(stat))
		_stat_option.set_item_metadata(_stat_option.item_count - 1, CharacterAttributesData.stat_key(stat))
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		_technique_option.add_item(technique.technique_name)
		_technique_option.set_item_metadata(_technique_option.item_count - 1, technique.id)
	for drill: DrillData in BodyRefiningManager.get_all_drills():
		_drill_option.add_item(drill.drill_name)
		_drill_option.set_item_metadata(_drill_option.item_count - 1, drill.id)
	for ability: AbilityData in AbilityManager.get_all_abilities():
		_ability_option.add_item(ability.ability_name)
		_ability_option.set_item_metadata(_ability_option.item_count - 1, ability.ability_id)
	_show_stage()
	_show_health()
	_madra_set.pressed.connect(_on_madra_set_pressed)
	_health_set.pressed.connect(_on_health_set_pressed)
	_gold_set.pressed.connect(_on_gold_set_pressed)
	_level_reach.pressed.connect(_on_level_reach_pressed)
	_advance_stage.pressed.connect(_on_advance_stage_pressed)
	_points_add.pressed.connect(_on_points_add_pressed)
	_stat_set.pressed.connect(_on_stat_set_pressed)
	_technique_unlock.pressed.connect(_on_technique_unlock_pressed)
	_technique_equip.pressed.connect(_on_technique_equip_pressed)
	_unlock_all_techniques.pressed.connect(_on_unlock_all_techniques_pressed)
	_drill_unlock.pressed.connect(_on_drill_unlock_pressed)
	_drill_equip.pressed.connect(_on_drill_equip_pressed)
	_unlock_all_drills.pressed.connect(_on_unlock_all_drills_pressed)
	_ability_unlock.pressed.connect(_on_ability_unlock_pressed)
	_ability_equip.pressed.connect(_on_ability_equip_pressed)
	_unlock_all_abilities.pressed.connect(_on_unlock_all_abilities_pressed)
	CultivationManager.core_density_level_updated.connect(_show_stage.unbind(2))
	CultivationManager.advancement_stage_changed.connect(_show_stage.unbind(1))
	ResourceManager.health_changed.connect(_show_health.unbind(1))
	CharacterManager.stats_changed.connect(_show_health)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_madra_set_pressed() -> void:
	_show_result(DevCommands.set_madra(_madra_spin.value))

func _on_health_set_pressed() -> void:
	_show_result(DevCommands.set_health(_health_spin.value))

func _on_gold_set_pressed() -> void:
	_show_result(DevCommands.set_gold(_gold_spin.value))

func _on_level_reach_pressed() -> void:
	_show_result(DevCommands.reach_core_density(int(_level_spin.value)))

func _on_advance_stage_pressed() -> void:
	_show_result(DevCommands.advance_stage())

func _on_points_add_pressed() -> void:
	_show_result(DevCommands.add_path_points(int(_points_spin.value)))

func _on_stat_set_pressed() -> void:
	_show_result(DevCommands.set_stat_level(StringName(_picked_id(_stat_option)), int(_stat_level_spin.value), _stat_xp_spin.value))

func _on_technique_unlock_pressed() -> void:
	_show_result(DevCommands.unlock_technique(_picked_id(_technique_option)))

func _on_technique_equip_pressed() -> void:
	_show_result(DevCommands.equip_technique(_picked_id(_technique_option)))

func _on_unlock_all_techniques_pressed() -> void:
	_show_result(DevCommands.unlock_all_techniques())

func _on_drill_unlock_pressed() -> void:
	_show_result(DevCommands.unlock_drill(_picked_id(_drill_option)))

func _on_drill_equip_pressed() -> void:
	_show_result(DevCommands.equip_drill(_picked_id(_drill_option)))

func _on_unlock_all_drills_pressed() -> void:
	_show_result(DevCommands.unlock_all_drills())

func _on_ability_unlock_pressed() -> void:
	_show_result(DevCommands.unlock_ability(_picked_id(_ability_option)))

func _on_ability_equip_pressed() -> void:
	_show_result(DevCommands.equip_ability(_picked_id(_ability_option), int(_ability_slot_spin.value)))

func _on_unlock_all_abilities_pressed() -> void:
	_show_result(DevCommands.unlock_all_abilities())

#-----------------------------------------------------------------------------
# PRIVATE HELPERS
#-----------------------------------------------------------------------------

## Shows why a command refused, above the controls, and hides the line once a command
## works (it returns "").
func _show_result(refusal: String) -> void:
	_status.text = refusal
	_status.visible = refusal != ""

## Shows the stage and Core Density, as "Stage: Foundation · Core Density 42 / 100".
func _show_stage() -> void:
	_stage_label.text = "Stage: %s · Core Density %d / %d" % [
		CultivationManager.get_current_advancement_stage_name(),
		int(CultivationManager.get_core_density_level()),
		CultivationManager.get_core_density_cap(),
	]

## Shows the saved Health pool over its max, as "Health 40 / 100", printed as
## every Health readout prints it (VitalsText), so the panel and the cabinet
## never show two Health numbers.
func _show_health() -> void:
	_health_label.text = "Health %s" % VitalsText.health_pair(ResourceManager.get_health(), ResourceManager.get_max_health())

## The id of the item the picker shows, or "" when it has none, which the commands refuse
## as an unknown id.
func _picked_id(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return option.get_item_metadata(option.selected)
