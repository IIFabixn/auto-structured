@tool
extends Node

@export var module_library: ModuleLibrary
@export var grid_size: Vector3i = Vector3i(5, 1, 5)
@export var run_test: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			test_wfc_generation()

func test_wfc_generation():
	if not module_library:
		print("ERROR: No module library assigned!")
		return
	
	if module_library.tiles.is_empty():
		print("ERROR: Module library has no tiles!")
		return
	
	print("\n=== WFC Test Started ===")
	print("Grid size: ", grid_size)
	print("Available tiles: ", module_library.tiles.size())
	for tile in module_library.tiles:
		print("  - ", tile.name, " with ", tile.sockets.size(), " sockets")
	
	# Create grid
	var wfc_grid = WfcGrid.from_library(grid_size, module_library)
	print("Created grid with ", wfc_grid.cells.size(), " cells")
	
	# Calculate total possible variants
	var first_cell = wfc_grid.get_cell(Vector3i.ZERO)
	if first_cell:
		print("Each cell starts with ", first_cell.possible_tile_variants.size(), " possible variants")
	
	# Create solver
	var solver = WfcSolver.new(wfc_grid)
	
	# Run solver
	print("\nRunning WFC solver...")
	var success = solver.solve()
	
	if success:
		print("✓ WFC generation SUCCESSFUL!")
		print_grid_summary(wfc_grid)
	else:
		print("✗ WFC generation FAILED!")
		if wfc_grid.has_contradiction():
			print("  Reason: Contradiction detected")
			print_contradictions(wfc_grid)
	
	print("=== WFC Test Ended ===\n")

func print_grid_summary(wfc_grid: WfcGrid):
	var collapsed_count = 0
	var tile_counts = {}
	
	for cell in wfc_grid.cells.values():
		if cell.is_collapsed():
			collapsed_count += 1
			var tile = cell.get_tile()
			if tile:
				var key = tile.name
				tile_counts[key] = tile_counts.get(key, 0) + 1
	
	print("\nGrid Summary:")
	print("  Collapsed cells: ", collapsed_count, " / ", wfc_grid.cells.size())
	print("  Tile distribution:")
	for tile_name in tile_counts.keys():
		print("    - ", tile_name, ": ", tile_counts[tile_name])

func print_contradictions(wfc_grid: WfcGrid):
	var contradiction_cells = []
	for cell in wfc_grid.cells.values():
		if cell.has_contradiction():
			contradiction_cells.append(cell.position)
	
	print("  Cells with contradictions: ", contradiction_cells.size())
	if contradiction_cells.size() <= 10:
		for pos in contradiction_cells:
			print("    - ", pos)
