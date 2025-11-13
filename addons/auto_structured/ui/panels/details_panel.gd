@tool
class_name DetailsPanel extends Control
## Panel for displaying and editing tile properties.
##
## Provides a clean API for showing tile details with proper state initialization.
## Use show_tile(tile, library) to display a tile's properties.

signal closed
signal tile_modified(tile: Tile)
signal socket_preview_requested(socket: Socket)

const SocketItem = preload("res://addons/auto_structured/ui/controls/socket_item.tscn")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const TagControl = preload("res://addons/auto_structured/ui/controls/tag_control.tscn")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const RequirementItem = preload("res://addons/auto_structured/ui/controls/requirement_item.tscn")
const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

@export var current_tile: Tile
var current_library: ModuleLibrary = null
var add_requirement_menu: PopupMenu

@onready var sockets_container = %SocketsContainer
@onready var name_label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/NameLabel
@onready var add_tag_edit: LineEdit = %AddTagEdit
@onready var add_tag_button: TextureButton = %AddTagButton
@onready var tags_container: VBoxContainer = %TagsContainer
@onready var requirements_container: VBoxContainer = %RequirementsContainer
@onready var add_requirement_button: Button = %AddRequirementButton
@onready var spin_box_x: SpinBox = %XSpinBox
@onready var spin_box_y: SpinBox = %YSpinBox
@onready var spin_box_z: SpinBox = %ZSpinBox


func _ready() -> void:
	add_tag_button.pressed.connect(_on_add_tag)
	add_tag_edit.text_submitted.connect(func(new_tag: String) -> void: _on_add_tag())
	add_requirement_button.pressed.connect(_on_add_requirement_pressed)
	_setup_requirement_menu()

func _add_socket_item(socket: Socket) -> void:
	"""Internal helper to add a socket item to the UI."""
	if not socket or not current_tile:
		return
	var socket_item: SocketItem = SocketItem.instantiate()
	sockets_container.add_child(socket_item)
	# Initialize after adding to tree so _ready() is called
	socket_item.initialize(socket, current_library, current_tile)
	socket_item.changed.connect(_on_socket_changed)
	socket_item.preview_requested.connect(_on_socket_preview_requested.bind(socket))
	socket_item.socket_types_changed.connect(_on_socket_types_changed)


func clear_sockets() -> void:
	for child in sockets_container.get_children():
		if child is SocketItem:
			child.queue_free()


func _on_socket_changed() -> void:
	# Socket properties were modified, save changes
	save_tile_changes()

func _on_socket_types_changed() -> void:
	"""When socket types are added, refresh all socket dropdowns"""
	_refresh_all_socket_dropdowns()

func _refresh_all_socket_dropdowns() -> void:
	"""Refresh socket type dropdowns for all socket items"""
	for child in sockets_container.get_children():
		if child is SocketItem:
			child._refresh_socket_type_dropdown()

func _on_socket_preview_requested(socket: Socket) -> void:
	"""Forward socket preview request with the socket_item reference"""
	socket_preview_requested.emit(socket)

func add_tag(tag: String) -> void:
	var tag_item: TagControl = TagControl.instantiate()
	tag_item.tag_name = tag
	tag_item.name_changed.connect(_on_tag_name_changed)
	tag_item.deleted.connect(_on_tag_delete_requested)
	tags_container.add_child(tag_item)


func _on_tag_name_changed(new_name: String) -> void:
	if not current_tile:
		return

	var tags_copy: Array[String] = []
	tags_copy.assign(current_tile.tags)
	var index = tags_copy.find(new_name)
	if index != -1:
		tags_copy[index] = new_name
		current_tile.tags = tags_copy


func _on_tag_delete_requested(tag_name: String) -> void:
	if not current_tile:
		return

	current_tile.remove_tag(tag_name)
	save_tile_changes()


func _on_add_tag() -> void:
	print("Adding tag")
	if not current_tile:
		return

	var tag = add_tag_edit.text.strip_edges()
	if tag == "":
		return

	current_tile.add_tag(tag)
	add_tag(tag)
	add_tag_edit.text = ""
	save_tile_changes()


func save_tile_changes() -> void:
	if current_tile:
		tile_modified.emit(current_tile)


func close_details() -> void:
	hide()
	name_label.text = "Tile: "
	clear_sockets()
	clear_tags()
	clear_requirements()
	current_tile = null
	closed.emit()


func clear_tags() -> void:
	for child in tags_container.get_children():
		if child is TagControl:
			child.queue_free()


func _clear_all() -> void:
	"""Clear all UI elements."""
	name_label.text = "Tile: "
	clear_sockets()
	clear_tags()
	clear_requirements()


func _populate_ui(tile: Tile) -> void:
	"""Populate UI with tile data. Assumes current_tile and current_library are already set."""
	name_label.text = "Tile: %s" % tile.name
	spin_box_x.value = tile.size.x
	spin_box_y.value = tile.size.y
	spin_box_z.value = tile.size.z
	
	# Ensure tile has all 6 sockets
	tile.ensure_all_sockets()
	
	# Add tags
	for tag in tile.tags:
		add_tag(tag)
	
	# Add requirements
	for requirement in tile.requirements:
		add_requirement_item(requirement)
	
	# Add sockets in fixed order
	_display_all_sockets_in_order()


