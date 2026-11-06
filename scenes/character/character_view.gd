class_name CharacterView
extends MenuBookView

## Character book, on pressed paper. The left page holds the six stats as
## tiles, a Physical and a Spiritual row of three, each with its level, its XP
## toward the next level and its total, and under them "In a fight": the totals
## a fight reads. The right page describes the stat pointed at: its level
## against the stage's cap and its XP, what it does now and at the next level,
## and where its total comes from. The right page keeps the last stat pointed
## at; Strength is shown when the book opens. While it is shown, the book
## follows CharacterManager: every stat, level and XP change, gear's included;
## the stage, whose breakthrough raises the cap; and the Health and Madra pools
## the In a fight block shows.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## What the right page says each stat is.
const STAT_DESCRIPTIONS: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: "Raw physical power. Your physical techniques hit harder.",
	CharacterAttributesData.AttributeType.BODY: "Physical constitution. Sets your maximum Health.",
	CharacterAttributesData.AttributeType.AGILITY: "Speed and footwork. Sets your Stamina and how fast it returns, and gives you a chance to dodge.",
	CharacterAttributesData.AttributeType.SPIRIT: "The force of your Madra. Your Spirit techniques hit harder.",
	CharacterAttributesData.AttributeType.MIND: "The depth of your Madra channels. Sets your maximum Madra.",
	CharacterAttributesData.AttributeType.CONTROL: "Mastery of your techniques. They cost less Madra and come back sooner.",
}

## What the right page says, in place of its rows, for a stat that does
## nothing the player knows of yet: Strength or Spirit before any technique
## that scales with it.
const NO_EFFECTS_TEXT: String = "Not yet active"

const TableRowScene := preload("res://scenes/inventory/pressed/table_row/table_row.tscn")

## The rows whose value is a pool's amount, printed in that pool's ink, by
## label: the fight block's Health and Madra, Body's Max Health and Mind's Max
## Madra.
const _POOL_INKS: Dictionary = {
	"Health": ThemeConstants.BOOK_HEALTH_INK,
	"Max Health": ThemeConstants.BOOK_HEALTH_INK,
	"Madra": ThemeConstants.BOOK_MADRA_INK,
	"Max Madra": ThemeConstants.BOOK_MADRA_INK,
}

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _physical_tiles: GridContainer = %PhysicalTiles
@onready var _spiritual_tiles: GridContainer = %SpiritualTiles
@onready var _fight_left_column: VBoxContainer = %FightLeftColumn
@onready var _fight_right_column: VBoxContainer = %FightRightColumn
@onready var _detail_plaque: PageTitle = %DetailPlaque
@onready var _detail_group: Label = %DetailGroup
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_value: PaperTag = %DetailValue
@onready var _detail_level: Label = %DetailLevel
@onready var _detail_xp_bar: LacquerRod = %DetailXpBar
@onready var _detail_xp_label: Label = %DetailXpLabel
@onready var _detail_cap_seal: Label = %DetailCapSeal
@onready var _detail_description: Label = %DetailDescription
@onready var _next_level_caption: Label = %NextLevelCaption
@onready var _effect_rows: VBoxContainer = %EffectRows
@onready var _no_effects_label: Label = %NoEffectsLabel
@onready var _source_rows: VBoxContainer = %SourceRows

## All stat tiles, looked up by type for refreshing.
var _tiles_by_type: Dictionary = {}

## The tile the right page describes.
var _selected_tile: AttributeTile = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	super._ready()
	for tile: AttributeTile in _find_all_tiles():
		_tiles_by_type[tile.attribute_type] = tile
		tile.hovered.connect(_on_tile_hovered)
	_no_effects_label.text = NO_EFFECTS_TEXT
	CharacterManager.stats_changed.connect(_refresh_if_shown)
	CharacterManager.stat_level_changed.connect(_refresh_if_shown.unbind(2))
	CharacterManager.stat_xp_changed.connect(_refresh_if_shown.unbind(3))
	# The cap the pages show comes from the stage, so a breakthrough moves it.
	CultivationManager.advancement_stage_changed.connect(_refresh_if_shown.unbind(1))
	# The Health and Madra rows show the pools, which runs, cycling and the dev
	# panel move.
	ResourceManager.health_changed.connect(_on_pool_changed)
	ResourceManager.madra_changed.connect(_on_pool_changed)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Reads every stat from CharacterManager: each tile's level, XP and total, the
