class_name CultivatorPlate
extends Control

## The cultivator cabinet at the zone view's top left (lacquer kit §5.1).
## Three rows on the lacquer board: the Madra orb with Madra / max and, while
## the running action earns Madra, its rate; the Core Density orb with the
## stage, level and XP beads; gold, at the right of the bottom row.
## The orbs are frames of the kit's strips under two pixel-art shaders that
## animate the fill on their own (lacquer_madra_orb: flowing liquid,
## lacquer_core_orb: a turning spiral); this script only hands them the fill.
## The beads are rows of their strip. It reads everything once on _ready, then
## follows the managers' signals.

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
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ResourceManager.madra_changed.connect(_on_madra_changed)
	ResourceManager.gold_changed.connect(_on_gold_changed)
	CultivationManager.core_density_xp_updated.connect(_on_core_density_xp_updated)
	CultivationManager.core_density_level_updated.connect(_on_core_density_level_updated)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	ActionManager.current_action_changed.connect(_on_current_action_changed)
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

## Madra / max and the orb's liquid at Madra / max. The max follows the Core
## Density level, so a level-up refreshes this too.
func _update_madra() -> void:
	var madra: float = ResourceManager.get_madra()
	var max_madra: float = CultivationManager.get_max_madra()
	var fraction: float = clampf(madra / max_madra, 0.0, 1.0) if max_madra > 0.0 else 0.0
	_madra_fill.set_shader_parameter(FILL_PARAMETER, fraction)
	_madra_value_label.text = str(floori(madra))
	_madra_max_label.text = " / %d" % floori(max_madra)

## "+1.5 / s" while the running action earns Madra; hidden otherwise.
func _update_rate() -> void:
	var rate: float = ActionManager.get_current_madra_per_second()
	_rate_label.visible = rate > 0.0
	if _rate_label.visible:
		_rate_label.text = LacquerText.decimal_bbcode(LacquerText.rate(rate) + " / s")

## Stage, level, the core orb's spiral at min(level, 100) / 100 (the dormant
## pebble at level 0) and the XP beads. A bead lights only once its share of
## the XP is earned, floor(xp × 18 / need), so the beads never run ahead of
## the floored "xp / need XP" figure.
func _update_core_density() -> void:
	var level: int = floori(CultivationManager.get_core_density_level())
	var xp: float = CultivationManager.get_core_density_xp()
	var need: float = CultivationManager.get_xp_for_next_level()
	_stage_label.text = CultivationManager.get_current_advancement_stage_name()
	_level_label.text = "Level %d" % level
	var level_fraction: float = float(clampi(level, 0, CultivationManager.BREAKTHROUGH_LEVEL)) / CultivationManager.BREAKTHROUGH_LEVEL
	_core_orb.set_frame(CORE_ORB_SOCKET_COLUMN if level > 0 else CORE_ORB_DORMANT_COLUMN)
	_core_fill.set_shader_parameter(FILL_PARAMETER, level_fraction)
	var lit_beads: int = floori(xp * XP_BEADS_LAST_ROW / need) if need > 0.0 else 0
	_xp_beads.set_frame(0, clampi(lit_beads, 0, XP_BEADS_LAST_ROW))
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
