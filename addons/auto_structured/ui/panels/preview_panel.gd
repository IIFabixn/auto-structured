@tool
class_name PreviewPanel extends Control
## 3D preview panel for tiles and socket compatibility visualization.
##
## Main functions:
##   - preview_tile(tile): Show a single tile preview
##   - preview_socket(tile, socket, compatible_tiles): Show tile with compatible tiles for a socket

const RESUME_DELAY: float = 2.0  # seconds before auto-rotate resumes
const CYCLE_DELAY: float = 3.0  # seconds between cycling compatible tiles

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")
const WfcGrid = preload("res://addons/auto_structured/core/wfc/wfc_grid.gd")
const WfcSolver = preload("res://addons/auto_structured/core/wfc/wfc_solver.gd")
const WfcStrategyBase = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd")
const WfcStrategyFillAll = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_fill_all.gd")
const WfcStrategySparse = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_sparse.gd")
const WfcStrategyPerimeter = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_perimeter.gd")
const WfcStrategyGroundWalls = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_ground_walls.gd")
const Viewport3DGrid = preload("res://addons/auto_structured/ui/controls/viewport_3d_grid.gd")

var camera_distance: float = 10.0
var camera_rotation: Vector2 = Vector2(15, 45)  # pitch, yaw in degrees
var camera_target: Vector3 = Vector3.ZERO
var is_rotating: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2
var viewport_rect: Rect2

# Camera smoothing
var target_camera_position: Vector3 = Vector3.ZERO
var camera_lerp_speed: float = 10.0  # Higher = snappier, lower = smoother

# Viewport options
@export var auto_rotate: bool = true
var auto_rotate_paused: bool = false
var resume_timer: float = 0.0

# Compatible tiles cycling
var compatible_results: Array[Dictionary] = []  # Array of {tile: Tile, socket: Socket} dictionaries
var current_compatible_index: int = 0
var cycle_timer: float = 0.0
var is_cycling: bool = false
var preview_root: Node3D = null  # Root node containing the main tile and compatible tiles
var main_tile: Tile = null  # The main tile being previewed
var main_socket: Socket = null  # The socket on the main tile that we're previewing from

# WFC generation state
var wfc_grid: WfcGrid = null
var wfc_solver: WfcSolver = null
var wfc_strategy: WfcStrategyBase = null
var module_library: ModuleLibrary = null
var grid_size: Vector3i = Vector3i(5, 1, 5)
var available_strategies: Array[WfcStrategyBase] = []
var current_strategy_index: int = 0
var is_generating: bool = false

@onready var viewport: SubViewport = %PreviewViewport
@onready var camera: Camera3D = %PreviewCamera
@onready
var viewport_container: SubViewportContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/Panel/SubViewportContainer
@onready var viewport_options: MenuButton = %ViewportOptions
@onready var new_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/NewButton
@onready var step_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/StepButton
@onready var solve_button: TextureButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/SolveButton
@onready var top_bar_menu: MenuButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/TopBar/MenuButton
@onready var x_spinbox: SpinBox = %XSpinBox
@onready var y_spinbox: SpinBox = %YSpinBox
@onready var z_spinbox: SpinBox = %ZSpinBox
@onready var strategy_option: OptionButton = %StrategyOption

# Grid and origin visualization
var viewport_grid: Viewport3DGrid = null


func _ready() -> void:
	update_camera_transform()
	viewport_container.gui_input.connect(_on_viewport_gui_input)
	viewport_rect = viewport_container.get_global_rect()
	
	# Create grid and origin
	viewport_grid = Viewport3DGrid.new()
	viewport.add_child(viewport_grid)

	# Connect viewport options menu
	var popup = viewport_options.get_popup()
	popup.id_pressed.connect(_on_viewport_option_selected)
	popup.set_item_checked(0, auto_rotate)
	popup.add_separator()
	popup.add_check_item("Show Grid", 2)
	popup.set_item_checked(popup.get_item_index(2), viewport_grid.show_grid if viewport_grid else true)
	popup.add_check_item("Show Origin", 3)
	popup.set_item_checked(popup.get_item_index(3), viewport_grid.show_origin if viewport_grid else true)
	
	# Discover and initialize available strategies automatically
	_discover_strategies()
	current_strategy_index = 0
	
	# Initialize grid size spinboxes
	x_spinbox.value = grid_size.x
	y_spinbox.value = grid_size.y
	z_spinbox.value = grid_size.z
	x_spinbox.value_changed.connect(_on_grid_size_changed)
	y_spinbox.value_changed.connect(_on_grid_size_changed)
	z_spinbox.value_changed.connect(_on_grid_size_changed)
	
	# Initialize strategy dropdown (clear first to avoid duplicates)
	strategy_option.clear()
	for strategy in available_strategies:
		strategy_option.add_item(strategy.get_name())
	strategy_option.selected = current_strategy_index
	strategy_option.item_selected.connect(_on_strategy_selected)
	
	# Update button states
	_update_button_states()


