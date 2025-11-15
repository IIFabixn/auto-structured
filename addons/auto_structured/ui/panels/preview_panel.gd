@tool
class_name PreviewPanel extends Control
## 3D preview panel for tiles and socket compatibility visualization.
##
## Main functions:
##   - preview_tile(tile): Show a single tile preview
##   - preview_socket(tile, socket, compatible_tiles): Show tile with compatible tiles for a socket

const CYCLE_DELAY: float = 3.0  # seconds between cycling compatible tiles

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const WfcStrategyBase = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd")
const Viewport3DGrid = preload("res://addons/auto_structured/ui/controls/viewport_3d_grid.gd")
const ViewportCameraController = preload("res://addons/auto_structured/ui/controls/viewport_camera_controller.gd")
const PreviewSettingsDialog = preload("res://addons/auto_structured/ui/dialogs/preview_settings_dialog.tscn")

const DEFAULT_CELL_WORLD_SIZE: Vector3 = Vector3(2, 3, 2)

# Camera controller
var camera_controller: ViewportCameraController = null

# Compatible tiles cycling
var compatible_results: Array[Dictionary] = []  # Array of {tile: Tile, socket: Socket} dictionaries
var current_compatible_index: int = 0
var cycle_timer: float = 0.0
var is_cycling: bool = false
var preview_root: Node3D = null  # Root node containing the main tile and compatible tiles
var main_tile: Tile = null  # The main tile being previewed
var main_socket: Socket = null  # The socket on the main tile that we're previewing from
var current_cell_world_size: Vector3 = DEFAULT_CELL_WORLD_SIZE
var current_tile_instance: Node3D = null
var library_cell_world_size: Vector3 = DEFAULT_CELL_WORLD_SIZE

# WFC generation state
var wfc_grid: WfcGrid = null
var wfc_solver: WfcSolver = null
var wfc_strategy: WfcStrategyBase = null
var module_library: ModuleLibrary = null
var is_generating: bool = false

# Settings dialog
var settings_dialog: Control = null

@onready var viewport: SubViewport = %PreviewViewport
@onready var camera: Camera3D = %PreviewCamera
@onready
var viewport_container: SubViewportContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/Panel/SubViewportContainer
@onready var viewport_options: MenuButton = %ViewportOptions
@onready var new_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/NewButton
@onready var step_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/StepButton
@onready var solve_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/SolveButton
@onready var top_bar_menu: MenuButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/MenuButton

# Grid and origin visualization
var viewport_grid: Viewport3DGrid = null


func _ready() -> void:
	# Initialize camera controller
	camera_controller = ViewportCameraController.new(camera, viewport_container)
	camera_controller.frame_structure()  # Initialize camera position
	viewport_container.gui_input.connect(_on_viewport_gui_input)
	
	# Create grid and origin
	viewport_grid = Viewport3DGrid.new()
	viewport.add_child(viewport_grid)

	# Connect viewport options menu
	var popup = viewport_options.get_popup()
	popup.id_pressed.connect(_on_viewport_option_selected)
	popup.set_item_checked(0, camera_controller.get_auto_rotate())
	popup.add_separator()
	popup.add_check_item("Show Grid", 2)
	popup.set_item_checked(popup.get_item_index(2), viewport_grid.show_grid if viewport_grid else true)
	popup.add_check_item("Show Origin", 3)
	popup.set_item_checked(popup.get_item_index(3), viewport_grid.show_origin if viewport_grid else true)
	
	# Initialize settings dialog immediately
	_initialize_settings_dialog()
	
	# Update button states
	_update_button_states()


func _initialize_settings_dialog() -> void:
	"""Initialize the settings dialog"""
	if not settings_dialog:
		# Instantiate settings UI
		settings_dialog = PreviewSettingsDialog.instantiate()
		# Add to scene tree (hidden) so _ready() gets called and it initializes properly
		add_child(settings_dialog)
		settings_dialog.hide()
		settings_dialog.apply_requested.connect(_on_settings_apply_requested)
		settings_dialog.cell_size_changed.connect(_on_cell_size_changed)
		settings_dialog.set_cell_size(library_cell_world_size, false)


