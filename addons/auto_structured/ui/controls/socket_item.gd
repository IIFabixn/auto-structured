@tool
class_name SocketItem extends FoldableContainer
## UI component for displaying and editing a socket's properties.
##
## Use initialize(socket, library, tile) to set up the socket item after adding to tree.
## This ensures proper initialization order and avoids setter side effects.

signal changed
signal selected
signal preview_requested
signal socket_types_changed  # Emitted when socket types are added/modified

const Socket = preload("res://addons/auto_structured/core/socket.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const ManageSocketsDialog = preload("res://addons/auto_structured/ui/dialogs/manage_sockets_dialog.tscn")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const RequirementItem = preload("res://addons/auto_structured/ui/controls/requirement_item.tscn")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const WfcHelper = preload("res://addons/auto_structured/core/wfc/wfc_helper.gd")

var socket: Socket = null
var library: ModuleLibrary = null
var current_tile: Tile = null

var socket_type_option: OptionButton
var manage_sockets_dialog: Window
var add_socket_requirement_menu: PopupMenu

@onready var manage_sockets_button: Button = $VBoxContainer/ManageSocketsButton
@onready var context_menu: PopupMenu = $PopupMenu
@onready var socket_requirements_container: VBoxContainer = %RequirementsContainer
@onready var add_socket_requirement_button: Button = %AddRequirementButton

const MENU_PREVIEW = 0
const CLEAR = 1

func _ready() -> void:
	socket_type_option = get_node_or_null("VBoxContainer/SocketTypeOption")
	
	if manage_sockets_button:
		manage_sockets_button.pressed.connect(_on_manage_sockets_pressed)
	
	if socket_type_option:
		socket_type_option.item_selected.connect(_on_socket_type_selected)
		# Refresh dropdown every time it's about to open
		var popup = socket_type_option.get_popup()
		if popup:
			popup.about_to_popup.connect(_refresh_socket_type_dropdown)
	
	if add_socket_requirement_button:
		add_socket_requirement_button.pressed.connect(_on_add_socket_requirement_pressed)
	
	_setup_socket_requirement_menu()
	
	# Setup context menu
	if context_menu:
		context_menu.clear()
		context_menu.add_item("Preview Compatible Tiles", MENU_PREVIEW)
		context_menu.add_item("Clear Socket Type", CLEAR)
		context_menu.id_pressed.connect(_on_context_menu_item_selected)


## Initialize the socket item with all required data.
## Call this after adding the socket item to the scene tree.
## This ensures proper initialization order without setter side effects.
func initialize(p_socket: Socket, p_library: ModuleLibrary, p_tile: Tile) -> void:
	# Set state first
	socket = p_socket
	library = p_library
	current_tile = p_tile
	
	# Update all UI based on state
	_update_all_ui()


func _update_all_ui() -> void:
	"""Update all UI elements based on current socket, library, and tile."""
	_refresh_socket_type_dropdown()
	if socket and socket_type_option:
		_select_socket_type_in_dropdown(socket.socket_id)
	_update_sockets_button_text()
	_display_socket_requirements()
	update_title()
	selected.emit()


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
	changed.emit()

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
	
	# Refresh the socket type dropdown (other sockets will refresh when opened)
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
	changed.emit()

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
			changed.emit()
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
		Vector3i(1, 0, 0): "Right (+X)",
		Vector3i(-1, 0, 0): "Left (-X)",
		Vector3i(0, 1, 0): "Up (+Y)",
		Vector3i(0, -1, 0): "Down (-Y)",
		Vector3i(0, 0, 1): "Forward (+Z)",
		Vector3i(0, 0, -1): "Back (-Z)"
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
		CLEAR:
			if socket:
				socket.socket_id = ""
				if socket_type_option:
					_select_socket_type_in_dropdown("")
				update_title()
				for compatible in socket.compatible_sockets:
					socket.remove_compatible_socket(compatible)
				_update_sockets_button_text()
				changed.emit()

# ============================================================================
# Socket Requirements Management
# ============================================================================

func _setup_socket_requirement_menu() -> void:
	"""Setup popup menu for adding different requirement types to sockets"""
	add_socket_requirement_menu = PopupMenu.new()
	add_child(add_socket_requirement_menu)
	
	add_socket_requirement_menu.add_item("Tag Requirement", 0)
	add_socket_requirement_menu.add_item("Height Range", 1)
	add_socket_requirement_menu.add_item("Ground Level Only", 2)
	add_socket_requirement_menu.add_item("Rotation Requirement", 3)
	
	add_socket_requirement_menu.id_pressed.connect(_on_socket_requirement_type_selected)


func _on_add_socket_requirement_pressed() -> void:
	"""Show menu to select requirement type for socket"""
	if add_socket_requirement_menu and add_socket_requirement_button:
		var button_pos = add_socket_requirement_button.global_position
		var button_size = add_socket_requirement_button.size
		add_socket_requirement_menu.position = Vector2i(button_pos.x, button_pos.y + button_size.y)
		add_socket_requirement_menu.popup()


func _on_socket_requirement_type_selected(id: int) -> void:
	"""Create a new requirement for this socket"""
	if not socket:
		return
	
	const GroundRequirement = preload("res://addons/auto_structured/core/requirements/ground_requirement.gd")
	const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
	const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
	const RotationRequirement = preload("res://addons/auto_structured/core/requirements/rotation_requirement.gd")
	
	var new_requirement: Requirement = null
	
	match id:
		0:  # Tag Requirement (most common for sockets)
			new_requirement = TagRequirement.new()
		1:  # Height Range
			new_requirement = HeightRequirement.new()
			new_requirement.max_height = 10
		2:  # Ground Level
			new_requirement = GroundRequirement.new()
		3:  # Rotation Requirement
			new_requirement = RotationRequirement.new()
			new_requirement.minimum_rotation_degrees = 90
	
	if new_requirement:
		# Add to socket's requirements array
		var reqs_copy: Array[Requirement] = []
		reqs_copy.assign(socket.requirements)
		reqs_copy.append(new_requirement)
		socket.requirements = reqs_copy
		
		print("Socket requirement added. Socket now has %d requirements" % socket.requirements.size())
		
		# Add to UI
		_add_socket_requirement_item(new_requirement)
		changed.emit()


func _add_socket_requirement_item(requirement: Requirement) -> void:
	"""Add a requirement item to the socket's requirement container"""
	if not requirement or not socket_requirements_container:
		return
	
	var req_item = RequirementItem.instantiate()
	socket_requirements_container.add_child(req_item)
	# Set properties after adding to tree so _ready() is called
	req_item.requirement = requirement
	req_item.library = library
	req_item.changed.connect(_on_socket_requirement_changed)
	req_item.deleted.connect(_on_socket_requirement_deleted)


func _display_socket_requirements() -> void:
	"""Display all requirements for this socket"""
	if not socket or not socket_requirements_container:
		return
	
	print("Displaying socket requirements. Socket has %d requirements" % socket.requirements.size())
	
	# Clear existing requirement items (but not the add button)
	for child in socket_requirements_container.get_children():
		if child is RequirementItem:
			child.queue_free()
	
	# Add requirement items for each requirement
	for requirement in socket.requirements:
		_add_socket_requirement_item(requirement)


func _on_socket_requirement_changed(_requirement: Requirement) -> void:
	"""Handle socket requirement property changes"""
	changed.emit()


func _on_socket_requirement_deleted(requirement: Requirement) -> void:
	"""Remove requirement from socket and UI"""
	if not socket:
		return
	
	var reqs_copy: Array[Requirement] = []
	reqs_copy.assign(socket.requirements)
	reqs_copy.erase(requirement)
	socket.requirements = reqs_copy
	
	# Remove from UI
	for child in socket_requirements_container.get_children():
		if child is RequirementItem and child.requirement == requirement:
			child.queue_free()
			break
	
	changed.emit()
