class_name VitalsPlate
extends Control

## The adventure's vitals cabinet at the view's top left, where the zone view
## keeps its cultivator cabinet (lacquer kit §5.1). On the same lacquer board:
## the Health orb with Health / max, the Madra orb with Madra / max, the Core
## row and the Stamina rod with its figures. During a fight, up to three buff sockets sit
## beside the Health figures: each shows its buff's icon, a count seal while it
## stacks and a brass flash when it lands, and hovering one opens a BuffTooltip
## beside the cabinet.
## Both orbs are the kit's socket art under lacquer_madra_orb.gdshader (the
## Health orb hands that shader the crimson ramp on its own material, the Madra
## orb keeps the shader's Madra colours); this script only hands them the
## fill. The Stamina row shakes in the soft shake's steps (the zone map's lock
## shake at half its travel) when a walk is refused.
## The Core row is the zone cabinet's core block (CultivatorPlate): the core orb,
## the stage, the level, the XP beads and "xp / need XP", following
## CultivationManager. A reward's Core Density flies to its orb as beads
## (AdventureView), and the row holds that XP back until each bead lands
## (hold_core_xp(), release_core_xp()), so the core climbs as they land.
## setup_vitals() reads the figures once and then follows the VitalsManager's
## signals; the AdventureView calls it at every run's start. bind_buffs() and
## unbind_buffs() bracket a fight.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The buff sockets in the scene: a fight shows this many buffs at most.
const MAX_BUFF_SOCKETS: int = 3
## The shader parameter both orbs fill to, 0 to 1.
const FILL_PARAMETER: StringName = &"progress"
## The gap between the cabinet's right edge and a buff tooltip.
const TOOLTIP_GAP: float = 8.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _health_orb: TextureRect = %HealthOrb
@onready var _health_fill: ShaderMaterial = _health_orb.material
@onready var _health_value_label: Label = %HealthValueLabel
@onready var _health_max_label: Label = %HealthMaxLabel
@onready var _madra_orb: TextureRect = %MadraOrb
@onready var _madra_fill: ShaderMaterial = _madra_orb.material
@onready var _madra_value_label: Label = %MadraValueLabel
@onready var _madra_max_label: Label = %MadraMaxLabel
@onready var _core_orb: LacquerStripRect = %CoreOrb
@onready var _core_fill: ShaderMaterial = _core_orb.material
@onready var _stage_label: Label = %StageLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_beads: LacquerStripRect = %XpBeads
@onready var _xp_label: Label = %XpLabel
@onready var _stamina_row: Control = %StaminaRow
@onready var _stamina_rod: LacquerRod = %StaminaRod
@onready var _stamina_value_label: Label = %StaminaValueLabel
@onready var _stamina_max_label: Label = %StaminaMaxLabel
@onready var _buff_sockets: Array[Control] = [%BuffSocket1, %BuffSocket2, %BuffSocket3]
@onready var _buff_icons: Array[TextureRect] = [%BuffIcon1, %BuffIcon2, %BuffIcon3]
@onready var _buff_seals: Array[LacquerCountSeal] = [%BuffSeal1, %BuffSeal2, %BuffSeal3]
@onready var _buff_flashes: Array[LacquerFrameOverlay] = [%BuffFlash1, %BuffFlash2, %BuffFlash3]
@onready var _buff_tooltip: BuffTooltip = %BuffTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _vitals: VitalsManager = null
var _buff_manager: CombatBuffManager = null
## The buffs the bound manager has on, oldest first. The sockets show the
## first MAX_BUFF_SOCKETS. The plate keeps its own list, built from the
## manager's signals, because clear_all_buffs() announces each removal before
## it empties the manager's own list.
var _buffs: Array[ActiveBuff] = []
## The buff whose tooltip is open, or null.
var _tooltip_buff: ActiveBuff = null
var _stamina_shake_tween: Tween = null
var _stamina_home_x: float = 0.0
## Core Density XP on its way to the Core orb, left out of the row until it lands.
var _held_core_xp: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_stamina_home_x = _stamina_row.position.x
	for index: int in MAX_BUFF_SOCKETS:
		_buff_sockets[index].mouse_entered.connect(_on_socket_mouse_entered.bind(index))
		_buff_sockets[index].mouse_exited.connect(_on_socket_mouse_exited)
	_refresh_buff_sockets()
	CultivationManager.core_density_level_updated.connect(_on_core_density_changed)
	CultivationManager.core_density_xp_updated.connect(_on_core_density_changed)
	CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	_update_core_density()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the vitals of vitals_manager and follows them from now on. A manager
## handed over earlier is let go first, so a new run (or the same manager
## again) never doubles the connections.
func setup_vitals(vitals_manager: VitalsManager) -> void:
	_disconnect_vitals()
	_vitals = vitals_manager
	if _vitals == null:
		return
	_vitals.health_changed.connect(_on_health_changed)
	_vitals.madra_changed.connect(_on_madra_changed)
	_vitals.stamina_changed.connect(_on_stamina_changed)
	_update_health()
	_update_madra()
	_update_stamina()

