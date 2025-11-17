class_name WfcSolver extends RefCounted

const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")

var grid: WfcGrid
var max_iterations: int = 10000

## Logging control: disable to run silently
var logging_enabled: bool = true

## Progress callback: Called periodically with progress info, signature: func(dict) -> void
## Dictionary contains: {"progress": float, "cells_collapsed": int, "total_cells": int, "iterations": int, "elapsed_ms": int}
var progress_callback: Callable = Callable()

## Progress reporting: How often to call progress_callback (in iterations), 0 = disabled
var progress_report_frequency: int = 100

## Performance tracking: Remaining uncollapsed cells
var _remaining_cells: int = 0

## Backtracking: Enable/disable backtracking on contradictions
var enable_backtracking: bool = true

## Backtracking: Maximum depth of backtrack stack
var max_backtrack_depth: int = 10

## Backtracking: Checkpoint frequency (save every N collapses)
var backtrack_checkpoint_frequency: int = 5

## Backtracking: State stack for contradiction recovery
var _backtrack_stack: Array[Dictionary] = []

## Backtracking: Counter for checkpoint frequency
var _collapses_since_checkpoint: int = 0

## Backtracking: Total number of backtracks performed
var _total_backtracks: int = 0

## Performance optimization: Fast compatibility cache using arrays instead of Dictionary
## 3D array: [source_variant_id][neighbor_variant_id][direction_index] = bool
var _compatibility_cache: Array = []

## Performance optimization: Variant ID mapping
var _variant_id_map: Dictionary = {}  # (tile_instance_id, rotation) -> variant_id

## Performance optimization: Pre-computed rotation bases
var _rotation_basis_cache: Dictionary = {
	0: WfcHelper.rotation_y_to_basis(0),
	90: WfcHelper.rotation_y_to_basis(90),
	180: WfcHelper.rotation_y_to_basis(180),
	270: WfcHelper.rotation_y_to_basis(270)
}

## Performance optimization: Cardinal directions (computed once)
var _directions: Array = []

## Performance optimization: Visited flags for propagation (reusable)
var _visited_flags: PackedByteArray

## Performance optimization: Scratch array for valid variants (reusable)
var _scratch_variants: Array[Dictionary] = []

func _init(wfc_grid: WfcGrid, prewarm_cache: bool = true) -> void:
	grid = wfc_grid
	
	# Auto-configure based on grid size
	var total_cells = grid.size.x * grid.size.y * grid.size.z
	_auto_configure(total_cells)
	
	# Initialize tile variant weights
	_initialize_variant_weights()	# Initialize fast data structures
	_directions = WfcHelper.get_cardinal_directions()
	_build_variant_ids()
	_initialize_fast_cache()
	_initialize_visited_flags()
	
	# Initialize remaining cells counter
	_remaining_cells = total_cells
	
	# Optionally pre-warm the compatibility cache for better performance on large grids
	if prewarm_cache and grid.all_tile_variants.size() < 200:  # Only for reasonable variant counts
		_prewarm_compatibility_cache()
		_validate_tile_compatibility()

func _build_variant_ids() -> void:
	"""Assign integer IDs to each variant for fast lookups."""
	var id = 0
	for variant in grid.all_tile_variants:
		variant["id"] = id
		var key = str(variant["tile"].get_instance_id(), ":", variant["rotation_degrees"])
		_variant_id_map[key] = id
		id += 1

func _initialize_fast_cache() -> void:
	"""Initialize 3D array cache for compatibility checks."""
	var n = grid.all_tile_variants.size()
	_compatibility_cache.resize(n)
	for i in n:
		_compatibility_cache[i] = []
		_compatibility_cache[i].resize(n)
		for j in n:
			_compatibility_cache[i][j] = []
			_compatibility_cache[i][j].resize(6)  # 6 cardinal directions
			for k in 6:
				_compatibility_cache[i][j][k] = null  # null = not cached yet

