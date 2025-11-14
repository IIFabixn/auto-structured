class_name WfcSolver extends RefCounted

const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcCell = preload("res://addons/auto_structured/core/wfc/wfc_cell.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcStrategyBase = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd")
const WfcStrategyFillAll = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_fill_all.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

var grid: WfcGrid
var strategy: WfcStrategyBase
var max_iterations: int = 10000

## Performance tuning: How often to yield (ms), 0 = disabled
var yield_interval_ms: int = 16

## Performance tuning: Cells to process before yielding in propagation, 0 = disabled
var propagation_batch_size: int = 50

## Performance tuning: Interval for progress reports (ms), 0 = disabled
var progress_report_interval_ms: int = 2000

## Performance tuning: Enable/disable yielding entirely for maximum speed
var _enable_yielding: bool = true

## Performance tracking: Remaining uncollapsed cells
var _remaining_cells: int = 0

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

func _init(wfc_grid: WfcGrid, wfc_strategy: WfcStrategyBase = null, prewarm_cache: bool = true) -> void:
	grid = wfc_grid
	strategy = wfc_strategy if wfc_strategy else WfcStrategyFillAll.new()
	strategy.initialize(grid.size)
	
	# Auto-configure based on grid size
	var total_cells = grid.size.x * grid.size.y * grid.size.z
	_auto_configure(total_cells)
	
	# Initialize fast data structures
	_directions = WfcHelper.get_cardinal_directions()
	_build_variant_ids()
	_initialize_fast_cache()
	_initialize_visited_flags()
	
	# Initialize remaining cells counter
	_remaining_cells = total_cells
	
	# Pre-mark cells that should not be filled according to strategy
	_apply_strategy_mask()
	
	# Run initial constraint propagation to update neighbors of empty cells
	_propagate_empty_cells()
	
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
		yield_interval_ms = 50
		propagation_batch_size = 100
		max_iterations = 20000
		progress_report_interval_ms = 5000
	elif total_cells < 50000:  # Medium grid
		yield_interval_ms = 16
		propagation_batch_size = 50
		max_iterations = 100000
		progress_report_interval_ms = 2000
	elif total_cells < 200000:  # Large grid
		yield_interval_ms = 8
		propagation_batch_size = 25
		max_iterations = 500000
		progress_report_interval_ms = 1000
	else:  # Very large grid
		yield_interval_ms = 4
		propagation_batch_size = 10
		max_iterations = 1000000
		progress_report_interval_ms = 500

func _apply_strategy_mask() -> void:
	"""Mark cells as empty if strategy says they shouldn't be collapsed, and apply semantic tags"""
	var cells_filtered_out = 0
	var tag_usage_stats = {}  # Track which tags are filtering out cells
	
	for x in range(grid.size.x):
		for y in range(grid.size.y):
			for z in range(grid.size.z):
				var pos = Vector3i(x, y, z)
				var cell = grid.get_cell(pos)
				
				# First check if this cell should be part of the solve at all
				if not strategy.should_collapse_cell(cell.position, grid.size):
					# Mark as empty
					cell.mark_empty()
					_remaining_cells -= 1  # Don't count empty cells
				else:
					# Cell will be collapsed - apply semantic tag filtering
					var tags = strategy.get_cell_tags(cell.position, grid.size)
					if not tags.is_empty():
						var before_count = cell.possible_tile_variants.size()
						cell.filter_variants_by_tags(tags)
						
						# If filtering removed all variants, mark as empty
						if cell.possible_tile_variants.is_empty():
							cell.mark_empty()
							_remaining_cells -= 1
							cells_filtered_out += 1
							
							# Track which tag combinations are causing filtering
							var tag_key = ", ".join(tags)
							tag_usage_stats[tag_key] = tag_usage_stats.get(tag_key, 0) + 1
	
	# Warning if many cells were filtered out due to missing tags
	if cells_filtered_out > 0:
		push_warning("[WFC Solver] %d cells filtered out due to missing tile tags!" % cells_filtered_out)
		push_warning("  Required tag combinations:")
		for tag_combo in tag_usage_stats:
			push_warning("    - [%s]: %d cells" % [tag_combo, tag_usage_stats[tag_combo]])
		push_warning("  -> Add these tags to your tiles, or use a strategy without tag requirements (e.g., 'Fill All')")

func _propagate_empty_cells() -> void:
	"""Propagate constraints from all empty cells to ensure neighbors understand empty adjacency"""
	# Empty cells don't constrain their neighbors in WFC
	# This is handled automatically during propagation
	pass

