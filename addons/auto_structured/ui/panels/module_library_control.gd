@tool
class_name ModuleLibraryControl extends Control

signal tile_selected(tile: Tile)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const ManageSocketsDialog = preload("res://addons/auto_structured/ui/controls/manage_sockets_dialog.tscn")

var libraries: Array[ModuleLibrary] = []
var current_library: ModuleLibrary
var selected_tile: Tile
var file_dialog: EditorFileDialog
var rename_dialog: AcceptDialog
var rename_line_edit: LineEdit
var manage_sockets_dialog: Window

@onready
var library_option: OptionButton = $Panel/MarginContainer/VBoxContainer/VBoxContainer/LibrarySelectorBar/OptionButton
@onready
var library_menu_button: MenuButton = $Panel/MarginContainer/VBoxContainer/VBoxContainer/LibrarySelectorBar/MenuButton
@onready var tile_list: ItemList = %TileList
@onready var search_edit: LineEdit = %AssetSearchEdit


func _ready() -> void:
	find_libraries()
	_refresh_tile_list()
	tile_list.get_parent().resized.connect(_on_tile_list_size_flags_changed)
	tile_list.item_selected.connect(on_tile_selected)
	library_option.item_selected.connect(_on_library_selected)
	search_edit.text_changed.connect(func(_new_text):
		_refresh_tile_list()
	)

	_on_tile_list_size_flags_changed()
	_setup_file_dialog()
	_setup_menu_button()
	_setup_rename_dialog()

func _exit_tree() -> void:
	if file_dialog:
		file_dialog.queue_free()
	if rename_dialog:
		rename_dialog.queue_free()

func find_libraries() -> void:
	# Scan the resource folder for ModuleLibrary resources.
	libraries.clear()
	library_option.clear()

	var libraries_found = _scan_directory_for_libraries("res://")

	if libraries_found.is_empty():
		library_option.add_item("No libraries found")
		library_option.disabled = true
		return

	for i in range(libraries_found.size()):
		var lib = libraries_found[i]
		libraries.append(lib)
		library_option.add_item(lib.library_name, i)

	if not libraries.is_empty():
		current_library = libraries[0]
		library_option.selected = 0


func _on_library_selected(index: int) -> void:
	if index < 0 or index >= libraries.size():
		return

	current_library = libraries[index]
	_refresh_tile_list()


func _scan_directory_for_libraries(path: String) -> Array[ModuleLibrary]:
	var found_libraries: Array[ModuleLibrary] = []
	var dir = DirAccess.open(path)

	if not dir:
		return found_libraries

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path.path_join(file_name)

		if dir.current_is_dir():
			# Skip .godot and addons directories to avoid recursion issues
			if file_name != ".godot" and file_name != ".git":
				found_libraries.append_array(_scan_directory_for_libraries(full_path))
		else:
			# Check if it's a .tres or .res file
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var resource = load(full_path)
				if resource is ModuleLibrary:
					found_libraries.append(resource)

		file_name = dir.get_next()

	dir.list_dir_end()
	return found_libraries


func _on_tile_list_size_flags_changed() -> void:
	var parent_width = tile_list.get_parent().get_size().x
	var column_width = max(50, (parent_width / 2) - 12)
	tile_list.fixed_column_width = column_width


func _setup_file_dialog() -> void:
	file_dialog = EditorFileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tscn", "Scene Files")
	file_dialog.add_filter("*.glb,*.gltf", "GLTF Files")
	file_dialog.add_filter("*.obj,*.fbx", "3D Model Files")
	file_dialog.files_selected.connect(_on_files_selected)


func _setup_menu_button() -> void:
	var popup = library_menu_button.get_popup()
	popup.id_pressed.connect(_on_library_menu_item_selected)


func _setup_rename_dialog() -> void:
	rename_dialog = AcceptDialog.new()
	rename_dialog.title = "Rename Library"
	rename_dialog.dialog_text = "Enter new library name:"
	add_child(rename_dialog)

	# Create line edit for name input
	rename_line_edit = LineEdit.new()
	rename_line_edit.custom_minimum_size = Vector2(300, 0)
	rename_dialog.add_child(rename_line_edit)

	# Connect signals
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	rename_line_edit.text_submitted.connect(
		func(_text):
			rename_dialog.hide()
			_on_rename_confirmed()
	)


