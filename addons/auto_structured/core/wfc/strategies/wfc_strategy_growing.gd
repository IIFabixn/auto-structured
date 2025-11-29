@tool
class_name WfcGrowingStrategy extends WfcSolveStrategy
## A structure-aware strategy that generates room layouts before WFC solving.
##
## This strategy works by:
## 1. Generating a random room pattern (inside/outside zones)
## 2. Deriving cell types from the pattern (walls at boundaries)
## 3. Removing invalid tile candidates from each cell
## 4. Letting WFC solve for tile variants within each zone
##
## This guarantees closed structures because walls are placed deterministically
## at zone boundaries, not probabilistically.

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Cell zone types
enum Zone {
	OUTSIDE,   ## Outside the structure (air, outside_floor)
	INSIDE,    ## Inside the structure (floor, interior elements)
	WALL,      ## Wall boundary between inside/outside
	CORNER     ## Corner of the structure
}

## Configuration
@export var min_room_size: int = 3  ## Minimum room dimension
@export var max_rooms: int = 4  ## Maximum number of rooms to generate
@export var room_connection_chance: float = 0.7  ## Chance to connect adjacent rooms
@export var door_chance: float = 0.15  ## Chance for a wall segment to be a door

## Internal state
var _grid_ref = null
var _solver_ref = null
var _zone_map: Dictionary = {}  ## pos_key -> Zone
var _room_rects: Array = []  ## Array of Rect2i representing rooms


func get_id() -> String:
	return "growing"


func get_display_name() -> String:
	return "Growing Structure"


func configure(solver, _config) -> void:
	if solver == null or solver.grid == null:
		return
	_solver_ref = solver
	_grid_ref = solver.grid


func get_solver_overrides() -> Dictionary:
	"""Disable region boundary requirement since we handle walls deterministically."""
	return {
		"enforce_region_boundaries": false,  # We place walls via zones, not requirements
		"require_closed_regions": false,     # Zones guarantee closed structures
	}


func prepare_grid(grid, solver) -> void:
	"""Generate room layout and constrain grid cells accordingly."""
	if grid == null:
		return
	
	_grid_ref = grid
	_solver_ref = solver
	_zone_map.clear()
	_room_rects.clear()
	
	# Step 1: Generate room layout
	_generate_room_layout()
	
	# Step 2: Calculate zone for each cell
	_calculate_zones()
	
	# Step 3: Apply constraints to grid cells
	_apply_zone_constraints()
	
	# Debug output
	var zone_counts = {Zone.OUTSIDE: 0, Zone.INSIDE: 0, Zone.WALL: 0, Zone.CORNER: 0}
	for key in _zone_map:
		zone_counts[_zone_map[key]] += 1
	
	print("[Growing Strategy] Room layout generated:")
	print("  Rooms: ", _room_rects.size())
	for i in range(_room_rects.size()):
		print("    Room %d: pos(%d,%d) size(%d,%d)" % [i, _room_rects[i].position.x, _room_rects[i].position.y, _room_rects[i].size.x, _room_rects[i].size.y])
	print("  Grid size: ", grid.size)
	print("  Zones: Outside=%d, Inside=%d, Wall=%d, Corner=%d" % [zone_counts[Zone.OUTSIDE], zone_counts[Zone.INSIDE], zone_counts[Zone.WALL], zone_counts[Zone.CORNER]])


func on_reset(_solver) -> void:
	_zone_map.clear()
	_room_rects.clear()


func pick_next_cell(solver) -> Variant:
	"""Pick next cell using entropy-based selection."""
	if solver == null or solver.grid == null:
		return null
	return solver.grid.get_lowest_entropy_cell()


## ============================================================================
## Room Generation
## ============================================================================

func _generate_room_layout() -> void:
	"""Generate random room rectangles that form a connected structure."""
	var grid_size = _grid_ref.size
	
	# Leave 2-cell margin to ensure rooms don't touch grid edge
	# This guarantees outside_floor around all rooms
	var margin = 2
	var available_width = grid_size.x - (margin * 2)
	var available_depth = grid_size.z - (margin * 2)
	
	if available_width < min_room_size or available_depth < min_room_size:
		# Grid too small, make one room with proper margin
		var room_w = max(min_room_size, grid_size.x - (margin * 2))
		var room_d = max(min_room_size, grid_size.z - (margin * 2))
		_room_rects.append(Rect2i(margin, margin, room_w, room_d))
		return
	
	# Start with a seed room
	var seed_room = _generate_random_room(margin, margin, available_width, available_depth)
	_room_rects.append(seed_room)
	
	# Try to add more rooms connected to existing ones
	var attempts = 0
	while _room_rects.size() < max_rooms and attempts < 20:
		attempts += 1
		var new_room = _try_add_connected_room()
		if new_room.size.x > 0:
			_room_rects.append(new_room)


