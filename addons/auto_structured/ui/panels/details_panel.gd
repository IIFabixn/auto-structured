@tool
class_name DetailsPanel extends Control

## Panel for displaying and editing tile properties.
##
## Provides a clean API for showing tile details with proper state initialization.
## Use show_tile(tile, library) to display a tile's properties.

signal closed
signal tile_modified(tile: Tile)
signal socket_preview_requested(socket: Socket)
signal socket_editor_requested(tile: Tile, start_mode: int)
signal request_preview(tile: Tile, socket: Socket)

const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")
const SelectionManager = preload("res://addons/auto_structured/core/events/selection_manager.gd")
const ValidationEventBus = preload("res://addons/auto_structured/core/events/validation_event_bus.gd")
const RequirementItemScene = preload("res://addons/auto_structured/ui/controls/details_panel_controls/requirement_item.tscn")
const RequirementItem = preload("res://addons/auto_structured/ui/controls/details_panel_controls/requirement_item.gd")
const TileThumbnailGenerator = preload("res://addons/auto_structured/utils/thumbnail_generator.gd")
const AddRequirementAction = preload("res://addons/auto_structured/core/actions/add_requirement_action.gd")
const RemoveRequirementAction = preload("res://addons/auto_structured/core/actions/remove_requirement_action.gd")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

const REQUIREMENTS_DIR := "res://addons/auto_structured/core/requirements"
const REQUIREMENT_MENU_META_TYPES := "requirement_type_defs"

const SOCKET_MENU_ID_NONE := 1000000
const SOCKET_MENU_ID_ANY := 1000001
const SOCKET_MENU_META_TYPES := "socket_type_mapping"

@onready var close_button: TextureButton = %CloseButton

@onready var name_label: Label = %NameLabel
@onready var preview_image: TextureRect = %TileImage

@onready var tab_container: TabContainer = %DetailsTabContainer
@onready var general_tab: Control = %DetailsTabContainer/Generel
@onready var requirements_tab: Control = %DetailsTabContainer/Requirements
@onready var sockets_tab: Control = %DetailsTabContainer/Sockets

@onready var x_size_spinbox: SpinBox = %XSizeSpinBox
@onready var y_size_spinbox: SpinBox = %YSizeSpinBox
@onready var z_size_spinbox: SpinBox = %ZSizeSpinBox

@onready var tags_menu_button: MenuButton = %TagsMenuButton
@onready var add_tag_button: TextureButton = %AddTagButton

@onready var weight_spinbox: SpinBox = %WeightSpinBox

@onready var rotation_symmetry_options: OptionButton = %RotationSymmetryOptionsButton

@onready var add_requirement_menu_button: MenuButton = %AddRequirementMenuButton
@onready var requirements_container: VBoxContainer = %RequirementsContainer

@onready var add_socket_button: TextureButton = %AddSocketButton

@onready var upSocketMenuButton: MenuButton = %UpSocketMenuButton
@onready var previewUpSocketButton: TextureButton = %PreviewUpSocketButton
@onready var downSocketMenuButton: MenuButton = %DownSocketMenuButton
@onready var previewDownSocketButton: TextureButton = %PreviewDownSocketButton
@onready var leftSocketMenuButton: MenuButton = %LeftSocketMenuButton
@onready var previewLeftSocketButton: TextureButton = %PreviewLeftSocketButton
@onready var rightSocketMenuButton: MenuButton = %RightSocketMenuButton
@onready var previewRightSocketButton: TextureButton = %PreviewRightSocketButton
@onready var frontSocketMenuButton: MenuButton = %FrontSocketMenuButton
@onready var previewFrontSocketButton: TextureButton = %PreviewFrontSocketButton
@onready var backSocketMenuButton: MenuButton = %BackSocketMenuButton
@onready var previewBackSocketButton: TextureButton = %PreviewBackSocketButton

var _tile: Tile
@export var tile: Tile:
	get:
		return _tile
	set(value):
		_tile = value
		if is_node_ready():
			_update_ui()

var undo_redo_manager: AutoStructuredUndoRedo
var selection_manager: SelectionManager
var validation_bus: ValidationEventBus
var current_library: ModuleLibrary

var _requirement_type_defs: Array = []

