@tool
class_name WfcHelper

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")


## Calculate the rotation needed to align a compatible tile's socket with a main tile's socket.
## Only rotates around the Y axis (up) to keep tiles upright.
##
## Args:
##   connecting_socket: The socket on the compatible tile that will connect
##   main_socket_direction: The direction the main tile's socket is facing
##
## Returns:
##   A Basis representing the rotation transform
static func calculate_socket_alignment_rotation(connecting_socket: Socket, main_socket_direction: Vector3i) -> Basis:
	# The connecting socket needs to face -main_socket_direction in world space
	var required_world_direction = -main_socket_direction
	
	# Get the socket's local direction (where it points on the tile before rotation)
	var socket_local_dir = Vector3(connecting_socket.direction)
	var required_world_dir = Vector3(required_world_direction)
	
	print("[WfcHelper] Aligning socket:")
	print("  Connecting socket direction (local): ", connecting_socket.direction)
	print("  Main socket direction: ", main_socket_direction)
	print("  Required world direction: ", required_world_direction)
	
	# If sockets already aligned, no rotation needed
	if socket_local_dir.is_equal_approx(required_world_dir):
		print("  Already aligned - no rotation")
		return Basis.IDENTITY
	
	# For vertical sockets (up/down), no Y-axis rotation will help
	# They should already be aligned vertically
	if abs(socket_local_dir.y) > 0.9 or abs(required_world_dir.y) > 0.9:
		print("  Vertical socket - no Y rotation")
		return Basis.IDENTITY
	
	# Project directions onto horizontal plane (XZ)
	var local_xz = Vector2(socket_local_dir.x, socket_local_dir.z)
	var required_xz = Vector2(required_world_dir.x, required_world_dir.z)
	
	# Calculate angle between projected directions
	var angle = local_xz.angle_to(required_xz)
	
	print("  Local XZ: ", local_xz, " Required XZ: ", required_xz)
	print("  Rotation angle: ", rad_to_deg(angle), " degrees")
	
	# Rotate around Y axis (up)
	return Basis(Vector3.UP, angle)


## Calculate the position offset for placing a compatible tile adjacent to a main tile.
## Takes into account both tiles' sizes to position them edge-to-edge.
##
## Args:
##   main_tile_size: Size of the main tile (Vector3)
##   compatible_tile_size: Size of the compatible tile (Vector3)
##   direction: Direction from main tile to compatible tile (Vector3i)
##   cell_size: World-space size of a single grid cell (Vector3)
##
## Returns:
##   The position offset as Vector3
static func calculate_adjacent_tile_position(main_tile_size: Vector3, compatible_tile_size: Vector3, direction: Vector3i, cell_size: Vector3 = Vector3.ONE) -> Vector3:
	"""Calculate world-space offset for placing a neighbor tile edge-to-edge."""
	var main_extent = Vector3(
		(main_tile_size.x * cell_size.x) * 0.5,
		(main_tile_size.y * cell_size.y) * 0.5,
		(main_tile_size.z * cell_size.z) * 0.5
	)
	var neighbor_extent = Vector3(
		(compatible_tile_size.x * cell_size.x) * 0.5,
		(compatible_tile_size.y * cell_size.y) * 0.5,
		(compatible_tile_size.z * cell_size.z) * 0.5
	)

	var offset = Vector3.ZERO
	if direction.x != 0:
		offset.x = direction.x * (main_extent.x + neighbor_extent.x)
	if direction.y != 0:
		offset.y = direction.y * (main_extent.y + neighbor_extent.y)
	if direction.z != 0:
		offset.z = direction.z * (main_extent.z + neighbor_extent.z)

	return offset


static func _normalize_rotation(rotation_degrees: float) -> int:
	var normalized := int(round(rotation_degrees)) % 360
	if normalized < 0:
		normalized += 360
	return normalized


