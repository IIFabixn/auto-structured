@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name AdjacentRequirement

## Requires specific tiles or tags to be adjacent to this tile.
## Useful for tiles that must be next to walls, other tiles, etc.

enum AdjacentMode {
	MUST_HAVE,       ## At least one adjacent tile must match
	MUST_NOT_HAVE,   ## No adjacent tiles can match
	EXACT_COUNT      ## Exactly N adjacent tiles must match
}

@export var mode: AdjacentMode = AdjacentMode.MUST_HAVE
@export var required_tags: Array[String] = []  ## Tags that adjacent tiles must have/not have
@export var required_count: int = 1  ## For EXACT_COUNT mode
@export var check_horizontal: bool = true  ## Check X/Z neighbors
@export var check_vertical: bool = false   ## Check Y neighbors

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	if required_tags.is_empty():
		return true
	
	var matching_neighbors = 0
	var directions = []
	
	if check_horizontal:
		directions.append(Vector3i(1, 0, 0))
		directions.append(Vector3i(-1, 0, 0))
		directions.append(Vector3i(0, 0, 1))
		directions.append(Vector3i(0, 0, -1))
	
	if check_vertical:
		directions.append(Vector3i(0, 1, 0))
		directions.append(Vector3i(0, -1, 0))
	
	for dir in directions:
		var neighbor_pos = position + dir
		if not grid.is_valid_position(neighbor_pos):
			continue
		
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if not neighbor_cell or not neighbor_cell.is_collapsed():
			continue
		
		var neighbor_tile = neighbor_cell.get_tile()
		if not neighbor_tile:
			continue
		
		# Check if neighbor has any of the required tags
		for tag in required_tags:
			if tag in neighbor_tile.tags:
				matching_neighbors += 1
				break
	
	match mode:
		AdjacentMode.MUST_HAVE:
			return matching_neighbors > 0
		AdjacentMode.MUST_NOT_HAVE:
			return matching_neighbors == 0
		AdjacentMode.EXACT_COUNT:
			return matching_neighbors == required_count
	
	return true

func get_failure_reason() -> String:
	var tag_str = ", ".join(required_tags)
	match mode:
		AdjacentMode.MUST_HAVE:
			return "Must be adjacent to tile with tags: %s" % tag_str
		AdjacentMode.MUST_NOT_HAVE:
			return "Cannot be adjacent to tile with tags: %s" % tag_str
		AdjacentMode.EXACT_COUNT:
			return "Must have exactly %d adjacent tiles with tags: %s" % [required_count, tag_str]
	return super.get_failure_reason()

func get_description() -> String:
	var tag_str = ", ".join(required_tags)
	var dir_str = ""
	if check_horizontal and check_vertical:
		dir_str = "any adjacent"
	elif check_horizontal:
		dir_str = "horizontally adjacent"
	elif check_vertical:
		dir_str = "vertically adjacent"
	
	match mode:
		AdjacentMode.MUST_HAVE:
			return "Requires %s tile with: %s" % [dir_str, tag_str]
		AdjacentMode.MUST_NOT_HAVE:
			return "Cannot be %s to: %s" % [dir_str, tag_str]
		AdjacentMode.EXACT_COUNT:
			return "Needs exactly %d %s tiles with: %s" % [required_count, dir_str, tag_str]
	return super.get_description()
