class_name AbilityCard
extends PanelContainer

## Expandable ability card for the AbilitiesView.
## Shows a collapsed summary row; click to expand for details and equip/unequip.

signal equip_requested(ability_id: String)
signal unequip_requested(ability_id: String)
signal card_selected(card: AbilityCard)

var _ability_data: AbilityData = null
var _is_expanded: bool = false
var _is_equipped: bool = false

@onready var _icon: TextureRect = %AbilityIcon
@onready var _name_label: Label = %AbilityName
@onready var _cost_label: Label = %CostLabel
@onready var _madra_badge: Label = %MadraBadge
@onready var _source_badge: Label = %SourceBadge
@onready var _equipped_dot: Control = %EquippedDot
@onready var _expanded_details: VBoxContainer = %ExpandedDetails
@onready var _description_label: Label = %DescriptionLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _equip_button: Button = %EquipButton

func _ready() -> void:
	_equip_button.pressed.connect(_on_equip_button_pressed)
	gui_input.connect(_on_gui_input)

# ----- Public API -----

## Configures the card with ability data and equipped status.
func setup(ability_data: AbilityData, is_equipped: bool) -> void:
	_ability_data = ability_data
	_is_equipped = is_equipped
	_update_display()

## Updates equipped state without full rebuild.
func set_equipped(is_equipped: bool) -> void:
	_is_equipped = is_equipped
	_update_equipped_display()

## Collapses the card.
func collapse() -> void:
	_is_expanded = false
	_expanded_details.visible = false

## Returns the ability data for this card.
func get_ability_data() -> AbilityData:
	return _ability_data

# ----- Private -----

func _update_display() -> void:
	if not _ability_data:
		return

	_icon.texture = _ability_data.icon
	_name_label.text = _ability_data.ability_name

	# Cost summary
	_cost_label.text = _ability_data.get_total_cost_display() + " · %.1fs CD" % _ability_data.base_cooldown

	# Madra badge
	if _ability_data.madra_type == AbilityData.MadraType.NONE:
		_madra_badge.visible = false
	else:
		_madra_badge.visible = true
		_madra_badge.text = AbilityData.MadraType.keys()[_ability_data.madra_type]

	# Source badge
	_source_badge.text = AbilityData.AbilitySource.keys()[_ability_data.ability_source].capitalize()

	# Expanded details
	_description_label.text = _ability_data.description

	var target_name: String = AbilityData.TargetType.keys()[_ability_data.target_type].capitalize().replace("_", " ")
	var type_name: String = AbilityData.AbilityType.keys()[_ability_data.ability_type].capitalize()
	var cast_text: String = "Instant" if _ability_data.cast_time <= 0.0 else "%.1fs" % _ability_data.cast_time
	var madra_text: String = AbilityData.MadraType.keys()[_ability_data.madra_type].capitalize()
	_stats_label.text = "%s · %s · Cast: %s · Madra: %s" % [type_name, target_name, cast_text, madra_text]

	_update_equipped_display()

func _update_equipped_display() -> void:
	_equipped_dot.visible = _is_equipped
	if _is_equipped:
		_equip_button.text = "UNEQUIP"
	else:
		if AbilityManager and AbilityManager._live_save_data:
			if AbilityManager._live_save_data.equipped_ability_ids.size() >= AbilityManager.get_max_slots():
				_equip_button.text = "SLOTS FULL"
				_equip_button.disabled = true
				return
		_equip_button.text = "EQUIP"
	_equip_button.disabled = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_expanded:
			collapse()
		else:
			card_selected.emit(self)
			_is_expanded = true
			_expanded_details.visible = true

func _on_equip_button_pressed() -> void:
	if not _ability_data:
		return
	if _is_equipped:
		unequip_requested.emit(_ability_data.ability_id)
	else:
		equip_requested.emit(_ability_data.ability_id)