## Display tile details with proper state initialization.
## This is the main entry point for showing a tile in the details panel.
func show_tile(tile: Tile, library: ModuleLibrary = null) -> void:
	# Clear previous state
	_clear_all()
	
	# Initialize state BEFORE creating dependent UI
	current_tile = tile
	current_library = library
	
	# Populate UI (depends on current_tile and current_library)
	_populate_ui(tile)
	
	show()


func _display_all_sockets_in_order() -> void:
	"""Display all 6 sockets in a fixed order: Up, Down, Right, Left, Forward, Back"""
	var directions = [
		Vector3i.UP,      # (0, 1, 0)
		Vector3i.DOWN,    # (0, -1, 0)
		Vector3i.RIGHT,   # (1, 0, 0)
		Vector3i.LEFT,    # (-1, 0, 0)
		Vector3i.FORWARD, # (0, 0, -1)
		Vector3i.BACK     # (0, 0, 1)
	]
	
	for direction in directions:
		var socket = current_tile.get_socket_by_direction(direction)
		if socket:
			_add_socket_item(socket)


# ============================================================================
# Requirements Management
# ============================================================================

func _setup_requirement_menu() -> void:
	"""Setup popup menu for adding different requirement types"""
	add_requirement_menu = PopupMenu.new()
	add_child(add_requirement_menu)
	
	add_requirement_menu.add_item("Ground Level Only", 0)
	add_requirement_menu.add_item("Height Range", 1)
	add_requirement_menu.add_item("Tag Requirement", 2)
	add_requirement_menu.add_item("Force Position", 3)
	add_requirement_menu.add_item("Rotation Requirement", 4)
	
	add_requirement_menu.id_pressed.connect(_on_requirement_type_selected)


func _on_add_requirement_pressed() -> void:
	"""Show menu to select requirement type"""
	if add_requirement_menu:
		var button_pos = add_requirement_button.global_position
		var button_size = add_requirement_button.size
		add_requirement_menu.position = Vector2i(button_pos.x, button_pos.y + button_size.y)
		add_requirement_menu.popup()


func _on_requirement_type_selected(id: int) -> void:
	"""Create a new requirement of the selected type"""
	if not current_tile:
		return
	
	const GroundRequirement = preload("res://addons/auto_structured/core/requirements/ground_requirement.gd")
	const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
	const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
	const PositionRequirement = preload("res://addons/auto_structured/core/requirements/position_requirement.gd")
	const RotationRequirement = preload("res://addons/auto_structured/core/requirements/rotation_requirement.gd")
	
	var new_requirement: Requirement = null
	
	match id:
		0:  # Ground Level
			new_requirement = GroundRequirement.new()
		1:  # Height Range
			new_requirement = HeightRequirement.new()
			new_requirement.max_height = 10
		2:  # Tag Requirement
			new_requirement = TagRequirement.new()
		3:  # Position Requirement
			new_requirement = PositionRequirement.new()
		4:  # Rotation Requirement
			new_requirement = RotationRequirement.new()
			new_requirement.minimum_rotation_degrees = 90
	
	if new_requirement:
		# Add to tile's requirements array
		var reqs_copy: Array[Requirement] = []
		reqs_copy.assign(current_tile.requirements)
		reqs_copy.append(new_requirement)
		current_tile.requirements = reqs_copy
		
		# Add to UI
		add_requirement_item(new_requirement)
		save_tile_changes()

func set_tile_x_size(new_value: float) -> void:
	_set_tile_size("x", new_value)
func set_tile_y_size(new_value: float) -> void:
	_set_tile_size("y", new_value)
func set_tile_z_size(new_value: float) -> void:
	_set_tile_size("z", new_value)

func _set_tile_size(axis: String, new_value: float) -> void:
	"""Set the size of the current tile along the specified axis."""
	if not current_tile:
		return

	var size_copy: Vector3 = current_tile.size

	match axis:
		"x":
			size_copy.x = new_value
		"y":
			size_copy.y = new_value
		"z":
			size_copy.z = new_value
		_:
			push_warning("Invalid axis specified for size change: %s" % axis)
			return

	current_tile.size = size_copy
	save_tile_changes()

func add_requirement_item(requirement: Requirement) -> void:
	"""Add a requirement item to the UI"""
	if not requirement:
		return
	
	var req_item = RequirementItem.instantiate()
	requirements_container.add_child(req_item)
	# Set properties after adding to tree so _ready() is called
	req_item.requirement = requirement
	req_item.library = current_library
	req_item.changed.connect(_on_requirement_changed)
	req_item.deleted.connect(_on_requirement_deleted)


func clear_requirements() -> void:
	"""Clear all requirement items from UI"""
	for child in requirements_container.get_children():
		child.queue_free()


func _on_requirement_changed(_requirement: Requirement) -> void:
	"""Handle requirement property changes"""
	save_tile_changes()


func _on_requirement_deleted(requirement: Requirement) -> void:
	"""Remove requirement from tile and UI"""
	if not current_tile:
		return
	
	var reqs_copy: Array[Requirement] = []
	reqs_copy.assign(current_tile.requirements)
	reqs_copy.erase(requirement)
	current_tile.requirements = reqs_copy
	
	# Remove from UI
	for child in requirements_container.get_children():
		if child.requirement == requirement:
			child.queue_free()
			break
	
	save_tile_changes()