func _process(delta: float) -> void:
	# Update camera controller
	if camera_controller:
		camera_controller.process(delta)
	
	# Handle compatible tiles cycling
	if is_cycling and compatible_results.size() > 0:
		cycle_timer -= delta
		if cycle_timer <= 0.0:
			cycle_timer = CYCLE_DELAY
			_show_next_compatible_tile()

func on_edit_preview_settings_pressed():
	"""Show the preview settings dialog"""
	if not settings_dialog:
		_initialize_settings_dialog()
	
	# Check if dialog is already in a popup window
	var parent = settings_dialog.get_parent()
	if parent is AcceptDialog:
		# Just show the existing dialog
		parent.popup_centered()
	else:
		# Create dialog wrapper for first time showing
		var dialog = AcceptDialog.new()
		dialog.title = "Preview Settings"
		dialog.min_size = Vector2i(400, 300)
		
		# Remove from current parent and add to dialog
		if parent:
			parent.remove_child(settings_dialog)
		dialog.add_child(settings_dialog)
		settings_dialog.show()
		
		# Handle dialog close (hide instead of destroy)
		dialog.confirmed.connect(func():
			dialog.hide()
		)
		dialog.canceled.connect(func():
			dialog.hide()
		)
		
		# Add to scene and show
		add_child(dialog)
		dialog.popup_centered()


func _on_settings_apply_requested(_strategy: WfcStrategyBase) -> void:
	# Reuse the existing generation workflow triggered by the "New" button
	_on_new_button_pressed()

func _on_viewport_option_selected(id: int) -> void:
	var popup = viewport_options.get_popup()
	match id:
		0:  # Auto Rotate
			if camera_controller:
				camera_controller.set_auto_rotate(!camera_controller.get_auto_rotate())
				popup.set_item_checked(0, camera_controller.get_auto_rotate())
		1:  # Reset Camera
			stop_compatible_tiles_preview()
			frame_structure()
		2:  # Show Grid
			if viewport_grid:
				viewport_grid.show_grid = !viewport_grid.show_grid
				popup.set_item_checked(popup.get_item_index(2), viewport_grid.show_grid)
		3:  # Show Origin
			if viewport_grid:
				viewport_grid.show_origin = !viewport_grid.show_origin
				popup.set_item_checked(popup.get_item_index(3), viewport_grid.show_origin)


func _on_viewport_gui_input(event: InputEvent) -> void:
	"""Delegate input events to the camera controller"""
	if camera_controller:
		camera_controller.handle_input(event)


func frame_structure() -> void:
	"""Frame the camera to show the entire structure"""
	# TODO: Calculate bounds of all structure nodes and adjust camera
	if camera_controller:
		camera_controller.frame_structure()


func add_structure_node(node: Node3D) -> void:
	"""Add a generated structure to the viewport for preview"""
	viewport.add_child(node)


func preview_tile(tile: Tile) -> void:
	"""Display a preview of a tile (no socket preview)"""
	# Stop any socket preview
	stop_compatible_tiles_preview()
	current_cell_world_size = library_cell_world_size
	
	# Clear and recreate the preview
	clear_structure()
	_create_tile_instance(tile)
	
	# Store the main tile reference
	main_tile = tile
	
	frame_structure()


