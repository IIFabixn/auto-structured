@tool
class_name ModuleLibraryPanel extends Control

signal library_loaded(library: ModuleLibrary)
signal library_created(library: ModuleLibrary)
signal library_selected(library_name: String)
signal library_deleted(library_name: String)
signal library_renamed(old_name: String, new_name: String)
signal library_saved(library: ModuleLibrary)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")
const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const TileItemScene = preload("res://addons/auto_structured/ui/controls/module_library_panel/tile_item.tscn")
const TileItem = preload("res://addons/auto_structured/ui/controls/module_library_panel/tile_item.gd")

const CREATE = 0
const RENAME = 1
const SAVE = 2
const DELETE = 3

@onready var library_option_button: OptionButton = %LibraryOptionButton
@onready var library_menu_button: MenuButton = %LibraryMenuButton
@onready var search_tile_edit: LineEdit = %SearchTileEdit
@onready var add_tile_button: TextureButton = %AddTileButton
@onready var tile_grid: GridContainer = %TileGrid

var undo_redo_manager: AutoStructuredUndoRedo
var selection_manager: SelectionManager
var current_library: ModuleLibrary = null
var available_libraries: Dictionary = {}  # library_name -> file_path

func _ready() -> void:
	"""Initialize the panel and set up connections."""
	_setup_library_menu()
	_scan_available_libraries()
	_update_library_list()
	
	# Connect add tile button
	if add_tile_button:
		add_tile_button.pressed.connect(_on_add_tile_button_pressed)
	
	# Connect library dropdown
	if library_option_button:
		library_option_button.item_selected.connect(_on_library_selected)
	
	# Connect search field
	if search_tile_edit:
		search_tile_edit.text_changed.connect(_on_search_text_changed)
	
	# Auto-load first library if available
	if not available_libraries.is_empty():
		var first_lib = available_libraries.keys()[0]
		_load_library(first_lib)
		_select_library_in_dropdown(first_lib)
		_update_tile_list()

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
	"""
	Initialize the undo/redo system for this panel.
	Should be called by the parent viewport after instantiation.
	"""
	undo_redo_manager = undo_redo

func setup_selection_manager(manager: SelectionManager) -> void:
	"""
	Initialize the selection manager event bus.
	Should be called by the parent viewport after instantiation.
	"""
	selection_manager = manager

## ============================================================================
## Library Menu Setup and Handling
## ============================================================================

func _setup_library_menu() -> void:
	"""Configure the library menu button with options."""
	var popup = library_menu_button.get_popup()
	popup.clear()
	popup.add_item("New Library", CREATE)
	popup.add_separator()
	popup.add_item("Rename Library", RENAME)
	popup.add_item("Save Library", SAVE)
	popup.add_separator()
	popup.add_item("Delete Library", DELETE)
	
	popup.id_pressed.connect(_on_library_menu_id_pressed)

func _on_library_menu_id_pressed(id: int) -> void:
	"""Handle library menu item selection."""
	match id:
		CREATE:
			_create_new_library()
		RENAME:
			_rename_library()
		SAVE:
			_save_library()
		DELETE:
			_delete_library()

## ============================================================================
## Library Management Functions
## ============================================================================

func _create_new_library() -> void:
	"""Create a new module library."""
	# Create dialog for library name input
	var dialog = AcceptDialog.new()
	dialog.title = "Create New Library"
	dialog.dialog_text = "Enter library name:"
	
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "My Library"
	name_edit.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(name_edit)
	
	dialog.confirmed.connect(func():
		var lib_name = name_edit.text.strip_edges()
		if lib_name.is_empty():
			_show_error("Library name cannot be empty.")
			return
		
		if available_libraries.has(lib_name):
			_show_error("A library with this name already exists.")
			return
		
		# Create new library
		var new_library = ModuleLibrary.new()
		new_library.library_name = lib_name
		new_library.ensure_defaults()
		
		# Save to disk
		var save_path = _get_library_save_path(lib_name)
		var error = ResourceSaver.save(new_library, save_path)
		
		if error != OK:
			_show_error("Failed to save library: " + error_string(error))
			return
		
		# Update tracking
		available_libraries[lib_name] = save_path
		current_library = new_library
		
		# Update UI
		_update_library_list()
		_select_library_in_dropdown(lib_name)
		_update_tile_list()
		
		# Emit signals
		library_created.emit(new_library)
		library_loaded.emit(new_library)
		
		print("Created library: %s at %s" % [lib_name, save_path])
	)
	
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered()
	name_edit.grab_focus()

