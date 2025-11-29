@tool
class_name BuildingBlueprint extends "res://addons/auto_structured/core/blueprints/blueprint_base.gd"
## Blueprint for generating building structures.
##
## Generates rooms with walls, corners, interior floors, and optional roofs.
## Supports multiple connected rooms and multi-story buildings.
##
## Configuration options:
## - min_room_size: int (default 3) - Minimum room dimension
## - max_room_size: int (default 7) - Maximum room dimension  
## - max_rooms: int (default 4) - Maximum number of rooms
## - room_connection_chance: float (default 0.7) - Chance to connect adjacent rooms
## - margin: int (default 2) - Space between rooms and grid edge
## - floor_height: int (default 1) - Height of each floor in cells
## - num_floors: int (default 1) - Number of floors
## - add_roof: bool (default false) - Add roof zone on top
## - door_chance: float (default 0.15) - Chance for wall to be a door

## Room data structure
var _room_rects: Array[Rect2i] = []

## Wall facing directions: position_key -> Vector3i (direction wall faces)
var _wall_facing: Dictionary = {}

## Guaranteed door positions per room (set during room generation)
var _guaranteed_doors: Dictionary = {}  # room_index -> Array[Vector2i]

## Default configuration
var min_room_size: int = 3
var max_room_size: int = 7
var max_rooms: int = 4
var room_connection_chance: float = 0.7
var margin: int = 2
var floor_height: int = 1
var num_floors: int = 1
var add_roof: bool = false
var doors_per_room: int = 1  # Number of guaranteed doors per room (0 = none, -1 = one total)


func get_id() -> String:
	return "building"


func get_display_name() -> String:
	return "Building"


func get_description() -> String:
	return "Generates building structures with rooms, walls, and floors"


func _on_configure(config: Dictionary) -> void:
	min_room_size = config.get("min_room_size", min_room_size)
	max_room_size = config.get("max_room_size", max_room_size)
	max_rooms = config.get("max_rooms", max_rooms)
	room_connection_chance = config.get("room_connection_chance", room_connection_chance)
	margin = config.get("margin", margin)
	floor_height = config.get("floor_height", floor_height)
	num_floors = config.get("num_floors", num_floors)
	add_roof = config.get("add_roof", add_roof)
	doors_per_room = config.get("doors_per_room", doors_per_room)


func _generate_zones(grid_size: Vector3i) -> void:
	_room_rects.clear()
	_wall_facing.clear()
	_guaranteed_doors.clear()
	
	# Step 1: Generate room footprints (2D on XZ plane)
	_generate_room_layout(grid_size)
	
	# Step 2: Pick guaranteed door positions for each room
	_pick_guaranteed_doors(grid_size)
	
	# Step 3: Classify each cell based on room layout and height
	_classify_all_cells(grid_size)
	
	# Step 4: Calculate wall facing directions
	_calculate_wall_facing(grid_size)
	
	_log("Generated %d rooms" % _room_rects.size())
	for i in range(_room_rects.size()):
		var room = _room_rects[i]
		_log("  Room %d: pos(%d,%d) size(%d,%d)" % [i, room.position.x, room.position.y, room.size.x, room.size.y])
	_log("  Total guaranteed doors: %d" % _count_guaranteed_doors())


func _get_valid_boundary_roles_for_zone(zone: Zone) -> Array[Tile.BoundaryRole]:
	match zone:
		Zone.EXTERIOR:
			return [Tile.BoundaryRole.NONE]
		Zone.INTERIOR:
			return [Tile.BoundaryRole.NONE, Tile.BoundaryRole.INFILL]
		Zone.WALL:
			return [Tile.BoundaryRole.EDGE]
		Zone.CORNER:
			return [Tile.BoundaryRole.CORNER]
		Zone.ROOF:
			return [Tile.BoundaryRole.NONE]  # Could add ROOF role later
		Zone.DOOR:
			return [Tile.BoundaryRole.PASSAGE]  # Only PASSAGE tiles for doors
		Zone.FLOOR:
			return [Tile.BoundaryRole.NONE, Tile.BoundaryRole.INFILL]
		_:
			return [Tile.BoundaryRole.NONE]


