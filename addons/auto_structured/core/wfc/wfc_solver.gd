class_name WfcSolver extends RefCounted

const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

var grid: WfcGrid
var max_iterations: int = 10000

func _init(wfc_grid: WfcGrid) -> void:
	grid = wfc_grid

func solve() -> bool:
	var iterations = 0

	while not grid.is_fully_collapsed():
		if iterations >= max_iterations:
			push_error("WFC: Max iterations reached")
			return false

		if grid.has_contradiction():
			push_error("WFC: Contradiction detected")
			return false

		# Observe: Pick cell with lowest entropy and collapse it
		var cell = grid.get_lowest_entropy_cell()
		if not cell:
			break

		if not cell.collapse():
			push_error("WFC: Failed to collapse cell at ", cell.position)
			return false

		# Propagate: Update neighbors based on the collapsed cell
		if not propagate(cell):
			push_error("WFC: Propagation failed at ", cell.position)
			return false

		iterations += 1

	return true

func propagate(start_cell: WfcCell) -> bool:
	var propagation_queue: Array[WfcCell] = [start_cell]
	var visited: Dictionary = {}

	while not propagation_queue.is_empty():
		var current_cell = propagation_queue.pop_front()

		# Get all 6 cardinal directions
		var directions = WfcHelper.get_cardinal_directions()

		for direction in directions:
			var neighbor = grid.get_neighbor_in_direction(current_cell.position, direction)
			if not neighbor or neighbor.is_collapsed():
				continue

			# Calculate which tile+rotation variants are valid for this neighbor based on current cell
			var valid_variants = get_valid_variants_for_neighbor(current_cell, neighbor, direction)

			# Constrain the neighbor
			var changed = neighbor.constrain(valid_variants)

			if neighbor.has_contradiction():
				return false

			# If neighbor's possibilities changed, add it to queue for further propagation
			if changed and neighbor.position not in visited:
				propagation_queue.append(neighbor)
				visited[neighbor.position] = true

	return true

func get_valid_variants_for_neighbor(source_cell: WfcCell, neighbor_cell: WfcCell, direction: Vector3i) -> Array[Dictionary]:
	"""
	Get all valid tile+rotation variants for a neighbor cell based on source cell constraints.
	
	Args:
		source_cell: The cell that was just collapsed or updated
		neighbor_cell: The neighboring cell to constrain
		direction: Direction from source to neighbor (Vector3i)
	
	Returns:
		Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int)
	"""
	var valid_variants: Array[Dictionary] = []

	# For each possible variant in the neighbor
	for neighbor_variant in neighbor_cell.possible_tile_variants:
		var is_compatible = false
		var neighbor_tile = neighbor_variant["tile"]
		var neighbor_rotation = neighbor_variant["rotation_degrees"]

		# Check against all possible variants in the source cell
		for source_variant in source_cell.possible_tile_variants:
			var source_tile = source_variant["tile"]
			var source_rotation = source_variant["rotation_degrees"]

			if are_variants_compatible(source_tile, source_rotation, neighbor_tile, neighbor_rotation, direction):
				is_compatible = true
				break

		if is_compatible:
			valid_variants.append(neighbor_variant)

	return valid_variants

func are_variants_compatible(source_tile: Tile, source_rotation: int, neighbor_tile: Tile, neighbor_rotation: int, direction: Vector3i) -> bool:
	"""
	Check if two tile+rotation variants can be placed adjacent to each other.
	
	Args:
		source_tile: The source tile
		source_rotation: Rotation of source tile in degrees (0, 90, 180, 270)
		neighbor_tile: The neighboring tile
		neighbor_rotation: Rotation of neighbor tile in degrees
		direction: Direction from source to neighbor
	
	Returns:
		true if the variants are compatible, false otherwise
	"""
	# Rotate the direction vector by the source tile's rotation to get the local direction
	var source_rotation_basis = WfcHelper.rotation_y_to_basis(source_rotation)
	var local_direction = WfcHelper.rotate_direction(direction, source_rotation_basis)

	# Get sockets on source tile that face toward neighbor (in local space)
	var source_sockets = source_tile.get_sockets_in_direction(local_direction)
	
	if source_sockets.is_empty():
		return false

	# Rotate the opposite direction by the neighbor tile's rotation
	var neighbor_rotation_basis = WfcHelper.rotation_y_to_basis(neighbor_rotation)
	var neighbor_local_direction = WfcHelper.rotate_direction(-direction, neighbor_rotation_basis)

	# Get sockets on neighbor tile that face back toward source (in local space)
	var neighbor_sockets = neighbor_tile.get_sockets_in_direction(neighbor_local_direction)
	
	if neighbor_sockets.is_empty():
		return false

	# Check if any socket pair is compatible (unidirectional from source perspective)
	for source_socket in source_sockets:
		for neighbor_socket in neighbor_sockets:
			# "none" sockets mean no connection allowed - both sides must be "none"
			if source_socket.socket_id == "none" and neighbor_socket.socket_id == "none":
				return true
			
			# If one side is "none" but not the other, incompatible
			if source_socket.socket_id == "none" or neighbor_socket.socket_id == "none":
				continue
				
			if source_socket.is_compatible_with(neighbor_socket):
				return true

	return false

func reset() -> void:
	grid.reset()