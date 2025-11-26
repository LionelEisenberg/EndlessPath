@tool
extends EditorScript

func _run() -> void:
	var effect = AwardItemEffectData.new()
	
	# We need a dummy item definition
	var item_def = ItemDefinitionData.new()
	item_def.item_name = "Test Item"
	item_def.item_type = ItemDefinitionData.ItemType.MATERIAL
	
	effect.item = item_def
	effect.quantity = 5
	
	print("Testing AwardItemEffectData:")
	print(effect)
	
	# We can't easily test process() because it depends on InventoryManager singleton which might not be initialized in EditorScript
	# But we can verify the object structure and string representation
	
	if effect.item == item_def and effect.quantity == 5:
		print("SUCCESS: AwardItemEffectData properties set correctly.")
	else:
		print("FAILURE: AwardItemEffectData properties incorrect.")
		
	if "AwardItemEffectData" in str(effect) and "Test Item" in str(effect) and "5" in str(effect):
		print("SUCCESS: _to_string() works correctly.")
	else:
		print("FAILURE: _to_string() output incorrect.")