func _on_library_menu_item_selected(id: int) -> void:
	match id:
		0:  # Rename
			_rename_library()
		1:  # Delete
			_delete_library()
		2:  # New
			create_new_library()
		3:  # Save
			_save_library()
		4:  # Manage Sockets
			_manage_library_sockets()


func _rename_library() -> void:
	if not current_library:
		push_warning("No library selected to rename")
		return

	# Populate the dialog with current name
	rename_line_edit.text = current_library.library_name
	rename_dialog.popup_centered()
	rename_line_edit.grab_focus()
	rename_line_edit.select_all()


func _on_rename_confirmed() -> void:
	var new_name = rename_line_edit.text.strip_edges()

	if new_name.is_empty():
		push_warning("Library name cannot be empty")
		return

	current_library.library_name = new_name

	# Update the option button
	var current_index = library_option.selected
	library_option.set_item_text(current_index, new_name)

	_save_library()


func _delete_library() -> void:
	if not current_library:
		push_warning("No library selected to delete")
		return

	# Remove from array
	var index = libraries.find(current_library)
	if index >= 0:
		libraries.remove_at(index)

	# Remove from dropdown
	library_option.remove_item(library_option.selected)

	# Delete the resource file
	if current_library.resource_path != "":
		DirAccess.remove_absolute(current_library.resource_path)

	# Select first library if available
	if not libraries.is_empty():
		current_library = libraries[0]
		library_option.selected = 0
		_refresh_tile_list()
	else:
		current_library = null
		tile_list.clear()


func _save_library() -> void:
	if not current_library:
		push_warning("No library selected to save")
		return

	if current_library.resource_path == "":
		push_warning("Library has no save path")
		return

	var err = ResourceSaver.save(current_library, current_library.resource_path)
	if err != OK:
		push_error("Failed to save library: ", err)


func save_current_library() -> void:
	_save_library()


func create_new_library() -> void:
	var new_library = ModuleLibrary.new()
	new_library.library_name = "New Library"
	
	# Find a unique filename
	var base_path = "res://module_library"
	var save_path = base_path + ".tres"
	var counter = 1
	
	while FileAccess.file_exists(save_path):
		save_path = base_path + "_" + str(counter) + ".tres"
		counter += 1
	
	var err = ResourceSaver.save(new_library, save_path)

	if err == OK:
		libraries.append(new_library)
		library_option.add_item(new_library.library_name, libraries.size() - 1)
		library_option.selected = libraries.size() - 1
		current_library = new_library
		_refresh_tile_list()
		print("Created new library at: ", save_path)
	else:
		push_error("Failed to save new library resource. Error code: ", err)


func add_tiles() -> void:
	# Open file browser for user to select scene/mesh files
	if not current_library:
		push_warning("No library selected")
		return

	if file_dialog:
		file_dialog.popup_centered_ratio(0.7)


func _on_files_selected(paths: PackedStringArray) -> void:
	if not current_library:
		return

	# Duplicate the tiles array to make it writable
	var tiles_copy: Array[Tile] = []
	tiles_copy.assign(current_library.tiles)

	for path in paths:
		var tile = Tile.new()

		# Set tile name based on filename
		tile.name = path.get_file().get_basename()

		# Load the resource based on file type
		if path.ends_with(".tscn"):
			tile.scene = load(path)
		elif (
			path.ends_with(".glb")
			or path.ends_with(".gltf")
			or path.ends_with(".obj")
			or path.ends_with(".fbx")
		):
			# GLTF files are imported as PackedScene by Godot
			tile.scene = load(path)

		# Add tile to the writable copy
		tiles_copy.append(tile)

	# Assign the modified array back
	current_library.tiles = tiles_copy

	# Save the library resource
	ResourceSaver.save(current_library, current_library.resource_path)

	# Refresh the tile list display
	_refresh_tile_list()