func _rename_library() -> void:
	"""Rename the current library."""
	if current_library == null:
		_show_error("No library is currently loaded.")
		return
	
	var old_name = current_library.library_name
	
	# Create dialog for new library name
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Library"
	dialog.dialog_text = "Enter new name for '%s':" % old_name
	
	var name_edit = LineEdit.new()
	name_edit.text = old_name
	name_edit.custom_minimum_size = Vector2(300, 0)
	dialog.add_child(name_edit)
	
	dialog.confirmed.connect(func():
		var new_name = name_edit.text.strip_edges()
		if new_name.is_empty():
			_show_error("Library name cannot be empty.")
			return
		
		if new_name == old_name:
			return  # No change
		
		if available_libraries.has(new_name):
			_show_error("A library with this name already exists.")
			return
		
		# Update library name
		current_library.library_name = new_name
		
		# Save at new path
		var old_path = available_libraries[old_name]
		var new_path = _get_library_save_path(new_name)
		var error = ResourceSaver.save(current_library, new_path)
		
		if error != OK:
			_show_error("Failed to save renamed library: " + error_string(error))
			return
		
		# Remove old file
		if old_path != new_path:
			DirAccess.remove_absolute(old_path)
		
		# Update tracking
		available_libraries.erase(old_name)
		available_libraries[new_name] = new_path
		
		# Update UI
		_update_library_list()
		_select_library_in_dropdown(new_name)
		
		# Emit signal
		library_renamed.emit(old_name, new_name)
		
		print("Renamed library: %s -> %s" % [old_name, new_name])
	)
	
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered()
	name_edit.select_all()
	name_edit.grab_focus()

func _save_library() -> void:
	"""Save the current library to disk."""
	if current_library == null:
		_show_error("No library is currently loaded.")
		return
	
	var lib_name = current_library.library_name
	var save_path = _get_library_save_path(lib_name)
	
	var error = ResourceSaver.save(current_library, save_path)
	
	if error != OK:
		_show_error("Failed to save library: " + error_string(error))
		return
	
	# Emit signal
	library_saved.emit(current_library)
	
	print("Saved library: %s" % save_path)

func _delete_library() -> void:
	"""Delete the current library after confirmation."""
	if current_library == null:
		_show_error("No library is currently loaded.")
		return
	
	var lib_name = current_library.library_name
	
	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Delete Library"
	dialog.dialog_text = "Are you sure you want to delete '%s'?\nThis cannot be undone." % lib_name
	
	dialog.confirmed.connect(func():
		# Get file path
		var file_path = available_libraries.get(lib_name, "")
		if file_path.is_empty():
			_show_error("Library file path not found.")
			return
		
		# Delete file
		var error = DirAccess.remove_absolute(file_path)
		if error != OK:
			_show_error("Failed to delete library file: " + error_string(error))
			return
		
		# Update tracking
		available_libraries.erase(lib_name)
		
		# Clear current library if it's the deleted one
		var was_current = (current_library.library_name == lib_name)
		if was_current:
			current_library = null
		
		# Update UI
		_update_library_list()
		
		# Emit signal
		library_deleted.emit(lib_name)
		
		print("Deleted library: %s" % lib_name)
		
		# Load first available library if we deleted the current one
		if was_current and not available_libraries.is_empty():
			var first_lib = available_libraries.keys()[0]
			_load_library(first_lib)
			_select_library_in_dropdown(first_lib)
			_update_tile_list()
		elif was_current:
			# No libraries left, clear the tile list
			_update_tile_list()
	)
	
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered()

## ============================================================================
## Library Discovery and Loading
## ============================================================================

