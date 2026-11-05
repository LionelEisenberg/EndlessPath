extends GutTest

## Content check for the one Madra pool: at home only cycling and the Aura Well
## refill it (spec, phase 2). Cycling adds Madra in code; the only content that
## may award Madra is the Aura Well's training action. Walks every resource
## file under res://resources/ and each resource it holds, so a quest reward,
## an unlock effect or a zone action that awards Madra fails here.

const RESOURCES_DIR: String = "res://resources/"
## The content allowed to hold a Madra award: the Aura Well's trickle.
const ALLOWED_HOLDERS: Array[String] = [
	"res://resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres",
]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every .tres path under `dir`, depth first.
func _resource_paths(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		paths.append_array(_resource_paths(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			paths.append(dir.path_join(file))
	return paths

## Adds to `holders` the path of each resource reachable from `value` that holds
## a Madra award itself, in a property or in an array or dictionary there. Only
## scripted resources are walked: textures, fonts and the like hold no effects.
func _collect_holders(value: Variant, holders: Dictionary, visited: Dictionary) -> void:
	if value is Array:
		for item: Variant in value:
			_collect_holders(item, holders, visited)
		return
	if value is Dictionary:
		for key: Variant in value:
			_collect_holders(key, holders, visited)
			_collect_holders(value[key], holders, visited)
		return
	if not value is Resource:
		return
	var resource: Resource = value
	if resource.get_script() == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	for property: Dictionary in resource.get_property_list():
		if not property.usage & PROPERTY_USAGE_STORAGE or property.name == "script":
			continue
		var held: Variant = resource.get(property.name)
		if _is_or_lists_a_madra_award(held):
			holders[resource.resource_path] = true
		_collect_holders(held, holders, visited)

## True when `value` is a Madra award, or an array or dictionary holding one.
func _is_or_lists_a_madra_award(value: Variant) -> bool:
	if value is Array:
		return (value as Array).any(_is_or_lists_a_madra_award)
	if value is Dictionary:
		return (value as Dictionary).values().any(_is_or_lists_a_madra_award)
	var award := value as AwardResourceEffectData if value is Object else null
	return award != null and award.resource_type == ResourceManager.ResourceType.MADRA

## The resources that hold a Madra award: a file's path, or the file's path
## and "::" and the id for a resource written inside another file.
func _madra_award_holders() -> Array[String]:
	var holders: Dictionary = {}
	var visited: Dictionary = {}
	for path: String in _resource_paths(RESOURCES_DIR.trim_suffix("/")):
		_collect_holders(load(path), holders, visited)
	var paths: Array[String] = []
	paths.assign(holders.keys())
	paths.sort()
	return paths

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_only_the_aura_well_awards_madra() -> void:
	var others: Array[String] = _madra_award_holders().filter(func(path: String) -> bool: return not ALLOWED_HOLDERS.has(path))
	assert_eq(others, [] as Array[String], "content that refills Madra at home besides cycling and the Aura Well")

## The walk finds the one award content has, so a walk that finds nothing
## can't pass the check above.
func test_the_walk_finds_the_aura_wells_trickle() -> void:
	assert_eq(_madra_award_holders(), ALLOWED_HOLDERS)