func _is_tile_valid_for_zone(tile: Tile, zone: Zone, _position: Vector3i) -> bool:
	match zone:
		Zone.EXTERIOR:
			# Only exterior/outside tiles
			if tile.has_tag("interior"):
				return false
			# Prefer tiles tagged as exterior, but allow generic floor tiles
			return true
		Zone.INTERIOR:
			# Only interior tiles
			if tile.has_tag("exterior"):
				return false
			return true
		Zone.DOOR:
			# Must be a PASSAGE tile (door, gate, archway, etc.)
			return tile.boundary_role == Tile.BoundaryRole.PASSAGE
		Zone.WALL:
			# Wall tiles but not passages
			if tile.boundary_role == Tile.BoundaryRole.PASSAGE:
				return false
			return true
		Zone.CORNER:
			# Corner tiles
			return tile.has_tag("corner") or tile.boundary_role == Tile.BoundaryRole.CORNER
		Zone.ROOF:
			# Roof tiles
			return tile.has_tag("roof")
		_:
			return true


func get_wall_facing_direction(position: Vector3i) -> Vector3i:
	var key = _pos_to_key(position)
	return _wall_facing.get(key, Vector3i.ZERO)


func get_rooms() -> Array[Rect2i]:
	## Get the generated room rectangles (for debugging/visualization)
	return _room_rects.duplicate()


## ============================================================================
## Room Generation
## ============================================================================

func _generate_room_layout(grid_size: Vector3i) -> void:
	## Generate random room rectangles that form a connected structure.
	var available_width = grid_size.x - (margin * 2)
	var available_depth = grid_size.z - (margin * 2)
	
	if available_width < min_room_size or available_depth < min_room_size:
		# Grid too small, make one room with reduced margin
		var room_w = max(min_room_size, grid_size.x - 2)
		var room_d = max(min_room_size, grid_size.z - 2)
		var room_x = max(1, (grid_size.x - room_w) / 2)
		var room_z = max(1, (grid_size.z - room_d) / 2)
		_room_rects.append(Rect2i(room_x, room_z, room_w, room_d))
		return
	
	# Start with a seed room
	var seed_room = _generate_random_room(margin, margin, available_width, available_depth)
	_room_rects.append(seed_room)
	
	# Try to add more connected rooms
	var attempts = 0
	while _room_rects.size() < max_rooms and attempts < 20:
		attempts += 1
		var new_room = _try_add_connected_room(grid_size)
		if new_room.size.x > 0:
			_room_rects.append(new_room)


func _generate_random_room(min_x: int, min_z: int, max_w: int, max_d: int) -> Rect2i:
	var w = randi_range(min_room_size, min(max_w, max_room_size))
	var d = randi_range(min_room_size, min(max_d, max_room_size))
	var x = randi_range(min_x, max(min_x, min_x + max_w - w))
	var z = randi_range(min_z, max(min_z, min_z + max_d - d))
	return Rect2i(x, z, w, d)


func _try_add_connected_room(grid_size: Vector3i) -> Rect2i:
	if _room_rects.is_empty():
		return Rect2i()
	
	var source_room = _room_rects[randi() % _room_rects.size()]
	
	# Pick a side to extend from (0=right, 1=left, 2=front, 3=back)
	var side = randi() % 4
	var room_w = randi_range(min_room_size, max_room_size)
	var room_d = randi_range(min_room_size, max_room_size)
	var new_room: Rect2i
	
	match side:
		0:  # Right (+X)
			var x = source_room.position.x + source_room.size.x
			var z = source_room.position.y + randi() % max(1, source_room.size.y - 1)
			new_room = Rect2i(x, z, room_w, room_d)
		1:  # Left (-X)
			var x = source_room.position.x - room_w
			var z = source_room.position.y + randi() % max(1, source_room.size.y - 1)
			new_room = Rect2i(x, z, room_w, room_d)
		2:  # Front (+Z)
			var x = source_room.position.x + randi() % max(1, source_room.size.x - 1)
			var z = source_room.position.y + source_room.size.y
			new_room = Rect2i(x, z, room_w, room_d)
		3:  # Back (-Z)
			var x = source_room.position.x + randi() % max(1, source_room.size.x - 1)
			var z = source_room.position.y - room_d
			new_room = Rect2i(x, z, room_w, room_d)
	
	# Check bounds
	if new_room.position.x < margin or new_room.position.y < margin:
		return Rect2i()
	if new_room.position.x + new_room.size.x > grid_size.x - margin:
		return Rect2i()
	if new_room.position.y + new_room.size.y > grid_size.z - margin:
		return Rect2i()
	
	# Check for excessive overlap
	for existing in _room_rects:
		var overlap = existing.intersection(new_room)
		if overlap.get_area() > 2:
			return Rect2i()
	
	return new_room