func _get_library() -> ModuleLibrary:
	"""
	Get the current library reference.
	Returns null if no library is set - caller should handle this gracefully.
	"""
	if not current_library:
		push_warning("DetailsPanel: No library reference - ensure setup_library() was called")
	return current_library

func _ready() -> void:
	"""Initialize the panel and connect signals."""
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Setup rotation symmetry options
	_setup_rotation_symmetry_options()
	_setup_requirement_menu()
	
	# Connect size spinboxes
	if x_size_spinbox:
		x_size_spinbox.value_changed.connect(_on_x_size_changed)
	if y_size_spinbox:
		y_size_spinbox.value_changed.connect(_on_y_size_changed)
	if z_size_spinbox:
		z_size_spinbox.value_changed.connect(_on_z_size_changed)
	
	# Connect weight spinbox
	if weight_spinbox:
		weight_spinbox.value_changed.connect(_on_weight_changed)
	
	# Connect tag controls
	if add_tag_button:
		add_tag_button.pressed.connect(_on_add_tag_pressed)
	
	# Connect tags menu button signals
	if tags_menu_button:
		var popup = tags_menu_button.get_popup()
		if not popup.about_to_popup.is_connected(_on_tags_menu_about_to_popup):
			popup.about_to_popup.connect(_on_tags_menu_about_to_popup)
		if not popup.id_pressed.is_connected(_on_tag_menu_item_pressed):
			popup.id_pressed.connect(_on_tag_menu_item_pressed)
	
	# Connect socket menu buttons and preview buttons
	_setup_socket_button(upSocketMenuButton, previewUpSocketButton, Vector3i.UP)
	_setup_socket_button(downSocketMenuButton, previewDownSocketButton, Vector3i.DOWN)
	_setup_socket_button(leftSocketMenuButton, previewLeftSocketButton, Vector3i.LEFT)
	_setup_socket_button(rightSocketMenuButton, previewRightSocketButton, Vector3i.RIGHT)
	_setup_socket_button(frontSocketMenuButton, previewFrontSocketButton, Vector3i.FORWARD)
	_setup_socket_button(backSocketMenuButton, previewBackSocketButton, Vector3i.BACK)
	
	# Start hidden until a tile is selected
	hide()

func _setup_rotation_symmetry_options() -> void:
	"""Populate the rotation symmetry dropdown with enum values."""
	if not rotation_symmetry_options:
		return
	
	rotation_symmetry_options.clear()
	rotation_symmetry_options.add_item("Auto-detect", Tile.RotationSymmetry.AUTO)
	rotation_symmetry_options.add_item("Full (4 rotations)", Tile.RotationSymmetry.FULL)
	rotation_symmetry_options.add_item("Half (2 rotations)", Tile.RotationSymmetry.HALF)
	rotation_symmetry_options.add_item("Quarter (1 rotation)", Tile.RotationSymmetry.QUARTER)
	rotation_symmetry_options.add_item("Custom", Tile.RotationSymmetry.CUSTOM)
	
	# Connect to value change
	if not rotation_symmetry_options.item_selected.is_connected(_on_rotation_symmetry_changed):
		rotation_symmetry_options.item_selected.connect(_on_rotation_symmetry_changed)

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
	# Disconnect from old manager if exists
	if selection_manager and selection_manager.tile_selected.is_connected(_on_tile_selected_via_eventbus):
		selection_manager.tile_selected.disconnect(_on_tile_selected_via_eventbus)
	
	selection_manager = manager
	
	# Connect to tile selection events
	if selection_manager and not selection_manager.tile_selected.is_connected(_on_tile_selected_via_eventbus):
		selection_manager.tile_selected.connect(_on_tile_selected_via_eventbus)

func setup_library(library: ModuleLibrary) -> void:
	"""
	Set the current library reference.
	Should be called by the parent viewport when library changes.
	"""
	current_library = library

func setup_validation_bus(bus: ValidationEventBus) -> void:
	"""
	Initialize the validation event bus.
	Should be called by the parent viewport after instantiation.
	"""
	validation_bus = bus

func _on_tile_selected_via_eventbus(selected_tile: Tile, _previous_tile: Tile) -> void:
	"""Handle tile selection from the event bus."""
	if selected_tile:
		tile = selected_tile
		show()
	else:
		hide()

