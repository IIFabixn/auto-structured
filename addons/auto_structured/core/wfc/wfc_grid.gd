class_name WfcGrid extends RefCounted

const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

## 3D grid of WFC cells for procedural generation.
var cells: Dictionary = {}
var size: Vector3i
var all_tiles: Array[Tile] = []
var all_tile_variants: Array[Dictionary] = []  # All possible tile+rotation combinations

static func from_library(grid_size: Vector3i, library: ModuleLibrary) -> WfcGrid:
	return WfcGrid.new(grid_size, library.tiles)

func _init(grid_size: Vector3i, tiles: Array[Tile]) -> void:
	size = grid_size
	all_tiles = tiles
	
	# Generate all possible tile+rotation combinations
	all_tile_variants = generate_all_variants(tiles)
	
	# Initialize cells with all possible variants
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var pos = Vector3i(x, y, z)
				cells[pos] = WfcCell.new(pos, all_tile_variants)

func generate_all_variants(tiles: Array[Tile]) -> Array[Dictionary]:
	"""Generate all possible tile+rotation combinations."""
	var variants: Array[Dictionary] = []
	var rotations = [0, 90, 180, 270]
	
	for tile in tiles:
		for rotation in rotations:
			variants.append({
				"tile": tile,
				"rotation_degrees": rotation
			})
	
	return variants


func get_cell(pos: Vector3i) -> WfcCell:
	return cells.get(pos, null)


func get_neighbors(pos: Vector3i) -> Array[WfcCell]:
	"""Get all valid neighbor cells in 6 directions (up, down, left, right, forward, back)."""
	var neighbors: Array[WfcCell] = []
	var directions = [
		Vector3i(1, 0, 0),  # Right
		Vector3i(-1, 0, 0),  # Left
		Vector3i(0, 1, 0),  # Up
		Vector3i(0, -1, 0),  # Down
		Vector3i(0, 0, 1),  # Forward
		Vector3i(0, 0, -1)  # Back
	]

	for dir in directions:
		var neighbor_pos = pos + dir
		if is_valid_position(neighbor_pos):
			var neighbor = get_cell(neighbor_pos)
			if neighbor:
				neighbors.append(neighbor)

	return neighbors


func get_neighbor_in_direction(pos: Vector3i, direction: Vector3i) -> WfcCell:
	"""Get the neighbor cell in a specific direction, or null if out of bounds."""
	var neighbor_pos = pos + direction
	if is_valid_position(neighbor_pos):
		return get_cell(neighbor_pos)
	return null


func get_lowest_entropy_cell() -> WfcCell:
	"""Find an uncollapsed cell with the lowest entropy (fewest possibilities)."""
	var lowest_entropy = INF
	var lowest_cells: Array[WfcCell] = []

	for cell in cells.values():
		if cell.is_collapsed():
			continue

		var entropy = cell.get_entropy()
		if entropy < 0:  # Skip collapsed cells
			continue

		if entropy < lowest_entropy:
			lowest_entropy = entropy
			lowest_cells = [cell]
		elif entropy == lowest_entropy:
			lowest_cells.append(cell)

	if lowest_cells.is_empty():
		return null

	# Randomly select from cells with same entropy to add variation
	return lowest_cells[randi() % lowest_cells.size()]


func is_fully_collapsed() -> bool:
	"""Check if all cells in the grid have been collapsed."""
	for cell in cells.values():
		if not cell.is_collapsed():
			return false
	return true


func has_contradiction() -> bool:
	"""Check if any cell has no possible tiles (contradiction state)."""
	for cell in cells.values():
		if cell.has_contradiction():
			return true
	return false


func is_valid_position(pos: Vector3i) -> bool:
	"""Check if a position is within grid bounds."""
	return (
		pos.x >= 0
		and pos.x < size.x
		and pos.y >= 0
		and pos.y < size.y
		and pos.z >= 0
		and pos.z < size.z
	)


func reset() -> void:
	"""Reset all cells to their initial uncollapsed state."""
	for cell in cells.values():
		cell.reset(all_tile_variants)
