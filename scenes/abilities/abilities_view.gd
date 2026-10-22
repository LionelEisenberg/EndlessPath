class_name AbilitiesView
extends MenuBookView

## Abilities book: your abilities on the left page, filtered with the
## inventory's selector and listed in loadout order; the loadout and the
## details of the ability you point at on the right page. Drag an ability onto
## a loadout slot, or right-click it to equip it into the first free slot or
## unequip it. The details card keeps the same layout for every ability, so
## pointing around never moves the page.

enum FilterMode { ALL, OFFENSIVE, BUFF, EQUIPPED }

## What an ability mainly does. Picks its type icon and its first stat line.
enum AbilityKind { DAMAGE, HEAL, BUFF, DEBUFF, OTHER }

## Filter selector options, in FilterMode order.
const FILTER_OPTIONS: PackedStringArray = ["All", "Offensive", "Buff", "Equipped"]

const AbilityRowScene: PackedScene = preload("res://scenes/abilities/ability_row/ability_row.tscn")

const _KIND_ICONS: Dictionary = {
	AbilityKind.DAMAGE: preload("res://assets/sprites/ui/stat_icons/combat_icon.png"),
	AbilityKind.HEAL: preload("res://assets/sprites/ui/stat_icons/health_icon.png"),
	AbilityKind.BUFF: preload("res://assets/sprites/ui/book/type_buff_ai.png"),
	AbilityKind.DEBUFF: preload("res://assets/sprites/ui/book/type_debuff_ai.png"),
}

## The Character book's attribute icons, for the damage breakdown.
const _ATTRIBUTE_ICONS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: preload("res://assets/sprites/ui/attribute_icons/strength_icon.png"),
	CharacterAttributesData.AttributeType.BODY: preload("res://assets/sprites/ui/attribute_icons/body_icon.png"),
	CharacterAttributesData.AttributeType.AGILITY: preload("res://assets/sprites/ui/attribute_icons/agility_icon.png"),
	CharacterAttributesData.AttributeType.SPIRIT: preload("res://assets/sprites/ui/attribute_icons/spirit_icon.png"),
	CharacterAttributesData.AttributeType.FOUNDATION: preload("res://assets/sprites/ui/attribute_icons/foundation_icon.png"),
	CharacterAttributesData.AttributeType.CONTROL: preload("res://assets/sprites/ui/attribute_icons/control_icon_ai.png"),
	CharacterAttributesData.AttributeType.RESILIENCE: preload("res://assets/sprites/ui/attribute_icons/resilience_icon.png"),
	CharacterAttributesData.AttributeType.WILLPOWER: preload("res://assets/sprites/ui/attribute_icons/willpower_icon.png"),
}

var _filter_mode: FilterMode = FilterMode.ALL
var _rows: Array[AbilityRow] = []
## The ability the right page describes.
var _selected_id: String = ""
## Damage and heal previews by ability id, so pointing back and forth doesn't
## redo them. Cleared on each opening and whenever a base attribute changes.
var _value_previews: Dictionary[String, float] = {}

@onready var _filter_selector: SortSubBanner = %FilterSelector
@onready var _ability_list: VBoxContainer = %AbilityList
@onready var _equip_slots: Array[AbilityEquipSlot] = [%EquipSlot1, %EquipSlot2, %EquipSlot3, %EquipSlot4]
@onready var _slot_counter: Label = %SlotCounter
@onready var _detail_card: Control = %DetailCard
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name: Label = %DetailName
@onready var _detail_badges: Label = %DetailBadges
@onready var _detail_tags: Label = %DetailTags
@onready var _type_icon: TextureRect = %TypeIcon
@onready var _primary_name: Label = %PrimaryName
@onready var _primary_value: Label = %PrimaryValue
@onready var _explain_text: Label = %ExplainText
@onready var _scaling_parts: Array[ScalingPart] = [%ScalingPart1, %ScalingPart2, %ScalingPart3]
@onready var _cooldown_value: Label = %CooldownValue
@onready var _cast_value: Label = %CastValue
@onready var _cost_value: Label = %CostValue
@onready var _detail_description: Label = %DetailDescription

