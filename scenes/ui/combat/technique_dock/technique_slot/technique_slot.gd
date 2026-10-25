class_name TechniqueSlot
extends DockSlot

## One technique slot in the technique dock (spec: The technique dock): the
## carved socket with the technique's icon, its key cap and the cost line
## under it. The dock puts each slot in one of three states:
## - EMPTY: the socket and the key cap; no icon, no cost.
## - PREVIEW (on the map): the icon, the cost and a tan key. Not usable.
## - ACTIVE (in a fight, bound to the player's CombatAbilityInstance): a cream
##   key and the cost in cream, tan while it cannot be paid (checked each frame
##   while the technique neither recharges nor casts), the cooldown sweep, a
##   steady brass frame while it casts and one brass flash when it is ready.
## The key cap, the cooldown sweep, hover, the press and the refusal shake are
## DockSlot's. Every fight starts each technique on a 1.5 s cooldown, which the
## sweep veils as fully as the technique's own, and techniques start it before
## the dock binds them, so bind() reads the running timer. As the mock's button
## shakes alone, the slot (what the pointer hovers), its key cap and its cost
## line stay put while the socket shakes.
## The cost line (the resource's mini icon and the amount) is centred under the
## slot in a box 81 px wide, not 80: a BoxContainer floors a centre that falls
## on a half pixel, and the extra pixel makes it round up instead, as the mock's
## CSS does, so a one-digit cost sits where the mock puts it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The keys a slot shows when its action has no key in the input map.
const FALLBACK_KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
## The mini icon of each resource a technique can cost.
const MINI_HEALTH: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const MINI_MADRA: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_madra_ai.png")
const MINI_STAMINA: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_stamina_ai.png")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _cast_frame: LacquerFrameOverlay = %CastFrame
@onready var _cost_line: Control = %CostLine
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_label: Label = %CostLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _ability_data: AbilityData = null
var _instance: CombatAbilityInstance = null
var _vitals_manager: VitalsManager = null
var _is_casting: bool = false
## Whether the cost shows in cream (true) or tan.
var _cost_affordable: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	super()
	_refresh()

## Runs while the slot is ACTIVE (the cost check) or shaking.
func _process(delta: float) -> void:
	super(delta)
	if _state == SlotState.ACTIVE and _vitals_manager != null and not _is_cooling and not _is_casting:
		var affordable: bool = _ability_data.can_afford(_vitals_manager)
		if affordable != _cost_affordable:
			_set_cost_affordable(affordable)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the slot empty: the socket and its key cap. Lets go of any instance.
func show_empty(slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.EMPTY
	_slot_index = slot_index
	_ability_data = null
	_refresh()

## Shows an equipped technique outside a fight: its icon, its cost and a tan
## key. Lets go of any instance.
func show_preview(data: AbilityData, slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.PREVIEW if data != null else SlotState.EMPTY
	_slot_index = slot_index
	_ability_data = data
	_refresh()

## Binds the slot to a fight's ability instance: its technique, a cream key and
## a cost checked against vitals_manager. A cooldown already running (every
## technique starts a fight on one) shows at once.
func bind(instance: CombatAbilityInstance, slot_index: int, vitals_manager: VitalsManager) -> void:
	_unbind_instance()
	_state = SlotState.ACTIVE
	_instance = instance
	_ability_data = instance.ability_data
	_slot_index = slot_index
	_vitals_manager = vitals_manager
	_bind_cooldown(instance.cooldown_started, instance.cooldown_updated, instance.cooldown_ready, instance.cooldown_timer)
	instance.cast_started.connect(_on_cast_started)
	instance.cast_finished.connect(_on_cast_finished)
	instance.cast_cancelled.connect(_on_cast_cancelled)
	_is_casting = instance.is_casting
	_refresh()

## Returns the instance the slot is bound to, or null outside a fight.
func get_ability_instance() -> CombatAbilityInstance:
	return _instance

## Returns the mini icon of the resource a technique's cost line shows: its
## first cost in the order AbilityRow.format_cost() lists them (Health, Madra,
## Stamina), so a technique with two costs shows the first under its slot (its
## tooltip lists them all); null for a free technique.
static func cost_icon(data: AbilityData) -> Texture2D:
	if data.health_cost > 0.0:
		return MINI_HEALTH
	if data.madra_cost > 0.0:
		return MINI_MADRA
	if data.stamina_cost > 0.0:
		return MINI_STAMINA
	return null

#-----------------------------------------------------------------------------
# DOCK SLOT
#-----------------------------------------------------------------------------

func _hover_data() -> Resource:
	return _ability_data if _state != SlotState.EMPTY else null

func _key_action(index: int) -> StringName:
	return StringName("ability_slot_%d" % (index + 1))

func _fallback_key(index: int) -> String:
	return FALLBACK_KEY_LABELS[index] if index < FALLBACK_KEY_LABELS.size() else ""

## An ACTIVE slot checks each frame whether its cost can be paid.
func _needs_process() -> bool:
	return _state == SlotState.ACTIVE

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The amount of the cost the cost line shows (see cost_icon()).
static func _shown_cost(data: AbilityData) -> float:
	if data.health_cost > 0.0:
		return data.health_cost
	if data.madra_cost > 0.0:
		return data.madra_cost
	return maxf(data.stamina_cost, 0.0)

## Puts the state on the nodes.
func _refresh() -> void:
	if not is_node_ready():
		return
	var has_technique: bool = _hover_data() != null
	_icon.texture = _ability_data.icon if has_technique else null
	_icon.visible = has_technique
	var mini_icon: Texture2D = cost_icon(_ability_data) if has_technique else null
	_cost_icon.texture = mini_icon
	_cost_label.text = AbilityRow.format_number(_shown_cost(_ability_data)) if mini_icon != null else ""
	_cost_line.visible = mini_icon != null
	_set_cost_affordable(true)
	_cast_frame.visible = _state == SlotState.ACTIVE and _is_casting
	_refresh_shared()

func _set_cost_affordable(affordable: bool) -> void:
	_cost_affordable = affordable
	_cost_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if affordable else ThemeConstants.LACQUER_TAN)

## Lets go of the bound instance and forgets its cooldown and cast.
func _unbind_instance() -> void:
	_unbind_cooldown()
	if is_instance_valid(_instance):
		for connection: Array in [
			[_instance.cast_started, _on_cast_started],
			[_instance.cast_finished, _on_cast_finished],
			[_instance.cast_cancelled, _on_cast_cancelled],
		]:
			var sig: Signal = connection[0]
			if sig.is_connected(connection[1]):
				sig.disconnect(connection[1])
	_instance = null
	_vitals_manager = null
	_is_casting = false

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(_cast_instance: CombatAbilityInstance, _duration: float) -> void:
	_is_casting = true
	_cast_frame.show()

func _on_cast_finished(_cast_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_cast_frame.hide()

func _on_cast_cancelled(_cast_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_cast_frame.hide()