static func get_rotated_bounds_in_cells(tile_size: Vector3i, rotation_degrees: float) -> Dictionary:
	"""Compute the axis-aligned bounds of a tile (in grid cells) after Y-rotation."""
	var normalized := _normalize_rotation(rotation_degrees)
	var rotation_basis := rotation_y_to_basis(normalized)
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	var x_values := [0.0, float(tile_size.x)]
	var y_values := [0.0, float(tile_size.y)]
	var z_values := [0.0, float(tile_size.z)]

	for x in x_values:
		for y in y_values:
			for z in z_values:
				var rotated := rotation_basis * Vector3(x, y, z)
				min_corner.x = min(min_corner.x, rotated.x)
				min_corner.y = min(min_corner.y, rotated.y)
				min_corner.z = min(min_corner.z, rotated.z)
				max_corner.x = max(max_corner.x, rotated.x)
				max_corner.y = max(max_corner.y, rotated.y)
				max_corner.z = max(max_corner.z, rotated.z)

	return {
		"min": min_corner,
		"max": max_corner
	}


static func get_rotated_size_in_cells(tile_size: Vector3i, rotation_degrees: float) -> Vector3:
	"""Get the size of a tile in grid cells after applying a Y-axis rotation."""
	var bounds := get_rotated_bounds_in_cells(tile_size, rotation_degrees)
	var min_corner: Vector3 = bounds["min"]
	var max_corner: Vector3 = bounds["max"]
	var size: Vector3 = max_corner - min_corner
	return Vector3(abs(size.x), abs(size.y), abs(size.z))


static func get_rotation_offset_in_cells(tile_size: Vector3i, rotation_degrees: float) -> Vector3:
	"""Get the translation (in cells) required to keep the rotated tile in positive grid space."""
	var bounds := get_rotated_bounds_in_cells(tile_size, rotation_degrees)
	var min_corner: Vector3 = bounds["min"]
	return Vector3(-min_corner.x, -min_corner.y, -min_corner.z)


static func get_rotated_size_world(tile_size: Vector3i, rotation_degrees: float, cell_size: Vector3 = Vector3.ONE) -> Vector3:
	var rotated_size := get_rotated_size_in_cells(tile_size, rotation_degrees)
	return Vector3(
		rotated_size.x * cell_size.x,
		rotated_size.y * cell_size.y,
		rotated_size.z * cell_size.z
	)


static func get_rotation_offset_world(tile_size: Vector3i, rotation_degrees: float, cell_size: Vector3 = Vector3.ONE) -> Vector3:
	var offset_cells := get_rotation_offset_in_cells(tile_size, rotation_degrees)
	return Vector3(
		offset_cells.x * cell_size.x,
		offset_cells.y * cell_size.y,
		offset_cells.z * cell_size.z
	)


## Get the opposite direction for socket matching.
## Used to find which socket on a neighboring tile should connect.
##
## Args:
##   direction: The original direction (Vector3i)
##
## Returns:
##   The opposite direction (Vector3i)
static func get_opposite_direction(direction: Vector3i) -> Vector3i:
	return -direction


## Check if two sockets can connect considering their compatibility and requirements.
##
## Args:
##   socket1: First socket
##   socket2: Second socket
##   tile1: Tile that socket1 belongs to (for requirement evaluation)
##   tile2: Tile that socket2 belongs to (for requirement evaluation)
##
## Returns:
##   true if sockets can connect, false otherwise
static func can_sockets_connect(socket1: Socket, socket2: Socket, tile1: Tile, tile2: Tile) -> bool:
	# Check bidirectional compatibility
	if not socket1.is_compatible_with(socket2) or not socket2.is_compatible_with(socket1):
		return false
	
	# TODO: Check socket requirements
	# socket1.requirements should be satisfied by tile2
	# socket2.requirements should be satisfied by tile1
	
	return true