## In a fight block, and the stat the right page describes.
func refresh() -> void:
	for stat: CharacterAttributesData.AttributeType in _tiles_by_type:
		var tile: AttributeTile = _tiles_by_type[stat]
		tile.set_stat(
			CharacterManager.get_stat_level(stat),
			CharacterManager.get_stat_xp(stat),
			CharacterManager.get_stat_xp_to_next(stat),
			CharacterManager.is_stat_capped(stat),
			CharacterManager.get_stat(StatModifierData.for_attribute(stat)),
		)
	_rebuild_fight_rows()
	if _selected_tile:
		_show_details(_selected_tile)

## Describes the given stat on the right page and marks its tile. Pointing
## again at the stat already described changes nothing.
func select_attribute(attr_type: CharacterAttributesData.AttributeType) -> void:
	var tile: AttributeTile = _tiles_by_type.get(attr_type)
	if tile == null or tile == _selected_tile:
		return
	if _selected_tile:
		_selected_tile.set_selected(false)
	_selected_tile = tile
	tile.set_selected(true)
	_show_details(tile)

## The stat the right page describes.
func get_selected_attribute() -> CharacterAttributesData.AttributeType:
	return _selected_tile.attribute_type if _selected_tile else CharacterAttributesData.AttributeType.STRENGTH

#-----------------------------------------------------------------------------
# LINES
#-----------------------------------------------------------------------------
# What the pages print, as plain text: the rows add the BBCode.

## What the stat does, a line each, as {"label", "now", "next"}: its figure
## read from the `now` block and from the `next` one. First the values derived
## from the stat (Body's Max Health, Mind's Max Madra, Agility's Max Stamina,
## Stamina regen and Dodge chance, Control's Technique cost cut and Cooldown
## cut), then every effect of `abilities`, on the target or the caster, that
## scales with the stat, as "<ability> damage", "healing" or "effect".
static func effect_lines(stat: CharacterAttributesData.AttributeType, now: CharacterAttributesData, next: CharacterAttributesData, abilities: Array[AbilityData]) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	match stat:
		CharacterAttributesData.AttributeType.BODY:
			lines.append(_effect_line("Max Health", _number(now.get_max_health()), _number(next.get_max_health())))
		CharacterAttributesData.AttributeType.MIND:
			lines.append(_effect_line("Max Madra", _number(now.get_max_madra()), _number(next.get_max_madra())))
		CharacterAttributesData.AttributeType.AGILITY:
			lines.append(_effect_line("Max Stamina", _number(now.get_max_stamina()), _number(next.get_max_stamina())))
			lines.append(_effect_line("Stamina regen", "%s / s" % _number(now.get_stamina_regen()), "%s / s" % _number(next.get_stamina_regen())))
			lines.append(_effect_line("Dodge chance", _percent(now.get_dodge_chance()), _percent(next.get_dodge_chance())))
		CharacterAttributesData.AttributeType.CONTROL:
			lines.append(_effect_line("Technique cost cut", _percent(now.get_madra_cost_cut()), _percent(next.get_madra_cost_cut())))
			lines.append(_effect_line("Cooldown cut", _percent(now.get_cooldown_cut()), _percent(next.get_cooldown_cut())))
	for ability: AbilityData in abilities:
		for effects: Array in [ability.effects_on_target, ability.effects_on_self]:
			for effect: CombatEffectData in effects:
				if effect.get_scaling(stat) != 0.0:
					lines.append(_effect_line(
						"%s %s" % [ability.ability_name, _describe_effect_kind(effect)],
						_number(effect.calculate_value(now)),
						_number(effect.calculate_value(next)),
					))
	return lines