func _on_close_pressed() -> void:
	"""Handle close button press."""
	closed.emit()
	hide()

func _update_ui() -> void:
	"""Update all UI elements to reflect the current tile's properties."""
	if add_requirement_menu_button:
		add_requirement_menu_button.disabled = _tile == null
	if not _tile:
		return
	
	# Update name
	if name_label:
		name_label.text = _tile.name if _tile.name else "Unnamed Tile"
	
	# Update size
	if x_size_spinbox:
		x_size_spinbox.value = _tile.size.x
	if y_size_spinbox:
		y_size_spinbox.value = _tile.size.y
	if z_size_spinbox:
		z_size_spinbox.value = _tile.size.z
	
	# Update weight
	if weight_spinbox:
		weight_spinbox.value = _tile.weight
	
	# Update rotation symmetry
	if rotation_symmetry_options:
		rotation_symmetry_options.select(_tile.rotation_symmetry)
	
	# Update tags display
	_update_tags_display()
	
	# Update requirements
	_update_requirements_display()
	
	# Update sockets
	_update_sockets_display()
	
	# Update preview image
	_update_preview_image()
	
	# Validate tile
	_validate_tile()

func _update_tags_display() -> void:
	"""Update the tags menu button text to show current tags."""
	if not tags_menu_button or not _tile:
		return
	
	if _tile.tags.is_empty():
		tags_menu_button.text = "None"
	else:
		tags_menu_button.text = ", ".join(_tile.tags)

func _on_tags_menu_about_to_popup() -> void:
	"""Populate the tags menu when it's about to open."""
	if not is_node_ready() or not tags_menu_button or not _tile:
		return
	
	var popup = tags_menu_button.get_popup()
	popup.clear()
	
	# Get all available tags from library (if available)
	var available_tags: Array[String] = []
	var library = _get_library()
	if library:
		available_tags = library.get_available_tags()
	
	# If no library tags, at least show the tile's current tags
	if available_tags.is_empty() and not _tile.tags.is_empty():
		available_tags = _tile.tags.duplicate()
	
	# Add library tags to menu with checkboxes
	for i in range(available_tags.size()):
		var tag = available_tags[i]
		popup.add_check_item(tag, i)
		
		# Check if this tag is on the tile
		if tag in _tile.tags:
			popup.set_item_checked(i, true)

func _update_requirements_display() -> void:
	"""Update the requirements list."""
	if not requirements_container or not _tile:
		return
	
	# Clear existing requirement items
	for child in requirements_container.get_children():
		child.queue_free()
	
	# Add requirement items
	for req in _tile.requirements:
		var item = RequirementItemScene.instantiate()
		if item is RequirementItem:
			requirements_container.add_child(item)
			item.requirement = req
			item.requirement_modified.connect(_on_requirement_modified)
			item.requirement_deleted.connect(_on_requirement_deleted)

func _update_sockets_display() -> void:
	"""Update socket menu buttons for all directions."""
	if not _tile:
		return
	
	# Update all 6 directional socket menu buttons
	_update_socket_menu_button_text(upSocketMenuButton, Vector3i.UP)
	_update_socket_menu_button_text(downSocketMenuButton, Vector3i.DOWN)
	_update_socket_menu_button_text(leftSocketMenuButton, Vector3i.LEFT)
	_update_socket_menu_button_text(rightSocketMenuButton, Vector3i.RIGHT)
	_update_socket_menu_button_text(frontSocketMenuButton, Vector3i.FORWARD)
	_update_socket_menu_button_text(backSocketMenuButton, Vector3i.BACK)

func _update_socket_menu_button_text(menu_button: MenuButton, direction: Vector3i) -> void:
	"""Update a single socket menu button's text based on tile's sockets for that direction."""
	if not menu_button or not _tile:
		return
	
	# Get sockets for this direction
	var sockets_in_direction = _tile.get_sockets_in_direction(direction)
	
	if sockets_in_direction.is_empty():
		menu_button.text = "none"
		return

	var has_any_type := false
	var display_ids: Array[String] = []
	for socket in sockets_in_direction:
		if socket.socket_type == null:
			continue
		var type_id: String = socket.socket_type.type_id.strip_edges()
		if type_id == "any":
			has_any_type = true
		elif type_id != "" and type_id != "none":
			if not display_ids.has(type_id):
				display_ids.append(type_id)

	if has_any_type and display_ids.is_empty():
		menu_button.text = "any"
		return

	if display_ids.is_empty():
		menu_button.text = "none"
		return

	display_ids.sort()
	menu_button.text = ", ".join(display_ids)

