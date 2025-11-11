class_name WfcSolver extends RefCounted

const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
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

		# Get all neighbors in 6 directions
		var neighbors = grid.get_neighbors(current_cell.position)

		for neighbor in neighbors:
			if neighbor.is_collapsed():
				continue

			# Calculate which tiles are valid for this neighbor based on current cell
			var valid_tiles = get_valid_tiles_for_neighbor(current_cell, neighbor)

			# Constrain the neighbor
			var changed = neighbor.constrain(valid_tiles)

			if neighbor.has_contradiction():
				return false

			# If neighbor's possibilities changed, add it to queue for further propagation
			if changed and neighbor.position not in visited:
				propagation_queue.append(neighbor)
				visited[neighbor.position] = true

	return true

func get_valid_tiles_for_neighbor(source_cell: WfcCell, neighbor_cell: WfcCell) -> Array[Tile]:
	var valid_tiles: Array[Tile] = []

	# Calculate direction from source to neighbor
	var direction = neighbor_cell.position - source_cell.position

	# For each possible tile in the neighbor
	for neighbor_tile in neighbor_cell.possible_tiles:
		var is_compatible = false

		# Check against all possible tiles in the source cell
		for source_tile in source_cell.possible_tiles:
			if are_tiles_compatible(source_tile, neighbor_tile, direction):
				is_compatible = true
				break

		if is_compatible:
			valid_tiles.append(neighbor_tile)

	return valid_tiles

func are_tiles_compatible(tile1: Tile, tile2: Tile, direction: Vector3i) -> bool:
	# Get sockets on tile1 that face toward tile2
	var tile1_sockets = tile1.get_sockets_in_direction(direction)

	# Get sockets on tile2 that face back toward tile1 (opposite direction)
	var tile2_sockets = tile2.get_sockets_in_direction(-direction)

	# Check if any socket pair is compatible
	for socket1 in tile1_sockets:
		for socket2 in tile2_sockets:
			# Bidirectional compatibility check
			if socket1.is_compatible_with(socket2) and socket2.is_compatible_with(socket1):
				return true

	return false

func reset() -> void:
	grid.reset()