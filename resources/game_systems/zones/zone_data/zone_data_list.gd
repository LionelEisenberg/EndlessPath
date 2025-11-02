class_name ZoneDataList
extends Resource

@export var list : Array[ZoneData] = []

func get_zone_data_by_id(zone_id: String) -> ZoneData:
	for zone_data in list:
		if zone_data.zone_id == zone_id:
			return zone_data
	return null
