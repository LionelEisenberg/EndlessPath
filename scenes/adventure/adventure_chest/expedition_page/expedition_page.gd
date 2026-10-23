class_name ExpeditionPage
extends AdventureChestPage

## The adventure chest's page for the map (spec: The right chest): the tile the
## player stands on, what it offers and the run so far. It holds three things,
## 408 wide from the page slot's top-left corner:
## - The Here tray: the tile's name, a carved tag (the BOSS seal for a boss) and
##   one line, with the encounter's glyph in its socket. Standing on an
##   unresolved encounter it names its kind (a fight also names the enemy and its
##   Health); on a resolved one it reads CLEARED and the line is what the tile
##   left behind; on open ground (a NoOp tile, or an encounter with no choices,
##   as the map treats it) it reads "Open ground" in tan.
## - The encounter: its lore, then a divider and one ChoiceDrawer per choice (at
##   most MAX_DRAWERS) saying what each does. A resolved tile shows its completed
##   text and the walk hint instead, which counts the steps the player's Stamina
##   still buys and follows it.
## - The Run ledger: fights, gold, tiles explored, and the run's latest loot.
## The page does not hear the map: the view calls show_tile(), show_resolved()
## and set_run_stats(). The lore, hint, divider and drawers flow in a
## VBoxContainer under the tray, so the page's content height is that box's
## bottom, and every change of tile emits content_resized for the chest to hug.
## Every row of the flow is an even number of px tall, as the mock's are: the
## lore Label is padded 2 px above and 1 under (a StyleBoxEmpty in the scene),
## which makes n wrapped lines 22 n tall and seats their glyphs as the mock's
## 22 px line boxes do; the walk hint's row is 10 + an 18 px line.
## The text rules are statics, so the tests and the page ask the same code.