func on_tile_selected(index: int) -> void:
	if not current_library:
		return

	if index < 0 or index >= current_library.tiles.size():
		return

	selected_tile = current_library.tiles[index]

	# Duplicate the tile to ensure it's not a placeholder instance
	# This workaround is needed because sub-resources in @tool scripts
	# can remain as placeholders even with @tool on all classes
	var tile_copy = selected_tile.duplicate(true)
	current_library.tiles[index] = tile_copy
	selected_tile = tile_copy

	tile_selected.emit(selected_tile)

func unselect_tile() -> void:
	tile_list.select(-1)
	tile_list.item_selected.emit(-1)
	selected_tile = null

func _refresh_tile_list() -> void:
	tile_list.clear()

	if not current_library:
		return

	var search_lower = search_edit.text.to_lower()
	var filtered_tiles: Array[Tile] = []
	for tile in current_library.tiles:
		if search_lower == "" or tile.name.to_lower().findn(search_lower) != -1:
			filtered_tiles.append(tile)
	for tile in filtered_tiles:
		tile_list.add_item(tile.name)
		# TODO: Add thumbnail preview if mesh/scene has one

func _manage_library_sockets() -> void:
	"""Open dialog to manage socket types in the current library"""
	if not current_library:
		push_warning("No library selected to manage sockets")
		return
	
	# Create dialog if it doesn't exist
	if not manage_sockets_dialog:
		manage_sockets_dialog = ManageSocketsDialog.instantiate()
		manage_sockets_dialog.socket_renamed.connect(_on_socket_renamed)
		manage_sockets_dialog.socket_deleted.connect(_on_socket_deleted)
		add_child(manage_sockets_dialog)
	
	# Get all registered socket types from library
	var socket_types = current_library.get_socket_types()
	
	# Update the dialog (no selection needed in editable mode)
	var empty_selection: Array[String] = []
	manage_sockets_dialog.set_available_sockets(socket_types, empty_selection)
	
	# Set editable mode (after data is set)
	manage_sockets_dialog.is_editable = true
	
	# Show dialog centered with explicit size (deferred to ensure UI is ready)
	manage_sockets_dialog.call_deferred("popup_centered", Vector2i(500, 500))

func _on_socket_renamed(old_name: String, new_name: String) -> void:
	"""Handle socket type rename"""
	if not current_library:
		return
	
	# Find and replace in socket_types array
	var index = current_library.socket_types.find(old_name)
	if index >= 0:
		current_library.socket_types[index] = new_name
	
	# Update all tiles that use this socket type
	for tile in current_library.tiles:
		for socket in tile.sockets:
			if socket.socket_id == old_name:
				socket.socket_id = new_name
			# Also update compatible sockets
			if old_name in socket.compatible_sockets:
				var compat_index = socket.compatible_sockets.find(old_name)
				socket.compatible_sockets[compat_index] = new_name
	
	# Refresh the dialog
	var empty_selection: Array[String] = []
	manage_sockets_dialog.set_available_sockets(current_library.get_socket_types(), empty_selection)
	
	# Save the library
	_save_library()
	
	print("Socket type renamed from '%s' to '%s'" % [old_name, new_name])

func _on_socket_deleted(socket_name: String) -> void:
	"""Handle socket type deletion"""
	if not current_library:
		return
	
	# Remove from socket_types array
	current_library.socket_types.erase(socket_name)
	
	# Update all tiles - replace deleted socket type with "none"
	for tile in current_library.tiles:
		for socket in tile.sockets:
			if socket.socket_id == socket_name:
				socket.socket_id = "none"
			# Also remove from compatible sockets
			socket.compatible_sockets.erase(socket_name)
	
	# Refresh the dialog
	var empty_selection: Array[String] = []
	manage_sockets_dialog.set_available_sockets(current_library.get_socket_types(), empty_selection)
	
	# Save the library
	_save_library()
	
	print("Socket type '%s' deleted" % socket_name)
