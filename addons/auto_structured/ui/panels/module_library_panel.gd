@tool
class_name ModuleLibraryPanel extends Control

signal tile_selected(tile: Tile)
signal library_loaded(library: ModuleLibrary)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const ManageSocketsDialog = preload("res://addons/auto_structured/ui/dialogs/manage_sockets_dialog.tscn")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketSuggestionDialogScene = preload("res://addons/auto_structured/ui/dialogs/socket_suggestion_dialog.tscn")
const SocketSuggestionBuilder = preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const SocketWizardDialogScene = preload("res://addons/auto_structured/ui/dialogs/socket_wizard.tscn")

var libraries: Array[ModuleLibrary] = []
var current_library: ModuleLibrary
var selected_tile: Tile
var file_dialog: EditorFileDialog
var rename_dialog: AcceptDialog
var rename_line_edit: LineEdit
var manage_sockets_dialog: Window
var tile_context_menu: PopupMenu
var thumbnail_cache: Dictionary = {}  # Cache thumbnails: tile_path -> Texture2D
var preview_generator: EditorResourcePreview
var pending_thumbnail_updates: Array[Dictionary] = []  # Queue of thumbnail updates
var is_processing_thumbnails: bool = false
var socket_suggestion_dialog: SocketSuggestionDialog
var _pending_suggestion_queue: Array = []
var _active_wizard: SocketWizardDialog
var _show_next_after_wizard: bool = false

@onready
var library_option: OptionButton = $Panel/MarginContainer/VBoxContainer/VBoxContainer/LibrarySelectorBar/OptionButton
@onready
var library_menu_button: MenuButton = $Panel/MarginContainer/VBoxContainer/VBoxContainer/LibrarySelectorBar/MenuButton
@onready var tile_list: ItemList = %TileList
@onready var search_edit: LineEdit = %AssetSearchEdit

const OPEN_TILE = 0
const DELETE_TILE = 1
const RESET_TILE = 2

func _ready() -> void:
	# Get EditorResourcePreview instance
	preview_generator = EditorInterface.get_resource_previewer()
	
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
	_setup_tile_context_menu()
	_setup_socket_suggestion_dialog()

func _exit_tree() -> void:
	# Clear thumbnail cache
	thumbnail_cache.clear()
	
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
		library_loaded.emit(current_library)


func _on_library_selected(index: int) -> void:
	if index < 0 or index >= libraries.size():
		return

	current_library = libraries[index]
	_refresh_tile_list()
	library_loaded.emit(current_library)


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
					resource.ensure_defaults()  # Ensure default socket types are set up
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


func _setup_tile_context_menu() -> void:
	tile_context_menu = PopupMenu.new()
	add_child(tile_context_menu)
	tile_context_menu.add_item("Open", OPEN_TILE)
	tile_context_menu.add_separator()
	tile_context_menu.add_item("Delete Tile", DELETE_TILE)
	tile_context_menu.add_item("Reset Tile", RESET_TILE)
	tile_context_menu.id_pressed.connect(_on_tile_context_menu_item_selected)
	
	# Connect to ItemList's item_clicked signal for right-click detection
	tile_list.item_clicked.connect(_on_tile_list_item_clicked)


func _on_tile_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		# Select the item that was right-clicked
		tile_list.select(index)
		on_tile_selected(index)
		
		# Show context menu at mouse position
		var mouse_pos = tile_list.get_screen_position() + at_position
		tile_context_menu.position = mouse_pos
		tile_context_menu.popup()


func _on_tile_context_menu_item_selected(id: int) -> void:
	match id:
		OPEN_TILE:
			_open_selected_tile()
		DELETE_TILE:  # Delete Tile
			_delete_selected_tile()
		RESET_TILE:  # Reset Tile (clear requirements, sockets, tags)
			_reset_selected_tile()