func _initialize_visited_flags() -> void:
	"""Initialize reusable visited flags array."""
	var total_cells = grid.size.x * grid.size.y * grid.size.z
	_visited_flags.resize(total_cells)

func _get_variant_id(tile: Tile, rotation: int) -> int:
	"""Get the integer ID for a tile+rotation variant."""
	var key = str(tile.get_instance_id(), ":", rotation)
	return _variant_id_map.get(key, -1)

func _get_cell_index(pos: Vector3i) -> int:
	"""Convert 3D position to flat array index."""
	return pos.x + pos.y * grid.size.x + pos.z * grid.size.x * grid.size.y

func _auto_configure(total_cells: int) -> void:
	"""Automatically configure performance settings based on grid size."""
	if total_cells < 10000:  # Small grid
		max_iterations = 20000
		progress_report_frequency = 500
	elif total_cells < 50000:  # Medium grid
		max_iterations = 100000
		progress_report_frequency = 200
	elif total_cells < 200000:  # Large grid
		max_iterations = 500000
		progress_report_frequency = 100
	else:  # Very large grid
		max_iterations = 1000000
		progress_report_frequency = 50

func _initialize_variant_weights() -> void:
	"""Initialize weights for all tile variants from their tile's weight property."""
	for variant in grid.all_tile_variants:
		var tile: Tile = variant.get("tile")
		if tile and tile.weight > 0.0:
			variant["weight"] = tile.weight
		elif not variant.has("weight"):
			variant["weight"] = 1.0

## Context dictionary for requirement evaluation
var _requirement_context: Dictionary = {}

