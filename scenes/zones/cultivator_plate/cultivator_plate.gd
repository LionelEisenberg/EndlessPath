class_name CultivatorPlate
extends Control

## The cultivator cabinet at the zone view's top left (lacquer kit §5.1).
## Four rows on the lacquer board: the Madra orb with Madra / max (the max is
## the max Madra stat, which Mind, gear and any modifier source move) and, while
## the running action earns Madra, its rate; the Core Density orb with the
## stage, level and XP beads (all lit, with "Core full" for the XP figure, at the
## stage's Core Density cap); the six stats in two triangles, Physical on the
## left and Spiritual on the right, each a StatCell showing the stat's trained
## level and a ring of its XP toward the next level, full at the stage's cap;
## gold, at the right of the bottom row.
## The orbs are frames of the kit's strips under two pixel-art shaders that
## animate the fill on their own (lacquer_madra_orb: flowing liquid,
## lacquer_core_orb: a turning spiral); this script only hands them the fill.
## The beads are rows of their strip. It reads everything once on _ready, then
## follows the managers' signals: the stats follow CharacterManager's
## stats_changed and stat_xp_changed, and the stage's change too, since a
## breakthrough raises their cap.
## Madra and XP the cycling view's pellets are still carrying to the orbs are
## held out of the readout (hold_madra, hold_core_xp) until each pellet lands
## (release_madra, release_core_xp), so the orbs fill as the pellets arrive, not
## as they leave: the Madra shown is the Madra less what is in flight, and the
## core is shown as it stood that much XP ago, level by level.
## Each stat's cell is where that stat's XP pellets land
## (get_stat_cell_global_position). A sender asks accepts_stat_xp() before it
## pays (a capped stat takes none), then holds what the stat took
## (hold_stat_xp) and releases each pellet's share as it lands
## (release_stat_xp): the cell shows the stat as it stood that much XP ago,
## level by level, and hops as each pellet lands. A cell plays its level-up look
## when the level it shows goes up from a gain, a set or a landing, never from a
## save loading, gear, a hold or the breakthrough. It decides once a frame, at its
## end (_settle_stat), so XP paid and then held in the same frame plays nothing
## until its pellet lands. Pointing at a cell shows its
## figure on a StatTooltip beside the cabinet.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The shader parameter both orbs fill to, 0 to 1.
const FILL_PARAMETER: StringName = &"progress"
## Core orb strip columns: the dormant pebble shown at Core Density 0, and the
## empty socket (with a seed dot the spiral covers) under the fill from level 1.
const CORE_ORB_DORMANT_COLUMN: int = 0
const CORE_ORB_SOCKET_COLUMN: int = 1
## Last row of the XP bead strip: 19 rows, 0 to 18 beads lit.
const XP_BEADS_LAST_ROW: int = 18
## Where the stat figure stands: this far right of the cabinet's left edge (the
## board and its shadow), and this far below the hovered cell's top.
const TOOLTIP_X: float = 444.0
const TOOLTIP_DROP: float = 4.0
## Held Madra or XP below this is float dust from releasing what was held, and
## counts as none.
const HELD_EPSILON: float = 0.0001

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_orb: TextureRect = %MadraOrb
@onready var _madra_fill: ShaderMaterial = _madra_orb.material
@onready var _madra_value_label: Label = %MadraValueLabel
@onready var _madra_max_label: Label = %MadraMaxLabel
@onready var _rate_label: RichTextLabel = %RateLabel
@onready var _core_orb: LacquerStripRect = %CoreOrb
@onready var _core_fill: ShaderMaterial = _core_orb.material
@onready var _stage_label: Label = %StageLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_beads: LacquerStripRect = %XpBeads
@onready var _xp_label: Label = %XpLabel
## The six stat cells, Physical then Spiritual, apex first.
@onready var _stat_cells: Array[StatCell] = [%StrengthCell, %BodyCell, %AgilityCell, %SpiritCell, %MindCell, %ControlCell]
@onready var _gold_value_label: Label = %GoldValueLabel
@onready var _stat_tooltip: StatTooltip = %StatTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Madra and Core Density XP on their way to the orbs, left out of the readout.
var _held_madra: float = 0.0
var _held_xp: float = 0.0
## Each stat's XP on its way to its cell, AttributeType to float.
var _held_stat_xp: Dictionary = {}
## The level each cell showed when it last settled, AttributeType to int: a
## level-up look plays when it goes up.
var _settled_levels: Dictionary = {}
## The stats waiting to settle at the end of the frame, AttributeType to whether
## a gain, a set or a landing moved them (only those may play the look).
var _unsettled: Dictionary = {}
## The cell under the pointer, whose figure the tooltip shows, or null.
var _hovered_cell: StatCell = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ResourceManager.madra_changed.connect(_on_madra_changed)
	ResourceManager.gold_changed.connect(_on_gold_changed)
	CultivationManager.core_density_xp_updated.connect(_on_core_density_xp_updated)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	CyclingManager.madra_rate_changed.connect(_on_madra_rate_changed)
	CharacterManager.stats_changed.connect(_on_stats_changed)
	CharacterManager.stat_xp_changed.connect(_on_stat_xp_changed)
	CharacterManager.stat_level_changed.connect(_on_stat_level_changed)
	for cell: StatCell in _stat_cells:
		cell.hover_changed.connect(_on_cell_hover_changed.bind(cell))
	_update_all()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the global position of the Madra orb's centre, where Madra
