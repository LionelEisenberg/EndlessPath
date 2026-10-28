extends ScrollContainer

## The dev panel's Player tab: the player's resources and progress, each set through
## DevCommands, which logs the change and says why it refused. Madra and gold are set
## to a value. Core Density is reached through real XP, so the milestones pay, and the
## stage shows next to it with a button to break through to the next. Path Points and a
## base attribute are added to. A cycling technique or a combat ability is unlocked, or
## equipped (an ability in the slot picked), or all of them are unlocked. A refusal
## shows above the controls until a command works.

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _status: Label = %PlayerStatus
@onready var _madra_spin: SpinBox = %MadraSpin
@onready var _madra_set: Button = %MadraSet
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _gold_set: Button = %GoldSet
@onready var _level_spin: SpinBox = %LevelSpin
@onready var _level_reach: Button = %LevelReach
@onready var _stage_label: Label = %StageLabel
@onready var _advance_stage: Button = %AdvanceStage
@onready var _points_spin: SpinBox = %PointsSpin
@onready var _points_add: Button = %PointsAdd
@onready var _attribute_option: OptionButton = %AttributeOption
@onready var _attribute_spin: SpinBox = %AttributeSpin
@onready var _attribute_add: Button = %AttributeAdd
@onready var _technique_option: OptionButton = %TechniqueOption
@onready var _technique_unlock: Button = %TechniqueUnlock
@onready var _technique_equip: Button = %TechniqueEquip
@onready var _unlock_all_techniques: Button = %UnlockAllTechniques
@onready var _ability_option: OptionButton = %AbilityOption
@onready var _ability_unlock: Button = %AbilityUnlock
@onready var _ability_equip: Button = %AbilityEquip
@onready var _ability_slot_spin: SpinBox = %AbilitySlotSpin
@onready var _unlock_all_abilities: Button = %UnlockAllAbilities

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

## Lists the attributes, the techniques and the abilities in their pickers, each item's
## metadata what its command takes (the attribute's enum value, the others' ids), shows
## the stage, and keeps it showing as the core and the stage change.
func _ready() -> void:
	for attribute: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		_attribute_option.add_item(CharacterManager.get_attribute_display_name(attribute))
		_attribute_option.set_item_metadata(_attribute_option.item_count - 1, attribute)
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		_technique_option.add_item(technique.technique_name)
		_technique_option.set_item_metadata(_technique_option.item_count - 1, technique.id)
	for ability: AbilityData in AbilityManager.get_all_abilities():
		_ability_option.add_item(ability.ability_name)
		_ability_option.set_item_metadata(_ability_option.item_count - 1, ability.ability_id)
	_show_stage()
	_madra_set.pressed.connect(_on_madra_set_pressed)
	_gold_set.pressed.connect(_on_gold_set_pressed)
	_level_reach.pressed.connect(_on_level_reach_pressed)
	_advance_stage.pressed.connect(_on_advance_stage_pressed)
	_points_add.pressed.connect(_on_points_add_pressed)
	_attribute_add.pressed.connect(_on_attribute_add_pressed)
	_technique_unlock.pressed.connect(_on_technique_unlock_pressed)
	_technique_equip.pressed.connect(_on_technique_equip_pressed)
	_unlock_all_techniques.pressed.connect(_on_unlock_all_techniques_pressed)
	_ability_unlock.pressed.connect(_on_ability_unlock_pressed)
	_ability_equip.pressed.connect(_on_ability_equip_pressed)
	_unlock_all_abilities.pressed.connect(_on_unlock_all_abilities_pressed)
	CultivationManager.core_density_level_updated.connect(_show_stage.unbind(2))
	CultivationManager.advancement_stage_changed.connect(_show_stage.unbind(1))

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_madra_set_pressed() -> void:
	_show_result(DevCommands.set_madra(_madra_spin.value))

func _on_gold_set_pressed() -> void:
	_show_result(DevCommands.set_gold(_gold_spin.value))

func _on_level_reach_pressed() -> void:
	_show_result(DevCommands.reach_core_density(int(_level_spin.value)))

func _on_advance_stage_pressed() -> void:
	_show_result(DevCommands.advance_stage())

func _on_points_add_pressed() -> void:
	_show_result(DevCommands.add_path_points(int(_points_spin.value)))

func _on_attribute_add_pressed() -> void:
	var attribute: CharacterAttributesData.AttributeType = _attribute_option.get_item_metadata(_attribute_option.selected)
	_show_result(DevCommands.add_attribute(attribute, _attribute_spin.value))

func _on_technique_unlock_pressed() -> void:
	_show_result(DevCommands.unlock_technique(_picked_id(_technique_option)))

func _on_technique_equip_pressed() -> void:
	_show_result(DevCommands.equip_technique(_picked_id(_technique_option)))

func _on_unlock_all_techniques_pressed() -> void:
	_show_result(DevCommands.unlock_all_techniques())

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

## The id of the item the picker shows, or "" when it has none, which the commands refuse
## as an unknown id.
func _picked_id(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return option.get_item_metadata(option.selected)
