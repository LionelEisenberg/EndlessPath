class_name CultivatorPlate
extends Control

## The cultivator cabinet at the zone view's top left (lacquer kit §5.1).
## Three rows on the lacquer board: the Madra orb with Madra / max and, while
## the running action earns Madra, its rate; the Core Density orb with the
## stage, level and XP beads (all lit, with "Core full" for the XP figure, at the
## stage's Core Density cap); gold, at the right of the bottom row.
## The orbs are frames of the kit's strips under two pixel-art shaders that
## animate the fill on their own (lacquer_madra_orb: flowing liquid,
## lacquer_core_orb: a turning spiral); this script only hands them the fill.
## The beads are rows of their strip. It reads everything once on _ready, then
## follows the managers' signals.
## Madra and XP the cycling view's pellets are still carrying to the orbs are
## held out of the readout (hold_madra, hold_core_xp) until each pellet lands
## (release_madra, release_core_xp), so the orbs fill as the pellets arrive, not
## as they leave: the Madra shown is the Madra less what is in flight, and the
## core is shown as it stood that much XP ago, level by level, with the Madra
## max of the level shown.

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
@onready var _gold_value_label: Label = %GoldValueLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## Madra and Core Density XP on their way to the orbs, left out of the readout.
var _held_madra: float = 0.0
var _held_xp: float = 0.0

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
	_update_madra()

## Shows `amount` of held Core Density XP: it has reached the Core orb.
func release_core_xp(amount: float) -> void:
	_held_xp = _less_held(_held_xp, amount)
	_update_core_density()
	_update_madra()

## Returns the core as it stood `xp_back` XP before `level` with `xp` toward the
## next level, as Vector2(level, xp): the XP comes off the current level's, then
## off each level below it in turn, `cost` giving a level's XP
## (CultivationManager.get_xp_for_level). It stops at level 0 with no XP.
static func rewind_core(level: int, xp: float, xp_back: float, cost: Callable) -> Vector2:
	var left: float = xp - xp_back
	while left < 0.0 and level > 0:
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
	_update_gold()

## Madra / max and the orb's liquid at Madra / max. The max follows the Core
## Density level shown, so a level-up refreshes this too.
func _update_madra() -> void:
	var madra: float = maxf(ResourceManager.get_madra() - _held_madra, 0.0)
	var max_madra: float = CultivationManager.get_max_madra_at(int(_shown_core().x))
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
## ahead of the floored "xp / need XP" figure. A full core takes no XP: the
## beads show their whole row and the figure reads "Core full". With XP held,
## the core shows as it stood that much XP ago (rewind_core), and not full.
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
		_xp_label.text = "%d / %d XP" % [floori(xp), floori(need)]

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

func _on_madra_changed(_amount: float) -> void:
	_update_madra()

func _on_gold_changed(_amount: float) -> void:
	_update_gold()

func _on_core_density_xp_updated(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_core_density_level_updated(_xp: float, _level: float) -> void:
	_update_core_density()
	_update_madra()

func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_core_density()
	_update_madra()

func _on_current_action_changed(_action_data: ZoneActionData) -> void:
	_update_rate()

## Ignores the payload and re-reads ActionManager, so the order of a session's
## end and the idle action's resume cannot leave a stale rate.
func _on_madra_rate_changed(_rate: float) -> void:
	_update_rate()