func _delete_selected_tile() -> void:
	if not current_library or not selected_tile:
		return
	
	var index = current_library.tiles.find(selected_tile)
	if index >= 0:
		current_library.tiles.remove_at(index)
		_save_library()
		_refresh_tile_list()
		selected_tile = null


func _reset_selected_tile() -> void:
	if not selected_tile:
		return

	var empty_requirements: Array[Requirement] = []
	selected_tile.requirements = empty_requirements

	var empty_sockets: Array[Socket] = []
	selected_tile.sockets = empty_sockets
	selected_tile.ensure_all_sockets()

	var empty_tags: Array[String] = []
	selected_tile.tags = empty_tags

	_save_library()
	_refresh_tile_list()
	if selected_tile:
		tile_selected.emit(selected_tile)


func _open_selected_tile() -> void:
	if not selected_tile:
		return

	if selected_tile.scene and selected_tile.scene.resource_path != "":
		EditorInterface.open_scene_from_path(selected_tile.scene.resource_path)
		return

	if selected_tile.mesh:
		EditorInterface.edit_resource(selected_tile.mesh)
		return

	push_warning("Tile has no scene or mesh to open")


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

	# Select first library if available, or create a new empty one if none exist
	if not libraries.is_empty():
		current_library = libraries[0]
		library_option.selected = 0
		_refresh_tile_list()
	else:
		# No libraries left, create a new empty one
		create_new_library()


func _save_library() -> void:
	if not current_library:
		push_warning("No library selected to save")
		return

	if current_library.resource_path == "":
		push_warning("Library has no save path")
		return

	print("Saving library: %s" % current_library.resource_path)
	var err = ResourceSaver.save(current_library, current_library.resource_path)
	if err != OK:
		push_error("Failed to save library: ", err)
	else:
		print("Library saved successfully")


func save_current_library() -> void:
	_save_library()


func create_new_library() -> void:
	var new_library = ModuleLibrary.new()
	new_library.library_name = "New Library"
	new_library.ensure_defaults()  # Set up default socket types
	
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
	var new_tiles: Array[Tile] = []

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
		new_tiles.append(tile)

	# Assign the modified array back
	current_library.tiles = tiles_copy

	# Save the library resource
	ResourceSaver.save(current_library, current_library.resource_path)

	# Refresh the tile list display
	_refresh_tile_list()
	if not new_tiles.is_empty():
		_handle_import_suggestions(new_tiles)


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
	
	for i in range(filtered_tiles.size()):
		var tile = filtered_tiles[i]
		var icon = get_thumbnail_for_tile(tile)
		tile_list.add_item(tile.name, icon)
		# Store the tile reference as metadata so we can update it later
		tile_list.set_item_metadata(i, tile)

	if selected_tile:
		var selected_index = filtered_tiles.find(selected_tile)
		if selected_index != -1:
			tile_list.select(selected_index)
			tile_list.ensure_current_is_visible()

func get_thumbnail_for_tile(tile: Tile) -> Texture2D:
	"""
	Get a thumbnail preview for the given tile using Godot's EditorResourcePreview.
	Returns cached thumbnail if available, otherwise requests generation.
	"""
	if not tile:
		return null
	
	# Determine the resource path to preview
	var resource_path: String = ""
	if tile.scene and tile.scene.resource_path:
		resource_path = tile.scene.resource_path
	elif tile.mesh and tile.mesh.resource_path:
		resource_path = tile.mesh.resource_path
	
	if resource_path.is_empty():
		return null
	
	# Check cache first
	if resource_path in thumbnail_cache:
		return thumbnail_cache[resource_path]
	
	# Request preview generation from EditorResourcePreview
	if preview_generator:
		preview_generator.queue_resource_preview(
			resource_path,
			self,
			"_on_preview_loaded",
			resource_path  # Pass path as userdata to identify which tile this is for
		)
	
	return null

