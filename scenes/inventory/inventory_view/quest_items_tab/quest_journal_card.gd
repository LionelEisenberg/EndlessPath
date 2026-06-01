extends PanelContainer

## QuestJournalCard
## Right-page card for a selected quest item. Shows big icon, name +
## sub, drop-cap body text, and a "From:" row populated from
## QuestItemDefinitionData.from_source. The "Linked quest" row is
## deferred until a QuestManager exists.

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _sub: Label = %Sub
@onready var _body: RichTextLabel = %Body
@onready var _from_row: HBoxContainer = %FromRow
@onready var _from_value: Label = %FromValue

## Populate from a quest item definition (or any ItemDefinitionData —
## non-QuestItemDefinitionData defs hide the From row).
func setup_from_definition(def: ItemDefinitionData) -> void:
	if def == null:
		reset()
		return
	_icon.texture = def.icon
	_name.text = def.item_name
	_sub.text = ""

	# Drop-cap effect: first letter rendered larger and in ribbon-red.
	var body_text: String = def.description if def.description != null else ""
	if body_text.length() >= 1:
		var first: String = body_text[0]
		var rest: String = body_text.substr(1)
		_body.text = "[font_size=38][color=#b04a2f]%s[/color][/font_size]%s" % [first, rest]
	else:
		_body.text = ""

	# "From:" row — only on QuestItemDefinitionData with non-empty from_source.
	if def is QuestItemDefinitionData:
		var quest_def: QuestItemDefinitionData = def as QuestItemDefinitionData
		_from_row.visible = not quest_def.from_source.is_empty()
		_from_value.text = quest_def.from_source
	else:
		_from_row.visible = false
		_from_value.text = ""

## Clear all fields.
func reset() -> void:
	_icon.texture = null
	_name.text = ""
	_sub.text = ""
	_body.text = ""
	_from_row.visible = false
	_from_value.text = ""