## Shows the buffs of buff_manager in the sockets, filled from the left, and
## follows them from now on; a buff that lands flashes its socket. Buffs
## already on show without a flash. Null just unbinds.
func bind_buffs(buff_manager: CombatBuffManager) -> void:
	unbind_buffs()
	_buff_manager = buff_manager
	if _buff_manager == null:
		return
	_buff_manager.buff_applied.connect(_on_buff_applied)
	_buff_manager.buff_removed.connect(_on_buff_removed)
	_buff_manager.buff_stacked.connect(_on_buff_stacked)
	_buff_manager.tree_exiting.connect(unbind_buffs)
	_buffs = _buff_manager.active_buffs.duplicate()
	_refresh_buff_sockets()

## Lets go of the bound buff manager: every socket hides, no flash goes on
## running and the tooltip closes.
func unbind_buffs() -> void:
	if is_instance_valid(_buff_manager):
		_buff_manager.buff_applied.disconnect(_on_buff_applied)
		_buff_manager.buff_removed.disconnect(_on_buff_removed)
		_buff_manager.buff_stacked.disconnect(_on_buff_stacked)
		_buff_manager.tree_exiting.disconnect(unbind_buffs)
	_buff_manager = null
	_buffs.clear()
	for flash: LacquerFrameOverlay in _buff_flashes:
		flash.flash(0)
	_hide_buff_tooltip()
	_refresh_buff_sockets()

## Shakes the Stamina row side to side in whole steps (the soft shake's
## keyframes, MapGlyph.SOFT_SHAKE_KEYFRAMES); a new shake restarts it. The rest
## of the cabinet stays put.
func shake_stamina() -> void:
	_stop_stamina_shake()
	if not is_inside_tree():
		return
	_stamina_shake_tween = create_tween()
	_stamina_shake_tween.tween_method(_apply_stamina_shake, 0.0, MapGlyph.SHAKE_SECONDS, MapGlyph.SHAKE_SECONDS)

## Leaves `amount` of the Core Density XP out of the Core row: it is on its way
## to the Core orb.
func hold_core_xp(amount: float) -> void:
	_held_core_xp += amount
	_update_core_density()

## Shows `amount` of the held Core Density XP: it has reached the Core orb.
func release_core_xp(amount: float) -> void:
	_held_core_xp = maxf(_held_core_xp - amount, 0.0)
	if _held_core_xp < CultivatorPlate.HELD_EPSILON:
		_held_core_xp = 0.0
	_update_core_density()

## Returns the global position of the Core orb's centre, where a reward's beads land.
func get_core_orb_global_position() -> Vector2:
	return _core_orb.global_position + _core_orb.size * 0.5

## True while the Stamina row is shaking.
func is_stamina_shaking() -> bool:
	return _stamina_shake_tween != null and _stamina_shake_tween.is_valid() and _stamina_shake_tween.is_running()

#-----------------------------------------------------------------------------
# VITALS DISPLAY
#-----------------------------------------------------------------------------

func _disconnect_vitals() -> void:
	if not is_instance_valid(_vitals):
		_vitals = null
		return
	_vitals.health_changed.disconnect(_on_health_changed)
	_vitals.madra_changed.disconnect(_on_madra_changed)
	_vitals.stamina_changed.disconnect(_on_stamina_changed)
	_vitals = null

## The orb or rod fill, current / max held to 0-1 (no max, no fill).
static func _fraction(current: float, maximum: float) -> float:
	return clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0

## Health / max and the orb's liquid at Health / max, rounded as every Health
## readout is (VitalsText), so the figure never reads 0 while the player is
## alive; the max follows the vitals manager, which has no signal for it, so
## every change re-reads it.
func _update_health() -> void:
	var health: float = _vitals.current_health
	var max_health: float = _vitals.max_health
	_health_fill.set_shader_parameter(FILL_PARAMETER, _fraction(health, max_health))
	_health_value_label.text = VitalsText.health_figure(health)
	_health_max_label.text = " / %s" % VitalsText.health_max_figure(max_health)

func _update_madra() -> void:
	var madra: float = _vitals.current_madra
	var max_madra: float = _vitals.max_madra
	_madra_fill.set_shader_parameter(FILL_PARAMETER, _fraction(madra, max_madra))
	_madra_value_label.text = str(floori(madra))
	_madra_max_label.text = " / %d" % floori(max_madra)

func _update_stamina() -> void:
	var stamina: float = _vitals.current_stamina
	var max_stamina: float = _vitals.max_stamina
	_stamina_rod.set_fraction(_fraction(stamina, max_stamina))
	_stamina_value_label.text = str(floori(stamina))
	_stamina_max_label.text = " / %d" % floori(max_stamina)