func _ready() -> void:
	super._ready()
	_filter_selector.set_options(FILTER_OPTIONS)
	_filter_selector.option_changed.connect(_on_filter_changed)
	for i: int in range(_equip_slots.size()):
		_equip_slots[i].setup(i)
		_equip_slots[i].ability_dropped.connect(_on_ability_dropped)
	CharacterManager.base_attribute_changed.connect(_on_base_attribute_changed)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Refreshes the list, the loadout and the details from AbilityManager.
func refresh() -> void:
	_rebuild_rows()
	_update_loadout()
	_show_details(_find_ability(_selected_id))

## Describes the given ability on the right page and marks its row. Pointing
## again at the ability already described changes nothing.
func select_ability(ability_id: String) -> void:
	if ability_id == _selected_id:
		return
	_selected_id = ability_id
	for row: AbilityRow in _rows:
		row.set_selected(row.get_ability_data().ability_id == ability_id)
	_show_details(_find_ability(ability_id))

## The ability the right page describes, or "" when there is none.
func get_selected_ability_id() -> String:
	return _selected_id

## The rows currently listed, in display order.
func get_rows() -> Array[AbilityRow]:
	return _rows

## Equips the ability into the first free slot, or unequips it when it is
## equipped. Does nothing to an unequipped ability while every slot is full.
func toggle_equipped(ability_id: String) -> void:
	if AbilityManager.is_ability_equipped(ability_id):
		AbilityManager.unequip_ability(ability_id)
	elif AbilityManager.get_filled_slot_count() < AbilityManager.get_max_slots():
		AbilityManager.equip_ability(ability_id)
	else:
		return
	refresh()

#-----------------------------------------------------------------------------
# HOOKS
#-----------------------------------------------------------------------------

func _before_open() -> void:
	_selected_id = ""
	_value_previews.clear()
	refresh()
	if not _rows.is_empty():
		select_ability(_rows[0].get_ability_data().ability_id)

#-----------------------------------------------------------------------------
# LIST
#-----------------------------------------------------------------------------

func _rebuild_rows() -> void:
	# Never called from a row's own input: right-click equips are deferred.
	for row: AbilityRow in _rows:
		_ability_list.remove_child(row)
		row.free()
	_rows.clear()

	var unlocked: Array[AbilityData] = AbilityManager.get_unlocked_abilities()
	for ability: AbilityData in _order_by_loadout(_apply_filter(unlocked)):
		var row: AbilityRow = AbilityRowScene.instantiate() as AbilityRow
		_ability_list.add_child(row)
		row.setup(ability, _slot_of(ability.ability_id))
		row.set_selected(ability.ability_id == _selected_id)
		row.hovered.connect(_on_row_hovered)
		row.quick_equip_requested.connect(_on_row_quick_equip_requested)
		_rows.append(row)

func _apply_filter(abilities: Array[AbilityData]) -> Array[AbilityData]:
	if _filter_mode == FilterMode.ALL:
		return abilities
	var result: Array[AbilityData] = []
	for ability: AbilityData in abilities:
		match _filter_mode:
			FilterMode.OFFENSIVE:
				if not ability.effects_on_target.is_empty():
					result.append(ability)
			FilterMode.BUFF:
				if ability.effects_on_target.is_empty():
					result.append(ability)
			FilterMode.EQUIPPED:
				if AbilityManager.is_ability_equipped(ability.ability_id):
					result.append(ability)
	return result

## The equipped abilities in slot order (Q, W, E, R), then the rest by name.
func _order_by_loadout(abilities: Array[AbilityData]) -> Array[AbilityData]:
	var ordered: Array[AbilityData] = abilities.duplicate()
	var unequipped_rank: int = AbilityManager.get_max_slots()
	ordered.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
		var a_slot: int = _slot_of(a.ability_id)
		var b_slot: int = _slot_of(b.ability_id)
		var a_rank: int = a_slot if a_slot >= 0 else unequipped_rank
		var b_rank: int = b_slot if b_slot >= 0 else unequipped_rank
		if a_rank != b_rank:
			return a_rank < b_rank
		return a.ability_name < b.ability_name
	)
	return ordered

#-----------------------------------------------------------------------------
# LOADOUT
#-----------------------------------------------------------------------------