## Where the stat's total comes from, a line each, as {"label", "value"}: the
## value its trained level gives ("Trained (Lv 4)", "13"), then the bonus of
## the gear worn ("Gear", "+2").
static func source_lines(stat: CharacterAttributesData.AttributeType) -> Array[Dictionary]:
	var lines: Array[Dictionary] = [
		{"label": "Trained (Lv %d)" % CharacterManager.get_stat_level(stat), "value": _number(CharacterManager.get_trained_value(stat))},
		{"label": "Gear", "value": "+" + _number(CharacterManager.get_gear_bonus(stat))},
	]
	return lines

## The totals a fight reads, a line each, as {"label", "value"}, from
## CharacterManager.get_stat(): Health, Madra, Stamina, Dodge chance,
## Technique cost cut, Cooldown cut, Armor and Ward. Health and Madra are the
## saved pools over their maxima: "62 / 100" as every Health readout prints it
## (VitalsText), and "46 / 100".
static func fight_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = [
		{"label": "Health", "value": VitalsText.health_pair(ResourceManager.get_health(), ResourceManager.get_max_health())},
		{"label": "Madra", "value": "%d / %d" % [floori(ResourceManager.get_madra()), floori(ResourceManager.get_max_madra())]},
		{"label": "Stamina", "value": _number(CharacterManager.get_stat(StatModifierData.Stat.MAX_STAMINA))},
		{"label": "Dodge chance", "value": _percent(CharacterManager.get_stat(StatModifierData.Stat.DODGE_CHANCE))},
		{"label": "Technique cost cut", "value": _percent(CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT))},
		{"label": "Cooldown cut", "value": _percent(CharacterManager.get_stat(StatModifierData.Stat.COOLDOWN_CUT))},
		{"label": "Armor", "value": _number(CharacterManager.get_stat(StatModifierData.Stat.ARMOR))},
		{"label": "Ward", "value": _number(CharacterManager.get_stat(StatModifierData.Stat.WARD))},
	]
	return lines

#-----------------------------------------------------------------------------
# HOOKS
#-----------------------------------------------------------------------------

func _before_open() -> void:
	select_attribute(CharacterAttributesData.AttributeType.STRENGTH)
	refresh()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _find_all_tiles() -> Array[AttributeTile]:
	var tiles: Array[AttributeTile] = []
	for group: GridContainer in [_physical_tiles, _spiritual_tiles]:
		for child: Node in group.get_children():
			if child is AttributeTile:
				tiles.append(child as AttributeTile)
	return tiles

## Re-reads the stats while the book is shown; a closed book refreshes as it
## opens.
func _refresh_if_shown() -> void:
	if is_visible_in_tree():
		refresh()

## A Health or Madra pool change rebuilds only the In a fight rows, while the
## book is shown.
func _on_pool_changed(_amount: float) -> void:
	if is_visible_in_tree():
		_rebuild_fight_rows()