## Check if a socket can be rotated around the Y-axis to face a required direction.
## Only considers horizontal sockets (not vertical up/down).
## Also checks if the required rotation meets the socket's minimum_rotation_degrees requirement.
##
## Args:
##   socket: The socket to check (needs direction and minimum_rotation_degrees)
##   required_direction: The direction it needs to face after rotation (Vector3)
##
## Returns:
##   true if the socket can be rotated to align and meets rotation requirements, false otherwise
static func can_socket_align_with_rotation(socket: Socket, required_direction: Vector3) -> bool:
	var socket_dir = Vector3(socket.direction)
	
	# For vertical sockets (up/down), they can only align if they're already aligned
	# because Y-axis rotation doesn't change vertical direction
	if abs(socket_dir.y) > 0.9:
		return socket_dir.is_equal_approx(required_direction)
	
	if abs(required_direction.y) > 0.9:
		return false  # Can't rotate horizontal socket to vertical
	
	# For horizontal sockets, check if they have the same length when projected to XZ plane
	var socket_xz = Vector2(socket_dir.x, socket_dir.z)
	var required_xz = Vector2(required_direction.x, required_direction.z)
	
	# Both should be horizontal (length ≈ 1.0 on XZ plane)
	var socket_horizontal = abs(socket_xz.length() - 1.0) < 0.1
	var required_horizontal = abs(required_xz.length() - 1.0) < 0.1
	
	return socket_horizontal and required_horizontal


## Find all tiles that have a compatible socket in any direction (rotation-aware).
## This function checks if a socket can be rotated (around Y-axis) to align with the source socket.
## Sockets should face each other: Socket A -> <- Socket B
##
## Args:
##   source_socket: The socket to find compatible tiles for
##   all_tiles: Array of all available tiles
##   source_tile: The tile that source_socket belongs to (to skip same socket)
##
## Returns:
##   Array of dictionaries with keys: "tile" (Tile), "socket" (Socket), "rotation_degrees" (int)
static func find_compatible_tiles(source_socket: Socket, all_tiles: Array[Tile], source_tile: Tile = null) -> Array[Dictionary]:
	var compatible_results: Array[Dictionary] = []
	
	# Skip "none" sockets
	if source_socket.socket_id == "none":
		return compatible_results
	
	# The connecting socket needs to face toward the source socket (opposite of source direction)
	var source_direction = Vector3(source_socket.direction)
	var required_direction = -source_direction
	
	# Check all tiles
	for tile in all_tiles:
		var matching_sockets = []
		
		# Check all sockets on this tile
		for tile_socket in tile.sockets:
			# Skip "none" sockets
			if tile_socket.socket_id == "none":
				continue
			
			# Skip the exact same socket we're checking from
			if tile == source_tile and tile_socket == source_socket:
				continue
			
			# Check if sockets are compatible by ID (bidirectional check)
			var is_compatible = source_socket.is_compatible_with(tile_socket) and tile_socket.is_compatible_with(source_socket)
			if not is_compatible:
				continue
			
			# Try all 4 cardinal rotations (0°, 90°, 180°, 270°) to see which ones work
			var cardinal_rotations = [0, 90, 180, 270]
			for rotation_deg in cardinal_rotations:
				# Apply rotation to socket direction
				var rotation_basis = Basis(Vector3.UP, deg_to_rad(rotation_deg))
				var rotated_direction = rotation_basis * Vector3(tile_socket.direction)
				
				# Check if rotated socket faces the required direction
				if not rotated_direction.is_equal_approx(required_direction):
					continue
				
				# This rotation makes the socket face the right way
				# Check socket requirements with rotation context
				var context = {
					"rotation_degrees": rotation_deg,
					"tags": tile.tags if tile else []
				}
				
				var requirements_met = true
				for requirement in tile_socket.requirements:
					if not requirement.evaluate(Vector3i.ZERO, context):
						requirements_met = false
						break
				
				if requirements_met:
					# Add this rotation variant with the rotation angle stored
					matching_sockets.append({
						"socket": tile_socket,
						"rotation_degrees": rotation_deg
					})
					break  # Only add each socket once (first valid rotation)
		
		# Add all matching sockets from this tile
		if matching_sockets.size() > 0:
			for matching_data in matching_sockets:
				var socket_obj = matching_data["socket"]
				var rotation = matching_data["rotation_degrees"]
				compatible_results.append({
					"tile": tile,
					"socket": socket_obj,
					"rotation_degrees": rotation
				})
	
	return compatible_results


## Convert a rotation in degrees (around Y axis) to a Basis.
##
## Args:
##   degrees: Rotation angle in degrees
##
## Returns:
##   Basis representing the rotation
static func rotation_y_to_basis(degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(degrees))


