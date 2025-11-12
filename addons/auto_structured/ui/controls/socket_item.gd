@tool
class_name SocketItem extends FoldableContainer

signal changed
signal selected
signal preview_requested

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const ManageSocketsDialog = preload("res://addons/auto_structured/ui/controls/manage_sockets_dialog.tscn")
const Tile = preload("res://addons/auto_structured/core/tile.gd")

@export var socket: Socket = null:
	set(value):
		socket = value
		if socket_type_option and socket:
			_select_socket_type_in_dropdown(socket.socket_id)
		_update_sockets_button_text()
		selected.emit()

var library: ModuleLibrary = null:
	set(value):
		library = value
		_refresh_socket_type_dropdown()

var socket_type_option: OptionButton
var manage_sockets_dialog: Window
var current_tile: Tile = null  # The tile this socket belongs to

@onready var manage_sockets_button: Button = $VBoxContainer/ManageSocketsButton
@onready var context_menu: PopupMenu = $PopupMenu

const MENU_PREVIEW = 0

func _ready() -> void:
	socket_type_option = get_node_or_null("VBoxContainer/SocketTypeOption")
	
	if manage_sockets_button:
		manage_sockets_button.pressed.connect(_on_manage_sockets_pressed)
	
	if socket_type_option:
		socket_type_option.item_selected.connect(_on_socket_type_selected)
	
	# Setup context menu
	if context_menu:
		context_menu.clear()
		context_menu.add_item("Preview Compatible Tiles", MENU_PREVIEW)
		context_menu.id_pressed.connect(_on_context_menu_item_selected)

	_refresh_socket_type_dropdown()
	_update_sockets_button_text()
	update_title()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if context_menu:
			# Get the screen position of the mouse
			var mouse_pos = DisplayServer.mouse_get_position()
			context_menu.position = mouse_pos
			context_menu.popup()
			accept_event()  # Prevent the event from propagating

func _update_sockets_button_text() -> void:
	"""Update the manage sockets button to show count"""
	if not manage_sockets_button or not socket:
		return
	
	var count = socket.compatible_sockets.size()
	if count == 0:
		manage_sockets_button.text = "Compatible Sockets: None"
	elif count == 1:
		manage_sockets_button.text = "Compatible Sockets: 1"
	else:
		manage_sockets_button.text = "Compatible Sockets: %d" % count

func _on_manage_sockets_pressed() -> void:
	"""Open dialog to manage compatible sockets"""
	if not socket or not library:
		return
	
	# Create dialog if it doesn't exist
	if not manage_sockets_dialog:
		manage_sockets_dialog = ManageSocketsDialog.instantiate()
		manage_sockets_dialog.sockets_changed.connect(_on_compatible_sockets_changed)
		manage_sockets_dialog.new_type_requested.connect(_on_new_type_requested)
		add_child(manage_sockets_dialog)
	
	# Get all registered socket types from library
	var available_sockets = library.get_socket_types()
	
	# Update the dialog with available and selected sockets
	manage_sockets_dialog.set_available_sockets(available_sockets, socket.compatible_sockets)
	
	# Show dialog
	manage_sockets_dialog.popup_centered()

func _on_compatible_sockets_changed(socket_ids: Array[String]) -> void:
	"""Handle changes from the manage sockets dialog"""
	if not socket:
		return
	
	# Clear current compatible sockets
	socket.compatible_sockets = []
	
	# Add all selected sockets
	for socket_id in socket_ids:
		socket.add_compatible_socket(socket_id)
	
	_update_sockets_button_text()
	changed.emit(socket)

func _on_new_type_requested(type_name: String) -> void:
	"""Handle request to add a new socket type"""
	if not library:
		return
	
	# Register the new type in the library
	library.register_socket_type(type_name)
	
	# Refresh the dialog with updated list (use socket_types, not just IDs in use)
	if manage_sockets_dialog and manage_sockets_dialog.visible:
		var available_sockets = library.get_socket_types()
		manage_sockets_dialog.set_available_sockets(available_sockets, socket.compatible_sockets)
	
	# Also refresh the socket type dropdown
	_refresh_socket_type_dropdown()