func solve(run_synchronously: bool = false) -> bool:
	print("[WFC Solver] Starting solve...")
	print("  Grid size: ", grid.size)
	print("  Total cells: ", grid.get_cell_count())
	print("  Cells to collapse: ", _remaining_cells)
	print("  Max iterations: ", max_iterations)
	
	# Configure yielding
	_enable_yielding = not run_synchronously
	if run_synchronously:
		print("  Running SYNCHRONOUSLY (no yielding) for maximum speed")
	else:
		print("  Yield interval: ", yield_interval_ms, "ms")
		print("  Propagation batch size: ", propagation_batch_size)
	
	# CRITICAL: Initialize entropy heap for O(log N) cell selection
	print("  Initializing entropy heap...")
	var heap_start = Time.get_ticks_msec()
	grid.initialize_heap()
	var heap_time = Time.get_ticks_msec() - heap_start
	print("  Heap initialized in ", heap_time, "ms")
	
	var iterations = 0
	var last_yield_time = Time.get_ticks_msec()
	var last_progress_time = Time.get_ticks_msec()
	var start_time = Time.get_ticks_msec()

	while _remaining_cells > 0:
		if iterations >= max_iterations:
			push_error("WFC: Max iterations reached (", max_iterations, ")")
			push_error("  Completed iterations: ", iterations)
			return false

		# Yield periodically to keep UI responsive (only if not synchronous)
		var current_time = Time.get_ticks_msec()
		if _enable_yielding and yield_interval_ms > 0 and current_time - last_yield_time > yield_interval_ms:
			await Engine.get_main_loop().process_frame
			last_yield_time = Time.get_ticks_msec()

		# Skip full grid scan - contradictions are caught during propagation

		# Observe: Pick cell with lowest entropy
		var cell_selection_start = Time.get_ticks_msec()
		var cell = grid.get_lowest_entropy_cell()
		if not cell:
			print("[WFC Solver] No more cells to collapse (fully collapsed)")
			break

		if not cell.collapse():
			push_error("WFC: Failed to collapse cell at ", cell.position)
			return false

		# Propagate: Update neighbors based on the collapsed cell
		var propagate_start = Time.get_ticks_msec()
		var propagate_result = await propagate(cell)
		var propagate_time = Time.get_ticks_msec() - propagate_start
		
		# Log slow propagations
		if propagate_time > 1000:
			print("  [WARNING] Iteration ", iterations + 1, " propagation took ", propagate_time, "ms")
		
		if not propagate_result:
			push_error("WFC: Propagation failed at ", cell.position)
			push_error("  Collapsed to: ", cell.get_tile().name if cell.get_tile() else "unknown", " @ ", cell.get_rotation(), "°")
			strategy.finalize()
			return false

		iterations += 1
		_remaining_cells -= 1  # We collapsed one more cell
		
		# Progress reporting at configured interval
		if progress_report_interval_ms > 0:
			current_time = Time.get_ticks_msec()
			if current_time - last_progress_time > progress_report_interval_ms:
				var total_cells = grid.get_cell_count()
				var collapsed_cells = total_cells - _remaining_cells
				var progress = (collapsed_cells / float(total_cells)) * 100.0
				var elapsed_seconds = (current_time - start_time) / 1000.0
				print("[%.1fs] WFC Progress: %.2f%% (%d/%d cells, %d iterations)" % 
					[elapsed_seconds, progress, collapsed_cells, total_cells, iterations])
				last_progress_time = current_time

	var elapsed_seconds = (Time.get_ticks_msec() - start_time) / 1000.0
	print("[WFC Solver] Solve completed successfully!")
	print("  Total iterations: ", iterations)
	print("  Time elapsed: %.2f seconds" % elapsed_seconds)
	print("  Avg iterations/sec: %.0f" % (iterations / max(elapsed_seconds, 0.001)))
	
	strategy.finalize()
	return true

