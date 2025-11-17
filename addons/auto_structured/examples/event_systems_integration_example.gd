@tool
extends Node
## Example demonstrating how to integrate the event systems.
##
## This example shows practical patterns for using SelectionManager,
## ValidationEventBus, and ModuleLibrary signals in UI components.

const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const ValidationEventBus = preload("res://addons/auto_structured/core/events/validation_event_bus.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

## Global instances (typically created once per editor session)
var selection_manager: SelectionManager
var validation_bus: ValidationEventBus
var library: ModuleLibrary

func _ready() -> void:
	setup_event_systems()
	demonstrate_selection_management()
	demonstrate_validation_events()
	demonstrate_library_events()


## ============================================================================
## SETUP
## ============================================================================

func setup_event_systems() -> void:
	"""Initialize the event systems."""
	print("=== Setting up Event Systems ===\n")
	
	# Create library
	library = ModuleLibrary.new()
	library.ensure_defaults()
	
	# Create selection manager
	selection_manager = SelectionManager.new(library)
	
	# Create validation bus
	validation_bus = ValidationEventBus.new()
	validation_bus.enable_history = true
	
	print("✓ Event systems initialized\n")


## ============================================================================
## SELECTION MANAGEMENT EXAMPLE
## ============================================================================

func demonstrate_selection_management() -> void:
	"""Show how to use SelectionManager for tracking user selections."""
	print("=== Selection Management Demo ===\n")
	
	# Connect to selection events
	selection_manager.tile_selected.connect(_on_tile_selected)
	selection_manager.socket_selected.connect(_on_socket_selected)
	selection_manager.selection_cleared.connect(_on_selection_cleared)
	selection_manager.multi_selection_changed.connect(_on_multi_selection_changed)
	
	# Create test tiles
	var tile1 = Tile.new()
	tile1.name = "Floor_Basic"
	tile1.size = Vector3i.ONE
	
	var tile2 = Tile.new()
	tile2.name = "Wall_Brick"
	tile2.size = Vector3i.ONE
	
	var socket = Socket.new()
	socket.direction = Vector3i.UP
	
	# Simulate user interactions
	print("User selects Floor_Basic tile...")
	selection_manager.select_tile(tile1)
	
	print("\nUser selects socket on Floor_Basic...")
	selection_manager.select_socket(socket, tile1)
	
	print("\nUser adds tiles to multi-selection...")
	selection_manager.add_to_selection(tile1)
	selection_manager.add_to_selection(tile2)
	
	print("\nUser clears selection...")
	selection_manager.clear_selection()
	
	print("\n✓ Selection management demo complete\n")


func _on_tile_selected(tile: Tile, previous_tile: Tile) -> void:
	"""Called when tile selection changes."""
	if tile:
		print("  → Tile selected: %s" % tile.name)
		# Update details panel, property inspector, etc.
	else:
		print("  → Tile deselected")


func _on_socket_selected(socket: Socket, tile: Tile, previous_socket: Socket) -> void:
	"""Called when socket selection changes."""
	if socket:
		print("  → Socket selected: %s on tile %s" % [socket.direction, tile.name if tile else "unknown"])
		# Update socket editor, show connections, etc.
	else:
		print("  → Socket deselected")


func _on_selection_cleared() -> void:
	"""Called when all selections are cleared."""
	print("  → All selections cleared")
	# Hide details panels, reset UI, etc.


func _on_multi_selection_changed(tiles: Array) -> void:
	"""Called when multi-selection changes."""
	print("  → Multi-selection: %d tiles" % tiles.size())
	# Enable batch operations UI, show count badge, etc.


## ============================================================================
## VALIDATION EVENTS EXAMPLE
## ============================================================================

func demonstrate_validation_events() -> void:
	"""Show how to use ValidationEventBus for real-time feedback."""
	print("=== Validation Events Demo ===\n")
	
	# Connect to validation events
	validation_bus.validation_error.connect(_on_validation_error)
	validation_bus.validation_warning.connect(_on_validation_warning)
	validation_bus.validation_info.connect(_on_validation_info)
	validation_bus.validation_started.connect(_on_validation_started)
	validation_bus.validation_completed.connect(_on_validation_completed)
	
	# Simulate validation workflow
	print("Starting tile validation...")
	validation_bus.start_validation(ValidationEventBus.Context.TILE, 3)
	
	# Emit various validation messages
	var tile = Tile.new()
	tile.name = ""  # Invalid
	
	validation_bus.emit_error("Tile name cannot be empty", tile, ValidationEventBus.Context.TILE)
	validation_bus.emit_warning("Tile has no sockets defined", tile, ValidationEventBus.Context.TILE)
	validation_bus.emit_info("Consider adding tags for better organization", tile, ValidationEventBus.Context.TILE)
	
	validation_bus.complete_validation(ValidationEventBus.Context.TILE)
	
	# Display statistics
	var stats = validation_bus.get_stats()
	print("\n✓ Validation complete:")
	print("  - Errors: %d" % stats["errors"])
	print("  - Warnings: %d" % stats["warnings"])
	print("  - Info: %d" % stats["info"])
	print("  - Valid: %s\n" % ("Yes" if stats["errors"] == 0 else "No"))


func _on_validation_error(message: String, context: int, severity: int, source: Variant, details: Dictionary) -> void:
	"""Called when validation error occurs."""
	print("  ✘ ERROR: %s [%s]" % [message, ValidationEventBus.get_context_name(context)])
	# Show error notification, highlight problem in UI, disable save button, etc.


func _on_validation_warning(message: String, context: int, source: Variant, details: Dictionary) -> void:
	"""Called when validation warning occurs."""
	print("  ⚠ WARNING: %s [%s]" % [message, ValidationEventBus.get_context_name(context)])
	# Show warning indicator, add to issues panel, etc.


func _on_validation_info(message: String, context: int, source: Variant, details: Dictionary) -> void:
	"""Called when validation info message occurs."""
	print("  ℹ INFO: %s [%s]" % [message, ValidationEventBus.get_context_name(context)])
	# Show suggestion tooltip, add to hints panel, etc.


func _on_validation_started(context: int, item_count: int) -> void:
	"""Called when validation batch starts."""
	print("  → Validating %d items (%s)..." % [item_count, ValidationEventBus.get_context_name(context)])
	# Show progress indicator, disable editing, etc.


func _on_validation_completed(context: int, total_errors: int, total_warnings: int, total_info: int) -> void:
	"""Called when validation batch completes."""
	print("  → Validation complete: %d errors, %d warnings, %d info" % [total_errors, total_warnings, total_info])
	# Hide progress, update status bar, re-enable editing, etc.


## ============================================================================
## LIBRARY EVENTS EXAMPLE
## ============================================================================

func demonstrate_library_events() -> void:
	"""Show how to use ModuleLibrary signals for tracking changes."""
	print("=== Library Events Demo ===\n")
	
	# Connect to library events
	library.tile_added.connect(_on_tile_added)
	library.tile_removed.connect(_on_tile_removed)
	library.tile_modified.connect(_on_tile_modified)
	library.socket_type_added.connect(_on_socket_type_added)
	library.socket_type_renamed.connect(_on_socket_type_renamed)
	library.socket_type_removed.connect(_on_socket_type_removed)
	library.library_changed.connect(_on_library_changed)
	
	# Simulate library modifications
	print("Adding tiles to library...")
	var tile = Tile.new()
	tile.name = "Test_Tile"
	tile.size = Vector3i.ONE
	library.add_tile(tile)
	
	print("\nModifying tile...")
	tile.name = "Test_Tile_Modified"
	library.notify_tile_modified(tile, "name")
	
	print("\nAdding socket type...")
	library.register_socket_type("custom_connector")
	
	print("\nRenaming socket type...")
	library.rename_socket_type("custom_connector", "advanced_connector")
	
	print("\nRemoving tile...")
	library.remove_tile(tile)
	
	print("\n✓ Library events demo complete\n")


func _on_tile_added(tile: Tile) -> void:
	"""Called when tile is added to library."""
	print("  → Tile added: %s" % tile.name)
	# Refresh tile list UI, update thumbnail cache, mark library as modified, etc.


func _on_tile_removed(tile: Tile) -> void:
	"""Called when tile is removed from library."""
	print("  → Tile removed: %s" % tile.name)
	# Remove from UI, clear selection if selected, update counts, etc.


func _on_tile_modified(tile: Tile, property: String) -> void:
	"""Called when tile is modified."""
	print("  → Tile modified: %s (property: %s)" % [tile.name, property])
	# Refresh property displays, invalidate cache, mark as unsaved, etc.


func _on_socket_type_added(socket_type) -> void:
	"""Called when socket type is added."""
	print("  → Socket type added: %s" % socket_type.type_id)
	# Add to socket type dropdown, refresh compatibility editor, etc.


func _on_socket_type_renamed(old_id: String, new_id: String) -> void:
	"""Called when socket type is renamed."""
	print("  → Socket type renamed: %s → %s" % [old_id, new_id])
	# Update all UI references, refresh dropdowns, etc.


func _on_socket_type_removed(socket_type_id: String) -> void:
	"""Called when socket type is removed."""
	print("  → Socket type removed: %s" % socket_type_id)
	# Remove from dropdowns, show migration dialog if needed, etc.


func _on_library_changed() -> void:
	"""Called whenever library is modified in any way."""
	# Mark library as unsaved, enable save button, update modification timestamp, etc.
	pass  # Don't print to avoid spam in this demo


## ============================================================================
## PRACTICAL INTEGRATION PATTERNS
## ============================================================================

## Pattern 1: Centralized state management in main UI controller
func pattern_centralized_state() -> void:
	"""
	Create global instances in your main UI controller:
	
	# In your main plugin or viewport:
	var selection_manager: SelectionManager
	var validation_bus: ValidationEventBus
	
	func _ready():
		selection_manager = SelectionManager.new(library)
		validation_bus = ValidationEventBus.new()
		
		# Pass to child components
		details_panel.setup(selection_manager, validation_bus)
		tile_list.setup(selection_manager, library)
		socket_editor.setup(selection_manager, validation_bus)
	"""
	pass


## Pattern 2: Real-time validation feedback
func pattern_validation_feedback() -> void:
	"""
	Connect validation bus to UI indicators:
	
	validation_bus.validation_error.connect(func(msg, ctx, sev, src, det):
		error_label.text = msg
		error_label.show()
		error_icon.modulate = Color.RED
	)
	
	validation_bus.validation_completed.connect(func(ctx, err, warn, info):
		if err == 0:
			status_label.text = "✓ Valid"
			status_label.modulate = Color.GREEN
		else:
			status_label.text = "✘ %d Errors" % err
			status_label.modulate = Color.RED
	)
	"""
	pass


## Pattern 3: Synchronized multi-panel selection
func pattern_synchronized_selection() -> void:
	"""
	Keep multiple panels in sync:
	
	# In tile list panel:
	selection_manager.tile_selected.connect(func(tile, prev):
		highlight_tile_in_list(tile)
		scroll_to_tile(tile)
	)
	
	# In details panel:
	selection_manager.tile_selected.connect(func(tile, prev):
		populate_tile_details(tile)
		show_panel()
	)
	
	# In 3D preview:
	selection_manager.tile_selected.connect(func(tile, prev):
		update_3d_preview(tile)
		focus_camera_on_tile(tile)
	)
	"""
	pass


## Pattern 4: Undo/Redo integration
func pattern_undo_redo_integration() -> void:
	"""
	Integrate with undo/redo system:
	
	# Before making changes
	undo_redo.create_action("Add Tile")
	undo_redo.add_do_method(library, "add_tile", tile)
	undo_redo.add_undo_method(library, "remove_tile", tile)
	undo_redo.commit_action()
	
	# The library signals will automatically fire when undo/redo happens,
	# keeping your UI in sync without extra code!
	"""
	pass