func _on_preview_loaded(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	"""
	Callback when a thumbnail has been generated by EditorResourcePreview.
	Caches the thumbnail and queues it for batch update to avoid stuttering.
	"""
	if not thumbnail and not preview:
		return
	
	# Prefer thumbnail (smaller) over full preview
	var texture = thumbnail if thumbnail else preview
	
	# Cache the thumbnail
	thumbnail_cache[userdata] = texture
	
	# Queue the update instead of doing it immediately
	pending_thumbnail_updates.append({
		"resource_path": userdata,
		"texture": texture
	})
	
	# Process thumbnails on next frame if not already scheduled
	if not is_processing_thumbnails:
		is_processing_thumbnails = true
		_process_thumbnail_updates.call_deferred()

func _process_thumbnail_updates() -> void:
	"""
	Process all pending thumbnail updates in a batch to minimize UI updates.
	This is called deferred to avoid stuttering when multiple thumbnails load at once.
	"""
	# Process all pending updates in one go
	for update_data in pending_thumbnail_updates:
		_update_tile_icon_by_resource_path(update_data["resource_path"], update_data["texture"])
	
	# Clear the queue
	pending_thumbnail_updates.clear()
	is_processing_thumbnails = false

func _update_tile_icon_by_resource_path(resource_path: String, texture: Texture2D) -> void:
	"""
	Update the icon of tile items that use the given resource path.
	This avoids rebuilding the entire list when thumbnails load.
	"""
	if not current_library:
		return
	
	# Find which tiles use this resource
	for i in range(tile_list.item_count):
		var tile = tile_list.get_item_metadata(i) as Tile
		if not tile:
			continue
		
		# Check if this tile uses the resource that just loaded
		var tile_resource_path = ""
		if tile.scene and tile.scene.resource_path:
			tile_resource_path = tile.scene.resource_path
		elif tile.mesh and tile.mesh.resource_path:
			tile_resource_path = tile.mesh.resource_path
		
		if tile_resource_path == resource_path:
			tile_list.set_item_icon(i, texture)

func _manage_library_sockets() -> void:
	"""Open dialog to manage socket types in the current library"""
	if not current_library:
		push_warning("No library selected to manage sockets")
		return
	
	# Create dialog if it doesn't exist
	if not manage_sockets_dialog:
		manage_sockets_dialog = ManageSocketsDialog.instanciate()
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

func _setup_socket_suggestion_dialog() -> void:
	if socket_suggestion_dialog:
		return
	socket_suggestion_dialog = SocketSuggestionDialogScene.instantiate() as SocketSuggestionDialog
	if socket_suggestion_dialog == null:
		push_warning("Failed to create Socket Suggestion dialog")
		return
	add_child(socket_suggestion_dialog)
	socket_suggestion_dialog.suggestions_accepted.connect(_on_socket_suggestions_accepted)
	socket_suggestion_dialog.modify_requested.connect(_on_socket_suggestions_modify)
	socket_suggestion_dialog.suggestions_rejected.connect(_on_socket_suggestions_rejected)

func _handle_import_suggestions(new_tiles: Array) -> void:
	if new_tiles.is_empty():
		return
	if socket_suggestion_dialog == null:
		_setup_socket_suggestion_dialog()
	if socket_suggestion_dialog == null:
		return
	for tile in new_tiles:
		var suggestions := SocketSuggestionBuilder.build_suggestions(tile, current_library)
		if suggestions.is_empty():
			continue
		_pending_suggestion_queue.append({
			"tile": tile,
			"suggestions": suggestions
		})
	if _active_wizard:
		return
	if socket_suggestion_dialog.visible:
		return
	if _pending_suggestion_queue.is_empty():
		return
	_show_next_socket_suggestion()

func _show_next_socket_suggestion() -> void:
	if socket_suggestion_dialog == null:
		return
	if _pending_suggestion_queue.is_empty():
		return
	var entry: Dictionary = _pending_suggestion_queue[0]
	_pending_suggestion_queue.remove_at(0)
	var tile: Tile = entry.get("tile", null)
	var suggestions: Array = entry.get("suggestions", [])
	socket_suggestion_dialog.show_for_tile(tile, suggestions)

func _on_socket_suggestions_accepted(tile: Tile, selections: Array) -> void:
	var applied := false
	if tile and not selections.is_empty():
		_apply_socket_suggestions(tile, selections)
		applied = true
	if applied:
		_save_library()
		_refresh_tile_list()
		selected_tile = tile
		tile_selected.emit(tile)
	_show_next_socket_suggestion()

func _on_socket_suggestions_modify(tile: Tile, selections: Array) -> void:
	var applied := false
	if tile and not selections.is_empty():
		_apply_socket_suggestions(tile, selections)
		applied = true
	if applied:
		_save_library()
		_refresh_tile_list()
	if tile:
		selected_tile = tile
		tile_selected.emit(tile)
		_show_next_after_wizard = true
		if not _open_socket_wizard_for_tile(tile):
			_show_next_after_wizard = false
			_show_next_socket_suggestion()
	else:
		_show_next_socket_suggestion()

func _on_socket_suggestions_rejected(_tile: Tile) -> void:
	_show_next_socket_suggestion()

func _apply_socket_suggestions(tile: Tile, selections: Array) -> void:
	if tile == null:
		return
	var changed := false
	for selection in selections:
		var suggestion: Dictionary = selection
		var socket_id := str(suggestion.get("socket_id", "")).strip_edges()
		if socket_id == "" or socket_id == "none":
			continue
		var direction: Vector3i = suggestion.get("direction", Vector3i.ZERO)
		if direction == Vector3i.ZERO:
			continue
		var socket := tile.get_socket_by_direction(direction)
		if socket == null:
			socket = Socket.new()
			socket.direction = direction
			tile.add_socket(socket)
		var compat_set := {}
		for compat in suggestion.get("compatible", []):
			var compat_id := str(compat).strip_edges()
			if compat_id == "":
				continue
			compat_set[compat_id] = true
		var compat_list: Array[String] = []
		for compat_id in compat_set.keys():
			compat_list.append(str(compat_id))
		compat_list.sort()
		socket.socket_id = socket_id
		socket.compatible_sockets = _to_string_array(compat_list)
		if current_library:
			current_library.register_socket_type(socket_id)
			for compat_id in compat_list:
				current_library.register_socket_type(compat_id)
		var partner_socket: Socket = suggestion.get("partner_socket", null)
		if partner_socket:
			var partner_compats: Array[String] = []
			partner_compats.assign(partner_socket.compatible_sockets)
			if socket_id not in partner_compats:
				partner_compats.append(socket_id)
			partner_socket.compatible_sockets = _to_string_array(partner_compats)
		changed = true
	if changed:
		tile.sockets = tile.sockets

func _open_socket_wizard_for_tile(tile: Tile) -> bool:
	if tile == null or current_library == null:
		return false
	var wizard := SocketWizardDialogScene.instantiate() as SocketWizardDialog
	if wizard == null:
		push_warning("Failed to create Socket Wizard dialog")
		return false
	_active_wizard = wizard
	add_child(wizard)
	wizard.wizard_applied.connect(_on_suggestions_wizard_applied)
	wizard.canceled.connect(_on_suggestions_wizard_closed)
	wizard.confirmed.connect(_on_suggestions_wizard_closed)
	wizard.call_deferred("initialize", tile, current_library)
	wizard.popup_centered()
	return true

func _on_suggestions_wizard_applied(tile: Tile, _changed_tiles: Array) -> void:
	_save_library()
	_refresh_tile_list()
	if tile:
		selected_tile = tile
		tile_selected.emit(tile)

func _on_suggestions_wizard_closed() -> void:
	if _active_wizard:
		_active_wizard.queue_free()
		_active_wizard = null
	if _show_next_after_wizard:
		_show_next_after_wizard = false
		_show_next_socket_suggestion()

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

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
