class_name MaterialDetailCard
extends ItemDetailCard

## MaterialDetailCard
## Extends ItemDetailCard with three material-specific rows: Source,
## Used in, Worth.

@onready var _source_value: Label = %SourceValue
@onready var _used_in_value: Label = %UsedInValue
@onready var _worth_value: Label = %WorthValue

func setup_from_definition(def: ItemDefinitionData) -> void:
	super.setup_from_definition(def)
	if def is MaterialDefinitionData:
		var m: MaterialDefinitionData = def as MaterialDefinitionData
		_source_value.text = m.source_description
		_used_in_value.text = m.used_in
		_worth_value.text = "%d" % int(m.base_value) if m.base_value > 0 else "—"
	else:
		_source_value.text = ""
		_used_in_value.text = ""
		_worth_value.text = ""

func reset() -> void:
	super.reset()
	if _source_value:
		_source_value.text = ""
	if _used_in_value:
		_used_in_value.text = ""
	if _worth_value:
		_worth_value.text = ""
