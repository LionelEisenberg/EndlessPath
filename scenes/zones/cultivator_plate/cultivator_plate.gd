class_name CultivatorPlate
extends Control

## The cultivator cabinet at the zone view's top left (lacquer kit §5.1).
## Three rows on the lacquer board: the Madra orb with Madra / max and, while
## the running action earns Madra, its rate; the Core Density orb with the
## stage, level and XP beads; gold. The orbs and beads are frames of the kit's
## strips. It reads everything once on _ready, then follows the managers'
## signals. Replaces ZoneResourcePanel.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Last frame of the Madra orb strip: 33 frames, 0 empty and 32 full.
const MADRA_ORB_LAST_FRAME: int = 32
## Last column of the core orb strip: 17 columns, Core Density 0 to 100.
const CORE_ORB_LAST_COLUMN: int = 16
## Swirl phases of the core orb: the strip's 4 rows, stepped by SwirlTimer.
const CORE_SWIRL_PHASES: int = 4
## Last row of the XP bead strip: 19 rows, 0 to 18 beads lit.
const XP_BEADS_LAST_ROW: int = 18

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_orb: LacquerStripRect = %MadraOrb
@onready var _madra_value_label: Label = %MadraValueLabel
@onready var _madra_max_label: Label = %MadraMaxLabel
@onready var _rate_label: RichTextLabel = %RateLabel
@onready var _core_orb: LacquerStripRect = %CoreOrb
@onready var _swirl_timer: Timer = %SwirlTimer
@onready var _stage_label: Label = %StageLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_beads: LacquerStripRect = %XpBeads
@onready var _xp_label: Label = %XpLabel
@onready var _gold_value_label: Label = %GoldValueLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _swirl_phase: int = 0

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
	_swirl_timer.timeout.connect(_on_swirl_timer_timeout)
	_update_all()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns the global position of the Madra orb's centre, where Madra
## particles fly to.
func get_madra_orb_global_position() -> Vector2:
	return _madra_orb.global_position + _madra_orb.size * 0.5

#-----------------------------------------------------------------------------
# DISPLAY UPDATES
#-----------------------------------------------------------------------------

func _update_all() -> void:
	_update_madra()
	_update_rate()
	_update_core_density()
	_update_gold()

## Madra / max and the orb frame round(Madra / max × 32). The max follows the
## Core Density level, so a level-up refreshes this too.
func _update_madra() -> void:
	var madra: float = ResourceManager.get_madra()
	var max_madra: float = CultivationManager.get_max_madra()
	var fraction: float = clampf(madra / max_madra, 0.0, 1.0) if max_madra > 0.0 else 0.0
	_madra_orb.set_frame(roundi(fraction * MADRA_ORB_LAST_FRAME))
	_madra_value_label.text = str(floori(madra))
	_madra_max_label.text = " / %d" % floori(max_madra)

## "+1.5 / s" while the running action earns Madra; hidden otherwise.
func _update_rate() -> void:
	var rate: float = ActionManager.get_current_madra_per_second()
	_rate_label.visible = rate > 0.0
	if _rate_label.visible:
		_rate_label.text = LacquerText.decimal_bbcode(LacquerText.rate(rate) + " / s")

## Stage, level, the core orb column round(min(level, 100) / 100 × 16) and the
## XP beads row round(xp / need × 18).
func _update_core_density() -> void:
	var level: int = floori(CultivationManager.get_core_density_level())
	var xp: float = CultivationManager.get_core_density_xp()
	var need: float = CultivationManager.get_xp_for_next_level()
	_stage_label.text = CultivationManager.get_current_advancement_stage_name()
	_level_label.text = "Level %d" % level
	var level_fraction: float = float(mini(level, CultivationManager.BREAKTHROUGH_LEVEL)) / CultivationManager.BREAKTHROUGH_LEVEL
	_core_orb.set_frame(roundi(level_fraction * CORE_ORB_LAST_COLUMN), _swirl_phase)
	var xp_fraction: float = clampf(xp / need, 0.0, 1.0) if need > 0.0 else 0.0
	_xp_beads.set_frame(0, roundi(xp_fraction * XP_BEADS_LAST_ROW))
	_xp_label.text = "%d / %d XP" % [floori(xp), floori(need)]

func _update_gold() -> void:
	_gold_value_label.text = "%d " % floori(ResourceManager.get_gold())

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

func _on_swirl_timer_timeout() -> void:
	_swirl_phase = (_swirl_phase + 1) % CORE_SWIRL_PHASES
	_core_orb.set_frame(_core_orb.get_frame().x, _swirl_phase)