## ============================================================================
## Cell Classification
## ============================================================================

func _classify_all_cells(grid_size: Vector3i) -> void:
	## Classify every cell in the grid based on room layout.
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			for z in range(grid_size.z):
				var pos = Vector3i(x, y, z)
				var zone = _classify_cell(pos, grid_size)
				set_zone(pos, zone)


func _classify_cell(pos: Vector3i, grid_size: Vector3i) -> Zone:
	## Determine the zone for a single cell.
	var x = pos.x
	var y = pos.y
	var z = pos.z
	
	# Check which floor this cell is on
	var floor_index = y / floor_height
	var is_ground_floor = (floor_index == 0)
	var is_top_floor = (floor_index >= num_floors - 1)
	var is_above_building = (y >= num_floors * floor_height)
	
	# If above the building height, check for roof
	if is_above_building:
		if add_roof and _is_inside_any_room(x, z):
			return Zone.ROOF
		return Zone.EMPTY
	
	# Not in any room = exterior
	if not _is_inside_any_room(x, z):
		return Zone.EXTERIOR
	
	# On the edge of a room
	if _is_on_room_edge(x, z):
		if _is_room_corner(x, z):
			return Zone.CORNER
		else:
			# Check if this is a guaranteed door position
			# Only guaranteed doors become DOOR zones - no random doors
			if is_ground_floor and _is_guaranteed_door(x, z):
				return Zone.DOOR
			return Zone.WALL
	
	# Inside a room (not on edge)
	if is_ground_floor:
		return Zone.FLOOR  # Ground floor interior
	else:
		return Zone.INTERIOR  # Upper floor interior


func _is_inside_any_room(x: int, z: int) -> bool:
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			return true
	return false


func _is_on_room_edge(x: int, z: int) -> bool:
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			var on_left = (x == room.position.x)
			var on_right = (x == room.position.x + room.size.x - 1)
			var on_top = (z == room.position.y)
			var on_bottom = (z == room.position.y + room.size.y - 1)
			if on_left or on_right or on_top or on_bottom:
				return true
	return false


func _is_room_corner(x: int, z: int) -> bool:
	for room in _room_rects:
		if _point_in_rect(x, z, room):
			var on_left = (x == room.position.x)
			var on_right = (x == room.position.x + room.size.x - 1)
			var on_top = (z == room.position.y)
			var on_bottom = (z == room.position.y + room.size.y - 1)
			if (on_left or on_right) and (on_top or on_bottom):
				return true
	return false


func _point_in_rect(x: int, z: int, rect: Rect2i) -> bool:
	return (x >= rect.position.x and x < rect.position.x + rect.size.x and
			z >= rect.position.y and z < rect.position.y + rect.size.y)


## ============================================================================
## Wall Facing Calculation
## ============================================================================

func _calculate_wall_facing(grid_size: Vector3i) -> void:
	## Calculate which direction each wall should face (toward exterior).
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			for z in range(grid_size.z):
				var pos = Vector3i(x, y, z)
				var zone = get_zone(pos)
				
				if zone != Zone.WALL and zone != Zone.DOOR:
					continue
				
				# Find direction toward exterior
				var facing = _find_exterior_direction(pos)
				if facing != Vector3i.ZERO:
					var key = _pos_to_key(pos)
					_wall_facing[key] = facing


func _find_exterior_direction(pos: Vector3i) -> Vector3i:
	## Find which cardinal direction points toward exterior from this wall cell.
	var directions = [
		Vector3i(1, 0, 0),   # +X
		Vector3i(-1, 0, 0),  # -X
		Vector3i(0, 0, 1),   # +Z
		Vector3i(0, 0, -1),  # -Z
	]
	
	for dir in directions:
		var neighbor_pos = pos + dir
		if not is_valid_position(neighbor_pos):
			# Edge of grid = exterior
			return dir
		
		var neighbor_zone = get_zone(neighbor_pos)
		if neighbor_zone == Zone.EXTERIOR or neighbor_zone == Zone.EMPTY:
			return dir
	
	return Vector3i.ZERO  # No exterior neighbor found (internal wall)


