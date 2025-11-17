@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name MaxCountRequirement

## Limits the total number of times this tile can appear in the entire grid.
## Useful for unique/rare tiles like boss rooms, treasure chests, etc.

@export_range(1, 1000) var max_count: int = 1

## Internal counter tracked during generation (set by solver)
var _current_count: int = 0

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	# Check if we've already reached the limit
	# The solver should track placement counts in the context
	var count_key = "tile_count_" + str(tile.get_instance_id())
	var current = context.get(count_key, 0)
	
	return current < max_count

func get_failure_reason() -> String:
	return "Maximum count of %d reached" % max_count

func get_description() -> String:
	return "Maximum %d instance%s" % [max_count, "s" if max_count != 1 else ""]

func reset() -> void:
	"""Reset the counter (called at the start of generation)."""
	_current_count = 0