func solve() -> bool:
	"""Solve the WFC puzzle synchronously. Use progress_callback for updates."""
	_log(["[WFC Solver] Starting solve..."])
	_log(["  Grid size: ", grid.size])
	_log(["  Total cells: ", grid.get_cell_count()])
	_log(["  Cells to collapse: ", _remaining_cells])
	_log(["  Max iterations: ", max_iterations])
	
	# Initialize requirement context (used for tracking tile counts, etc.)
	_requirement_context.clear()
	_reset_tile_requirements()
	
	# CRITICAL: Initialize entropy heap for O(log N) cell selection
	_log(["  Initializing entropy heap..."])
	var heap_start = Time.get_ticks_msec()
	grid.initialize_heap()
	var heap_time = Time.get_ticks_msec() - heap_start
	_log(["  Heap initialized in ", heap_time, "ms"])
	
	var iterations = 0
	var start_time = Time.get_ticks_msec()
	_backtrack_stack.clear()
	_collapses_since_checkpoint = 0
	_total_backtracks = 0

	while _remaining_cells > 0:
		if iterations >= max_iterations:
			push_error("WFC: Max iterations reached (", max_iterations, ")")
			push_error("  Completed iterations: ", iterations)
			if _total_backtracks > 0:
				push_error("  Total backtracks: ", _total_backtracks)
			return false

		# Report progress periodically
		if progress_callback.is_valid() and progress_report_frequency > 0 and iterations % progress_report_frequency == 0:
			var current_time = Time.get_ticks_msec()
			var total_cells = grid.get_cell_count()
			var collapsed_cells = total_cells - _remaining_cells
			var progress_data = {
				"progress": (collapsed_cells / float(total_cells)) * 100.0,
				"cells_collapsed": collapsed_cells,
				"total_cells": total_cells,
				"iterations": iterations,
				"elapsed_ms": current_time - start_time,
				"backtracks": _total_backtracks
			}
			progress_callback.call(progress_data)

		# Observe: Pick cell with lowest entropy
		var cell = grid.get_lowest_entropy_cell()
		if not cell:
			_log(["[WFC Solver] No more cells to collapse (fully collapsed)"])
			break
		
		# Filter cell variants based on requirements before collapse
		_apply_requirements_to_cell(cell)
		
		if cell.has_contradiction():
			if enable_backtracking and not _backtrack_stack.is_empty():
				_log(["  Requirements caused contradiction at ", cell.position, " - attempting backtrack"])
				if not _attempt_backtrack():
					push_error("WFC: Requirements created contradiction at ", cell.position, " and backtracking exhausted")
					return false
				iterations += 1
				continue
			else:
				push_error("WFC: Requirements caused contradiction at ", cell.position)
				return false

		# Save checkpoint before collapsing (if backtracking enabled)
		if enable_backtracking and _collapses_since_checkpoint >= backtrack_checkpoint_frequency:
			if _backtrack_stack.size() < max_backtrack_depth:
				var snapshot = _create_snapshot()
				_backtrack_stack.append(snapshot)
				_collapses_since_checkpoint = 0
			else:
				# Stack full - remove oldest checkpoint
				_backtrack_stack.pop_front()
				var snapshot = _create_snapshot()
				_backtrack_stack.append(snapshot)
				_collapses_since_checkpoint = 0

		if not cell.collapse():
			if enable_backtracking and not _backtrack_stack.is_empty():
				_log(["  Cell collapse failed at ", cell.position, " - attempting backtrack"])
				if not _attempt_backtrack():
					push_error("WFC: Failed to collapse cell at ", cell.position, " and backtracking exhausted")
					return false
				iterations += 1
				continue
			else:
				push_error("WFC: Failed to collapse cell at ", cell.position)
				return false
		
		# Update requirement context after successful collapse
		_update_requirement_context_after_collapse(cell)

		# Propagate: Update neighbors based on the collapsed cell
		var propagate_result = propagate(cell)
		
		if not propagate_result:
			# Contradiction detected - try backtracking
			if enable_backtracking and not _backtrack_stack.is_empty():
				_log(["  Propagation failed at ", cell.position, " - attempting backtrack"])
				if not _attempt_backtrack():
					push_error("WFC: Propagation failed at ", cell.position)
					push_error("  Collapsed to: ", cell.get_tile().name if cell.get_tile() else "unknown", " @ ", cell.get_rotation(), "°")
					return false
				iterations += 1
				continue
			else:
				push_error("WFC: Propagation failed at ", cell.position)
				push_error("  Collapsed to: ", cell.get_tile().name if cell.get_tile() else "unknown", " @ ", cell.get_rotation(), "°")
				return false

		iterations += 1
		_remaining_cells -= 1  # We collapsed one more cell
		_collapses_since_checkpoint += 1

	var elapsed_seconds = (Time.get_ticks_msec() - start_time) / 1000.0
	_log(["[WFC Solver] Solve completed successfully!"])
	_log(["  Total iterations: ", iterations])
	if _total_backtracks > 0:
		_log(["  Total backtracks: ", _total_backtracks])
	_log(["  Time elapsed: %.2f seconds" % elapsed_seconds])
	_log(["  Avg iterations/sec: %.0f" % (iterations / max(elapsed_seconds, 0.001))])

	return true

