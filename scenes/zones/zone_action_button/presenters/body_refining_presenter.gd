class_name BodyRefiningPresenter
extends ZoneActionPresenter
## Presenter for BODY_REFINING cards: what every drill gives, each with its 16 px
## icon, as the forage card lists its finds ([heart] Health  [arm] Strength XP):
## the Health heart the dock shows for a Health cost, and Strength's mini. The
## drill, what a rep pays and the set's progress are the board's and the Now
## strip's to show, not the card's (the user's review, 2026-10-24). The two
## rewards stand in a flow, so a reward that would pass the line's room moves to
## the next line whole: nothing is cut off.

const HEALTH_TEXT: String = "Health"
const STRENGTH_TEXT: String = "Strength XP"
const HEALTH_ICON: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")

@onready var _rewards: HFlowContainer = %Rewards
@onready var _health_reward: HBoxContainer = %HealthReward
@onready var _strength_reward: HBoxContainer = %StrengthReward

## Moves the rewards into the card and fills them.
func setup(data: ZoneActionData, owner_button: ZoneActionButton) -> void:
	action_data = data
	button = owner_button
	_rewards.reparent(button.get_detail_slot(), false)
	_fill(_health_reward, HEALTH_ICON, HEALTH_TEXT)
	_fill(_strength_reward, StatDisplay.mini_icon_of(CharacterAttributesData.AttributeType.STRENGTH), STRENGTH_TEXT)
	button.relayout()

## Nothing to undo: the rewards never change.
func teardown() -> void:
	pass

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _fill(reward: HBoxContainer, icon: Texture2D, text: String) -> void:
	(reward.get_node("%Icon") as TextureRect).texture = icon
	(reward.get_node("%YieldText") as RichTextLabel).text = LacquerText.decimal_bbcode(text)
