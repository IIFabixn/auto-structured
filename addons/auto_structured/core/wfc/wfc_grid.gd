@tool
class_name WfcGrid extends RefCounted

const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const WfcTileCatalog = preload("res://addons/auto_structured/core/wfc/wfc_tile_catalog.gd")
const WfcTileCatalogBuilder = preload("res://addons/auto_structured/core/wfc/wfc_tile_catalog_builder.gd")
const WfcInternalFallbackFactory = preload("res://addons/auto_structured/core/wfc/wfc_internal_fallback_factory.gd")
const AutoStructuredSettings = preload("res://addons/auto_structured/utils/auto_structured_settings.gd")
const WfcGridChunk = preload("res://addons/auto_structured/core/wfc/wfc_grid_chunk.gd")

## 3D grid of WFC cells for procedural generation.
## Optimized: Flat array storage instead of Dictionary for better performance
var _cells: Array[WfcCell] = []
var size: Vector3i
var all_tiles: Array[Tile] = []
var all_tile_variants: Array[Dictionary] = []  # All possible tile+rotation combinations
var fallback_tile: Tile = null  ## Internal "air" tile the solver can fall back to when needed
var tile_catalog: WfcTileCatalog = null

## Chunking metadata for large grids
const DEFAULT_CHUNK_EDGE := 16
var chunk_size: Vector3i = Vector3i(DEFAULT_CHUNK_EDGE, DEFAULT_CHUNK_EDGE, DEFAULT_CHUNK_EDGE)
var _chunk_counts: Vector3i = Vector3i(1, 1, 1)
var _chunks: Dictionary = {}
var _chunk_list: Array[WfcGridChunk] = []

## Performance optimization: Priority queue (min-heap) for entropy selection
var _entropy_heap: Array = []  # Array of { "entropy": float, "seq": int, "cell": WfcCell }
var _heap_seq: int = 0  # Monotonic counter for tie-breaking in heap

## Heap optimization: Track cells in heap to avoid duplicates
var _cells_in_heap: Dictionary = {}  # cell -> true

## Helper function to convert 3D position to flat array index
func _index(pos: Vector3i) -> int:
	return pos.x + pos.y * size.x + pos.z * size.x * size.y

func _resolve_chunk_size(grid_size: Vector3i, requested: Vector3i) -> Vector3i:
	var resolved = Vector3i(
		_resolve_chunk_axis(grid_size.x, requested.x),
		_resolve_chunk_axis(grid_size.y, requested.y),
		_resolve_chunk_axis(grid_size.z, requested.z)
	)
	return resolved

func _resolve_chunk_axis(axis_length: int, requested: int) -> int:
	if requested > 0:
		return clampi(requested, 1, max(axis_length, 1))
	if axis_length <= DEFAULT_CHUNK_EDGE:
		return max(axis_length, 1)
	return DEFAULT_CHUNK_EDGE

func _initialize_chunks() -> void:
	_chunks.clear()
	_chunk_list.clear()
	_chunk_counts = _compute_chunk_counts()
	for cz in range(_chunk_counts.z):
		for cy in range(_chunk_counts.y):
			for cx in range(_chunk_counts.x):
				var coords = Vector3i(cx, cy, cz)
				var origin = Vector3i(cx * chunk_size.x, cy * chunk_size.y, cz * chunk_size.z)
				var max_extent = Vector3i(
					min(chunk_size.x, size.x - origin.x),
					min(chunk_size.y, size.y - origin.y),
					min(chunk_size.z, size.z - origin.z)
				)
				var chunk = WfcGridChunk.new(coords, origin, max_extent)
				_chunks[coords] = chunk
				_chunk_list.append(chunk)

func _compute_chunk_counts() -> Vector3i:
	return Vector3i(
		int(ceil(float(size.x) / float(chunk_size.x))),
		int(ceil(float(size.y) / float(chunk_size.y))),
		int(ceil(float(size.z) / float(chunk_size.z)))
	)

