class_name AbilitiesView
extends Control

## AbilitiesView
## Manages the ability list, filter bar, sort, loadout sidebar, and card interactions.

enum FilterMode { ALL, OFFENSIVE, BUFF, EQUIPPED }
enum SortMode { EQUIPPED_FIRST, NAME_AZ, MADRA_COST, COOLDOWN }

const AbilityCardScene: PackedScene = preload("res://scenes/abilities/ability_card/ability_card.tscn")

var _filter_mode: FilterMode = FilterMode.ALL
var _sort_mode: SortMode = SortMode.EQUIPPED_FIRST
var _cards: Array[AbilityCard] = []
var _expanded_card: AbilityCard = null

@onready var _card_list: VBoxContainer = %CardList
@onready var _slot_counter: Label = %SlotCounter
@onready var _sort_dropdown: OptionButton = %SortDropdown
@onready var _equip_slots: Array[TextureRect] = [%EquipSlot1, %EquipSlot2, %EquipSlot3, %EquipSlot4]
@onready var _filter_all: Button = %FilterAll
@onready var _filter_offensive: Button = %FilterOffensive
@onready var _filter_buff: Button = %FilterBuff
@onready var _filter_equipped: Button = %FilterEquipped

func _ready() -> void:
	_setup_sort_dropdown()
	_setup_filter_buttons()
	visibility_changed.connect(_on_visibility_changed)

# ----- Public API -----

## Refreshes the entire view from AbilityManager state.
func refresh() -> void:
	_rebuild_card_list()
	_update_loadout_sidebar()
	_update_slot_counter()

# ----- Private: Setup -----

func _setup_sort_dropdown() -> void:
	_sort_dropdown.clear()
	_sort_dropdown.add_item("Equipped First", SortMode.EQUIPPED_FIRST)
	_sort_dropdown.add_item("Name A-Z", SortMode.NAME_AZ)
	_sort_dropdown.add_item("Madra Cost", SortMode.MADRA_COST)
	_sort_dropdown.add_item("Cooldown", SortMode.COOLDOWN)
	_sort_dropdown.selected = 0
	_sort_dropdown.item_selected.connect(_on_sort_changed)

func _setup_filter_buttons() -> void:
	_filter_all.pressed.connect(_on_filter_pressed.bind(FilterMode.ALL))
	_filter_offensive.pressed.connect(_on_filter_pressed.bind(FilterMode.OFFENSIVE))
	_filter_buff.pressed.connect(_on_filter_pressed.bind(FilterMode.BUFF))
	_filter_equipped.pressed.connect(_on_filter_pressed.bind(FilterMode.EQUIPPED))
	_update_filter_button_styles()

# ----- Private: Card Management -----

func _rebuild_card_list() -> void:
	for card: AbilityCard in _cards:
		card.queue_free()
	_cards.clear()
	_expanded_card = null

	var unlocked: Array[AbilityData] = AbilityManager.get_unlocked_abilities()
	var filtered: Array[AbilityData] = _apply_filter(unlocked)
	var sorted: Array[AbilityData] = _apply_sort(filtered)

	for ability: AbilityData in sorted:
		var card: AbilityCard = AbilityCardScene.instantiate()
		_card_list.add_child(card)
		card.setup(ability, AbilityManager.is_ability_equipped(ability.ability_id))
		card.equip_requested.connect(_on_equip_requested)
		card.unequip_requested.connect(_on_unequip_requested)
		card.card_selected.connect(_on_card_selected)
		_cards.append(card)

func _apply_filter(abilities: Array[AbilityData]) -> Array[AbilityData]:
	if _filter_mode == FilterMode.ALL:
		return abilities
	var result: Array[AbilityData] = []
	for ability: AbilityData in abilities:
		match _filter_mode:
			FilterMode.OFFENSIVE:
				if ability.target_type != AbilityData.TargetType.SELF:
					result.append(ability)
			FilterMode.BUFF:
				if ability.target_type == AbilityData.TargetType.SELF:
					result.append(ability)
			FilterMode.EQUIPPED:
				if AbilityManager.is_ability_equipped(ability.ability_id):
					result.append(ability)
	return result

func _apply_sort(abilities: Array[AbilityData]) -> Array[AbilityData]:
	var sorted: Array[AbilityData] = abilities.duplicate()
	match _sort_mode:
		SortMode.EQUIPPED_FIRST:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				var a_eq: bool = AbilityManager.is_ability_equipped(a.ability_id)
				var b_eq: bool = AbilityManager.is_ability_equipped(b.ability_id)
				if a_eq != b_eq:
					return a_eq
				return a.ability_name < b.ability_name
			)
		SortMode.NAME_AZ:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.ability_name < b.ability_name
			)
		SortMode.MADRA_COST:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.madra_cost < b.madra_cost
			)
		SortMode.COOLDOWN:
			sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
				return a.base_cooldown < b.base_cooldown
			)
	return sorted

# ----- Private: Loadout Sidebar -----

func _update_loadout_sidebar() -> void:
	var equipped: Array[AbilityData] = AbilityManager.get_equipped_abilities()
	for i: int in range(_equip_slots.size()):
		if i < equipped.size():
			_equip_slots[i].texture = equipped[i].icon
			_equip_slots[i].modulate = Color.WHITE
		else:
			_equip_slots[i].texture = null
			_equip_slots[i].modulate = Color(1, 1, 1, 0.3)

func _update_slot_counter() -> void:
	var equipped_count: int = AbilityManager.get_equipped_abilities().size()
	_slot_counter.text = "%d / %d" % [equipped_count, AbilityManager.get_max_slots()]

func _update_filter_button_styles() -> void:
	var buttons: Array[Button] = [_filter_all, _filter_offensive, _filter_buff, _filter_equipped]
	var modes: Array[FilterMode] = [FilterMode.ALL, FilterMode.OFFENSIVE, FilterMode.BUFF, FilterMode.EQUIPPED]
	for i: int in range(buttons.size()):
		if modes[i] == _filter_mode:
			buttons[i].add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
		else:
			buttons[i].remove_theme_color_override("font_color")

# ----- Signal Handlers -----

func _on_visibility_changed() -> void:
	if visible:
		refresh()

func _on_filter_pressed(mode: FilterMode) -> void:
	_filter_mode = mode
	_update_filter_button_styles()
	_rebuild_card_list()

func _on_sort_changed(_index: int) -> void:
	_sort_mode = _sort_dropdown.get_selected_id() as SortMode
	_rebuild_card_list()

func _on_card_selected(card: AbilityCard) -> void:
	if _expanded_card and _expanded_card != card:
		_expanded_card.collapse()
	_expanded_card = card

func _on_equip_requested(ability_id: String) -> void:
	AbilityManager.equip_ability(ability_id)
	refresh()

func _on_unequip_requested(ability_id: String) -> void:
	AbilityManager.unequip_ability(ability_id)
	refresh()