func preview_socket(tile: Tile, socket: Socket, compatible_tiles: Array[Dictionary]) -> void:
	"""
	Display a preview of a tile with its socket's compatible tiles.
	
	Args:
		tile: The main tile to preview
		socket: The socket on the tile to show compatible connections for
		compatible_tiles: Array of {tile: Tile, socket: Socket} dictionaries
	"""
	# Clear previous preview
	stop_compatible_tiles_preview()
	current_cell_world_size = library_cell_world_size
	clear_structure()
	
	# Create the main tile instance
	_create_tile_instance(tile)
	
	# Store references
	main_tile = tile
	main_socket = socket
	
	# Start cycling through compatible tiles if any exist
	if compatible_tiles.size() > 0:
		compatible_results = compatible_tiles
		is_cycling = true
		cycle_timer = CYCLE_DELAY
		_show_compatible_tile(0)
	else:
		push_warning("No compatible tiles found for socket: %s" % socket.socket_id)
	
	frame_structure()


func _create_tile_instance(tile: Tile) -> void:
	"""Create the main tile instance in the preview"""
	if not tile:
		return
	
	# Create preview root if needed
	if not preview_root:
		preview_root = Node3D.new()
		preview_root.name = "PreviewRoot"
		add_structure_node(preview_root)
	
	var instance: Node3D = null
	if tile.scene != null:
		instance = tile.scene.instantiate()
		if not instance is Node3D:
			push_error("Tile %s scene is not a Node3D" % tile.name)
			return
	elif tile.mesh != null:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = tile.mesh
		instance = mesh_instance
	else:
		push_error("Tile has no scene assigned")
		return
	
	# Add the main tile as a child of the root
	instance.name = "MainTile"
	preview_root.add_child(instance)
	current_tile_instance = instance
	current_cell_world_size = library_cell_world_size


func _get_effective_cell_size() -> Vector3:
	var size := current_cell_world_size
	if size.x <= 0.0001:
		size.x = DEFAULT_CELL_WORLD_SIZE.x
	if size.y <= 0.0001:
		size.y = DEFAULT_CELL_WORLD_SIZE.y
	if size.z <= 0.0001:
		size.z = DEFAULT_CELL_WORLD_SIZE.z
	return size

func _ensure_cell_world_size_from_library() -> void:
	current_cell_world_size = library_cell_world_size

func _refresh_library_cell_size() -> void:
	var size := DEFAULT_CELL_WORLD_SIZE
	if module_library:
		var lib_size: Vector3 = module_library.cell_world_size
		if lib_size.x > 0.0 and lib_size.y > 0.0 and lib_size.z > 0.0:
			size = lib_size
	library_cell_world_size = size
	current_cell_world_size = library_cell_world_size
	if settings_dialog:
		settings_dialog.set_cell_size(library_cell_world_size, false)


func _on_cell_size_changed(new_size: Vector3) -> void:
	var clamped_size = Vector3(
		max(new_size.x, 0.1),
		max(new_size.y, 0.1),
		max(new_size.z, 0.1)
	)
	if library_cell_world_size == clamped_size:
		return

	library_cell_world_size = clamped_size
	current_cell_world_size = library_cell_world_size
	if settings_dialog:
		settings_dialog.set_cell_size(library_cell_world_size, false)
	if module_library and module_library.cell_world_size != clamped_size:
		module_library.cell_world_size = clamped_size
		if module_library.resource_path != "":
			ResourceSaver.save(module_library, module_library.resource_path)

	if wfc_grid:
		_visualize_grid()
	elif main_tile:
		preview_tile(main_tile)

func clear_structure() -> void:
	"""Remove all structure nodes from the viewport"""
	for child in viewport.get_children():
		if child is Node3D and child != camera and child != viewport_grid:
			child.queue_free()
	preview_root = null
	main_tile = null
	main_socket = null
	current_tile_instance = null
	current_cell_world_size = library_cell_world_size


func get_viewport_world() -> World3D:
	"""Get the 3D world of the preview viewport"""
	return viewport.world_3d

func stop_compatible_tiles_preview() -> void:
	"""Stop cycling through compatible tiles and remove only the preview tile"""
	is_cycling = false
	compatible_results.clear()
	current_compatible_index = 0
	cycle_timer = 0.0
	main_socket = null
	# Note: main_tile is not cleared here as it's still being previewed
	_remove_compatible_tile_preview()
	current_cell_world_size = library_cell_world_size