func _chunk_coords_from_position(pos: Vector3i) -> Vector3i:
	var coords = Vector3i(
		int(floor(float(pos.x) / float(chunk_size.x))),
		int(floor(float(pos.y) / float(chunk_size.y))),
		int(floor(float(pos.z) / float(chunk_size.z)))
	)
	return Vector3i(
		clampi(coords.x, 0, max(_chunk_counts.x - 1, 0)),
		clampi(coords.y, 0, max(_chunk_counts.y - 1, 0)),
		clampi(coords.z, 0, max(_chunk_counts.z - 1, 0))
	)

func _get_chunk_from_coords(coords: Vector3i) -> WfcGridChunk:
	if _chunks.has(coords):
		return _chunks[coords]
	return null

func get_chunk_from_position(pos: Vector3i) -> WfcGridChunk:
	if not is_valid_position(pos):
		return null
	return _get_chunk_from_coords(_chunk_coords_from_position(pos))

func get_chunks() -> Array[WfcGridChunk]:
	return _chunk_list

func get_chunk_counts() -> Vector3i:
	return _chunk_counts

func get_chunk_size() -> Vector3i:
	return chunk_size

func has_multiple_chunks() -> bool:
	return _chunk_list.size() > 1

func get_lowest_entropy_chunk() -> WfcGridChunk:
	var best_chunk: WfcGridChunk = null
	var best_entropy := INF
	for chunk in _chunk_list:
		if chunk == null:
			continue
		if chunk.uncollapsed_cells <= 0:
			continue
		var entropy_hint := chunk.get_entropy_hint()
		if best_chunk == null or entropy_hint < best_entropy:
			best_chunk = chunk
			best_entropy = entropy_hint
	return best_chunk

func get_lowest_entropy_cell_in_chunk(chunk: WfcGridChunk) -> WfcCell:
	if chunk == null:
		return null
	var best_cell: WfcCell = null
	var best_entropy := INF
	for cell in chunk.cells:
		if cell == null or cell.is_collapsed():
			continue
		var entropy := cell.get_entropy()
		if best_cell == null or entropy < best_entropy:
			best_cell = cell
			best_entropy = entropy
	return best_cell

func get_chunked_lowest_entropy_cell() -> WfcCell:
	if _chunk_list.is_empty():
		return null
	var attempts := _chunk_list.size()
	for i in range(attempts):
		var chunk = get_lowest_entropy_chunk()
		if chunk == null:
			return null
		var cell = get_lowest_entropy_cell_in_chunk(chunk)
		if cell != null:
			return cell
		chunk.recompute_uncollapsed_count()
		chunk.mark_entropy_dirty()
	return null

func _rebuild_chunk_tracking() -> void:
	for chunk in _chunk_list:
		chunk.recompute_uncollapsed_count()

func rebuild_chunk_state() -> void:
	"""Recompute derived chunk metrics after bulk cell mutations."""
	_rebuild_chunk_tracking()

## Get total number of cells in the grid
func get_cell_count() -> int:
	return _cells.size()

static func from_library(grid_size: Vector3i, library: ModuleLibrary) -> WfcGrid:
	var use_catalog := AutoStructuredSettings.get_use_bitset_catalog()
	if use_catalog:
		var catalog := WfcTileCatalogBuilder.build(library)
		return WfcGrid.new(grid_size, library.tiles, catalog)
	return WfcGrid.new(grid_size, library.tiles)

