extends SceneTree

func _init():
	print("Starting Item Description Test...")
	
	# Test Material
	var material_def = MaterialDefinitionData.new()
	material_def.item_name = "Iron Ore"
	material_def.description = "A chunk of iron ore."
	material_def.base_value = 10
	material_def.source_zone_ids = ["Zone A", "Zone B"]
	
	var material_instance = ItemInstanceData.new()
	material_instance.item_definition = material_def
	material_instance.quantity = 5
	
	print("\n--- Material Description ---")
	print(material_instance._to_description_box())
	
	# Test Weapon
	var weapon_def = WeaponDefinitionData.new()
	weapon_def.item_name = "Steel Sword"
	weapon_def.description = "A sharp steel sword."
	weapon_def.base_value = 100
	weapon_def.attack_power = 50
	weapon_def.scaling = {"STR": 1.5, "DEX": 0.5}
	
	var weapon_instance = ItemInstanceData.new()
	weapon_instance.item_definition = weapon_def
	
	print("\n--- Weapon Description ---")
	print(weapon_instance._to_description_box())
	
	# Test Armor
	var armor_def = ArmorDefinitionData.new()
	armor_def.item_name = "Leather Armor"
	armor_def.description = "Basic leather armor."
	armor_def.base_value = 50
	armor_def.defense = 10
	
	var armor_instance = ItemInstanceData.new()
	armor_instance.item_definition = armor_def
	armor_instance.metadata = {"Durability": 100}
	
	print("\n--- Armor Description ---")
	print(armor_instance._to_description_box())
	
	quit()