func propagate(start_cell: WfcCell) -> bool:
	"""Propagate constraints from a collapsed cell to its neighbors."""
	var propagation_queue: Array[WfcCell] = [start_cell]
	
	# Reset visited flags (fast memset)
	_visited_flags.fill(0)
	
	# Use pre-computed cardinal directions
	var directions = _directions
	
	# CRITICAL OPTIMIZATION: Use index-based traversal instead of pop_front() which is O(n)
	var head := 0
	while head < propagation_queue.size():
		var current_cell = propagation_queue[head]
		head += 1
		
		# Check if current cell has contradiction before propagating from it
		if current_cell.has_contradiction():
			push_error("  Cell ", current_cell.position, " has contradiction (0 variants) when trying to propagate from it")
			return false

		for direction in directions:
			var neighbor = grid.get_neighbor_in_direction(current_cell.position, direction)
			if not neighbor:
				continue
			
			# Skip if neighbor is already collapsed with a tile
			if neighbor.is_collapsed():
				continue
			
			# Skip if neighbor already has contradiction (shouldn't happen, but defensive)
			if neighbor.has_contradiction():
				push_error("  Neighbor ", neighbor.position, " already has contradiction before constraining")
				return false

			# Store original count for debugging
			var original_count = neighbor.possible_tile_variants.size()
		
			# Calculate which tile+rotation variants are valid for this neighbor based on current cell
			var valid_variants = get_valid_variants_for_neighbor(current_cell, neighbor, direction)

			# Constrain the neighbor
			var changed = neighbor.constrain(valid_variants)

			if neighbor.has_contradiction():
				push_error("  Contradiction at neighbor ", neighbor.position, " in direction ", direction)
				push_error("  Neighbor had ", original_count, " variants before, 0 after")
				push_error("  Valid variants computed: ", valid_variants.size())
				push_error("  Current cell: ", current_cell.position, " with ", current_cell.possible_tile_variants.size(), " variants")
				push_error("")
				push_error("  This means NO variants from current cell can connect to ANY variants in neighbor!")
				push_error("  This indicates incompatible tile sockets or over-constrained tiles.")
				return false

			# If neighbor's possibilities changed, add it to queue for further propagation
			# Use fast flat array index for visited check
			if changed:
				var neighbor_idx = _get_cell_index(neighbor.position)
				if _visited_flags[neighbor_idx] == 0:
					propagation_queue.append(neighbor)
					_visited_flags[neighbor_idx] = 1
				
				# CRITICAL: Update heap when cell entropy changes
				grid.mark_cell_entropy_changed(neighbor)
	
	return true

func get_valid_variants_for_neighbor(source_cell: WfcCell, neighbor_cell: WfcCell, direction: Vector3i) -> Array[Dictionary]:
	"""
	Get all valid tile+rotation variants for a neighbor cell based on source cell constraints.
	Optimized with early exits and minimal allocations.
	
	Args:
		source_cell: The cell that was just collapsed or updated
		neighbor_cell: The neighboring cell to constrain
		direction: Direction from source to neighbor (Vector3i)
	
	Returns:
		Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int), "weight" (float)
	"""
	# Reuse scratch array to avoid allocations
	_scratch_variants.clear()
	
	# Get source variants (always use possible_tile_variants now)
	var source_variants = source_cell.possible_tile_variants
	var source_count = source_variants.size()
	if source_count == 0:
		return neighbor_cell.possible_tile_variants
	
	var neighbor_variants = neighbor_cell.possible_tile_variants
	var neighbor_count = neighbor_variants.size()

	# For each possible variant in the neighbor
	for i in range(neighbor_count):
		var neighbor_variant = neighbor_variants[i]
		var neighbor_tile = neighbor_variant["tile"]
		var neighbor_rotation = neighbor_variant["rotation_degrees"]

		# Check against all possible variants in the source cell
		for j in range(source_count):
			var source_variant = source_variants[j]
			var source_tile = source_variant["tile"]
			var source_rotation = source_variant["rotation_degrees"]

			if are_variants_compatible(source_tile, source_rotation, neighbor_tile, neighbor_rotation, direction, source_cell.position, neighbor_cell.position):
				_scratch_variants.append(neighbor_variant)
				break  # Found compatible match, move to next neighbor variant

	return _scratch_variants

