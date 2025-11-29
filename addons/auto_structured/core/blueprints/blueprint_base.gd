@tool
class_name BlueprintBase extends RefCounted
## Abstract base class for WFC blueprints.
##
## Blueprints define the macro-structure of what WFC should generate.
## They classify cells into semantic zones and provide filtering rules
## for which tiles are valid in each zone.
##
## Subclasses implement specific generation patterns:
## - BuildingBlueprint: Rooms, walls, floors, roofs
## - VillageBlueprint: Roads, buildings, plazas
## - ParkBlueprint: Paths, gardens, fences
##
## Usage:
##   var blueprint = BuildingBlueprint.new()
##   blueprint.configure({"min_room_size": 3, "max_rooms": 4})
##   blueprint.generate(grid_size)
##   
##   # Then apply to grid in a strategy:
##   for cell in grid.get_all_cells():
##       var zone = blueprint.get_zone(cell.position)
##       blueprint.filter_cell_by_zone(cell, zone)

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Zone types - subclasses can define additional zones
enum Zone {
	UNKNOWN = -1,   ## Unclassified cell
	EMPTY = 0,      ## Cell should be left empty (air)
	EXTERIOR = 1,   ## Outside area (grass, paths, etc.)
	INTERIOR = 2,   ## Inside area (floors)
	WALL = 3,       ## Wall boundary
	CORNER = 4,     ## Corner of structure
	ROOF = 5,       ## Top of structure
	FLOOR = 6,      ## Ground level (may have doors)
	DOOR = 7,       ## Designated door location
	CUSTOM_1 = 100, ## For subclass-specific zones
	CUSTOM_2 = 101,
	CUSTOM_3 = 102,
}

## Human-readable zone names for debugging
const ZONE_NAMES = {
	Zone.UNKNOWN: "UNKNOWN",
	Zone.EMPTY: "EMPTY",
	Zone.EXTERIOR: "EXTERIOR",
	Zone.INTERIOR: "INTERIOR",
	Zone.WALL: "WALL",
	Zone.CORNER: "CORNER",
	Zone.ROOF: "ROOF",
	Zone.FLOOR: "FLOOR",
	Zone.DOOR: "DOOR",
	Zone.CUSTOM_1: "CUSTOM_1",
	Zone.CUSTOM_2: "CUSTOM_2",
	Zone.CUSTOM_3: "CUSTOM_3",
}

## Generated zone data: position_key -> Zone
var _zone_map: Dictionary = {}

## Grid size this blueprint was generated for
var _grid_size: Vector3i = Vector3i.ZERO

## Configuration options (subclass-specific)
var _config: Dictionary = {}

## Debug mode - prints extra info during generation
var debug_enabled: bool = false


## ============================================================================
## Abstract Methods - Subclasses MUST implement these
## ============================================================================

func get_id() -> String:
	## Unique identifier for this blueprint type
	push_error("BlueprintBase.get_id() must be implemented by subclass")
	return "unknown"


func get_display_name() -> String:
	## Human-readable name for UI
	push_error("BlueprintBase.get_display_name() must be implemented by subclass")
	return "Unknown Blueprint"


func get_description() -> String:
	## Description of what this blueprint generates
	return "No description available"


func _generate_zones(_grid_size: Vector3i) -> void:
	## Generate zone classifications for all cells.
	## Must populate _zone_map with Zone values for each position.
	push_error("BlueprintBase._generate_zones() must be implemented by subclass")


func _get_valid_boundary_roles_for_zone(_zone: Zone) -> Array[Tile.BoundaryRole]:
	## Return which BoundaryRole values are allowed in this zone.
	## Default implementation - subclasses should override.
	return [Tile.BoundaryRole.NONE, Tile.BoundaryRole.EDGE, Tile.BoundaryRole.CORNER, Tile.BoundaryRole.INFILL]


## ============================================================================
## Public API
## ============================================================================

func configure(config: Dictionary) -> void:
	## Set configuration options for this blueprint.
	## Call before generate().
	_config = config.duplicate()
	_on_configure(config)


func generate(grid_size: Vector3i) -> void:
	## Generate the blueprint for a grid of the given size.
	## Populates the internal zone map.
	_grid_size = grid_size
	_zone_map.clear()
	
	_log("Generating %s blueprint for grid %s..." % [get_display_name(), grid_size])
	
	_generate_zones(grid_size)
	
	if debug_enabled:
		_print_zone_summary()


func get_zone(position: Vector3i) -> Zone:
	## Get the zone type for a position.
	## Returns UNKNOWN if position wasn't classified.
	var key = _pos_to_key(position)
	return _zone_map.get(key, Zone.UNKNOWN)


func get_zone_name(zone: Zone) -> String:
	## Get human-readable name for a zone.
	return ZONE_NAMES.get(zone, "ZONE_%d" % zone)