func propagate(start_cell: WfcCell) -> bool:
	var propagation_queue: Array[WfcCell] = [start_cell]
	
	# Reset visited flags (fast memset)
	_visited_flags.fill(0)
	
	# Use pre-computed cardinal directions
	var directions = _directions
	
	# Yield periodically during propagation to prevent lag
	var cells_processed = 0
	var max_queue_size = 1

	# CRITICAL OPTIMIZATION: Use index-based traversal instead of pop_front() which is O(n)
	var head := 0
	while head < propagation_queue.size():
		# Track max queue size for diagnostics
		if propagation_queue.size() > max_queue_size:
			max_queue_size = propagation_queue.size()
		var current_cell = propagation_queue[head]
		head += 1
		
		# Yield during large propagation cascades (batch-based, no time check, only if yielding enabled)
		cells_processed += 1
		if _enable_yielding and propagation_batch_size > 0 and cells_processed % propagation_batch_size == 0:
			await Engine.get_main_loop().process_frame
		
		# Skip propagation if this cell is empty (marked by strategy)
		if current_cell.is_empty():
			continue
		
		# Check if current cell has contradiction before propagating from it
		if current_cell.has_contradiction():
			push_error("  Cell ", current_cell.position, " has contradiction (0 variants) when trying to propagate from it")
			return false

		for direction in directions:
			var neighbor = grid.get_neighbor_in_direction(current_cell.position, direction)
			if not neighbor:
				continue
			
			# Skip if neighbor is empty (strategy-masked cell)
			if neighbor.is_empty():
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

	# Log propagation stats only for very large cascades (reduce spam)
	if cells_processed > 500 or max_queue_size > 200:
		print("    [Propagation] Processed ", cells_processed, " cells, max queue: ", max_queue_size)
	
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
		Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int)
	"""
	# If source cell is empty (strategy-masked), all neighbor variants are valid
	if source_cell.is_empty():
		return neighbor_cell.possible_tile_variants  # No copy needed

	# Reuse scratch array to avoid allocations
	_scratch_variants.clear()
	
	# Pre-fetch to avoid repeated access
	var source_variants: Array[Dictionary] = []
	var source_count: int = 0
	if source_cell.is_collapsed():
		var collapsed_variant := source_cell.get_variant()
		if collapsed_variant.is_empty():
			return neighbor_cell.possible_tile_variants
		source_variants.append(collapsed_variant)
		source_count = 1
	else:
		source_variants = source_cell.possible_tile_variants
		source_count = source_variants.size()
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

			if are_variants_compatible(source_tile, source_rotation, neighbor_tile, neighbor_rotation, direction):
				_scratch_variants.append(neighbor_variant)
				break  # Found compatible match, move to next neighbor variant

	return _scratch_variants

func are_variants_compatible(source_tile: Tile, source_rotation: int, neighbor_tile: Tile, neighbor_rotation: int, direction: Vector3i) -> bool:
	"""
	Check if two tile+rotation variants can be placed adjacent to each other.
	Uses fast array-based caching for O(1) lookups.
	
	Args:
		source_tile: The source tile
		source_rotation: Rotation of source tile in degrees (0, 90, 180, 270)
		neighbor_tile: The neighboring tile
		neighbor_rotation: Rotation of neighbor tile in degrees
		direction: Direction from source to neighbor
	
	Returns:
		true if the variants are compatible, false otherwise
	"""
	# Get variant IDs and direction index for fast cache lookup
	var src_id = _get_variant_id(source_tile, source_rotation)
	var neigh_id = _get_variant_id(neighbor_tile, neighbor_rotation)
	var dir_index = WfcHelper.get_direction_index(direction)
	
	# Check cache first (O(1) array access)
	var cached = _compatibility_cache[src_id][neigh_id][dir_index]
	if cached != null:
		return cached
	
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
	
	var result = false
	
	# Socket compatibility rules:
	# - Both empty (no sockets): compatible (both have open/flat edges)
	# - Both have sockets: check socket compatibility
	# - One empty, one has "none" socket: compatible (no socket = "none" socket)
	# - One empty, one has real socket: incompatible
	
	if source_sockets.is_empty() and neighbor_sockets.is_empty():
		result = true  # Both have no sockets - compatible
	elif source_sockets.is_empty():
		# Source has no sockets - only compatible if neighbor has "none" sockets
		result = true
		for neighbor_socket in neighbor_sockets:
			if neighbor_socket.socket_id != "none":
				result = false
				break
	elif neighbor_sockets.is_empty():
		# Neighbor has no sockets - only compatible if source has "none" sockets
		result = true
		for source_socket in source_sockets:
			if source_socket.socket_id != "none":
				result = false
				break
	else:
		# Both sides have sockets - check compatibility
		for source_socket in source_sockets:
			for neighbor_socket in neighbor_sockets:
				# "none" sockets mean no connection - both sides must be "none"
				if source_socket.socket_id == "none" and neighbor_socket.socket_id == "none":
					result = true
					break
				
				# Allow sockets that explicitly list "none" as compatible to face empty space
				if source_socket.socket_id == "none":
					if "none" in neighbor_socket.compatible_sockets:
						result = true
						break
					continue
				if neighbor_socket.socket_id == "none":
					if "none" in source_socket.compatible_sockets:
						result = true
						break
					continue
				
				if source_socket.is_compatible_with(neighbor_socket) and neighbor_socket.is_compatible_with(source_socket):
					result = true
					break
			
			if result:
				break
	
	# Cache the result (fast array write)
	_compatibility_cache[src_id][neigh_id][dir_index] = result
	return result

func reset() -> void:
	grid.reset()
	# Note: Keep cache - it's valid across resets with same tiles

func get_cache_stats() -> Dictionary:
	"""Get statistics about the compatibility cache for debugging/optimization."""
	var n = grid.all_tile_variants.size()
	var cache_entries = n * n * 6  # Full 3D array size
	return {
		"cache_size": cache_entries,
		"estimated_memory_kb": cache_entries * 0.001  # 1 byte per bool entry
	}

func _prewarm_compatibility_cache() -> void:
	"""Pre-compute compatibility for all tile variant pairs in all directions.
	This trades initialization time for faster solve time on large grids."""
	var directions = WfcHelper.get_cardinal_directions()
	var variants = grid.all_tile_variants
	var total_checks = 0
	
	print("Pre-warming compatibility cache...")
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
	print("Pre-warmed ", total_checks, " compatibility checks in ", elapsed, "ms")
	print("Cache: ", n, "x", n, "x6 array (", n * n * 6, " entries)")

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
				print("✓ Universal tile found: ", variant["tile"].name, " @ ", variant["rotation_degrees"], "° (can connect to itself)")
	
	if universal_count > 1:
		print("  (", universal_count, " total universal variants)")
	
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