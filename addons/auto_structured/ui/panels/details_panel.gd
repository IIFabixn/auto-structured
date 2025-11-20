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
	else:
		# Display socket type IDs as comma-separated list
		var socket_type_ids: Array[String] = []
		for socket in sockets_in_direction:
			if socket.socket_type:
				socket_type_ids.append(socket.socket_type.type_id)
			else:
				# Socket exists but has no type assigned - treat as "none"
				socket_type_ids.append("none")
		
		if socket_type_ids.is_empty():
			menu_button.text = "none"
		else:
			menu_button.text = ", ".join(socket_type_ids)

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
	
	_tile.requirements.erase(requirement)
	_update_requirements_display()
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
	
	# Get all available socket types from library
	var socket_types = library.get_socket_type_resources()
	
	# Get current sockets for this direction
	var current_sockets = _tile.get_sockets_in_direction(direction)
	
	# Add socket types to menu with checkboxes
	for i in range(socket_types.size()):
		var socket_type = socket_types[i]
		popup.add_check_item(socket_type.get_display_name(), i)
		
		# Check if this socket type is already on the tile in this direction
		for socket in current_sockets:
			if socket.socket_type == socket_type:
				popup.set_item_checked(i, true)
				break

func _on_socket_menu_item_pressed(id: int, direction: Vector3i) -> void:
	"""Handle socket menu item press - toggle socket type on/off for this direction."""
	if not _tile:
		return
	
	var library = _get_library()
	if not library:
		return
	
	var socket_types = library.get_socket_type_resources()
	if id < 0 or id >= socket_types.size():
		return
	
	var socket_type = socket_types[id]
	var current_sockets = _tile.get_sockets_in_direction(direction)
	
	# Check if this socket type already exists for this direction
	var existing_socket: Socket = null
	for socket in current_sockets:
		if socket.socket_type == socket_type:
			existing_socket = socket
			break
	
	if existing_socket:
		# Remove the socket
		_tile.remove_socket(existing_socket)
	else:
		# Add new socket with this type
		var new_socket = Socket.new()
		new_socket.direction = direction
		new_socket.socket_type = socket_type
		_tile.add_socket(new_socket)
	
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