func _update_preview_image() -> void:
	"""Update the preview image/3D representation of the tile."""
	if not preview_image or not _tile:
		return
	
	var texture = await TileThumbnailGenerator.generate_thumbnail(_tile, self, Vector2i(128, 128))
	if texture:
		preview_image.texture = texture

func _on_requirement_modified(requirement) -> void:
	"""Handle requirement modification."""
	if _tile:
		tile_modified.emit(_tile)

func _on_requirement_deleted(requirement) -> void:
	"""Handle requirement deletion."""
	if not _tile:
		return
	
	if undo_redo_manager:
		var action := RemoveRequirementAction.new(undo_redo_manager, _tile, requirement)
		action.execute()
	else:
		_tile.requirements.erase(requirement)
	_update_requirements_display()
	_validate_tile()
	tile_modified.emit(_tile)

func _on_rotation_symmetry_changed(index: int) -> void:
	"""Handle rotation symmetry selection change."""
	if not _tile or not rotation_symmetry_options:
		return
	
	var selected_id = rotation_symmetry_options.get_item_id(index)
	_tile.rotation_symmetry = selected_id
	tile_modified.emit(_tile)

func _on_x_size_changed(value: float) -> void:
	"""Handle X size spinbox change."""
	if not _tile:
		return
	_tile.size.x = int(value)
	_validate_tile()
	tile_modified.emit(_tile)

func _on_y_size_changed(value: float) -> void:
	"""Handle Y size spinbox change."""
	if not _tile:
		return
	_tile.size.y = int(value)
	_validate_tile()
	tile_modified.emit(_tile)

func _on_z_size_changed(value: float) -> void:
	"""Handle Z size spinbox change."""
	if not _tile:
		return
	_tile.size.z = int(value)
	_validate_tile()
	tile_modified.emit(_tile)

func _on_weight_changed(value: float) -> void:
	"""Handle weight spinbox change."""
	if not _tile:
		return
	_tile.weight = value
	_validate_tile()
	tile_modified.emit(_tile)

func _on_add_tag_pressed() -> void:
	"""Handle add tag button press - show input dialog."""
	var dialog = AcceptDialog.new()
	dialog.title = "Add Tag"
	dialog.dialog_text = "Enter tag name:"
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "tag_name"
	dialog.add_child(line_edit)
	
	# Set minimum size for the dialog
	dialog.min_size = Vector2(300, 100)
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Focus the line edit
	line_edit.grab_focus()
	
	# Handle confirmation
	var on_confirmed = func():
		var tag_name = line_edit.text.strip_edges()
		if not tag_name.is_empty() and _tile:
			if _tile.add_tag(tag_name):
				# Add tag to library's available tags
				var library = _get_library()
				if library:
					library.add_available_tag(tag_name)
				_update_tags_display()
				tile_modified.emit(_tile)
		dialog.queue_free()
	
	var on_canceled = func():
		dialog.queue_free()
	
	dialog.confirmed.connect(on_confirmed)
	dialog.canceled.connect(on_canceled)
	
	# Also allow Enter key to confirm
	line_edit.text_submitted.connect(func(_text): 
		on_confirmed.call()
	)

func _on_tag_menu_item_pressed(id: int) -> void:
	"""Handle tag menu item press - toggle the tag on/off."""
	if not _tile:
		return
	
	# Get all available tags (same logic as popup)
	var available_tags: Array[String] = []
	var library = _get_library()
	if library:
		available_tags = library.get_available_tags()
	if available_tags.is_empty() and not _tile.tags.is_empty():
		available_tags = _tile.tags.duplicate()
	
	if id < 0 or id >= available_tags.size():
		return
	
	var tag = available_tags[id]
	
	# Toggle tag on/off
	if tag in _tile.tags:
		_tile.remove_tag(tag)
	else:
		_tile.add_tag(tag)
	
	_update_tags_display()
	tile_modified.emit(_tile)