## particles fly to.
func get_madra_orb_global_position() -> Vector2:
	return _madra_orb.global_position + _madra_orb.size * 0.5

## Returns the global position of the Core orb's centre, where Core Density XP
## particles fly to.
func get_core_orb_global_position() -> Vector2:
	return _core_orb.global_position + _core_orb.size * 0.5

## Leaves `amount` of the Madra out of the readout: it is on its way to the orb.
func hold_madra(amount: float) -> void:
	_held_madra += amount
	_update_madra()

## Shows `amount` of held Madra: it has reached the orb.
func release_madra(amount: float) -> void:
	_held_madra = _less_held(_held_madra, amount)
	_update_madra()

## Leaves `amount` of the Core Density XP out of the readout: it is on its way to
## the Core orb.
func hold_core_xp(amount: float) -> void:
	_held_xp += amount
	_update_core_density()

## Shows `amount` of held Core Density XP: it has reached the Core orb.
func release_core_xp(amount: float) -> void:
	_held_xp = _less_held(_held_xp, amount)
	_update_core_density()

## Returns the global position of a stat's ring centre, where that stat's XP
## pellets fly to.
func get_stat_cell_global_position(stat: CharacterAttributesData.AttributeType) -> Vector2:
	return _cell_of(stat).get_ring_global_center()

## True when the stat takes XP pellets: a stat at the stage's cap takes none,
## and its XP would be lost.
func accepts_stat_xp(stat: CharacterAttributesData.AttributeType) -> bool:
	return not CharacterManager.is_stat_capped(stat)

## Leaves `amount` of the stat's XP out of its cell: it is on its way there.
## Hold the XP the stat took, not more.
func hold_stat_xp(stat: CharacterAttributesData.AttributeType, amount: float) -> void:
	_held_stat_xp[stat] = _held_stat_xp.get(stat, 0.0) + amount
	_update_stat(stat, false)

## Shows `amount` of the stat's held XP: a pellet has reached its cell, which
## hops, and plays its level-up look if the level it shows goes up.
func release_stat_xp(stat: CharacterAttributesData.AttributeType, amount: float) -> void:
	_held_stat_xp[stat] = _less_held(_held_stat_xp.get(stat, 0.0), amount)
	_cell_of(stat).hop()
	_update_stat(stat, true)

## Returns the core as it stood `xp_back` XP before `level` with `xp` toward the
## next level, as Vector2(level, xp): the XP comes off the current level's, then
## off each level below it in turn, `cost` giving a level's XP
## (CultivationManager.get_xp_for_level). It stops at `lowest` (level 0 for the
## core, 1 for a stat) with no XP.
static func rewind_core(level: int, xp: float, xp_back: float, cost: Callable, lowest: int = 0) -> Vector2:
	var left: float = xp - xp_back
	while left < 0.0 and level > lowest:
		left += cost.call(level)
		level -= 1
	return Vector2(level, maxf(left, 0.0))

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

func _update_all() -> void:
	_update_madra()
	_update_rate()
	_update_core_density()
	_update_stats()
	_update_gold()