func _show_details(tile: AttributeTile) -> void:
	var stat: CharacterAttributesData.AttributeType = tile.attribute_type
	var level: int = CharacterManager.get_stat_level(stat)
	var capped: bool = CharacterManager.is_stat_capped(stat)
	var now: CharacterAttributesData = CharacterManager.get_total_attributes_data()

	_detail_plaque.title = StatDisplay.name_of(stat)
	_detail_group.text = StatDisplay.side_name(stat).to_upper()
	_detail_icon.texture = StatDisplay.icon_of(stat)
	_detail_value.set_figure("%.0f" % CharacterManager.get_stat(StatModifierData.for_attribute(stat)))
	_detail_level.text = "Lv %d / %d" % [level, CharacterManager.get_stat_level_cap()]

	# At the cap the bar is full under the seal, and there is no next level.
	_detail_cap_seal.visible = capped
	_detail_xp_label.visible = not capped
	_next_level_caption.visible = not capped
	var xp: float = CharacterManager.get_stat_xp(stat)
	var xp_to_next: float = CharacterManager.get_stat_xp_to_next(stat)
	_detail_xp_bar.set_fraction(AttributeTile.xp_fraction(xp, xp_to_next, capped))
	if not capped:
		_detail_xp_label.text = "%d / %d XP" % [floori(xp), ceili(xp_to_next)]
		_next_level_caption.text = "NOW → LV %d" % (level + 1)

	_detail_description.text = STAT_DESCRIPTIONS.get(stat, "")

	var lines: Array[Dictionary] = effect_lines(stat, now, _next_level_block(stat, now, level), AbilityManager.get_unlocked_abilities())
	_clear_rows(_effect_rows)
	for line: Dictionary in lines:
		_add_row(_effect_rows, line.label, line.now if capped else "%s → %s" % [line.now, line.next])
	_no_effects_label.visible = lines.is_empty()

	_clear_rows(_source_rows)
	for line: Dictionary in source_lines(stat):
		_add_row(_source_rows, line.label, line.value)

## The block `now` would be one level up in `stat`: the stat raised by what its
## next level adds, every bonus kept as it is now, gear's included.
func _next_level_block(stat: CharacterAttributesData.AttributeType, now: CharacterAttributesData, level: int) -> CharacterAttributesData:
	var progression: StatProgressionData = CharacterManager.stat_progression
	var next: CharacterAttributesData = now.duplicate() as CharacterAttributesData
	next.set_attribute(stat, now.get_attribute(stat) + progression.get_value_for_level(level + 1) - progression.get_value_for_level(level))
	return next

## Rebuilds the In a fight block from fight_lines() in its two columns, whose
## widths the scene sets: the first half of the lines runs down the left column
## and the rest down the right.
func _rebuild_fight_rows() -> void:
	var lines: Array[Dictionary] = fight_lines()
	var half: int = ceili(lines.size() / 2.0)
	_clear_rows(_fight_left_column)
	_clear_rows(_fight_right_column)
	for index: int in lines.size():
		var column: VBoxContainer = _fight_left_column if index < half else _fight_right_column
		_add_row(column, lines[index].label, lines[index].value)

## Adds a TableRow to `container`: `label` in capitals, and the value with its
## decimal points set for the page, a Health or Madra amount in its pool's ink.
func _add_row(container: Container, label: String, value: String) -> TableRow:
	var row: TableRow = TableRowScene.instantiate() as TableRow
	container.add_child(row)
	var value_bbcode: String = LacquerText.decimal_bbcode(value)
	if _POOL_INKS.has(label):
		# The tag goes on after decimal_bbcode(), which escapes every "[" it is given.
		value_bbcode = "[color=#%s]%s[/color]" % [(_POOL_INKS[label] as Color).to_html(false), value_bbcode]
	row.setup(label.to_upper(), value_bbcode)
	return row

## Frees the container's rows at once, so a rebuild never counts the old ones.
func _clear_rows(container: Container) -> void:
	for row: Node in container.get_children():
		container.remove_child(row)
		row.free()

## One line of effect_lines().
static func _effect_line(label: String, now_text: String, next_text: String) -> Dictionary:
	return {"label": label, "now": now_text, "next": next_text}

## A number as the pages print it: "3", "1.5".
static func _number(value: float) -> String:
	return AbilityRow.format_number(value)

## A fraction as a percent to a tenth: 0.0875 is "8.8%", 0.1 is "10%".
static func _percent(value: float) -> String:
	return "%s%%" % AbilityRow.format_number(snappedf(value * 100.0, 0.1))

static func _describe_effect_kind(effect: CombatEffectData) -> String:
	match effect.effect_type:
		CombatEffectData.EffectType.DAMAGE:
			return "damage"
		CombatEffectData.EffectType.HEAL:
			return "healing"
	return "effect"

func _on_tile_hovered(tile: AttributeTile) -> void:
	select_attribute(tile.attribute_type)