func _setup_socket_button(menu_button: MenuButton, preview_button: TextureButton, direction: Vector3i) -> void:
	"""Setup a socket menu button and its preview button for a specific direction."""
	if not menu_button:
		return
	
	# Connect menu button popup
	var popup = menu_button.get_popup()
	if popup:
		# Store direction in metadata for later use
		menu_button.set_meta("socket_direction", direction)
		
		if not popup.about_to_popup.is_connected(_on_socket_menu_about_to_popup.bind(direction)):
			popup.about_to_popup.connect(_on_socket_menu_about_to_popup.bind(direction))
		if not popup.id_pressed.is_connected(_on_socket_menu_item_pressed.bind(direction)):
			popup.id_pressed.connect(_on_socket_menu_item_pressed.bind(direction))
	
	# Connect preview button
	if preview_button:
		preview_button.set_meta("socket_direction", direction)
		if not preview_button.pressed.is_connected(_on_preview_socket_pressed.bind(direction)):
			preview_button.pressed.connect(_on_preview_socket_pressed.bind(direction))

func _on_socket_menu_about_to_popup(direction: Vector3i) -> void:
	"""Populate socket menu when it's about to open."""
	if not _tile:
		return
	
	var library = _get_library()
	if not library:
		return
	
	# Find the menu button for this direction
	var menu_button = _get_socket_menu_button_for_direction(direction)
	if not menu_button:
		return
	
	var popup = menu_button.get_popup()
	popup.clear()

	var current_sockets = _tile.get_sockets_in_direction(direction)
	var selected_type_ids: Array[String] = []
	var has_any_type := false
	for socket in current_sockets:
		if socket.socket_type == null:
			continue
		var type_id: String = socket.socket_type.type_id.strip_edges()
		if type_id == "any":
			has_any_type = true
		elif type_id != "" and type_id != "none":
			if not selected_type_ids.has(type_id):
				selected_type_ids.append(type_id)

	var none_selected := current_sockets.is_empty() or (selected_type_ids.is_empty() and not has_any_type)
	var any_selected := has_any_type and selected_type_ids.is_empty()

	var none_index := popup.get_item_count()
	popup.add_radio_check_item("None", SOCKET_MENU_ID_NONE)
	popup.set_item_checked(none_index, none_selected)

	var any_index := popup.get_item_count()
	popup.add_radio_check_item("Any", SOCKET_MENU_ID_ANY)
	popup.set_item_checked(any_index, any_selected)

	popup.add_separator()

	var socket_types = library.get_socket_type_resources()
	var selectable_types: Array[SocketType] = []
	for socket_type in socket_types:
		if socket_type == null:
			continue
		var type_id: String = socket_type.type_id.strip_edges()
		if type_id == "" or type_id == "none" or type_id == "any":
			continue
		selectable_types.append(socket_type)

	menu_button.set_meta(SOCKET_MENU_META_TYPES, selectable_types)

	for i in range(selectable_types.size()):
		var socket_type: SocketType = selectable_types[i]
		var label := socket_type.get_display_name()
		if label.strip_edges() == "":
			label = socket_type.type_id
		else:
			var trimmed_id := socket_type.type_id.strip_edges()
			if trimmed_id != "" and label != trimmed_id:
				label = "%s [%s]" % [label, trimmed_id]
		var item_index := popup.get_item_count()
		popup.add_check_item(label, i)
		popup.set_item_checked(item_index, selected_type_ids.has(socket_type.type_id.strip_edges()))

func _on_socket_menu_item_pressed(id: int, direction: Vector3i) -> void:
	"""Handle socket menu item press - toggle socket type on/off for this direction."""
	if not _tile:
		return
	
	var library = _get_library()
	if not library:
		return

	match id:
		SOCKET_MENU_ID_NONE:
			_clear_direction_sockets(direction)
		SOCKET_MENU_ID_ANY:
			_set_direction_to_any(direction, library)
		_:
			var menu_button = _get_socket_menu_button_for_direction(direction)
			if not menu_button:
				return
			var selectable_types: Array = menu_button.get_meta(SOCKET_MENU_META_TYPES, [])
			if id < 0 or id >= selectable_types.size():
				return
			var socket_type: SocketType = selectable_types[id]
			_toggle_socket_type(direction, socket_type)
	
	_update_sockets_display()
	tile_modified.emit(_tile)