func _process(delta: float) -> void:
	# Handle auto-rotate resume timer
	if auto_rotate_paused:
		resume_timer -= delta
		if resume_timer <= 0.0:
			auto_rotate_paused = false

	# Apply auto-rotation
	if auto_rotate and not auto_rotate_paused and not is_rotating and not is_panning:
		camera_rotation.y += delta * 15.0  # Rotate 15 degrees per second
		update_camera_transform()
	
	# Smooth camera movement
	if camera and target_camera_position != Vector3.ZERO:
		camera.global_position = camera.global_position.lerp(target_camera_position, delta * camera_lerp_speed)
	
	# Handle compatible tiles cycling
	if is_cycling and compatible_results.size() > 0:
		cycle_timer -= delta
		if cycle_timer <= 0.0:
			cycle_timer = CYCLE_DELAY
			_show_next_compatible_tile()


func _on_viewport_option_selected(id: int) -> void:
	var popup = viewport_options.get_popup()
	match id:
		0:  # Auto Rotate
			auto_rotate = !auto_rotate
			popup.set_item_checked(0, auto_rotate)
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				viewport_rect = viewport_container.get_global_rect()
				# Pause auto-rotation during interaction
				auto_rotate_paused = true
				# Check shift directly from Input singleton
				if Input.is_key_pressed(KEY_SHIFT):
					is_panning = true
				else:
					is_rotating = true
				last_mouse_pos = get_global_mouse_position()
				viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			else:
				is_rotating = false
				is_panning = false
				viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Start resume timer
				resume_timer = RESUME_DELAY

		# Zoom with scroll wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(2.0, camera_distance - 1.0)
			update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(50.0, camera_distance + 1.0)
			update_camera_transform()

	elif event is InputEventMouseMotion:
		if is_rotating or is_panning:
			# Update mode based on current shift state
			var shift_now = Input.is_key_pressed(KEY_SHIFT)
			if shift_now and not is_panning:
				is_panning = true
				is_rotating = false
			elif not shift_now and not is_rotating:
				is_rotating = true
				is_panning = false

			var current_mouse = get_global_mouse_position()
			var delta = current_mouse - last_mouse_pos

			if is_rotating:
				camera_rotation.y -= delta.x * 0.5
				camera_rotation.x = clamp(camera_rotation.x - delta.y * 0.5, -89, 89)
				update_camera_transform()

			elif is_panning:
				delta *= 0.01
				var right = camera.global_transform.basis.x
				var up = Vector3.UP
				camera_target -= right * delta.x * camera_distance * 0.1
				camera_target += up * delta.y * camera_distance * 0.1
				update_camera_transform()

			# Wrap cursor at viewport edges
			var wrapped_pos = current_mouse
			var wrapped = false

			if current_mouse.x <= viewport_rect.position.x:
				wrapped_pos.x = viewport_rect.end.x - 2
				wrapped = true
			elif current_mouse.x >= viewport_rect.end.x:
				wrapped_pos.x = viewport_rect.position.x + 2
				wrapped = true

			if current_mouse.y <= viewport_rect.position.y:
				wrapped_pos.y = viewport_rect.end.y - 2
				wrapped = true
			elif current_mouse.y >= viewport_rect.end.y:
				wrapped_pos.y = viewport_rect.position.y + 2
				wrapped = true

			if wrapped:
				get_viewport().warp_mouse(wrapped_pos)
				last_mouse_pos = wrapped_pos
			else:
				last_mouse_pos = current_mouse