func _refresh_socket_type_dropdown() -> void:
	if not socket_type_option or not library:
		return
	
	socket_type_option.clear()
	socket_type_option.add_item("-- Select Socket Type --", -1)
	socket_type_option.set_item_disabled(0, true)
	
	var socket_types = library.get_socket_types()
	for i in range(socket_types.size()):
		socket_type_option.add_item(socket_types[i], i)
	
	socket_type_option.add_separator()
	socket_type_option.add_item("+ Add New Type...", 9999)
	
	if socket:
		_select_socket_type_in_dropdown(socket.socket_id)

func _select_socket_type_in_dropdown(socket_id: String) -> void:
	if not socket_type_option:
		return
	
	for i in range(socket_type_option.item_count):
		if socket_type_option.get_item_text(i) == socket_id:
			socket_type_option.selected = i
			return

func _on_socket_type_selected(index: int) -> void:
	if not socket or not socket_type_option:
		return
	
	var item_id = socket_type_option.get_item_id(index)
	
	# Handle "Add New Type" option
	if item_id == 9999:
		_show_add_new_type_dialog()
		return
	
	var selected_type = socket_type_option.get_item_text(index)
	socket.socket_id = selected_type
	update_title()
	changed.emit(socket)

func _show_add_new_type_dialog() -> void:
	# Create a simple dialog for adding new socket type
	var dialog = AcceptDialog.new()
	dialog.title = "Add New Socket Type"
	dialog.dialog_text = "Enter new socket type ID:"
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "e.g. wall_plain"
	dialog.add_child(line_edit)
	
	dialog.confirmed.connect(func():
		var new_type = line_edit.text.strip_edges()
		if new_type and library:
			library.register_socket_type(new_type)
			_refresh_socket_type_dropdown()
			# Select the newly added type
			_select_socket_type_in_dropdown(new_type)
			socket.socket_id = new_type
			update_title()
			changed.emit(socket)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		# Reset to previous selection
		if socket:
			_select_socket_type_in_dropdown(socket.socket_id)
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func update_title() -> void:
	if not socket:
		return

	var icon = get_direction_icon(socket.direction)
	var dir_name = get_direction_name(socket.direction)
	var socket_type = socket.socket_id if socket.socket_id else "(not set)"
	title = "%s %s: %s" % [icon, dir_name, socket_type]
	
	if socket_type_option:
		_select_socket_type_in_dropdown(socket.socket_id)

func get_direction_name(direction: Vector3i) -> String:
	var direction_names = {
		Vector3i(1, 0, 0): "Right",
		Vector3i(-1, 0, 0): "Left",
		Vector3i(0, 1, 0): "Up",
		Vector3i(0, -1, 0): "Down",
		Vector3i(0, 0, 1): "Forward",
		Vector3i(0, 0, -1): "Back"
	}

	return direction_names.get(direction, "Unknown")

func get_direction_icon(direction: Vector3i) -> String:
	var direction_icons = {
		Vector3i(1, 0, 0): "➡️",
		Vector3i(-1, 0, 0): "⬅️",
		Vector3i(0, 1, 0): "⬆️",
		Vector3i(0, -1, 0): "⬇️",
		Vector3i(0, 0, 1): "⏩",
		Vector3i(0, 0, -1): "⏪"
	}

	return direction_icons.get(direction, "❓")

func _on_context_menu_item_selected(id: int) -> void:
	"""Handle context menu item selection"""
	match id:
		MENU_PREVIEW:
			preview_requested.emit()

func get_compatible_tiles() -> Array[Tile]:
	"""Get all tiles that have sockets compatible with this socket"""
	var compatible_tiles: Array[Tile] = []
	
	if not library or not socket:
		return compatible_tiles
	
	# Get the opposite direction (where tiles would connect)
	var opposite_direction = -socket.direction
	
	# Check all tiles in the library
	for tile in library.tiles:
		# Skip the current tile (don't show itself as compatible)
		if tile == current_tile:
			continue
		
		# Get the socket on the opposite side
		var tile_socket = tile.get_socket_by_direction(opposite_direction)
		if not tile_socket:
			continue
		
		# Check if the sockets are compatible
		if socket.is_compatible_with(tile_socket) or tile_socket.is_compatible_with(socket):
			compatible_tiles.append(tile)
	
	return compatible_tiles