func are_variants_compatible(source_tile: Tile, source_rotation: int, neighbor_tile: Tile, neighbor_rotation: int, direction: Vector3i, source_position: Vector3i = Vector3i.ZERO, neighbor_position: Vector3i = Vector3i.ZERO) -> bool:
	"""
	Check if two tile+rotation variants can be placed adjacent to each other.
	Uses fast array-based caching for O(1) lookups.
	
	Args:
		source_tile: The source tile
		source_rotation: Rotation of source tile in degrees (0, 90, 180, 270)
		neighbor_tile: The neighboring tile
		neighbor_rotation: Rotation of neighbor tile in degrees
		direction: Direction from source to neighbor
		source_position: Grid position of source cell (optional)
		neighbor_position: Grid position of neighbor cell (optional)
	
	Returns:
		true if the variants are compatible, false otherwise
	"""
	# Get variant IDs and direction index for fast cache lookup
	var src_id = _get_variant_id(source_tile, source_rotation)
	var neigh_id = _get_variant_id(neighbor_tile, neighbor_rotation)
	var dir_index = WfcHelper.get_direction_index(direction)
	
	# Use pre-computed rotation bases (convert world direction into tile's local space)
	var source_rotation_basis: Basis = _rotation_basis_cache[source_rotation]
	var local_direction = WfcHelper.rotate_direction(direction, source_rotation_basis.inverse())

	# Get sockets on source tile that face toward neighbor (in local space)
	var source_sockets = source_tile.get_sockets_in_direction(local_direction)

	# Rotate the opposite direction by the neighbor tile's rotation
	var neighbor_rotation_basis: Basis = _rotation_basis_cache[neighbor_rotation]
	var neighbor_local_direction = WfcHelper.rotate_direction(-direction, neighbor_rotation_basis.inverse())

	# Get sockets on neighbor tile that face back toward source (in local space)
	var neighbor_sockets = neighbor_tile.get_sockets_in_direction(neighbor_local_direction)
	
	# If either tile has no sockets in this direction, they're incompatible
	if source_sockets.is_empty() or neighbor_sockets.is_empty():
		_compatibility_cache[src_id][neigh_id][dir_index] = false
		return false

	# Check cache first (O(1) array access)
	var cached = _compatibility_cache[src_id][neigh_id][dir_index]
	if cached != null:
		return cached
	
	# Check if any socket pair is compatible
	var result = false
	for source_socket in source_sockets:
		for neighbor_socket in neighbor_sockets:
			if source_socket.is_compatible_with(neighbor_socket) and neighbor_socket.is_compatible_with(source_socket):
				result = true
				break
		if result:
			break
	
	# Cache the result (fast array write)
	_compatibility_cache[src_id][neigh_id][dir_index] = result
	return result

func reset() -> void:
	"""Reset the grid to initial state. Cache is preserved."""
	grid.reset()
	_backtrack_stack.clear()
	_total_backtracks = 0
	_collapses_since_checkpoint = 0
	# Note: Keep cache - it's valid across resets with same tiles

func set_tile_weight(tile: Tile, rotation: int, weight: float) -> void:
	"""Set the weight/frequency for a specific tile+rotation variant.
	Higher weights make the tile more likely to appear.
	Must be called before solve() to take effect."""
	for variant in grid.all_tile_variants:
		if variant["tile"] == tile and variant["rotation_degrees"] == rotation:
			variant["weight"] = weight
			return
	push_warning("Tile variant not found: ", tile.name, " @ ", rotation, "°")

func set_tile_weight_all_rotations(tile: Tile, weight: float) -> void:
	"""Set the weight for a tile across all its rotations."""
	for variant in grid.all_tile_variants:
		if variant["tile"] == tile:
			variant["weight"] = weight

func get_cache_stats() -> Dictionary:
	"""Get statistics about the compatibility cache for debugging/optimization."""
	var n = grid.all_tile_variants.size()
	var cache_entries = n * n * 6  # Full 3D array size
	return {
		"cache_size": cache_entries,
		"estimated_memory_kb": cache_entries * 0.001,  # 1 byte per bool entry
		"variants": n
	}

func set_logging_enabled(enabled: bool) -> void:
	"""Enable or disable logging output."""
	logging_enabled = enabled

func _reset_tile_requirements() -> void:
	"""Reset any stateful requirements (like MaxCountRequirement counters)."""
	for variant in grid.all_tile_variants:
		var tile: Tile = variant.get("tile")
		if not tile or tile.requirements.is_empty():
			continue
		
		for req in tile.requirements:
			if req.has_method("reset"):
				req.reset()