## ============================================================================
## Guaranteed Door Placement
## ============================================================================

func _pick_guaranteed_doors(grid_size: Vector3i) -> void:
	## Ensure each room has the configured number of doors on exterior-facing walls.
	## doors_per_room: 0 = no doors, 1+ = doors per room, -1 = exactly one door total
	
	if doors_per_room == 0:
		return
	
	# Collect all exterior wall positions across all rooms
	var all_exterior_walls: Array[Dictionary] = []  # [{room_idx, pos}]
	
	for room_idx in range(_room_rects.size()):
		var room = _room_rects[room_idx]
		var exterior_walls = _get_exterior_wall_positions(room, grid_size)
		
		for wall_pos in exterior_walls:
			all_exterior_walls.append({"room_idx": room_idx, "pos": wall_pos})
	
	if all_exterior_walls.is_empty():
		_log("  Warning: No exterior walls found for door placement")
		return
	
	# Mode: exactly one door total (for tiles with Global Max 1)
	if doors_per_room == -1:
		var chosen = all_exterior_walls[randi() % all_exterior_walls.size()]
		var room_idx = chosen["room_idx"]
		var door_pos = chosen["pos"]
		
		if not _guaranteed_doors.has(room_idx):
			_guaranteed_doors[room_idx] = []
		_guaranteed_doors[room_idx].append(door_pos)
		
		_log("  Single door at room %d pos (%d, %d)" % [room_idx, door_pos.x, door_pos.y])
		return
	
	# Mode: N doors per room
	for room_idx in range(_room_rects.size()):
		var room = _room_rects[room_idx]
		var exterior_walls = _get_exterior_wall_positions(room, grid_size)
		
		if exterior_walls.is_empty():
			_log("  Warning: Room %d has no exterior walls for door placement" % room_idx)
			continue
		
		# Shuffle and pick up to doors_per_room
		exterior_walls.shuffle()
		var num_doors = mini(doors_per_room, exterior_walls.size())
		
		if not _guaranteed_doors.has(room_idx):
			_guaranteed_doors[room_idx] = []
		
		for i in range(num_doors):
			var door_pos = exterior_walls[i]
			_guaranteed_doors[room_idx].append(door_pos)
			_log("  Room %d door at (%d, %d)" % [room_idx, door_pos.x, door_pos.y])


func _get_exterior_wall_positions(room: Rect2i, grid_size: Vector3i) -> Array[Vector2i]:
	## Get all wall positions on this room that face the exterior (not another room).
	var result: Array[Vector2i] = []
	
	# Check each edge of the room (excluding corners)
	# Left edge (-X)
	for z in range(room.position.y + 1, room.position.y + room.size.y - 1):
		var x = room.position.x
		if _is_exterior_at(x - 1, z):
			result.append(Vector2i(x, z))
	
	# Right edge (+X)
	for z in range(room.position.y + 1, room.position.y + room.size.y - 1):
		var x = room.position.x + room.size.x - 1
		if _is_exterior_at(x + 1, z):
			result.append(Vector2i(x, z))
	
	# Top edge (-Z)
	for x in range(room.position.x + 1, room.position.x + room.size.x - 1):
		var z = room.position.y
		if _is_exterior_at(x, z - 1):
			result.append(Vector2i(x, z))
	
	# Bottom edge (+Z)
	for x in range(room.position.x + 1, room.position.x + room.size.x - 1):
		var z = room.position.y + room.size.y - 1
		if _is_exterior_at(x, z + 1):
			result.append(Vector2i(x, z))
	
	return result


func _is_exterior_at(x: int, z: int) -> bool:
	## Check if the given position is exterior (outside all rooms or outside grid).
	if x < 0 or z < 0 or x >= _grid_size.x or z >= _grid_size.z:
		return true  # Outside grid = exterior
	return not _is_inside_any_room(x, z)


func _is_guaranteed_door(x: int, z: int) -> bool:
	## Check if this position is a guaranteed door for any room.
	for room_idx in _guaranteed_doors:
		var doors = _guaranteed_doors[room_idx]
		for door_pos in doors:
			if door_pos.x == x and door_pos.y == z:
				return true
	return false


func _count_guaranteed_doors() -> int:
	var count = 0
	for room_idx in _guaranteed_doors:
		count += _guaranteed_doors[room_idx].size()
	return count