func update_camera_transform() -> void:
	"""Update camera position based on orbit controls"""
	if not camera:
		return

	var pitch_rad = deg_to_rad(camera_rotation.x)
	var yaw_rad = deg_to_rad(camera_rotation.y)

	var offset = (
		Vector3(cos(pitch_rad) * sin(yaw_rad), sin(pitch_rad), cos(pitch_rad) * cos(yaw_rad))
		* camera_distance
	)

	# Set target position for smooth interpolation
	target_camera_position = camera_target + offset
	
	# For immediate updates (like mouse drag), skip interpolation
	if is_rotating or is_panning:
		camera.global_position = target_camera_position
	
	# Always update look_at immediately for smooth rotation
	camera.look_at(camera_target, Vector3.UP)


func frame_structure() -> void:
	"""Frame the camera to show the entire structure"""
	# TODO: Calculate bounds of all structure nodes and adjust camera
	camera_target = Vector3.ZERO
	camera_distance = 10.0
	camera_rotation = Vector2(15, 45)  # Reset to default pitch and yaw
	update_camera_transform()


func add_structure_node(node: Node3D) -> void:
	"""Add a generated structure to the viewport for preview"""
	viewport.add_child(node)


func preview_tile(tile: Tile) -> void:
	"""Display a preview of a tile (no socket preview)"""
	# Stop any socket preview
	stop_compatible_tiles_preview()
	
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

func clear_structure() -> void:
	"""Remove all structure nodes from the viewport"""
	for child in viewport.get_children():
		if child is Node3D and child != camera and child != viewport_grid:
			child.queue_free()
	preview_root = null
	main_tile = null


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
	var connecting_socket: Socket = result["socket"]
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
		
		# Get tile sizes
		var main_tile_size = main_tile.size if main_tile else Vector3.ONE
		var compatible_tile_size = tile.size
		
		# Position the compatible tile adjacent to the main tile
		var main_direction = main_socket.direction
		instance.position = WfcHelper.calculate_adjacent_tile_position(
			main_tile_size,
			compatible_tile_size,
			main_direction
		)
		
		# Use the rotation that was determined in find_compatible_tiles
		instance.transform.basis = Basis(Vector3.UP, deg_to_rad(predetermined_rotation))
		
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
	_update_button_states()


func set_grid_size(size: Vector3i) -> void:
	"""Set the grid size for generation"""
	grid_size = size
	print("WFC grid size set to: ", grid_size)


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
	if not module_library or module_library.tiles.is_empty():
		push_warning("No module library or tiles available")
		return
	
	print("\n=== Starting New WFC Generation ===")
	print("Grid size: ", grid_size)
	print("Available tiles: ", module_library.tiles.size())
	
	# Get current strategy
	wfc_strategy = available_strategies[current_strategy_index]
	print("Strategy: ", wfc_strategy.get_name())
	
	# Stop any current preview
	stop_compatible_tiles_preview()
	clear_structure()
	
	# Create new grid and solver
	wfc_grid = WfcGrid.from_library(grid_size, module_library)
	wfc_solver = WfcSolver.new(wfc_grid, wfc_strategy)
	is_generating = true
	
	print("Grid created with ", wfc_grid.cells.size(), " cells")
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
	
	# Propagate constraints
	if not wfc_solver.propagate(cell):
		push_error("WFC: Propagation failed at ", cell.position)
		_finish_generation()
		return
	
	# Update visualization
	_visualize_grid()


func _on_solve_button_pressed() -> void:
	"""Solve the entire WFC generation automatically"""
	if not is_generating or not wfc_grid or not wfc_solver:
		return
	
	print("\n=== Solving WFC Automatically ===")
	
	var success = wfc_solver.solve()
	
	if success:
		print("✓ WFC generation SUCCESSFUL!")
		_print_grid_summary()
	else:
		push_error("✗ WFC generation FAILED!")
		if wfc_grid.has_contradiction():
			print("  Reason: Contradiction detected")
	
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
	
	# Create preview root
	preview_root = Node3D.new()
	preview_root.name = "WfcStructure"
	add_structure_node(preview_root)
	
	# Calculate center offset to center the grid at origin
	var center_offset = Vector3.ZERO
	if not wfc_grid.cells.is_empty():
		# Get a sample tile to determine tile size
		var sample_cell = wfc_grid.cells.values()[0]
		var sample_tile: Tile = null
		if sample_cell.is_collapsed():
			sample_tile = sample_cell.get_tile()
		elif sample_cell.possible_tile_variants.size() > 0:
			sample_tile = sample_cell.possible_tile_variants[0].get("tile")
		
		if sample_tile:
			var tile_size = sample_tile.size
			# Calculate the center of the grid in world space
			center_offset = Vector3(
				(grid_size.x - 1) * tile_size.x * 0.5,
				(grid_size.y - 1) * tile_size.y * 0.5,
				(grid_size.z - 1) * tile_size.z * 0.5
			)
	
	# Instantiate all collapsed cells
	for cell in wfc_grid.cells.values():
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
			# Position based on grid position and tile size, centered at origin
			var world_pos = WfcHelper.grid_to_world(cell.position, tile.size)
			instance.position = world_pos - center_offset
			
			# Apply rotation
			instance.transform.basis = Basis(Vector3.UP, deg_to_rad(rotation))
			
			instance.name = "Cell_%d_%d_%d" % [cell.position.x, cell.position.y, cell.position.z]
			preview_root.add_child(instance)
	
	frame_structure()