## Get all 4 possible Y-axis rotations (0°, 90°, 180°, 270°).
## Useful for generating tile variants.
##
## Returns:
##   Array of Basis representing the 4 rotations
static func get_cardinal_rotations() -> Array[Basis]:
	return [
		Basis.IDENTITY,                    # 0°
		rotation_y_to_basis(90.0),         # 90°
		rotation_y_to_basis(180.0),        # 180°
		rotation_y_to_basis(270.0)         # 270°
	]


## Calculate grid position from world position.
##
## Args:
##   world_position: Position in world space
##   grid_cell_size: Size of each grid cell (default Vector3.ONE)
##
## Returns:
##   Grid position as Vector3i
static func world_to_grid(world_position: Vector3, grid_cell_size: Vector3 = Vector3.ONE) -> Vector3i:
	return Vector3i(
		int(floor(world_position.x / grid_cell_size.x)),
		int(floor(world_position.y / grid_cell_size.y)),
		int(floor(world_position.z / grid_cell_size.z))
	)


## Calculate world position from grid position.
##
## Args:
##   grid_position: Position in grid space
##   grid_cell_size: Size of each grid cell (default Vector3.ONE)
##
## Returns:
##   World position as Vector3
##
## NOTE: This positions tiles at the grid origin without centering offsets.
## Tiles are expected to be modeled with their local origin at the bottom-left-back corner.
## This ensures proper stacking on the Y-axis (no gaps between floors).
static func grid_to_world(grid_position: Vector3i, grid_cell_size: Vector3 = Vector3.ONE) -> Vector3:
	# Position tiles directly at grid coordinates without centering offset
	# This prevents gaps when stacking tiles vertically
	return Vector3(
		grid_position.x * grid_cell_size.x,
		grid_position.y * grid_cell_size.y,
		grid_position.z * grid_cell_size.z
	)


## Get all 6 cardinal directions.
##
## Returns:
##   Array of Vector3i representing the 6 directions
static func get_cardinal_directions() -> Array[Vector3i]:
	return [
		Vector3i.RIGHT,   # (1, 0, 0)  - index 0
		Vector3i.LEFT,    # (-1, 0, 0) - index 1
		Vector3i.UP,      # (0, 1, 0)  - index 2
		Vector3i.DOWN,    # (0, -1, 0) - index 3
		Vector3i.BACK,    # (0, 0, 1)  - index 4
		Vector3i.FORWARD  # (0, 0, -1) - index 5
	]


## Get the index (0-5) for a cardinal direction.
## Used for fast array lookups.
##
## Returns:
##   Integer index 0-5, or -1 if not a cardinal direction
static func get_direction_index(direction: Vector3i) -> int:
	if direction == Vector3i.RIGHT:
		return 0
	elif direction == Vector3i.LEFT:
		return 1
	elif direction == Vector3i.UP:
		return 2
	elif direction == Vector3i.DOWN:
		return 3
	elif direction == Vector3i.BACK:
		return 4
	elif direction == Vector3i.FORWARD:
		return 5
	return -1


## Get a human-readable name for a direction.
##
## Args:
##   direction: The direction vector
##
## Returns:
##   String name like "Right (+X)" or "Up (+Y)"
static func get_direction_name(direction: Vector3i) -> String:
	var direction_names = {
		Vector3i(1, 0, 0): "Right (+X)",
		Vector3i(-1, 0, 0): "Left (-X)",
		Vector3i(0, 1, 0): "Up (+Y)",
		Vector3i(0, -1, 0): "Down (-Y)",
		Vector3i(0, 0, 1): "Back (+Z)",
		Vector3i(0, 0, -1): "Forward (-Z)"
	}
	return direction_names.get(direction, "Unknown")


## Rotate a direction vector by a Y-axis rotation.
##
## Args:
##   direction: The direction to rotate
##   rotation: The rotation Basis
##
## Returns:
##   Rotated direction as Vector3i
static func rotate_direction(direction: Vector3i, rotation: Basis) -> Vector3i:
	var rotated = rotation * Vector3(direction)
	return Vector3i(
		int(round(rotated.x)),
		int(round(rotated.y)),
		int(round(rotated.z))
	)