## Madra / max and the orb's liquid at Madra / max, the max being the pool's
## (ResourceManager.get_max_madra()).
func _update_madra() -> void:
	var madra: float = maxf(ResourceManager.get_madra() - _held_madra, 0.0)
	var max_madra: float = ResourceManager.get_max_madra()
	var fraction: float = clampf(madra / max_madra, 0.0, 1.0) if max_madra > 0.0 else 0.0
	_madra_fill.set_shader_parameter(FILL_PARAMETER, fraction)
	_madra_value_label.text = str(floori(madra))
	_madra_max_label.text = " / %d" % floori(max_madra)

## "+1.5 / s" while the running action earns Madra (while cycling, the Madra the
## ball is drawing); hidden otherwise. The rate is read to CyclingManager.RATE_STEP
## first, the step the manager announces it in, so a rate that reads +0 hides the
## label instead of showing "+0 / s".
func _update_rate() -> void:
	var rate: float = snappedf(ActionManager.get_current_madra_per_second(), CyclingManager.RATE_STEP)
	_rate_label.visible = rate > 0.0
	if _rate_label.visible:
		_rate_label.text = LacquerText.decimal_bbcode(LacquerText.rate(rate) + " / s")

## Stage, level, the core orb's spiral at min(level, cap) / cap (0 with no cap;
## the dormant pebble at level 0) and the XP beads. A bead lights only once its
## share of the XP is earned, floor(xp × 18 / need), so the beads never run
## ahead of the "xp / need XP" figure, which floors the XP and rounds the need
## up: a need with decimals never reads as met before it is. A full core takes
## no XP: the beads show their whole row and the figure reads "Core full". With
## XP held, the core shows as it stood that much XP ago (rewind_core), and not
## full.
func _update_core_density() -> void:
	var shown: Vector2 = _shown_core()
	var level: int = int(shown.x)
	var xp: float = shown.y
	var cap: int = CultivationManager.get_core_density_cap()
	_stage_label.text = CultivationManager.get_current_advancement_stage_name()
	_level_label.text = "Level %d" % level
	var level_fraction: float = float(clampi(level, 0, cap)) / cap if cap > 0 else 0.0
	_core_orb.set_frame(CORE_ORB_SOCKET_COLUMN if level > 0 else CORE_ORB_DORMANT_COLUMN)
	_core_fill.set_shader_parameter(FILL_PARAMETER, level_fraction)
	if CultivationManager.is_core_full() and _held_xp <= 0.0:
		_xp_beads.set_frame(0, XP_BEADS_LAST_ROW)
		_xp_label.text = CultivationManager.CORE_FULL_TEXT
	else:
		var need: float = CultivationManager.get_xp_for_level(level + 1)
		var lit_beads: int = floori(xp * XP_BEADS_LAST_ROW / need) if need > 0.0 else 0
		_xp_beads.set_frame(0, clampi(lit_beads, 0, XP_BEADS_LAST_ROW))
		_xp_label.text = "%d / %d XP" % [floori(xp), ceili(need)]

## Every stat cell, with no level-up look (a load, gear or the stage moved
## them).
func _update_stats() -> void:
	for cell: StatCell in _stat_cells:
		_update_stat(cell.attribute_type, false)

## One stat cell: its trained level, its XP toward the next level and whether it
## stands at the cap, less the XP still flying to it (shown as it stood that much
## XP ago, and never capped while XP flies). Trained levels, never totals, so
## gear moves no cell. With `celebrate`, a rise in the level it shows plays the
## level-up look.
func _update_stat(stat: CharacterAttributesData.AttributeType, celebrate: bool) -> void:
	var cell: StatCell = _cell_of(stat)
	var shown: Vector2 = _shown_stat(stat)
	var level: int = int(shown.x)
	var held: bool = _held_stat_xp.get(stat, 0.0) > 0.0
	cell.set_stat(
		level,
		shown.y,
		CharacterManager.stat_progression.get_xp_to_next(level),
		CharacterManager.is_stat_capped(stat) and not held,
	)
	if not _unsettled.has(stat):
		_settle_stat.call_deferred(stat)
	_unsettled[stat] = _unsettled.get(stat, false) or celebrate
	if cell == _hovered_cell:
		_show_tooltip(cell)