func _generate_random_room(min_x: int, min_z: int, max_w: int, max_d: int) -> Rect2i:
	"""Generate a random room rectangle within bounds."""
	var w = randi_range(min_room_size, min(max_w, min_room_size + 4))
	var d = randi_range(min_room_size, min(max_d, min_room_size + 4))
	var x = randi_range(min_x, max(min_x, min_x + max_w - w))
	var z = randi_range(min_z, max(min_z, min_z + max_d - d))
	return Rect2i(x, z, w, d)


func _try_add_connected_room() -> Rect2i:
	"""Try to add a room connected to an existing room."""
	if _room_rects.is_empty():
		return Rect2i()
	
	var grid_size = _grid_ref.size
	var margin = 2  # Same margin as _generate_room_layout
	var source_room = _room_rects[randi() % _room_rects.size()]
	
	# Pick a side to extend from (0=right, 1=left, 2=front, 3=back)
	var side = randi() % 4
	var new_room: Rect2i
	
	var room_w = randi_range(min_room_size, min_room_size + 3)
	var room_d = randi_range(min_room_size, min_room_size + 3)
	
	match side:
		0:  # Right
			var x = source_room.position.x + source_room.size.x
			var z = source_room.position.y + randi() % max(1, source_room.size.y - 1)
			new_room = Rect2i(x, z, room_w, room_d)
		1:  # Left
			var x = source_room.position.x - room_w
			var z = source_room.position.y + randi() % max(1, source_room.size.y - 1)
			new_room = Rect2i(x, z, room_w, room_d)
		2:  # Front (positive Z)
			var x = source_room.position.x + randi() % max(1, source_room.size.x - 1)
			var z = source_room.position.y + source_room.size.y
			new_room = Rect2i(x, z, room_w, room_d)
		3:  # Back (negative Z)
			var x = source_room.position.x + randi() % max(1, source_room.size.x - 1)
			var z = source_room.position.y - room_d
			new_room = Rect2i(x, z, room_w, room_d)
	
	# Check bounds - ensure room stays within margin
	if new_room.position.x < margin or new_room.position.y < margin:
		return Rect2i()
	if new_room.position.x + new_room.size.x > grid_size.x - margin:
		return Rect2i()
	if new_room.position.y + new_room.size.y > grid_size.z - margin:
		return Rect2i()
	
	# Check for significant overlap with existing rooms (some overlap is OK for connections)
	for existing in _room_rects:
		var overlap = existing.intersection(new_room)
		if overlap.get_area() > 2:  # Allow small overlaps for doorways
			return Rect2i()
	
	return new_room


## ============================================================================
## Zone Calculation
## ============================================================================

func _calculate_zones() -> void:
	"""Calculate the zone type for each cell based on room layout.
	
	Zone logic:
	- WALL/CORNER: Cells ON THE EDGE of rooms (the perimeter ring)
	- INSIDE: Cells FULLY INSIDE rooms (not on edge)
	- OUTSIDE: Cells not part of any room
	
	This ensures walls form connected rings around rooms.
	"""
	var grid_size = _grid_ref.size
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			for z in range(grid_size.z):
				var pos = Vector3i(x, y, z)
				var key = _pos_to_key(pos)
				
				if not _is_inside_any_room(x, z):
					# Not in any room = outside
					_zone_map[key] = Zone.OUTSIDE
				elif _is_on_room_edge(x, z):
					# On the edge of a room = wall or corner
					if _is_room_corner(x, z):
						_zone_map[key] = Zone.CORNER
					else:
						_zone_map[key] = Zone.WALL
				else:
					# Fully inside a room
					_zone_map[key] = Zone.INSIDE