func _init(grid_size: Vector3i, tiles: Array[Tile], catalog: WfcTileCatalog = null, chunk_size_override: Vector3i = Vector3i(0, 0, 0)) -> void:
	size = grid_size
	all_tiles = tiles.duplicate()
	tile_catalog = catalog
	chunk_size = _resolve_chunk_size(size, chunk_size_override)
	_initialize_chunks()
	var solver_tiles: Array[Tile] = all_tiles.duplicate()
	if tile_catalog:
		fallback_tile = tile_catalog.internal_fallback_tile
		all_tile_variants = tile_catalog.get_solver_variant_dicts()
	else:
		fallback_tile = WfcInternalFallbackFactory.create_fallback_tile()
		if fallback_tile:
			solver_tiles.append(fallback_tile)
		all_tile_variants = generate_all_variants(solver_tiles)
	
	# Pre-allocate flat array for all cells
	var total_cells = size.x * size.y * size.z
	_cells.resize(total_cells)
	var variant_count_for_cells := tile_catalog.get_variant_count() if tile_catalog else -1
	var enable_masks := tile_catalog != null
	
	# Initialize cells with all possible variants
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var pos = Vector3i(x, y, z)
				var cell = WfcCell.new(pos, all_tile_variants, variant_count_for_cells, enable_masks)
				_cells[_index(pos)] = cell
				var chunk = _get_chunk_from_coords(_chunk_coords_from_position(pos))
				if chunk:
					chunk.add_cell(cell)
	
	# Initialize heap - will be populated when solver needs it
	_entropy_heap.clear()
	_heap_seq = 0
	_cells_in_heap.clear()

func generate_all_variants(tiles: Array[Tile]) -> Array[Dictionary]:
	"""Generate all possible tile+rotation combinations."""
	var variants: Array[Dictionary] = []
	for tile in tiles:
		if tile == null:
			continue
		var is_fallback := fallback_tile != null and tile == fallback_tile
		var rotations = tile.get_unique_rotations()
		for rotation in rotations:
			variants.append({
				"tile": tile,
				"rotation_degrees": rotation,
				"is_internal_fallback": is_fallback
			})
	
	return variants


func get_fallback_tile() -> Tile:
	return fallback_tile



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
		
		# Skip if cell is now collapsed
		if cell.is_collapsed():
			continue
		
		# Cell is valid - return it
		# Note: We don't check if entropy changed since push - that's fine,
		# duplicates in heap are cheaper than scanning 125k cells
		return cell
	
	return null


func mark_cell_entropy_changed(cell: WfcCell) -> void:
	"""Call this whenever a cell's entropy changes (after constraint propagation).
	Adds the cell to the heap so it can be selected later."""
	if cell == null:
		return
	var chunk = get_chunk_from_position(cell.position)
	if chunk:
		chunk.mark_entropy_dirty()
	if cell.is_collapsed():
		return

	_heap_push(cell)

func notify_cell_collapsed(cell: WfcCell) -> void:
	if cell == null:
		return
	var chunk = get_chunk_from_position(cell.position)
	if chunk:
		chunk.on_cell_collapsed(cell)


func initialize_heap() -> void:
	"""Initialize the heap with all uncollapsed cells. Call once at start of solve."""
	_entropy_heap.clear()
	_heap_seq = 0
	_cells_in_heap.clear()
	
	for cell in _cells:
		if not cell.is_collapsed():
			_heap_push(cell)


## Binary min-heap operations (keyed by entropy, then by sequence number for stability)

func _heap_push(cell: WfcCell) -> void:
	"""Add a cell to the min-heap. Avoids duplicates."""
	# Skip if cell already in heap (prevents duplicate entries)
	if _cells_in_heap.has(cell):
		return
	
	var item = {
		"entropy": cell.get_entropy(),
		"seq": _heap_seq,
		"cell": cell
	}
	_heap_seq += 1
	_entropy_heap.append(item)
	_cells_in_heap[cell] = true
	_heap_sift_up(_entropy_heap.size() - 1)


func _heap_pop() -> Dictionary:
	"""Remove and return the minimum entropy item from the heap."""
	if _entropy_heap.is_empty():
		return {}
	
	var root = _entropy_heap[0]
	var root_cell = root.get("cell")
	if root_cell:
		_cells_in_heap.erase(root_cell)
	
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
	
	rebuild_chunk_state()

	# Clear heap - will be reinitialized on next solve
	_entropy_heap.clear()
	_heap_seq = 0
	_cells_in_heap.clear()
