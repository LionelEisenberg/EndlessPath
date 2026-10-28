class_name MaterialSources
extends RefCounted

## MaterialSources
## Where the player can gather a material, for the Materials page's details:
## every foraging activity whose loot table lists it, with the activity's
## zone, the loot entry's quantity range and how often the activity rolls.
## Only sources the player can already see are listed: activities they have
## unlocked, in zones the map shows them and has charted and opened, so the
## page spoils nothing. Worked out on each call, so it follows the unlocks.

#-----------------------------------------------------------------------------
# SOURCE
#-----------------------------------------------------------------------------

## One place a material comes from.
class Source:
	extends RefCounted

	## The activity's name ("Spring Forest Foraging").
	var activity_name: String = ""
	## The name of the zone the activity is in ("Spirit Valley").
	var zone_name: String = ""
	## The fewest the loot entry awards per roll.
	var min_quantity: int = 0
	## The most the loot entry awards per roll.
	var max_quantity: int = 0
	## How often the activity rolls its loot table, in seconds.
	var interval_seconds: float = 0.0

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Returns every source of `material` the player can already see, in zone
## order: one per loot entry, in an open or current zone on the map, of an
## available ForageActionData that has a loot table, whose item has the
## material's item_id.
static func find(material: MaterialDefinitionData) -> Array[MaterialSources.Source]:
	var sources: Array[MaterialSources.Source] = []
	if material == null:
		return sources
	for zone: ZoneData in ZoneManager.get_map_zones():
		var state: ZoneManager.ZoneMapState = ZoneManager.get_zone_map_state(zone)
		if state == ZoneManager.ZoneMapState.LOCKED or state == ZoneManager.ZoneMapState.UNCHARTED:
			continue
		for action: ZoneActionData in ZoneManager.get_available_actions(zone.zone_id):
			var forage: ForageActionData = action as ForageActionData
			if forage == null or forage.loot_table == null:
				continue
			for entry: LootTableEntry in forage.loot_table.entries:
				if entry.item != null and entry.item.item_id == material.item_id:
					sources.append(_source(forage, zone, entry))
	return sources

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## The source a foraging activity's loot entry makes.
static func _source(forage: ForageActionData, zone: ZoneData, entry: LootTableEntry) -> MaterialSources.Source:
	var source: MaterialSources.Source = MaterialSources.Source.new()
	source.activity_name = forage.action_name
	source.zone_name = zone.zone_name
	source.min_quantity = entry.min_quantity
	source.max_quantity = entry.max_quantity
	source.interval_seconds = forage.foraging_interval_in_sec
	return source