func _apply_requirements_to_cell(cell: WfcCell) -> void:
	"""Filter cell's possible variants based on tile requirements."""
	if cell.is_collapsed():
		return
	
	var valid_variants: Array[Dictionary] = []
	
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if not tile:
			valid_variants.append(variant)
			continue
		
		# If tile has no requirements, it's always valid
		if tile.requirements.is_empty():
			valid_variants.append(variant)
			continue
		
		# Check all requirements
		var all_satisfied = true
		for req in tile.requirements:
			if not req.enabled:
				continue
			
			if not req.evaluate(tile, cell.position, grid, _requirement_context):
				all_satisfied = false
				if logging_enabled:
					_log(["  Requirement '", req.display_name, "' failed for tile '", tile.name, "' at ", cell.position])
					_log(["    Reason: ", req.get_failure_reason()])
				break
		
		if all_satisfied:
			valid_variants.append(variant)
	
	# Update cell with only valid variants
	if valid_variants.size() < cell.possible_tile_variants.size():
		cell.possible_tile_variants = valid_variants
		cell._entropy_valid = false

func _update_requirement_context_after_collapse(cell: WfcCell) -> void:
	"""Update requirement context after a tile is placed (for count tracking, etc.)."""
	if not cell.is_collapsed():
		return
	
	var tile: Tile = cell.get_tile()
	if not tile:
		return
	
	# Update tile count in context
	var count_key = "tile_count_" + str(tile.get_instance_id())
	_requirement_context[count_key] = _requirement_context.get(count_key, 0) + 1

func _log(parts: Array) -> void:
	if not logging_enabled:
		return
	var text := ""
	for part in parts:
		text += str(part)
	print(text)

func _prewarm_compatibility_cache() -> void:
	"""Pre-compute compatibility for all tile variant pairs in all directions.
	This trades initialization time for faster solve time on large grids."""
	var directions = WfcHelper.get_cardinal_directions()
	var variants = grid.all_tile_variants
	var total_checks = 0
	
	_log(["Pre-warming compatibility cache..."])
	var start_time = Time.get_ticks_msec()
	
	# Check all variant pairs in all directions
	for i in range(variants.size()):
		for j in range(variants.size()):
			for direction in directions:
				var v1 = variants[i]
				var v2 = variants[j]
				# This will populate the cache
				are_variants_compatible(v1["tile"], v1["rotation_degrees"], 
										v2["tile"], v2["rotation_degrees"], direction)
				total_checks += 1
	
	var elapsed = Time.get_ticks_msec() - start_time
	var n = variants.size()
	_log(["Pre-warmed ", total_checks, " compatibility checks in ", elapsed, "ms"])
	_log(["Cache: ", n, "x", n, "x6 array (", n * n * 6, " entries)"])

func _validate_tile_compatibility() -> void:
	"""Validate that at least one tile can fit anywhere (prevents impossible puzzles)."""
	var directions = WfcHelper.get_cardinal_directions()
	var variants = grid.all_tile_variants
	
	# Check if any variant can be placed next to itself in all directions
	var has_universal_variant = false
	var universal_count = 0
	for variant in variants:
		var compatible_all_dirs = true
		for direction in directions:
			if not are_variants_compatible(variant["tile"], variant["rotation_degrees"],
										   variant["tile"], variant["rotation_degrees"], direction):
				compatible_all_dirs = false
				break
		if compatible_all_dirs:
			has_universal_variant = true
			universal_count += 1
			if universal_count == 1:
				_log(["✓ Universal tile found: ", variant["tile"].name, " @ ", variant["rotation_degrees"], "° (can connect to itself)"])
	
	if universal_count > 1:
		_log(["  (", universal_count, " total universal variants)"])
	
	if not has_universal_variant:
		push_warning("⚠ No universal tile found! This may cause contradictions.")
		push_warning("  Consider adding a simple tile that can connect to itself in all directions.")
	
	# Check overall connectivity - can every variant connect to at least one other variant in each direction?
	var isolated_variants = []
	for i in range(variants.size()):
		var variant = variants[i]
		for direction in directions:
			var has_compatible_neighbor = false
			for j in range(variants.size()):
				var other_variant = variants[j]
				if are_variants_compatible(variant["tile"], variant["rotation_degrees"],
										  other_variant["tile"], other_variant["rotation_degrees"], direction):
					has_compatible_neighbor = true
					break
			
			if not has_compatible_neighbor:
				var key = str(variant["tile"].name, " @ ", variant["rotation_degrees"], "° in direction ", direction)
				if key not in isolated_variants:
					isolated_variants.append(key)
	
	if not isolated_variants.is_empty():
		push_warning("⚠ Found ", isolated_variants.size(), " variant-direction pairs with NO compatible neighbors:")
		for i in range(mini(5, isolated_variants.size())):
			push_warning("  - ", isolated_variants[i])
		if isolated_variants.size() > 5:
			push_warning("  ... and ", isolated_variants.size() - 5, " more")