func _show_next_compatible_tile() -> void:
	"""Show the next tile in the compatible tiles list"""
	if compatible_results.size() == 0:
		return
	
	current_compatible_index = (current_compatible_index + 1) % compatible_results.size()
	_show_compatible_tile(current_compatible_index)

func _remove_compatible_tile_preview() -> void:
	"""Remove the compatible tile preview but keep the main tile"""
	if not preview_root:
		return
	
	# Remove all children except the MainTile
	for child in preview_root.get_children():
		if child.name != "MainTile":
			child.queue_free()

func _show_compatible_tile(index: int) -> void:
	"""Display a specific compatible tile with translucent appearance next to the current tile"""
	if index < 0 or index >= compatible_results.size():
		return
	
	if not preview_root or not main_socket:
		return
	
	# Remove previous compatible tile preview
	_remove_compatible_tile_preview()
	
	var result = compatible_results[index]
	var tile: Tile = result["tile"]
	var predetermined_rotation: float = result.get("rotation_degrees", 0.0)
	var instance: Node3D = null
	
	# Try to instantiate from scene first, then mesh
	if tile.scene != null:
		instance = tile.scene.instantiate()
	elif tile.mesh != null:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = tile.mesh
		instance = mesh_instance
	
	if instance:
		instance.name = "CompatibleTile"
		
		# Apply rotation first (this affects the tile's socket directions)
		instance.transform.basis = Basis(Vector3.UP, deg_to_rad(predetermined_rotation))
		
		# Get tile sizes
		var main_tile_cells: Vector3i = main_tile.size if main_tile else Vector3i.ONE
		var compatible_tile_cells: Vector3i = tile.size
		var main_tile_size = Vector3(float(main_tile_cells.x), float(main_tile_cells.y), float(main_tile_cells.z))
		var rotated_compatible_size = WfcHelper.get_rotated_size_in_cells(compatible_tile_cells, predetermined_rotation)
		
		# Position the compatible tile adjacent to the main tile
		var main_direction = main_socket.direction
		var cell_size = _get_effective_cell_size()
		var calculated_position = WfcHelper.calculate_adjacent_tile_position(
			main_tile_size,
			rotated_compatible_size,
			main_direction,
			cell_size
		)
		var rotation_offset = WfcHelper.get_rotation_offset_world(compatible_tile_cells, predetermined_rotation, cell_size)
		instance.position = calculated_position + rotation_offset
		
		# Make the preview translucent
		_make_translucent(instance)
		
		# Add as child to the preview root
		preview_root.add_child(instance)