func _print_grid_summary() -> void:
	"""Print a summary of the generated grid"""
	if not wfc_grid:
		return
	
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


# =============================================================================
# Strategy Discovery
# =============================================================================

func _discover_strategies() -> void:
	"""Automatically discover all strategy classes in the strategies folder"""
	available_strategies.clear()
	
	var strategies_path = "res://addons/auto_structured/core/wfc/strategies/"
	var dir = DirAccess.open(strategies_path)
	
	if not dir:
		push_error("Could not open strategies directory: " + strategies_path)
		# Fallback to hardcoded strategies
		available_strategies = [
			WfcStrategyFillAll.new(),
			WfcStrategySparse.new(0.5),
			WfcStrategyPerimeter.new(),
			WfcStrategyGroundWalls.new()
		]
		return
	
	# Collect all .gd files (except base class)
	var strategy_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			# Skip the base class
			if file_name != "wfc_strategy_base.gd":
				strategy_files.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort alphabetically for consistent ordering
	strategy_files.sort()
	
	# Instantiate each strategy
	for strategy_file in strategy_files:
		var script_path = strategies_path + strategy_file
		var script = load(script_path)
		
		if script and script is GDScript:
			# Try to instantiate the strategy
			var strategy_instance = script.new()
			
			# Verify it's a valid strategy (has the required methods)
			if strategy_instance.has_method("should_collapse_cell") and \
			   strategy_instance.has_method("get_name") and \
			   strategy_instance.has_method("get_description"):
				
				# Special handling for Sparse strategy - set default probability
				if strategy_instance is WfcStrategySparse:
					strategy_instance.fill_probability = 0.5
				
				available_strategies.append(strategy_instance)
				print("Discovered strategy: ", strategy_instance.get_name())
			else:
				push_warning("Skipped invalid strategy: " + strategy_file)
	
	# Ensure we have at least one strategy
	if available_strategies.is_empty():
		push_error("No valid strategies found! Using fallback.")
		available_strategies = [WfcStrategyFillAll.new()]


# =============================================================================
# Toolbar Controls
# =============================================================================

func _on_grid_size_changed(_value: float) -> void:
	"""Handle grid size spinbox changes"""
	grid_size = Vector3i(
		int(x_spinbox.value),
		int(y_spinbox.value),
		int(z_spinbox.value)
	)
	print("Grid size changed to: ", grid_size)


func _on_strategy_selected(index: int) -> void:
	"""Handle strategy dropdown selection"""
	if index >= 0 and index < available_strategies.size():
		current_strategy_index = index
		var strategy = available_strategies[index]
		print("Strategy changed to: ", strategy.get_name())
		
		# Show config popup for strategies that need it (like Sparse)
		if strategy is WfcStrategySparse:
			_show_sparse_probability_dialog(strategy)


func _show_sparse_probability_dialog(strategy: WfcStrategySparse) -> void:
	"""Show a simple dialog to configure sparse probability"""
	var dialog = AcceptDialog.new()
	dialog.title = "Configure Sparse Strategy"
	dialog.size = Vector2i(300, 150)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var label = Label.new()
	label.text = "Fill Probability:"
	vbox.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.name = "ProbabilitySpinBox"
	spinbox.min_value = 0
	spinbox.max_value = 100
	spinbox.step = 5
	spinbox.value = strategy.fill_probability * 100.0
	spinbox.suffix = "%"
	vbox.add_child(spinbox)
	
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		strategy.fill_probability = spinbox.value / 100.0
		print("Sparse probability set to: ", strategy.fill_probability)
		# Update the strategy name in dropdown to show percentage
		strategy_option.set_item_text(current_strategy_index, strategy.get_name())
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