func _scan_available_libraries() -> void:
	"""Scan for available library files."""
	available_libraries.clear()
	
	var libraries_dir = "res://libraries/"
	
	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(libraries_dir):
		DirAccess.make_dir_recursive_absolute(libraries_dir)
	
	# Scan for .tres files
	var dir = DirAccess.open(libraries_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var file_path = libraries_dir + file_name
				var resource = load(file_path)
				
				if resource is ModuleLibrary:
					available_libraries[resource.library_name] = file_path
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

func _update_library_list() -> void:
	"""Update the library dropdown with available libraries."""
	library_option_button.clear()
	
	if available_libraries.is_empty():
		library_option_button.add_item("(No Libraries)")
		library_option_button.disabled = true
		return
	
	library_option_button.disabled = false
	
	var lib_names = available_libraries.keys()
	lib_names.sort()
	
	for lib_name in lib_names:
		library_option_button.add_item(lib_name)

func _select_library_in_dropdown(lib_name: String) -> void:
	"""Select a specific library in the dropdown."""
	for i in range(library_option_button.item_count):
		if library_option_button.get_item_text(i) == lib_name:
			library_option_button.selected = i
			break

func _load_library(lib_name: String) -> void:
	"""Load a library by name."""
	var file_path = available_libraries.get(lib_name, "")
	if file_path.is_empty():
		_show_error("Library '%s' not found." % lib_name)
		return
	
	var library = load(file_path)
	if not library is ModuleLibrary:
		_show_error("Failed to load library '%s'." % lib_name)
		return
	
	current_library = library
	library_loaded.emit(library)
	
	print("Loaded library: %s" % lib_name)

## ============================================================================
## Utility Functions
## ============================================================================

func _get_library_save_path(lib_name: String) -> String:
	"""Get the file path for saving a library."""
	var safe_name = lib_name.to_lower().replace(" ", "_")
	return "res://libraries/%s.tres" % safe_name

func _show_error(message: String) -> void:
	"""Show an error dialog."""
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	push_error(message)

func _show_info(message: String) -> void:
	"""Show an info dialog."""
	var dialog = AcceptDialog.new()
	dialog.title = "Info"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

## ============================================================================
## Tile Import
## ============================================================================

func _on_add_tile_button_pressed() -> void:
	"""Handle add tile button press."""
	if current_library == null:
		_show_error("No library is currently loaded. Please create or select a library first.")
		return
	
	# Step 1: Open Godot FileDialog for file selection
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.add_filter("*.tscn,*.glb,*.gltf,*.obj,*.fbx", "3D Models")
	file_dialog.title = "Select Tiles to Import"
	file_dialog.files_selected.connect(_on_import_files_selected)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

func _on_import_files_selected(files: PackedStringArray) -> void:
	"""Handle file selection from file dialog."""
	if files.is_empty():
		return
	
	# Find and cleanup the file dialog first
	for child in get_children():
		if child is FileDialog:
			child.queue_free()
	
	# Wait one frame for the FileDialog to be freed before opening ImportDialog
	await get_tree().process_frame
	
	# Step 2: Open ImportDialog for configuration
	var import_dialog_scene = load("res://addons/auto_structured/ui/dialogs/import_dialog.tscn")
	if not import_dialog_scene:
		_show_error("Failed to load import dialog scene.")
		return
	
	var import_dialog = import_dialog_scene.instantiate()
	if not import_dialog:
		_show_error("Failed to instantiate import dialog.")
		return
	
	import_dialog.setup(files, current_library)
	import_dialog.tiles_imported.connect(_on_tiles_imported)
	import_dialog.canceled.connect(import_dialog.queue_free)
	import_dialog.confirmed.connect(import_dialog.queue_free)
	
	add_child(import_dialog)
	import_dialog.popup_centered_ratio(0.8)

func _on_tiles_imported(tiles: Array) -> void:
	"""Handle imported tiles."""
	if current_library == null:
		return
	
	# Add tiles to library
	for tile in tiles:
		current_library.add_tile(tile)
	
	# Save library
	_save_library()
	
	# Update tile list UI (to be implemented)
	_update_tile_list()
	
	print("Added %d tiles to library '%s'" % [tiles.size(), current_library.library_name])

func _update_tile_list() -> void:
	"""Update the tile list display."""
	if not tile_grid:
		return
	
	for child in tile_grid.get_children():
		child.queue_free()
	
	if current_library == null:
		return
	
	# Get search filter
	var search_text = ""
	if search_tile_edit:
		search_text = search_tile_edit.text.strip_edges().to_lower()
	
	# Add tiles to list (filtered by search)
	for tile in current_library.tiles:
		# Apply search filter
		if not search_text.is_empty() and not tile.name.to_lower().contains(search_text):
			continue
		
		var scene : TileItem = TileItemScene.instantiate()
		tile_grid.add_child(scene)
		scene.tile = tile
		
		if not scene.tile_selected.is_connected(_on_tile_item_selected):
			scene.tile_selected.connect(_on_tile_item_selected)
		if not scene.tile_deleted.is_connected(_on_tile_item_deleted):
			scene.tile_deleted.connect(_on_tile_item_deleted)

func _on_tile_item_selected(tile: Tile) -> void:
	"""Handle tile selection from a tile item."""
	if selection_manager:
		selection_manager.select_tile(tile)

func _on_tile_item_deleted(tile: Tile) -> void:
	"""Handle tile deletion from a tile item."""
	if current_library:
		current_library.remove_tile(tile)
		_save_library()
		_update_tile_list()

func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text change."""
	_update_tile_list()

func _on_library_selected(index: int) -> void:
	"""Handle library selection from dropdown."""
	if index < 0 or index >= library_option_button.item_count:
		return
	
	var lib_name = library_option_button.get_item_text(index)
	_load_library(lib_name)
	_update_tile_list()
	library_selected.emit(lib_name)