class_name LootTable
extends Resource

## LootTable
## A resource that defines a collection of items with independent drop chances.
## Each entry rolls separately, allowing multiple items to drop from a single roll.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## Array of loot entries that will be rolled independently
@export var entries: Array[LootTableEntry] = []

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _init() -> void:
	call_deferred("_verify_loot_table")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Roll all loot entries and return items that passed their probability checks.
## Returns: Dictionary[ItemDefinitionData, int] mapping items to total quantities
func roll_loot() -> Dictionary:
	var result: Dictionary = {}
	
	Log.info("LootTable: Rolling loot table with %d entries" % entries.size())
	
	for entry in entries:
		if not entry or not entry.item:
			Log.warn("LootTable: Skipping invalid entry (null or missing item)")
			continue
		
		# Roll for this entry
		var roll: float = randf()
		
		if roll <= entry.drop_chance:
			# Success! Determine quantity
			var quantity: int = randi_range(entry.min_quantity, entry.max_quantity)
			
			Log.info("LootTable: SUCCESS - %s (roll: %.3f <= %.3f) x%d" % [
				entry.item.item_name,
				roll,
				entry.drop_chance,
				quantity
			])
			
			# Add to result (combine if item already exists)
			if result.has(entry.item):
				result[entry.item] += quantity
			else:
				result[entry.item] = quantity
		else:
			Log.info("LootTable: FAILED - %s (roll: %.3f > %.3f)" % [
				entry.item.item_name,
				roll,
				entry.drop_chance
			])
	
	Log.info("LootTable: Roll complete, %d unique items awarded" % result.size())
	return result

#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

## Verify that all loot entries are valid
func _verify_loot_table() -> bool:	
	var valid: bool = true
	
	for i in range(entries.size()):
		var entry = entries[i]
		
		if not entry:
			Log.error("LootTable: Entry %d is null" % i)
			valid = false
			continue
		
		# Check for valid item
		if not entry.item:
			Log.error("LootTable: Entry %d has null item" % i)
			valid = false
		
		# Check drop chance range
		if entry.drop_chance < 0.0 or entry.drop_chance > 1.0:
			Log.error("LootTable: Entry %d has invalid drop_chance: %f (must be 0.0-1.0)" % [
				i,
				entry.drop_chance
			])
			valid = false
		
		# Check quantity range
		if entry.min_quantity < 1:
			Log.error("LootTable: Entry %d has invalid min_quantity: %d (must be >= 1)" % [
				i,
				entry.min_quantity
			])
			valid = false
		
		if entry.max_quantity < 1:
			Log.error("LootTable: Entry %d has invalid max_quantity: %d (must be >= 1)" % [
				i,
				entry.max_quantity
			])
			valid = false
		
		if entry.min_quantity > entry.max_quantity:
			Log.error("LootTable: Entry %d has min_quantity (%d) > max_quantity (%d)" % [
				i,
				entry.min_quantity,
				entry.max_quantity
			])
			valid = false
	
	if not valid:
		Log.error("LootTable: Validation failed!")
	
	return valid

#-----------------------------------------------------------------------------
# STRING REPRESENTATION
#-----------------------------------------------------------------------------

func _to_string() -> String:
	var lines: Array[String] = []
	lines.append("\nLootTable {")
	lines.append("  Entries: %d" % entries.size())
	for i in range(entries.size()):
		if entries[i]:
			lines.append("    [%d] %s" % [i, entries[i]._to_string()])
	lines.append("}")
	return "\n".join(lines)
