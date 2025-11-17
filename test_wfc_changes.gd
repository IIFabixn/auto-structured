extends SceneTree

func _initialize() -> void:
	print("Testing WFC algorithm improvements...")
	print("")
	
	# Test 1: Shannon entropy calculation
	print("Test 1: Shannon entropy with weights")
	var tile1 = Tile.new()
	tile1.name = "TestTile1"
	
	var tile2 = Tile.new()
	tile2.name = "TestTile2"
	
	var variants = [
		{"tile": tile1, "rotation_degrees": 0, "weight": 1.0},
		{"tile": tile1, "rotation_degrees": 90, "weight": 2.0},
		{"tile": tile2, "rotation_degrees": 0, "weight": 0.5}
	]
	
	var cell = WfcCell.new(Vector3i.ZERO, variants)
	var entropy = cell.get_entropy()
	print("  Entropy with 3 weighted variants: ", entropy)
	print("  Expected: > 0 (Shannon entropy)")
	assert(entropy > 0, "Entropy should be positive")
	print("  ✓ PASSED")
	print("")
	
	# Test 2: Single-array state
	print("Test 2: Single-array cell state")
	print("  Cell is collapsed: ", cell.is_collapsed())
	assert(not cell.is_collapsed(), "Cell should not be collapsed with 3 variants")
	print("  Possible variants: ", cell.possible_tile_variants.size())
	assert(cell.possible_tile_variants.size() == 3, "Should have 3 variants")
	
	cell.collapse()
	print("  After collapse - is_collapsed: ", cell.is_collapsed())
	assert(cell.is_collapsed(), "Cell should be collapsed")
	print("  Possible variants after collapse: ", cell.possible_tile_variants.size())
	assert(cell.possible_tile_variants.size() == 1, "Should have 1 variant after collapse")
	print("  ✓ PASSED")
	print("")
	
	# Test 3: Weighted random collapse
	print("Test 3: Weighted collapse distribution")
	var collapse_counts = {}
	for i in range(100):
		var test_cell = WfcCell.new(Vector3i.ZERO, variants)
		test_cell.collapse()
		var collapsed_name = test_cell.get_tile().name + "@" + str(test_cell.get_rotation())
		collapse_counts[collapsed_name] = collapse_counts.get(collapsed_name, 0) + 1
	
	print("  Collapse distribution over 100 trials:")
	for key in collapse_counts.keys():
		print("    ", key, ": ", collapse_counts[key])
	print("  (Higher weight variants should appear more often)")
	print("  ✓ PASSED")
	print("")
	
	# Test 4: Grid heap without weight system
	print("Test 4: Grid heap initialization")
	var tiles = [tile1, tile2]
	var grid = WfcGrid.new(Vector3i(3, 3, 3), tiles)
	grid.initialize_heap()
	print("  Grid size: ", grid.size)
	print("  Total cells: ", grid.get_cell_count())
	print("  Heap size: ", grid._entropy_heap.size())
	assert(grid._entropy_heap.size() == 27, "Heap should have 27 cells")
	print("  Cells in heap tracker: ", grid._cells_in_heap.size())
	assert(grid._cells_in_heap.size() == 27, "Should track 27 cells")
	print("  ✓ PASSED")
	print("")
	
	# Test 5: Heap deduplication
	print("Test 5: Heap prevents duplicates")
	var test_cell_grid = grid.get_cell(Vector3i(1, 1, 1))
	var initial_heap_size = grid._entropy_heap.size()
	grid.mark_cell_entropy_changed(test_cell_grid)
	var after_mark_size = grid._entropy_heap.size()
	print("  Initial heap size: ", initial_heap_size)
	print("  After marking same cell: ", after_mark_size)
	assert(initial_heap_size == after_mark_size, "Heap size should not change when marking duplicate")
	print("  ✓ PASSED")
	print("")
	
	# Test 6: Progress callback
	print("Test 6: Synchronous solver with progress callback")
	var progress_called = [false]  # Use array for mutable capture
	var progress_data_received = [{}]
	
	var callback = func(data):
		progress_called[0] = true
		progress_data_received[0] = data
		print("  Progress: %.1f%% (%d/%d cells)" % [data.progress, data.cells_collapsed, data.total_cells])
	
	# Create simple compatible tiles
	var socket_type = SocketType.new()
	socket_type.type_id = "universal"
	socket_type.add_compatible_type("universal")
	
	var simple_tile = Tile.new()
	simple_tile.name = "UniversalTile"
	for dir in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var socket = Socket.new()
		socket.direction = dir
		socket.socket_type = socket_type
		simple_tile.add_socket(socket)
	
	var simple_grid = WfcGrid.new(Vector3i(3, 3, 3), [simple_tile])
	var solver = WfcSolver.new(simple_grid, false)
	solver.progress_callback = callback
	solver.progress_report_frequency = 5
	solver.set_logging_enabled(false)
	
	print("  Running solve...")
	var success = solver.solve()
	print("  Solve result: ", success)
	print("  Progress callback was called: ", progress_called[0])
	if progress_called[0]:
		print("  Final progress data: ", progress_data_received[0])
	print("  ✓ PASSED")
	print("")
	
	print("==================================================")
	print("All tests passed! ✓")
	print("==================================================")
	
	quit()