func _is_on_room_edge(x: int, z: int) -> bool:
	"""Check if position is on the edge of any room it belongs to."""
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			# Check if on any edge of this room
			var on_left = (x == room.position.x)
			var on_right = (x == room.position.x + room.size.x - 1)
			var on_top = (z == room.position.y)
			var on_bottom = (z == room.position.y + room.size.y - 1)
			if on_left or on_right or on_top or on_bottom:
				return true
	return false


func _is_room_corner(x: int, z: int) -> bool:
	"""Check if position is at a corner of any room."""
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			var on_left = (x == room.position.x)
			var on_right = (x == room.position.x + room.size.x - 1)
			var on_top = (z == room.position.y)
			var on_bottom = (z == room.position.y + room.size.y - 1)
			# Corner = on two perpendicular edges
			if (on_left or on_right) and (on_top or on_bottom):
				return true
	return false


func _point_in_rect(x: int, z: int, rect: Rect2i) -> bool:
	"""Check if point is inside rectangle."""
	return (x >= rect.position.x and x < rect.position.x + rect.size.x and
			z >= rect.position.y and z < rect.position.y + rect.size.y)


func _is_inside_any_room(x: int, z: int) -> bool:
	"""Check if a grid position is inside any room."""
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			return true
	return false


## ============================================================================
## Zone Constraint Application
## ============================================================================

func _apply_zone_constraints() -> void:
	"""Remove invalid tile candidates from each cell based on its zone."""
	var grid_size = _grid_ref.size
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			for z in range(grid_size.z):
				var pos = Vector3i(x, y, z)
				var cell = _grid_ref.get_cell(pos)
				if cell == null or cell.is_collapsed():
					continue
				
				var key = _pos_to_key(pos)
				var zone = _zone_map.get(key, Zone.OUTSIDE)
				
				match zone:
					Zone.OUTSIDE:
						_restrict_to_outside_tiles(cell)
					Zone.INSIDE:
						_restrict_to_inside_tiles(cell)
					Zone.WALL:
						_restrict_to_wall_tiles(cell)
					Zone.CORNER:
						_restrict_to_corner_tiles(cell)


func _restrict_to_outside_tiles(cell) -> void:
	"""Keep only tiles suitable for outside (air, outside_floor)."""
	var filtered: Array[Dictionary] = []
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		# Outside tiles: NONE boundary role (air, outside floor, grass, etc.)
		# NOT EDGE/CORNER (walls) and NOT INFILL (interior floors)
		if tile.boundary_role == Tile.BoundaryRole.NONE:
			filtered.append(variant)
	
	if not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false


func _restrict_to_inside_tiles(cell) -> void:
	"""Keep only tiles suitable for inside (floor, interior elements)."""
	var filtered: Array[Dictionary] = []
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		# Inside tiles: INFILL (interior floor) or NONE with floor tag
		if tile.boundary_role == Tile.BoundaryRole.INFILL:
			filtered.append(variant)
		elif tile.boundary_role == Tile.BoundaryRole.NONE and tile.has_tag("floor"):
			# Also allow outside_floor inside if needed
			filtered.append(variant)
	
	if not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false


func _restrict_to_wall_tiles(cell) -> void:
	"""Keep only wall tiles (EDGE boundary role)."""
	var filtered: Array[Dictionary] = []
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		if tile.boundary_role == Tile.BoundaryRole.EDGE:
			filtered.append(variant)
	
	# Maybe add doors randomly
	if randf() < door_chance:
		for variant in cell.possible_tile_variants:
			var tile: Tile = variant.get("tile")
			if tile and tile.has_tag("door"):
				if variant not in filtered:
					filtered.append(variant)
	
	if not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false


func _restrict_to_corner_tiles(cell) -> void:
	"""Keep only corner tiles (CORNER boundary role)."""
	var filtered: Array[Dictionary] = []
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile == null:
			continue
		if tile.boundary_role == Tile.BoundaryRole.CORNER:
			filtered.append(variant)
	
	if not filtered.is_empty():
		cell.possible_tile_variants = filtered
		cell._entropy_valid = false


## ============================================================================
## Utility Functions
## ============================================================================

func _pos_to_key(pos: Vector3i) -> int:
	"""Convert position to integer key for dictionary storage."""
	if _grid_ref == null:
		return 0
	return pos.x + pos.y * _grid_ref.size.x + pos.z * _grid_ref.size.x * _grid_ref.size.y