## The Core row, as the zone cabinet draws its core (CultivatorPlate): the stage,
## the level, the core orb's spiral at min(level, cap) / cap (the dormant pebble at
## level 0) and the XP beads, a bead lit only once its share of the XP is earned,
## beside "xp / need XP". A full core reads "Core full" with every bead lit. With
## XP held, the core shows as it stood that much XP ago (CultivatorPlate.rewind_core()).
func _update_core_density() -> void:
	var level: int = int(CultivationManager.get_core_density_level())
	var xp: float = CultivationManager.get_core_density_xp()
	if _held_core_xp > 0.0:
		var shown: Vector2 = CultivatorPlate.rewind_core(level, xp, _held_core_xp, CultivationManager.get_xp_for_level)
		level = int(shown.x)
		xp = shown.y
	var cap: int = CultivationManager.get_core_density_cap()
	_stage_label.text = CultivationManager.get_current_advancement_stage_name()
	_level_label.text = "Level %d" % level
	_core_orb.set_frame(CultivatorPlate.CORE_ORB_SOCKET_COLUMN if level > 0 else CultivatorPlate.CORE_ORB_DORMANT_COLUMN)
	_core_fill.set_shader_parameter(FILL_PARAMETER, float(clampi(level, 0, cap)) / cap if cap > 0 else 0.0)
	if CultivationManager.is_core_full() and _held_core_xp <= 0.0:
		_xp_beads.set_frame(0, CultivatorPlate.XP_BEADS_LAST_ROW)
		_xp_label.text = CultivationManager.CORE_FULL_TEXT
	else:
		var need: float = CultivationManager.get_xp_for_level(level + 1)
		var lit_beads: int = floori(xp * CultivatorPlate.XP_BEADS_LAST_ROW / need) if need > 0.0 else 0
		_xp_beads.set_frame(0, clampi(lit_beads, 0, CultivatorPlate.XP_BEADS_LAST_ROW))
		_xp_label.text = "%d / %d XP" % [floori(xp), ceili(need)]

#-----------------------------------------------------------------------------
# STAMINA SHAKE
#-----------------------------------------------------------------------------

func _apply_stamina_shake(elapsed: float) -> void:
	_stamina_row.position.x = _stamina_home_x + MapGlyph.shake_offset_at(elapsed, MapGlyph.SOFT_SHAKE_KEYFRAMES)

func _stop_stamina_shake() -> void:
	if _stamina_shake_tween != null and _stamina_shake_tween.is_valid():
		_stamina_shake_tween.kill()
	_stamina_shake_tween = null
	if is_node_ready():
		_stamina_row.position.x = _stamina_home_x

#-----------------------------------------------------------------------------
# BUFF SOCKETS
#-----------------------------------------------------------------------------

## Shows the first MAX_BUFF_SOCKETS buffs, one per socket from the left: its
## icon, and the count seal while it has stacked.
func _refresh_buff_sockets() -> void:
	for index: int in MAX_BUFF_SOCKETS:
		var buff: ActiveBuff = _buffs[index] if index < _buffs.size() else null
		_buff_sockets[index].visible = buff != null
		if buff == null:
			continue
		_buff_icons[index].texture = buff.buff_data.buff_icon
		_buff_seals[index].visible = buff.stack_count > 1
		_buff_seals[index].show_count(buff.stack_count)

func _hide_buff_tooltip() -> void:
	_tooltip_buff = null
	_buff_tooltip.hide_tooltip()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_health_changed(_new_health: float) -> void:
	_update_health()

func _on_madra_changed(_new_madra: float) -> void:
	_update_madra()

func _on_core_density_changed(_xp: float, _level: float) -> void:
	_update_core_density()

func _on_advancement_stage_changed(_stage: CultivationManager.AdvancementStage) -> void:
	_update_core_density()

func _on_stamina_changed(_new_stamina: float) -> void:
	_update_stamina()

## A new buff takes the next socket and flashes it.
func _on_buff_applied(buff_id: String, _duration: float) -> void:
	var buff: ActiveBuff = _buff_manager.get_active_buff(buff_id)
	if buff == null or _buffs.has(buff):
		return
	_buffs.append(buff)
	_refresh_buff_sockets()
	var index: int = _buffs.size() - 1
	if index < MAX_BUFF_SOCKETS:
		_buff_flashes[index].flash(1)

## The sockets close up on the left, and a tooltip open for this buff closes.
func _on_buff_removed(buff_id: String) -> void:
	for index: int in _buffs.size():
		if _buffs[index].buff_data.buff_id == buff_id:
			_buffs.remove_at(index)
			break
	if _tooltip_buff != null and _tooltip_buff.buff_data.buff_id == buff_id:
		_hide_buff_tooltip()
	_refresh_buff_sockets()

func _on_buff_stacked(_buff_id: String, _stack_count: int) -> void:
	_refresh_buff_sockets()

## Opens the tooltip of the buff in this socket, beside the cabinet and level
## with the socket.
func _on_socket_mouse_entered(index: int) -> void:
	if index >= _buffs.size():
		return
	_tooltip_buff = _buffs[index]
	var top_left: Vector2 = Vector2(global_position.x + size.x + TOOLTIP_GAP, _buff_sockets[index].global_position.y)
	_buff_tooltip.show_for_buff(_tooltip_buff, top_left)

func _on_socket_mouse_exited() -> void:
	_hide_buff_tooltip()