func set_zone(position: Vector3i, zone: Zone) -> void:
	## Manually set the zone for a position.
	var key = _pos_to_key(position)
	_zone_map[key] = zone


func get_all_positions_in_zone(zone: Zone) -> Array[Vector3i]:
	## Get all positions that belong to a specific zone.
	var positions: Array[Vector3i] = []
	for key in _zone_map:
		if _zone_map[key] == zone:
			positions.append(_key_to_pos(key))
	return positions


func filter_cell_by_zone(cell, zone: Zone) -> void:
	## Filter a cell's possible variants based on its zone.
	## This is the main hook for applying blueprint constraints to the grid.
	if cell == null or cell.is_collapsed():
		return
	
	var valid_roles = _get_valid_boundary_roles_for_zone(zone)
	var filtered: Array[Dictionary] = []
	
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		
		# Check boundary role
		if tile.boundary_role not in valid_roles:
			continue
		
		# Apply additional zone-specific filtering
		if not _is_tile_valid_for_zone(tile, zone, cell.position):
			continue
		
		filtered.append(variant)
	
	if not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false
	elif debug_enabled:
		push_warning("Blueprint: Cell %s in zone %s has no valid variants after filtering!" % [cell.position, get_zone_name(zone)])


func get_anchor_cells() -> Array[Dictionary]:
	## Return cells that should be pre-collapsed to specific tiles.
	## Each dictionary has: {"position": Vector3i, "tile_filter": Callable, "rotation": int (optional)}
	## Override in subclasses to force specific tiles at key positions.
	return []


func get_collapse_priority(position: Vector3i) -> float:
	## Return priority for collapsing this cell (higher = earlier).
	## Override to influence WFC solve order.
	## Default: collapse from bottom to top, then center outward.
	var zone = get_zone(position)
	var priority = 0.0
	
	# Corners and anchors first
	if zone == Zone.CORNER:
		priority += 1000.0
	elif zone == Zone.DOOR:
		priority += 500.0
	elif zone == Zone.WALL:
		priority += 100.0
	
	# Bottom to top
	priority += float(_grid_size.y - position.y) * 10.0
	
	return priority


func get_wall_facing_direction(position: Vector3i) -> Vector3i:
	## For WALL zone cells, return which direction the wall should face (toward outside).
	## Returns Vector3i.ZERO if no specific facing required.
	## Override in subclasses for orientation-aware wall placement.
	return Vector3i.ZERO


## ============================================================================
## Protected Methods - Subclasses can override these
## ============================================================================

func _on_configure(_config: Dictionary) -> void:
	## Called when configure() is called. Override to process config.
	pass


func _is_tile_valid_for_zone(tile: Tile, zone: Zone, _position: Vector3i) -> bool:
	## Additional tile validation beyond boundary role.
	## Override for zone-specific tag filtering.
	match zone:
		Zone.EXTERIOR:
			# Exclude interior-only tiles
			if tile.has_tag("interior"):
				return false
		Zone.INTERIOR:
			# Exclude exterior-only tiles
			if tile.has_tag("exterior"):
				return false
		Zone.DOOR:
			# Only allow door tiles
			if not tile.has_tag("door"):
				return false
	
	return true


## ============================================================================
## Utility Methods
## ============================================================================

func _pos_to_key(pos: Vector3i) -> int:
	## Convert position to integer key for dictionary storage.
	return pos.x + pos.y * _grid_size.x + pos.z * _grid_size.x * _grid_size.y


func _key_to_pos(key: int) -> Vector3i:
	## Convert integer key back to position.
	var x = key % _grid_size.x
	var remainder = key / _grid_size.x
	var y = remainder % _grid_size.y
	var z = remainder / _grid_size.y
	return Vector3i(x, y, z)


func _log(message: String) -> void:
	if debug_enabled:
		print("[%s] %s" % [get_id(), message])


func _print_zone_summary() -> void:
	## Print a summary of zone distribution.
	var counts: Dictionary = {}
	for key in _zone_map:
		var zone = _zone_map[key]
		counts[zone] = counts.get(zone, 0) + 1
	
	print("[%s] Zone summary for grid %s:" % [get_id(), _grid_size])
	for zone in counts:
		print("  %s: %d cells" % [get_zone_name(zone), counts[zone]])


func is_valid_position(pos: Vector3i) -> bool:
	## Check if position is within grid bounds.
	return (
		pos.x >= 0 and pos.x < _grid_size.x and
		pos.y >= 0 and pos.y < _grid_size.y and
		pos.z >= 0 and pos.z < _grid_size.z
	)


func get_neighbor_zone(position: Vector3i, direction: Vector3i) -> Zone:
	## Get the zone of a neighboring cell.
	var neighbor_pos = position + direction
	if not is_valid_position(neighbor_pos):
		return Zone.EMPTY  # Outside grid = empty
	return get_zone(neighbor_pos)