func _on_preview_socket_pressed(direction: Vector3i) -> void:
	"""Handle preview socket button press - emit request_preview signal."""
	if not _tile:
		push_warning("Cannot preview socket: no tile selected")
		return
	
	# Get the first socket in this direction to preview
	var sockets_in_direction = _tile.get_sockets_in_direction(direction)
	if sockets_in_direction.is_empty():
		push_warning("No socket in direction %s to preview" % direction)
		return
	
	# Emit request_preview signal with the tile and first socket in this direction
	var socket = sockets_in_direction[0]
	request_preview.emit(_tile, socket)

func _get_socket_menu_button_for_direction(direction: Vector3i) -> MenuButton:
	"""Get the menu button for a specific direction."""
	if direction == Vector3i.UP:
		return upSocketMenuButton
	elif direction == Vector3i.DOWN:
		return downSocketMenuButton
	elif direction == Vector3i.LEFT:
		return leftSocketMenuButton
	elif direction == Vector3i.RIGHT:
		return rightSocketMenuButton
	elif direction == Vector3i.FORWARD:
		return frontSocketMenuButton
	elif direction == Vector3i.BACK:
		return backSocketMenuButton
	return null

func _clear_direction_sockets(direction: Vector3i) -> void:
	"""Remove all sockets for a given direction."""
	if not _tile:
		return
	var sockets = _tile.get_sockets_in_direction(direction)
	for socket in sockets:
		_tile.remove_socket(socket)

func _set_direction_to_any(direction: Vector3i, library: ModuleLibrary) -> void:
	"""Replace sockets in the direction with a single 'any' socket."""
	if not _tile:
		return
	_clear_direction_sockets(direction)
	var any_type: SocketType = library.get_socket_type_by_id("any")
	if not any_type:
		any_type = library.ensure_socket_type("any")
	if not any_type:
		push_warning("DetailsPanel: Could not resolve 'any' socket type in library")
		return
	var socket = Socket.new()
	socket.direction = direction
	socket.socket_type = any_type
	_tile.add_socket(socket)

func _toggle_socket_type(direction: Vector3i, socket_type: SocketType) -> void:
	"""Toggle a specific socket type for a direction."""
	if socket_type == null:
		return
	if not _tile:
		return

	var sockets = _tile.get_sockets_in_direction(direction)
	for socket in sockets:
		if socket.socket_type == socket_type:
			_tile.remove_socket(socket)
			return

	_remove_placeholder_sockets(direction)
	_remove_any_socket(direction)
	var new_socket = Socket.new()
	new_socket.direction = direction
	new_socket.socket_type = socket_type
	_tile.add_socket(new_socket)

func _remove_placeholder_sockets(direction: Vector3i) -> void:
	"""Remove sockets with empty type or 'none' marker in a direction."""
	if not _tile:
		return
	var sockets = _tile.get_sockets_in_direction(direction)
	for socket in sockets:
		if socket.socket_type == null:
			_tile.remove_socket(socket)
			continue
		var type_id: String = socket.socket_type.type_id.strip_edges()
		if type_id == "" or type_id == "none":
			_tile.remove_socket(socket)

func _remove_any_socket(direction: Vector3i) -> void:
	"""Remove wildcard 'any' sockets from a direction."""
	if not _tile:
		return
	var sockets = _tile.get_sockets_in_direction(direction)
	for socket in sockets:
		if socket.socket_type and socket.socket_type.type_id.strip_edges() == "any":
			_tile.remove_socket(socket)

func _setup_requirement_menu() -> void:
	"""Connect signals for the add requirement menu and preload available requirement types."""
	_load_requirement_types()
	if not add_requirement_menu_button:
		return
	var popup := add_requirement_menu_button.get_popup()
	if popup:
		if not popup.about_to_popup.is_connected(_on_add_requirement_menu_about_to_popup):
			popup.about_to_popup.connect(_on_add_requirement_menu_about_to_popup)
		if not popup.id_pressed.is_connected(_on_add_requirement_menu_item_pressed):
			popup.id_pressed.connect(_on_add_requirement_menu_item_pressed)