## At the end of a frame that moved the stat's cell: plays the level-up look if
## a gain, a set or a landing moved it and the level it shows has gone up since
## it last settled.
func _settle_stat(stat: CharacterAttributesData.AttributeType) -> void:
	var celebrate: bool = _unsettled.get(stat, false)
	_unsettled.erase(stat)
	var cell: StatCell = _cell_of(stat)
	var level: int = cell.get_shown_level()
	if celebrate and level > _settled_levels.get(stat, level):
		cell.play_level_up()
	_settled_levels[stat] = level

## The stat as its cell shows it, Vector2(level, xp): as it is, less the XP
## still flying to it, never below Lv 1.
func _shown_stat(stat: CharacterAttributesData.AttributeType) -> Vector2:
	var level: int = CharacterManager.get_stat_level(stat)
	var xp: float = CharacterManager.get_stat_xp(stat)
	var held: float = _held_stat_xp.get(stat, 0.0)
	if held <= 0.0:
		return Vector2(level, xp)
	return rewind_core(level, xp, held, _stat_level_cost, 1)

## The XP a stat's `level` costs from the level below, for rewind_core.
static func _stat_level_cost(level: int) -> float:
	return CharacterManager.stat_progression.get_xp_to_next(level - 1)

## The cell that shows `stat`.
func _cell_of(stat: CharacterAttributesData.AttributeType) -> StatCell:
	for cell: StatCell in _stat_cells:
		if cell.attribute_type == stat:
			return cell
	return null

## Fills the tooltip from what `cell` shows and stands it beside the cabinet,
## level with the cell.
func _show_tooltip(cell: StatCell) -> void:
	_stat_tooltip.set_figure(
		cell.attribute_type,
		cell.get_shown_level(),
		cell.get_shown_xp(),
		cell.get_shown_xp_to_next(),
		cell.is_shown_capped(),
		CultivationManager.get_current_advancement_stage_name(),
		CultivationManager.has_next_stage(),
	)
	_stat_tooltip.show_at(Vector2(global_position.x + TOOLTIP_X, cell.global_position.y + TOOLTIP_DROP))

func _update_gold() -> void:
	_gold_value_label.text = "%d " % floori(ResourceManager.get_gold())

## The core as the readout shows it, Vector2(level, xp): as it is, less the XP
## still flying to it.
func _shown_core() -> Vector2:
	var level: int = floori(CultivationManager.get_core_density_level())
	var xp: float = CultivationManager.get_core_density_xp()
	if _held_xp <= 0.0:
		return Vector2(level, xp)
	return rewind_core(level, xp, _held_xp, CultivationManager.get_xp_for_level)

## Returns `held` less `amount`, none once only float dust is left.
static func _less_held(held: float, amount: float) -> float:
	var left: float = held - amount
	return left if left > HELD_EPSILON else 0.0

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## The rate follows the pool too: a training action's trickle reads 0 at the max.
func _on_madra_changed(_amount: float) -> void:
	_update_madra()
	_update_rate()

func _on_gold_changed(_amount: float) -> void:
	_update_gold()

func _on_core_density_xp_updated(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_core_density_level_updated(_xp: float, _level: float) -> void:
	_update_core_density()

## A breakthrough raises the stats' cap too, so the cells re-read.
func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_core_density()
	_update_stats()

func _on_current_action_changed(_action_data: ZoneActionData) -> void:
	_update_rate()

## Ignores the payload and re-reads ActionManager, so the order of a session's
## end and the idle action's resume cannot leave a stale rate.
func _on_madra_rate_changed(_rate: float) -> void:
	_update_rate()

## Mind, gear and any modifier source move the max Madra, so the Madra row
## re-reads too.
func _on_stats_changed() -> void:
	_update_stats()
	_update_madra()

## Re-reads the stat from CharacterManager rather than the payload: XP at the cap
## arrives as 0 XP, and the capped cell stays capped.
func _on_stat_xp_changed(stat: CharacterAttributesData.AttributeType, _xp: float, _xp_to_next: float) -> void:
	_update_stat(stat, true)

## A level gained or set: the cell plays its level-up look if the level it shows
## goes up (with XP still flying, the landing plays it).
func _on_stat_level_changed(stat: CharacterAttributesData.AttributeType, _level: int) -> void:
	_update_stat(stat, true)

func _on_cell_hover_changed(hovering: bool, cell: StatCell) -> void:
	if hovering:
		_hovered_cell = cell
		_show_tooltip(cell)
	elif _hovered_cell == cell:
		_hovered_cell = null
		_stat_tooltip.hide()