func _make_translucent(node: Node3D) -> void:
	"""Recursively make all meshes in the node translucent"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		
		# Process all surface materials for this mesh
		var surface_count = mesh_instance.get_surface_override_material_count()
		if surface_count == 0 and mesh_instance.mesh:
			surface_count = mesh_instance.mesh.get_surface_count()
		
		for surface_idx in range(surface_count):
			var material: Material = mesh_instance.get_surface_override_material(surface_idx)
			if not material:
				material = mesh_instance.get_active_material(surface_idx)
			
			if material:
				# Duplicate the material to avoid modifying the original
				material = material.duplicate()
			else:
				material = StandardMaterial3D.new()
			
			if material is StandardMaterial3D:
				var std_mat = material as StandardMaterial3D
				std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				std_mat.albedo_color.a = 0.5  # 50% opacity
				mesh_instance.set_surface_override_material(surface_idx, std_mat)
	
	# Recursively apply to children
	for child in node.get_children():
		if child is Node3D:
			_make_translucent(child)


# =============================================================================
# WFC Generation Control
# =============================================================================

func set_module_library(library: ModuleLibrary) -> void:
	"""Set the module library to use for generation"""
	module_library = library
	if not settings_dialog:
		_initialize_settings_dialog()
	if settings_dialog and settings_dialog.has_method("set_module_library"):
		settings_dialog.set_module_library(library)
	_refresh_library_cell_size()
	_update_button_states()


func set_grid_size(size: Vector3i) -> void:
	"""Set the grid size for generation"""
	if settings_dialog:
		settings_dialog.set_grid_size(size)
	print("WFC grid size set to: ", size)


func _update_button_states() -> void:
	"""Update button enabled/disabled states based on current state"""
	if not new_button:
		return
	
	var has_library = module_library != null and module_library.tiles.size() > 0
	new_button.disabled = not has_library
	step_button.disabled = not is_generating
	solve_button.disabled = not is_generating


func _on_new_button_pressed() -> void:
	"""Start a new WFC generation"""
	print("\n=== Initiating WFC Generation ===")
	
	# Clean up any existing generation first
	if is_generating:
		print("Stopping previous generation...")
		_finish_generation()
	
	if not module_library or module_library.tiles.is_empty():
		push_warning("No module library or tiles available")
		return
	
	if not settings_dialog:
		push_error("Settings dialog not initialized")
		return
	
	# Get settings from dialog
	var grid_size = settings_dialog.get_grid_size()
	wfc_strategy = settings_dialog.get_current_strategy()
	_on_cell_size_changed(settings_dialog.get_cell_size())
	
	if not wfc_strategy:
		push_error("No strategy selected")
		return
	
	print("\n=== Starting New WFC Generation ===")
	print("Grid size: ", grid_size)
	print("Available tiles: ", module_library.tiles.size())
	print("Strategy: ", wfc_strategy.get_name())
	
	# Stop any current preview
	stop_compatible_tiles_preview()
	clear_structure()
	
	# Create new grid and solver with fresh state
	wfc_grid = WfcGrid.from_library(grid_size, module_library)
	wfc_solver = WfcSolver.new(wfc_grid, wfc_strategy)
	is_generating = true
	
	print("Grid created with ", wfc_grid.get_cell_count(), " cells")
	print("Waiting for user to step through or solve...")
	
	# Visualize the initial empty grid
	_visualize_grid()
	
	_update_button_states()
	frame_structure()


func _on_step_button_pressed() -> void:
	"""Execute one step of WFC generation (collapse one cell)"""
	if not is_generating or not wfc_grid or not wfc_solver:
		return
	
	if wfc_grid.is_fully_collapsed():
		print("Generation complete!")
		_finish_generation()
		return
	
	if wfc_grid.has_contradiction():
		push_error("WFC: Contradiction detected - cannot continue")
		_finish_generation()
		return
	
	# Get the cell with lowest entropy
	var cell = wfc_grid.get_lowest_entropy_cell()
	if not cell:
		print("Generation complete!")
		_finish_generation()
		return
	
	print("\n[Step] Collapsing cell at ", cell.position, " (entropy: ", cell.get_entropy(), ")")
	
	# Collapse the cell
	if not cell.collapse():
		push_error("WFC: Failed to collapse cell at ", cell.position)
		_finish_generation()
		return
	
	var variant = cell.get_variant()
	print("  Selected: ", variant["tile"].name, " at ", variant["rotation_degrees"], "°")
	
	# Propagate constraints (now async)
	var propagate_success = await wfc_solver.propagate(cell)
	if not propagate_success:
		push_error("WFC: Propagation failed at ", cell.position)
		_finish_generation()
		return
	
	# Update visualization
	_visualize_grid()


func _on_solve_button_pressed() -> void:
	"""Solve the entire WFC generation automatically"""
	if not is_generating or not wfc_grid or not wfc_solver:
		print("⚠ Cannot solve: not generating or missing grid/solver")
		return
	
	print("\n=== Solving WFC Automatically ===")
	print("Starting solve with ", wfc_grid.get_cell_count(), " cells...")
	
	var success = false
	var error_message = ""
	
	# Wrap in try-catch equivalent to handle any errors
	var solve_result = await wfc_solver.solve()
	
	if solve_result == null:
		error_message = "Solver returned null (unexpected error)"
	elif typeof(solve_result) == TYPE_BOOL:
		success = solve_result
	else:
		error_message = "Solver returned unexpected type: " + str(typeof(solve_result))
	
	print("\n=== Solve Complete ===")
	if success:
		print("✓ WFC generation SUCCESSFUL!")
		_print_grid_summary()
	else:
		push_error("✗ WFC generation FAILED!")
		if error_message:
			push_error("  Error: ", error_message)
		if wfc_grid and wfc_grid.has_contradiction():
			push_error("  Reason: Contradiction detected")
	
	# Update visualization
	_visualize_grid()
	
	_finish_generation()


func _finish_generation() -> void:
	"""Clean up after generation is complete or failed"""
	is_generating = false
	_update_button_states()


func _visualize_grid() -> void:
	"""Visualize the current state of the WFC grid"""
	if not wfc_grid:
		return
	
	# Clear previous structure
	clear_structure()
	_ensure_cell_world_size_from_library()
	var cell_size = _get_effective_cell_size()
	
	# Create preview root
	preview_root = Node3D.new()
	preview_root.name = "WfcStructure"
	add_structure_node(preview_root)
	
	# Calculate center offset to center the grid at origin
	var center_offset = Vector3.ZERO
	if wfc_grid.get_cell_count() > 0 and settings_dialog:
		var grid_size = settings_dialog.get_grid_size()
		center_offset = Vector3(
			(grid_size.x - 1) * cell_size.x * 0.5,
			(grid_size.y - 1) * cell_size.y * 0.5,
			(grid_size.z - 1) * cell_size.z * 0.5
		)
	
	# Instantiate all collapsed cells
	for cell in wfc_grid.get_all_cells():
		if not cell.is_collapsed():
			continue
		
		var variant = cell.get_variant()
		
		# Skip empty cells (cells marked as empty by strategy)
		if variant.is_empty():
			continue
		
		var tile: Tile = variant.get("tile")
		var rotation: int = variant.get("rotation_degrees", 0)
		
		if not tile:
			continue
		
		var instance: Node3D = null
		if tile.scene != null:
			instance = tile.scene.instantiate()
		elif tile.mesh != null:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = tile.mesh
			instance = mesh_instance
		
		if instance:
			# Apply rotation and keep tiles anchored to their grid cell origin
			instance.transform.basis = Basis(Vector3.UP, deg_to_rad(rotation))

			# Position based on grid position, rotation offset, and cell size, centered at origin
			var world_pos = WfcHelper.grid_to_world(cell.position, cell_size)
			var rotation_offset = WfcHelper.get_rotation_offset_world(tile.size, rotation, cell_size)
			instance.position = world_pos + rotation_offset - center_offset
			
			instance.name = "Cell_%d_%d_%d" % [cell.position.x, cell.position.y, cell.position.z]
			preview_root.add_child(instance)
	
	frame_structure()


func _print_grid_summary() -> void:
	"""Print a summary of the generated grid"""
	if not wfc_grid:
		return
	
	var collapsed_count = 0
	var tile_counts = {}
	
	for cell in wfc_grid.get_all_cells():
		if cell.is_collapsed():
			collapsed_count += 1
			var tile = cell.get_tile()
			if tile:
				var key = tile.name
				tile_counts[key] = tile_counts.get(key, 0) + 1
	
	print("\nGrid Summary:")
	print("  Collapsed cells: ", collapsed_count, " / ", wfc_grid.get_cell_count())
	print("  Tile distribution:")
	for tile_name in tile_counts.keys():
		print("    - ", tile_name, ": ", tile_counts[tile_name])