func _load_requirement_types() -> void:
	"""Discover requirement scripts so they can be offered in the menu."""
	if not _requirement_type_defs.is_empty():
		return
	var dir := DirAccess.open(REQUIREMENTS_DIR)
	if not dir:
		push_warning("DetailsPanel: Unable to open requirements directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var discovered: Array = []
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		if not file_name.ends_with(".gd") or file_name == "requirement.gd":
			file_name = dir.get_next()
			continue
		var path := "%s/%s" % [REQUIREMENTS_DIR, file_name]
		var script := load(path)
		if script:
			var instance = script.new()
			if instance is Requirement:
				instance._init()
				var display_name: String = instance.display_name.strip_edges()
				if display_name.is_empty():
					display_name = instance.get_class()
				discovered.append({
					"name": display_name,
					"script": script,
					"path": path,
				})
				instance = null
			else:
				instance = null
		file_name = dir.get_next()
	dir.list_dir_end()
	if discovered.is_empty():
		return
	discovered.sort_custom(func(a, b):
		return a["name"].naturalnocasecmp_to(b["name"]) < 0
	)
	_requirement_type_defs = discovered

func _on_add_requirement_menu_about_to_popup() -> void:
	"""Populate the requirement add menu before it opens."""
	if not add_requirement_menu_button:
		return
	var popup := add_requirement_menu_button.get_popup()
	if not popup:
		return
	popup.clear()
	if not _tile:
		popup.add_item("Select a tile first")
		popup.set_item_disabled(0, true)
		return
	_load_requirement_types()
	if _requirement_type_defs.is_empty():
		popup.add_item("No requirements available")
		popup.set_item_disabled(0, true)
		return
	popup.set_meta(REQUIREMENT_MENU_META_TYPES, _requirement_type_defs)
	for i in range(_requirement_type_defs.size()):
		popup.add_item(_requirement_type_defs[i]["name"], i)

func _on_add_requirement_menu_item_pressed(id: int) -> void:
	"""Create and add a requirement when the menu item is pressed."""
	if not _tile:
		return
	var popup := add_requirement_menu_button.get_popup()
	if not popup:
		return
	var defs: Array = popup.get_meta(REQUIREMENT_MENU_META_TYPES, [])
	if id < 0 or id >= defs.size():
		return
	var def: Dictionary = defs[id]
	var script = def.get("script", null)
	if script == null:
		push_warning("DetailsPanel: Requirement script missing for menu entry")
		return
	var requirement_instance = script.new()
	if not requirement_instance is Requirement:
		return
	_add_requirement_instance(requirement_instance)

func _add_requirement_instance(requirement_instance: Requirement) -> void:
	"""Insert a new requirement into the current tile and refresh the UI."""
	if not _tile or requirement_instance == null:
		return
	if undo_redo_manager:
		var action := AddRequirementAction.new(undo_redo_manager, _tile, requirement_instance)
		action.execute()
	else:
		var requirements_copy: Array = []
		requirements_copy.assign(_tile.requirements)
		requirements_copy.append(requirement_instance)
		_tile.requirements = requirements_copy
	_update_requirements_display()
	_validate_tile()
	tile_modified.emit(_tile)

func _validate_tile() -> void:
	"""Validate current tile and emit validation events."""
	if not _tile or not validation_bus:
		return
	
	# Clear previous validation
	validation_bus.clear_validation(ValidationEventBus.Context.TILE)
	
	# Validate weight
	if _tile.weight <= 0:
		validation_bus.emit_warning("Weight should be greater than 0", _tile, ValidationEventBus.Context.TILE)
	
	# Validate size
	if _tile.size.x <= 0 or _tile.size.y <= 0 or _tile.size.z <= 0:
		validation_bus.emit_error("All size dimensions must be greater than 0", _tile, ValidationEventBus.Context.TILE)
	
	# Validate sockets (check if tile has at least one socket)
	if _tile.sockets.is_empty():
		validation_bus.emit_warning("%s has no sockets defined" %_tile.name, _tile, ValidationEventBus.Context.TILE)
	
	# Validate mesh or scene
	if not _tile.mesh and not _tile.scene:
		validation_bus.emit_error("%s must have either a mesh or scene assigned" %_tile.name, _tile, ValidationEventBus.Context.TILE)
