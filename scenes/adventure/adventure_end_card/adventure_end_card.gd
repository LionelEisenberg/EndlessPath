class_name AdventureEndCard
extends Control

## AdventureEndCard
## Displays adventure results on a scroll overlay. Populated from AdventureResultData,
## plays open/close animations, and emits return_requested when dismissed.
## Under the stats, the run's Core Density: the core's stars as they stand, the
## part the run added in jade (LacquerStarRow, on parchment), and the XP the run's
## rewards paid, "+N", or "none this run", with "Core full" once the core is.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal return_requested

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var title_label: Label = %TitleLabel
@onready var defeat_reason_label: Label = %DefeatReasonLabel
@onready var combat_value_label: Label = %CombatValueLabel
@onready var gold_value_label: Label = %GoldValueLabel
@onready var time_value_label: Label = %TimeValueLabel
@onready var health_value_label: Label = %HealthValueLabel
@onready var tiles_value_label: Label = %TilesValueLabel
@onready var madra_value_label: Label = %MadraValueLabel
@onready var core_density_stars: LacquerStarRow = %CoreDensityStars
@onready var core_density_value_label: Label = %CoreDensityValueLabel
@onready var loot_container: HBoxContainer = %LootContainer
@onready var loot_empty_label: Label = %LootEmptyLabel
@onready var return_button: Button = %ReturnButton
@onready var content_container: Control = %ContentContainer
@onready var left_icon: TextureRect = %LeftIcon
@onready var right_icon: TextureRect = %RightIcon

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const VICTORY_COLOR := Color("#8b6914")
const DEFEAT_COLOR := Color("#8b2020")
const GOLD_COLOR := Color("#b8860b")
const HEALTH_GOOD_COLOR := Color("#228b22")
const HEALTH_DEAD_COLOR := Color("#8b2020")
const MADRA_COLOR := Color("#4a7ab5")
const CORE_FULL_TEXT: String = "Core full"

const VICTORY_ICON := preload("res://assets/sprites/ui/stat_icons/victory_icon.png")
const DEFEAT_ICON := preload("res://assets/sprites/ui/stat_icons/skull_icon.png")

const _ITEM_DISPLAY_SLOT_SCENE := preload("res://scenes/common/item_display_slot/item_display_slot.tscn")

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)


#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Populate the end card with adventure results and play the open animation.
func show_results(result_data: AdventureResultData) -> void:
	_populate(result_data)
	visible = true
	animation_player.play_backwards("scroll_animation")
	await animation_player.animation_finished
	content_container.modulate.a = 1.0

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _populate(data: AdventureResultData) -> void:
	# Title and icons
	if data.is_victory:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", VICTORY_COLOR)
		left_icon.texture = VICTORY_ICON
		right_icon.texture = VICTORY_ICON
		defeat_reason_label.visible = false
	else:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", DEFEAT_COLOR)
		left_icon.texture = DEFEAT_ICON
		right_icon.texture = DEFEAT_ICON
		defeat_reason_label.text = data.defeat_reason
		defeat_reason_label.visible = true

	# Stats
	combat_value_label.text = "%d / %d" % [data.combats_fought, data.combats_total]
	gold_value_label.text = str(data.gold_earned)
	gold_value_label.add_theme_color_override("font_color", GOLD_COLOR)

	var minutes: int = int(data.time_elapsed) / 60
	var seconds: int = int(data.time_elapsed) % 60
	time_value_label.text = "%d:%02d" % [minutes, seconds]

	health_value_label.text = VitalsText.health_pair(data.health_remaining, data.health_max)
	if data.health_remaining <= 0.0:
		health_value_label.add_theme_color_override("font_color", HEALTH_DEAD_COLOR)
	else:
		health_value_label.add_theme_color_override("font_color", HEALTH_GOOD_COLOR)

	tiles_value_label.text = "%d / %d" % [data.tiles_explored, data.tiles_total]

	madra_value_label.text = "%d / %d" % [floori(data.madra_left), floori(data.madra_max)]
	madra_value_label.add_theme_color_override("font_color", MADRA_COLOR)

	core_density_stars.set_fills(
		CultivationManager.get_star_fills_at(data.core_density_level_after),
		CultivationManager.get_star_fills_at(data.core_density_level_before))
	core_density_value_label.text = core_density_text(data)

	# Loot
	_populate_loot(data.loot_items)

## The run's Core Density line beside its stars: "+N", the XP the run's rewards
## paid; "none this run"; and "Core full" after it once the core is full ("+N ·
## Core full" when the run filled it, "Core full" alone when it was full all run).
static func core_density_text(data: AdventureResultData) -> String:
	var xp: int = floori(data.core_density_xp_earned)
	var cap: int = CultivationManager.get_core_density_cap()
	var full: bool = cap > 0 and data.core_density_level_after >= cap
	if xp <= 0:
		return CORE_FULL_TEXT if full else "none this run"
	if full:
		return "+%d · %s" % [xp, CORE_FULL_TEXT]
	return "+%d" % xp

func _populate_loot(items: Array[Resource]) -> void:
	# Clear existing preview/placeholder slots
	for child in loot_container.get_children():
		child.queue_free()

	if items.is_empty():
		loot_empty_label.visible = true
		loot_container.visible = false
	else:
		loot_empty_label.visible = false
		loot_container.visible = true
		for item in items:
			var slot := _ITEM_DISPLAY_SLOT_SCENE.instantiate() as ItemDisplaySlot
			if item is ItemInstanceData:
				slot.setup_from_instance(item)
			elif item is ItemDefinitionData:
				slot.setup_from_definition(item)
			loot_container.add_child(slot)

func _on_return_pressed() -> void:
	animation_player.play("scroll_animation")
	await animation_player.animation_finished
	visible = false
	return_requested.emit()