func _update_loadout() -> void:
	for i: int in range(_equip_slots.size()):
		var ability: AbilityData = _find_ability(AbilityManager.get_ability_at_slot(i))
		if ability:
			_equip_slots[i].set_ability(ability)
		else:
			_equip_slots[i].clear_slot()
	_slot_counter.text = "%d / %d equipped" % [AbilityManager.get_filled_slot_count(), AbilityManager.get_max_slots()]

## The loadout slot holding the ability, or -1.
func _slot_of(ability_id: String) -> int:
	for i: int in range(AbilityManager.get_max_slots()):
		if AbilityManager.get_ability_at_slot(i) == ability_id:
			return i
	return -1

#-----------------------------------------------------------------------------
# DETAILS
#-----------------------------------------------------------------------------

func _show_details(ability: AbilityData) -> void:
	_detail_card.visible = ability != null
	if ability == null:
		return
	var kind: AbilityKind = _get_kind(ability)
	_detail_icon.texture = ability.icon
	_detail_name.text = ability.ability_name
	_detail_badges.text = _describe_badges(ability)
	_detail_tags.text = " · ".join(_describe_tags(ability, kind))
	_type_icon.texture = _KIND_ICONS.get(kind)
	_show_primary_stat(ability, kind)
	_cooldown_value.text = AbilityRow.format_seconds(ability.base_cooldown)
	_cast_value.text = AbilityRow.format_seconds(ability.cast_time) if ability.cast_time > 0.0 else "Instant"
	var cost: String = AbilityRow.format_cost(ability)
	_cost_value.text = cost if not cost.is_empty() else "Free"
	_detail_description.text = ability.description

func _get_kind(ability: AbilityData) -> AbilityKind:
	if ability.deals_damage():
		return AbilityKind.DAMAGE
	if ability.heals_self():
		return AbilityKind.HEAL
	if ability.buffs_self():
		return AbilityKind.BUFF
	if ability.debuffs_target():
		return AbilityKind.DEBUFF
	return AbilityKind.OTHER

## The first stat line and its explainer: damage or healing with how it adds
## up, or what a buff or debuff does and for how long.
func _show_primary_stat(ability: AbilityData, kind: AbilityKind) -> void:
	_explain_text.text = ""
	for part: ScalingPart in _scaling_parts:
		part.visible = false
	match kind:
		AbilityKind.DAMAGE:
			_primary_name.text = "Damage"
			_show_value_breakdown(ability.ability_id, _find_effect(ability.effects_on_target, CombatEffectData.EffectType.DAMAGE))
		AbilityKind.HEAL:
			_primary_name.text = "Heal"
			_show_value_breakdown(ability.ability_id, _find_effect(ability.effects_on_self, CombatEffectData.EffectType.HEAL))
		AbilityKind.BUFF:
			_primary_name.text = "Effect"
			_show_buff(_find_effect(ability.effects_on_self, CombatEffectData.EffectType.BUFF) as BuffEffectData, "you")
		AbilityKind.DEBUFF:
			_primary_name.text = "Effect"
			_show_buff(_find_effect(ability.effects_on_target, CombatEffectData.EffectType.BUFF) as BuffEffectData, "the target")
		_:
			_primary_name.text = "Effect"
			_primary_value.text = "—"

## The value with the player's attributes now, then its base and what each
## attribute adds, for example "10 base" then Strength "+17" and Agility "+7".
func _show_value_breakdown(ability_id: String, effect: CombatEffectData) -> void:
	_primary_value.text = AbilityRow.format_number(_get_value_preview(ability_id, effect))
	if effect.base_value != 0.0:
		_explain_text.text = "%s base" % AbilityRow.format_number(effect.base_value)
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	var part_index: int = 0
	for attribute: int in CharacterAttributesData.AttributeType.values():
		var attribute_type: CharacterAttributesData.AttributeType = attribute as CharacterAttributesData.AttributeType
		if effect.get_scaling(attribute_type) == 0.0 or part_index >= _scaling_parts.size():
			continue
		var part: ScalingPart = _scaling_parts[part_index]
		part.setup(_ATTRIBUTE_ICONS[attribute_type], effect.get_scaling_contribution(attribute_type, attrs))
		part.visible = true
		part_index += 1