func _create_snapshot() -> Dictionary:
	"""Create a snapshot of the current grid state for backtracking."""
	var snapshot := {
		"remaining_cells": _remaining_cells,
		"collapses_since_checkpoint": _collapses_since_checkpoint,
		"cell_states": [],
		"heap_state": _copy_heap_state(),
		"visited_flags": _visited_flags.duplicate()
	}
	
	for cell in grid.get_all_cells():
		var cell_state := {
			"position": cell.position,
			"possible_variants": [],
			"entropy_valid": cell._entropy_valid,
			"cached_entropy": cell._cached_entropy
		}
		
		# Store references to variants (variants are shared, no deep copy needed)
		for variant in cell.possible_tile_variants:
			cell_state["possible_variants"].append(variant)
		
		snapshot["cell_states"].append(cell_state)
	
	return snapshot

func _copy_heap_state() -> Dictionary:
	"""Create a copy of the current heap state."""
	return {
		"heap": grid._entropy_heap.duplicate(true),
		"seq": grid._heap_seq,
		"cells_in_heap": grid._cells_in_heap.duplicate()
	}

func _restore_snapshot(snapshot: Dictionary) -> void:
	"""Restore grid state from a snapshot."""
	_remaining_cells = snapshot["remaining_cells"]
	_collapses_since_checkpoint = snapshot["collapses_since_checkpoint"]
	var cell_states: Array = snapshot["cell_states"]
	
	# Restore cell states
	for i in range(cell_states.size()):
		var cell_state: Dictionary = cell_states[i]
		var cell = grid.get_cell(cell_state["position"])
		if cell == null:
			continue
		
		cell.possible_tile_variants.clear()
		for variant in cell_state["possible_variants"]:
			cell.possible_tile_variants.append(variant)
		
		cell._entropy_valid = cell_state["entropy_valid"]
		cell._cached_entropy = cell_state["cached_entropy"]
	
	# Restore heap state
	_restore_heap_state(snapshot["heap_state"])
	
	# Restore visited flags
	_visited_flags = snapshot["visited_flags"].duplicate()

func _restore_heap_state(heap_state: Dictionary) -> void:
	"""Restore the heap from saved state."""
	grid._entropy_heap = heap_state["heap"].duplicate(true)
	grid._heap_seq = heap_state["seq"]
	grid._cells_in_heap = heap_state["cells_in_heap"].duplicate()

func _attempt_backtrack() -> bool:
	"""Attempt to backtrack to the last checkpoint and try a different path."""
	if _backtrack_stack.is_empty():
		return false
	
	var snapshot = _backtrack_stack.pop_back()
	_restore_snapshot(snapshot)
	_total_backtracks += 1
	_collapses_since_checkpoint = 0
	
	_log(["  Backtracked to checkpoint (backtracks: ", _total_backtracks, ", stack depth: ", _backtrack_stack.size(), ")"])
	return true