## Emitted when the player presses an available drawer: the choice it stands for.
signal choice_selected(choice: EncounterChoice)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The scene holds this many choice drawers (the most choices any encounter has
## is two) and this many loot sockets.
const MAX_DRAWERS: int = 3
const MAX_LOOT: int = 6

const OPEN_GROUND_NAME: String = "Open ground"
const CLEARED_TAG: String = "CLEARED"
const COMPLETED_TEXT_FALLBACK: String = "Encounter completed."
const SEPARATOR: String = " · "
## The Here tray's line on open ground (%d: the Stamina a step costs).
const WALK_LINE_FORMAT: String = "Click a hex to walk · %d Stamina a step"
## The walk hint (%d, %d: the Stamina a step costs, the steps Stamina buys).
const WALK_HINT_FORMAT: String = "Click a hex to walk · %d Stamina a step · %d steps left"

## The glyph of a talk: the story icon, 16 px art shown at 32.
const STORY_GLYPH: Texture2D = preload("res://assets/ui/lacquer/icons/ic_story_ai.png")
const STORY_GLYPH_FRAME_SIZE: Vector2i = Vector2i(16, 16)

## The tray's name stops this far short of the tag or seal beside it. Beside the
## tag (at x 320, the name at x 78) that is the kit's 236 px; beside the wider
## BOSS seal (at x 308) it is 224, so a long boss name ellipsizes before the seal
## instead of running under it.
const NAME_GAP: float = 6.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _here_tray: Control = %HereTray
@onready var _glyph: LacquerStripRect = %Glyph
@onready var _name_label: Label = %NameLabel
@onready var _tag: Control = %Tag
@onready var _tag_label: Label = %TagLabel
@onready var _boss_seal: Control = %BossSeal
@onready var _boss_seal_label: Label = %BossSealLabel
@onready var _line_label: Label = %LineLabel
@onready var _flow: Control = %Flow
@onready var _lore_label: Label = %LoreLabel
@onready var _hint_row: Control = %HintRow
@onready var _walk_hint: Label = %WalkHint
@onready var _divider_row: Control = %DividerRow
@onready var _drawer_rows: Control = %DrawerRows
@onready var _drawers: Array[ChoiceDrawer] = [%ChoiceDrawer1, %ChoiceDrawer2, %ChoiceDrawer3]
@onready var _fights_value: Label = %FightsValue
@onready var _gold_value: Label = %GoldValue
@onready var _explored_value: Label = %ExploredValue
@onready var _loot_icons: Array[TextureRect] = [
	%LootIcon1, %LootIcon2, %LootIcon3, %LootIcon4, %LootIcon5, %LootIcon6,
]

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The encounter the tray shows (show_resolved() resolves that one) and the
## run's action, whose gold multiplier a fight's drawer counts in.
var _encounter: AdventureEncounter = null
var _adventure_action: AdventureActionData = null
## The choices behind the shown drawers, in order, which a press picks from.
var _shown_choices: Array[EncounterChoice] = []
## Where the tray rests, which the shake moves it from.
var _here_home: Vector2 = Vector2.ZERO
## Seconds into the tray's shake, or -1 while it is not shaking.
var _shake_elapsed: float = -1.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_here_home = _here_tray.position
	set_process(false)
	for index: int in MAX_DRAWERS:
		_drawers[index].pressed.connect(_on_drawer_pressed.bind(index))
	var vitals: VitalsManager = PlayerManager.vitals_manager
	if vitals != null:
		vitals.stamina_changed.connect(_on_stamina_changed)
		_walk_hint.text = walk_hint(vitals.current_stamina)
	_show_open_ground()

func _exit_tree() -> void:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	if vitals != null and vitals.stamina_changed.is_connected(_on_stamina_changed):
		vitals.stamina_changed.disconnect(_on_stamina_changed)

func _process(delta: float) -> void:
	if not is_here_shaking():
		return
	_shake_elapsed += delta
	_here_tray.position.x = _here_home.x + MapGlyph.shake_offset_at(_shake_elapsed)
	if _shake_elapsed >= MapGlyph.SHAKE_SECONDS:
		_shake_elapsed = -1.0
		set_process(false)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the tile the player stands on. `encounter` is its encounter (null,
## a NoOpEncounter, or one with no choices is open ground), `summary` the line
## its resolved encounter left behind ("" while it is not resolved), and
## `adventure_action` the run's action, whose gold multiplier a fight's drawer
## counts in. Always replaces what the page showed, and emits content_resized.
func show_tile(encounter: AdventureEncounter, summary: String, adventure_action: AdventureActionData) -> void:
	_encounter = encounter
	_adventure_action = adventure_action
	if _is_open_ground(encounter):
		_show_open_ground()
	elif summary.is_empty():
		_show_unresolved()
	else:
		_show_cleared(summary)
	content_resized.emit()

## Shows the tile the page last showed as resolved, with `summary` as the line
## it left behind: the CLEARED tag, the completed text, the walk hint, and no
## drawers. Does nothing when that tile is open ground (there is nothing there
## to resolve).
func show_resolved(summary: String) -> void:
	if _is_open_ground(_encounter):
		return
	_show_cleared(summary)
	content_resized.emit()

## Shows the run so far: fights fought of the fights on the map (the view counts
## every fight that ends, a lost one included), gold earned, tiles explored of
## the tiles on the map, and the run's loot, oldest first. The six sockets hold
## the latest six items; the rest are empty.
func set_run_stats(fights: int, fights_total: int, gold: int, explored: int, explored_total: int, loot: Array[ItemDefinitionData]) -> void:
	_fights_value.text = "%d / %d" % [fights, fights_total]
	_gold_value.text = str(gold)
	_explored_value.text = "%d / %d" % [explored, explored_total]
	var first: int = maxi(loot.size() - MAX_LOOT, 0)
	for index: int in MAX_LOOT:
		var item: ItemDefinitionData = loot[first + index] if first + index < loot.size() else null
		var icon: Texture2D = item.icon if item != null else null
		_loot_icons[index].texture = icon
		_loot_icons[index].visible = icon != null

## Shakes the Here tray side to side in the zone map's lock-shake steps, to say
## a click did nothing because an encounter on the tile waits for a choice. The
## rest of the page stays put. A new shake restarts it.
func shake_here() -> void:
	_shake_elapsed = 0.0
	_here_tray.position.x = _here_home.x + MapGlyph.shake_offset_at(0.0)
	set_process(true)

## Returns true while the Here tray is shaking.
func is_here_shaking() -> bool:
	return _shake_elapsed >= 0.0

## Returns the choice drawer at `index` (0 to MAX_DRAWERS - 1), shown or not, or
## null for an index outside them.
func get_drawer(index: int) -> ChoiceDrawer:
	if index < 0 or index >= MAX_DRAWERS:
		return null
	return _drawers[index]

## Returns how tall the page's content is: the bottom of the flow under the tray.
## It is asked of the layout's own minimum sizes, so it is right at once after a
## change, without waiting for the containers to sort.
func get_content_height() -> float:
	return _flow.position.y + _flow.get_combined_minimum_size().y

## Returns the word for what an encounter of the type is: Fight, Ambush, Elite,
## Boss, Rest, Trap or Treasure; "" for no encounter.
static func kind_word(type: AdventureEncounter.EncounterType) -> String:
	match type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR:
			return "Fight"
		AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			return "Ambush"
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			return "Elite"
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			return "Boss"
		AdventureEncounter.EncounterType.REST_SITE:
			return "Rest"
		AdventureEncounter.EncounterType.TRAP:
			return "Trap"
		AdventureEncounter.EncounterType.TREASURE:
			return "Treasure"
	return ""

## Returns the tag for an encounter of the type: FIGHT (a regular fight or an
## ambush), ELITE, BOSS, REST, TREASURE or TRAP; "" for no encounter.
static func kind_tag(type: AdventureEncounter.EncounterType) -> String:
	match type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			return "FIGHT"
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			return "ELITE"
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			return "BOSS"
		AdventureEncounter.EncounterType.REST_SITE:
			return "REST"
		AdventureEncounter.EncounterType.TREASURE:
			return "TREASURE"
		AdventureEncounter.EncounterType.TRAP:
			return "TRAP"
	return ""

## Returns the Here tray's line for an unresolved encounter. A fight reads
## "<kind> · <enemy> · <n> Health": the kind word, the name of the first enemy of
## its first combat choice (the one AdventureCombat fights) and that enemy's max
## Health as a whole number, by the same rule the fight uses
## (VitalsManager.max_health_for()). Any other encounter, and a fight with no
## enemy to name, reads its kind word.
static func here_line(encounter: AdventureEncounter) -> String:
	if encounter == null:
		return ""
	var word: String = kind_word(encounter.encounter_type)
	if not _is_fight(encounter.encounter_type):
		return word
	for choice: EncounterChoice in encounter.choices:
		var combat := choice as CombatChoice
		if combat == null or combat.enemy_pool.is_empty() or combat.enemy_pool[0] == null:
			continue
		var enemy: CombatantData = combat.enemy_pool[0]
		var health: int = floori(VitalsManager.max_health_for(enemy.attributes))
		return SEPARATOR.join([word, enemy.character_name, "%d Health" % health])
	return word

## Returns the detail line of a choice's drawer: its tooltip when it has one;
## otherwise, for a combat choice, "Uses <techniques> · <gold> gold if you win",
## with the first enemy's technique names and the gold the win pays
## (AdventureCombat.gold_reward_for()); otherwise "". A fight against an enemy
## with no techniques leaves the "Uses" part out, and one with no enemy at all
## says nothing.
static func choice_detail(choice: EncounterChoice, adventure_action: AdventureActionData) -> String:
	if choice == null:
		return ""
	if choice.tooltip != "":
		return choice.tooltip
	var combat := choice as CombatChoice
	if combat == null or combat.enemy_pool.is_empty() or combat.enemy_pool[0] == null:
		return ""
	var technique_names: PackedStringArray = PackedStringArray()
	for ability: AbilityData in combat.enemy_pool[0].abilities:
		if ability != null:
			technique_names.append(ability.ability_name)
	var gold_line: String = "%d gold if you win" % AdventureCombat.gold_reward_for(combat, adventure_action)
	if technique_names.is_empty():
		return gold_line
	return SEPARATOR.join(["Uses " + ", ".join(technique_names), gold_line])

## Returns the walk hint for the Stamina: the cost of a step and the whole
## steps the Stamina still buys.
static func walk_hint(stamina: float) -> String:
	var cost: float = AdventureTilemap.MOVEMENT_STAMINA_COST
	return WALK_HINT_FORMAT % [int(cost), floori(stamina / cost)]

#-----------------------------------------------------------------------------
# THE TILE'S THREE LOOKS
#-----------------------------------------------------------------------------

## Open ground: a tan name, no glyph, tag or seal, the walk line, and nothing
## under the tray but the ledger.
func _show_open_ground() -> void:
	_name_label.text = OPEN_GROUND_NAME
	_name_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_TAN)
	_glyph.strip = null
	_glyph.visible = false
	_show_tag("", false)
	_line_label.text = WALK_LINE_FORMAT % int(AdventureTilemap.MOVEMENT_STAMINA_COST)
	_lore_label.visible = false
	_hint_row.visible = false
	_show_drawers(0)

## An unresolved encounter: its name, glyph and kind (a boss wears the seal), its
## lore, and one drawer per choice.
func _show_unresolved() -> void:
	_show_encounter_name_and_glyph()
	_show_tag(kind_tag(_encounter.encounter_type), _encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS)
	_line_label.text = here_line(_encounter)
	_show_lore(_encounter.description)
	_hint_row.visible = false
	_set_up_drawers()

## A resolved encounter: CLEARED and the summary under its name, the completed
## text, the walk hint, and no drawers.
func _show_cleared(summary: String) -> void:
	_show_encounter_name_and_glyph()
	_show_tag(CLEARED_TAG, false)
	_line_label.text = summary
	var completed_text: String = _encounter.text_description_completed
	_show_lore(completed_text if completed_text != "" else COMPLETED_TEXT_FALLBACK)
	_walk_hint.text = walk_hint(_player_stamina())
	_hint_row.visible = true
	_show_drawers(0)

func _show_encounter_name_and_glyph() -> void:
	_name_label.text = _encounter.encounter_name
	_name_label.remove_theme_color_override(&"font_color")
	var type: AdventureEncounter.EncounterType = _encounter.encounter_type
	var glyph: Texture2D = EncounterCoin.glyph_for(type, false)
	_glyph.strip = glyph
	_glyph.frame_size = EncounterCoin.glyph_frame_size_for(type)
	_glyph.set_frame(0)
	_glyph.visible = glyph != null

## Shows `text` on the tag, or on the BOSS seal in its place; "" shows neither.
## The name is as wide as the room the tag or the seal leaves it.
func _show_tag(text: String, as_seal: bool) -> void:
	_tag.visible = text != "" and not as_seal
	_tag_label.text = text
	_boss_seal.visible = text != "" and as_seal
	_boss_seal_label.text = text
	var right_neighbour: Control = _boss_seal if text != "" and as_seal else _tag
	_name_label.size.x = right_neighbour.position.x - NAME_GAP - _name_label.position.x

func _show_lore(text: String) -> void:
	_lore_label.text = text
	_lore_label.visible = text != ""

## Sets one drawer up for each of the encounter's choices, up to MAX_DRAWERS.
func _set_up_drawers() -> void:
	_shown_choices.clear()
	for choice: EncounterChoice in _encounter.choices:
		if choice == null:
			continue
		if _shown_choices.size() >= MAX_DRAWERS:
			Log.warn("ExpeditionPage: '%s' has more than %d choices; the rest are not shown" % [_encounter.encounter_name, MAX_DRAWERS])
			break
		var index: int = _shown_choices.size()
		_shown_choices.append(choice)
		_drawers[index].setup(choice, _drawer_glyph(choice), _drawer_glyph_frame_size(choice), choice_detail(choice, _adventure_action))
	_show_drawers(_shown_choices.size())

## Shows the first `count` drawers with the divider above them, and hides the rest.
func _show_drawers(count: int) -> void:
	if count == 0:
		_shown_choices.clear()
	_divider_row.visible = count > 0
	_drawer_rows.visible = count > 0
	for index: int in MAX_DRAWERS:
		_drawers[index].visible = index < count

## A talk shows the story glyph; any other choice shows the encounter's own.
func _drawer_glyph(choice: EncounterChoice) -> Texture2D:
	if choice is DialogueChoice:
		return STORY_GLYPH
	return EncounterCoin.glyph_for(_encounter.encounter_type, false)

func _drawer_glyph_frame_size(choice: EncounterChoice) -> Vector2i:
	if choice is DialogueChoice:
		return STORY_GLYPH_FRAME_SIZE
	return EncounterCoin.glyph_frame_size_for(_encounter.encounter_type)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## True for a tile with nothing to choose: no encounter, a NoOpEncounter, or an
## encounter with no choices (the map auto-completes all three).
static func _is_open_ground(encounter: AdventureEncounter) -> bool:
	return encounter == null or encounter is NoOpEncounter or encounter.choices.is_empty()

## True for the encounters that start a fight.
static func _is_fight(type: AdventureEncounter.EncounterType) -> bool:
	return type in [
		AdventureEncounter.EncounterType.COMBAT_REGULAR,
		AdventureEncounter.EncounterType.COMBAT_AMBUSH,
		AdventureEncounter.EncounterType.COMBAT_ELITE,
		AdventureEncounter.EncounterType.COMBAT_BOSS,
	]

func _player_stamina() -> float:
	var vitals: VitalsManager = PlayerManager.vitals_manager
	return vitals.current_stamina if vitals != null else 0.0

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A press on the drawer at `index` picks its choice.
func _on_drawer_pressed(index: int) -> void:
	if index < _shown_choices.size() and _drawers[index].is_available():
		choice_selected.emit(_shown_choices[index])

func _on_stamina_changed(new_stamina: float) -> void:
	_walk_hint.text = walk_hint(new_stamina)