## The effect's value with the player's attributes, worked out the first time
## the ability is described in this opening.
func _get_value_preview(ability_id: String, effect: CombatEffectData) -> float:
	if not _value_previews.has(ability_id):
		_value_previews[ability_id] = effect.calculate_value(CharacterManager.get_total_attributes_data())
	return _value_previews[ability_id]

func _show_buff(buff: BuffEffectData, wearer: String) -> void:
	if buff == null:
		_primary_value.text = "—"
		return
	_primary_value.text = _describe_buff(buff)
	_explain_text.text = "on your next attack" if buff.consume_on_use else "for %s on %s" % [AbilityRow.format_seconds(buff.duration), wearer]

## What a buff does at a glance, for example "×1.5 damage".
func _describe_buff(buff: BuffEffectData) -> String:
	match buff.buff_type:
		BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER:
			return "×%s damage" % AbilityRow.format_number(buff.damage_multiplier)
		BuffEffectData.BuffType.DAMAGE_OVER_TIME:
			return "%s damage per tick" % AbilityRow.format_number(buff.dot_damage_per_tick)
		BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE:
			var parts: PackedStringArray = []
			for attribute: CharacterAttributesData.AttributeType in buff.attribute_modifiers:
				parts.append("×%s %s" % [
					AbilityRow.format_number(buff.attribute_modifiers[attribute]),
					CharacterManager.get_attribute_display_name(attribute),
				])
			return ", ".join(parts)
	return "—"

## The first effect of the given type, or null.
func _find_effect(effects: Array[CombatEffectData], effect_type: CombatEffectData.EffectType) -> CombatEffectData:
	for effect: CombatEffectData in effects:
		if effect.effect_type == effect_type:
			return effect
	return null

func _describe_badges(ability: AbilityData) -> String:
	var parts: PackedStringArray = []
	if ability.madra_type != AbilityData.MadraType.NONE:
		parts.append(AbilityData.MadraType.keys()[ability.madra_type].capitalize())
	parts.append(AbilityData.AbilitySource.keys()[ability.ability_source].capitalize())
	return " · ".join(parts)

## Who the ability targets, then what it does besides its main kind (the type
## icon shows that).
func _describe_tags(ability: AbilityData, kind: AbilityKind) -> PackedStringArray:
	var tags: PackedStringArray = []
	var has_target_effects: bool = not ability.effects_on_target.is_empty()
	var has_self_effects: bool = not ability.effects_on_self.is_empty()
	if has_target_effects and has_self_effects:
		tags.append("Mixed")
	elif has_target_effects:
		tags.append("Targeted")
	else:
		tags.append("Self-cast")
	if ability.interrupts_target():
		tags.append("Interrupts")
	if ability.strips_target_buffs():
		tags.append("Strips buffs")
	if kind != AbilityKind.HEAL and ability.heals_self():
		tags.append("Heals you")
	if kind != AbilityKind.BUFF and ability.buffs_self():
		tags.append("Buffs you")
	if kind != AbilityKind.DEBUFF and ability.debuffs_target():
		tags.append("Debuffs")
	return tags

func _find_ability(ability_id: String) -> AbilityData:
	if ability_id.is_empty():
		return null
	for ability: AbilityData in AbilityManager.get_unlocked_abilities():
		if ability.ability_id == ability_id:
			return ability
	return null

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_row_hovered(row: AbilityRow) -> void:
	select_ability(row.get_ability_data().ability_id)

## Deferred: equipping rebuilds the rows, and the row that asked is still
## handling its click.
func _on_row_quick_equip_requested(ability_id: String) -> void:
	toggle_equipped.call_deferred(ability_id)

func _on_filter_changed(index: int) -> void:
	_filter_mode = index as FilterMode
	_rebuild_rows()

func _on_ability_dropped(ability_id: String, slot_index: int, from_slot: int) -> void:
	if from_slot >= 0:
		AbilityManager.swap_slots(from_slot, slot_index)
	else:
		AbilityManager.equip_ability_at_slot(ability_id, slot_index)
	refresh()

## A training tick can raise an attribute while the book is open.
func _on_base_attribute_changed(_attribute_type: CharacterAttributesData.AttributeType, _new_value: float) -> void:
	_value_previews.clear()
	if _detail_card.is_visible_in_tree():
		_show_details(_find_ability(_selected_id))
