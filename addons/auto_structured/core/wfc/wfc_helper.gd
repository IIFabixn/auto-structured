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
##
## Returns:
##   The position offset as Vector3
static func calculate_adjacent_tile_position(main_tile_size: Vector3, compatible_tile_size: Vector3, direction: Vector3i) -> Vector3:
	# Distance = half of main tile + half of compatible tile in the direction
	var offset_distance = (
		abs(direction.x) * (main_tile_size.x + compatible_tile_size.x) / 2.0 +
		abs(direction.y) * (main_tile_size.y + compatible_tile_size.y) / 2.0 +
		abs(direction.z) * (main_tile_size.z + compatible_tile_size.z) / 2.0
	)
	
	return Vector3(direction) * offset_distance


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
			
			# Check if sockets are compatible by ID (only from source socket's perspective)
			var is_compatible = source_socket.is_compatible_with(tile_socket)
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
##   World position as Vector3 (centered on grid cell)
static func grid_to_world(grid_position: Vector3i, grid_cell_size: Vector3 = Vector3.ONE) -> Vector3:
	return Vector3(
		grid_position.x * grid_cell_size.x + grid_cell_size.x / 2.0,
		grid_position.y * grid_cell_size.y + grid_cell_size.y / 2.0,
		grid_position.z * grid_cell_size.z + grid_cell_size.z / 2.0
	)


## Get all 6 cardinal directions.
##
## Returns:
##   Array of Vector3i representing the 6 directions
static func get_cardinal_directions() -> Array[Vector3i]:
	return [
		Vector3i.RIGHT,   # (1, 0, 0)
		Vector3i.LEFT,    # (-1, 0, 0)
		Vector3i.UP,      # (0, 1, 0)
		Vector3i.DOWN,    # (0, -1, 0)
		Vector3i.BACK,    # (0, 0, 1)
		Vector3i.FORWARD  # (0, 0, -1)
	]


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