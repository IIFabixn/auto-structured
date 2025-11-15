class_name WfcGrid extends RefCounted

const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

## 3D grid of WFC cells for procedural generation.
## Optimized: Flat array storage instead of Dictionary for better performance
var _cells: Array[WfcCell] = []
var size: Vector3i
var all_tiles: Array[Tile] = []
var all_tile_variants: Array[Dictionary] = []  # All possible tile+rotation combinations

## Performance optimization: Priority queue (min-heap) for entropy selection
var _entropy_heap: Array = []  # Array of { "entropy": float, "seq": int, "cell": WfcCell }
var _heap_seq: int = 0  # Monotonic counter for tie-breaking in heap

## Helper function to convert 3D position to flat array index
func _index(pos: Vector3i) -> int:
	return pos.x + pos.y * size.x + pos.z * size.x * size.y

## Get total number of cells in the grid
func get_cell_count() -> int:
	return _cells.size()

static func from_library(grid_size: Vector3i, library: ModuleLibrary) -> WfcGrid:
	return WfcGrid.new(grid_size, library.tiles)

func _init(grid_size: Vector3i, tiles: Array[Tile]) -> void:
	size = grid_size
	all_tiles = tiles
	
	# Generate all possible tile+rotation combinations
	all_tile_variants = generate_all_variants(tiles)
	
	# Pre-allocate flat array for all cells
	var total_cells = size.x * size.y * size.z
	_cells.resize(total_cells)
	
	# Initialize cells with all possible variants
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var pos = Vector3i(x, y, z)
				var cell = WfcCell.new(pos, all_tile_variants)
				_apply_tile_requirements(cell)
				_cells[_index(pos)] = cell
	
	# Initialize heap - will be populated when solver needs it
	_entropy_heap.clear()
	_heap_seq = 0

func generate_all_variants(tiles: Array[Tile]) -> Array[Dictionary]:
	"""Generate all possible tile+rotation combinations."""
	var variants: Array[Dictionary] = []
	for tile in tiles:
		var rotations = tile.get_unique_rotations()
		for rotation in rotations:
			variants.append({
				"tile": tile,
				"rotation_degrees": rotation
			})
	
	return variants


func get_cell(pos: Vector3i) -> WfcCell:
	if not is_valid_position(pos):
		return null
	return _cells[_index(pos)]

## Get all cells in the grid for iteration
func get_all_cells() -> Array[WfcCell]:
	return _cells

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
	"""Find an uncollapsed cell with the lowest entropy using a min-heap. O(log N) instead of O(N)."""
	# Pop from heap until we find a valid uncollapsed cell
	# (Stale/collapsed entries are skipped)
	while not _entropy_heap.is_empty():
		var item = _heap_pop()
		if item == null:
			break
		
		var cell: WfcCell = item["cell"]
		
		# Skip if cell is now collapsed or empty
		if cell.is_collapsed() or cell.is_empty():
			continue
		
		# Cell is valid - return it
		# Note: We don't check if entropy changed since push - that's fine,
		# duplicates in heap are cheaper than scanning 125k cells
		return cell
	
	return null


func mark_cell_entropy_changed(cell: WfcCell) -> void:
	"""Call this whenever a cell's entropy changes (after constraint propagation).
	Adds the cell to the heap so it can be selected later."""
	if cell.is_collapsed() or cell.is_empty():
		return
	
	_heap_push(cell)


func initialize_heap() -> void:
	"""Initialize the heap with all uncollapsed cells. Call once at start of solve."""
	_entropy_heap.clear()
	_heap_seq = 0
	
	for cell in _cells:
		if not cell.is_collapsed() and not cell.is_empty():
			_heap_push(cell)


## Binary min-heap operations (keyed by entropy, then by sequence number for stability)

func _heap_push(cell: WfcCell) -> void:
	"""Add a cell to the min-heap."""
	var item = {
		"entropy": cell.get_entropy(),
		"seq": _heap_seq,
		"cell": cell
	}
	_heap_seq += 1
	_entropy_heap.append(item)
	_heap_sift_up(_entropy_heap.size() - 1)


func _heap_pop() -> Dictionary:
	"""Remove and return the minimum entropy item from the heap."""
	if _entropy_heap.is_empty():
		return {}
	
	var root = _entropy_heap[0]
	var last = _entropy_heap.pop_back()
	
	if not _entropy_heap.is_empty():
		_entropy_heap[0] = last
		_heap_sift_down(0)
	
	return root


func _heap_sift_up(idx: int) -> void:
	"""Restore heap property by moving element up."""
	while idx > 0:
		var parent_idx = (idx - 1) / 2
		if not _heap_less_than(idx, parent_idx):
			break
		
		# Swap with parent
		var temp = _entropy_heap[idx]
		_entropy_heap[idx] = _entropy_heap[parent_idx]
		_entropy_heap[parent_idx] = temp
		idx = parent_idx


func _heap_sift_down(idx: int) -> void:
	"""Restore heap property by moving element down."""
	var size = _entropy_heap.size()
	
	while true:
		var smallest = idx
		var left = 2 * idx + 1
		var right = 2 * idx + 2
		
		if left < size and _heap_less_than(left, smallest):
			smallest = left
		if right < size and _heap_less_than(right, smallest):
			smallest = right
		
		if smallest == idx:
			break
		
		# Swap with smallest child
		var temp = _entropy_heap[idx]
		_entropy_heap[idx] = _entropy_heap[smallest]
		_entropy_heap[smallest] = temp
		idx = smallest


func _heap_less_than(a_idx: int, b_idx: int) -> bool:
	"""Compare two heap items. Returns true if a < b."""
	var a = _entropy_heap[a_idx]
	var b = _entropy_heap[b_idx]
	
	# First compare by entropy
	if a["entropy"] < b["entropy"]:
		return true
	elif a["entropy"] > b["entropy"]:
		return false
	
	# Tie-break by sequence (for stability and randomization)
	return a["seq"] < b["seq"]


func is_fully_collapsed() -> bool:
	"""Check if all cells in the grid have been collapsed.
	NOTE: With heap-based selection, solver should use _remaining_cells counter instead."""
	for cell in _cells:
		if not cell.is_collapsed():
			return false
	return true


func has_contradiction() -> bool:
	"""Check if any cell has no possible tiles (contradiction state)."""
	for cell in _cells:
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
	for cell in _cells:
		cell.reset(all_tile_variants)
		_apply_tile_requirements(cell)
	
	# Clear heap - will be reinitialized on next solve
	_entropy_heap.clear()
	_heap_seq = 0


func _apply_tile_requirements(cell: WfcCell) -> void:
	"""Filter a cell's variants based on tile-level requirements."""
	if cell == null:
		return

	var filtered: Array[Dictionary] = []
	for variant in all_tile_variants:
		if _variant_meets_tile_requirements(variant, cell.position):
			filtered.append(variant)

	cell.possible_tile_variants = filtered


func _variant_meets_tile_requirements(variant: Dictionary, cell_position: Vector3i) -> bool:
	var tile: Tile = variant.get("tile")
	if tile == null:
		return false

	var tile_requirements: Array = tile.requirements
	if tile_requirements.is_empty():
		return true

	var context: Dictionary = {
		"module": tile,
		"tags": tile.tags,
		"grid": self,
		"grid_size": size,
		"rotation_degrees": variant.get("rotation_degrees", 0)
	}

	for requirement in tile_requirements:
		if requirement == null:
			continue
		if not requirement.evaluate(cell_position, context):
			return false

	return true
