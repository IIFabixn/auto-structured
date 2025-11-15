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
const TileClipboard = preload("res://addons/auto_structured/ui/utils/tile_clipboard.gd")
const TilePresetStore = preload("res://addons/auto_structured/ui/utils/tile_preset_store.gd")

const COPY_MENU_COPY_TILE := 0
const COPY_MENU_PASTE_TILE := 1
const COPY_MENU_COPY_TAGS := 2
const COPY_MENU_PASTE_TAGS := 3
const COPY_MENU_COPY_REQUIREMENTS := 4
const COPY_MENU_PASTE_REQUIREMENTS := 5
const COPY_MENU_COPY_SOCKETS := 6
const COPY_MENU_PASTE_SOCKETS := 7

const PRESET_MENU_SAVE := 0
const PRESET_MENU_DELETE := 1
const PRESET_MENU_PLACEHOLDER := 2
const PRESET_MENU_APPLY_BASE := 1000

@export var current_tile: Tile
var current_library: ModuleLibrary = null
var add_requirement_menu: PopupMenu

@onready var sockets_container = %SocketsContainer
@onready var name_label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/NameLabel
@onready var symmetry_option_button: OptionButton = %SymmetryOptionButton
@onready var add_tag_button: TextureButton = %AddTagButton
@onready var tags_container: VBoxContainer = %TagsContainer
@onready var requirements_container: VBoxContainer = %RequirementsContainer
@onready var add_requirement_button: Button = %AddRequirementButton
@onready var spin_box_x: SpinBox = %XSpinBox
@onready var spin_box_y: SpinBox = %YSpinBox
@onready var spin_box_z: SpinBox = %ZSpinBox
@onready var copy_menu_button: MenuButton = %CopyMenuButton
@onready var preset_menu_button: MenuButton = %PresetMenuButton
@onready var tile_preset_save_dialog: AcceptDialog = %TilePresetSaveDialog
@onready var tile_preset_name_edit: LineEdit = %TilePresetNameEdit
@onready var tile_preset_delete_dialog: ConfirmationDialog = %TilePresetDeleteDialog
@onready var tile_preset_delete_option: OptionButton = %TilePresetDeleteOption


func _ready() -> void:
	if symmetry_option_button:
		symmetry_option_button.clear()
		symmetry_option_button.add_item("None", Tile.Symmetry.NONE)
		symmetry_option_button.add_item("Rotation 180°", Tile.Symmetry.ROTATION_180)
		symmetry_option_button.add_item("Rotation 90°", Tile.Symmetry.ROTATION_90)
		symmetry_option_button.selected = 0
		if not symmetry_option_button.item_selected.is_connected(_on_symmetry_option_selected):
			symmetry_option_button.item_selected.connect(_on_symmetry_option_selected)
	add_tag_button.pressed.connect(_on_add_tag)
	add_requirement_button.pressed.connect(_on_add_requirement_pressed)
	_setup_requirement_menu()

	if copy_menu_button:
		var copy_popup := copy_menu_button.get_popup()
		copy_popup.clear()
		copy_popup.add_item("Copy Entire Tile", COPY_MENU_COPY_TILE)
		copy_popup.add_item("Paste Entire Tile", COPY_MENU_PASTE_TILE)
		copy_popup.add_separator()
		copy_popup.add_item("Copy Tags", COPY_MENU_COPY_TAGS)
		copy_popup.add_item("Paste Tags", COPY_MENU_PASTE_TAGS)
		copy_popup.add_item("Copy Requirements", COPY_MENU_COPY_REQUIREMENTS)
		copy_popup.add_item("Paste Requirements", COPY_MENU_PASTE_REQUIREMENTS)
		copy_popup.add_separator()
		copy_popup.add_item("Copy All Sockets", COPY_MENU_COPY_SOCKETS)
		copy_popup.add_item("Paste All Sockets", COPY_MENU_PASTE_SOCKETS)
		copy_popup.id_pressed.connect(_on_copy_menu_id_pressed)
		copy_popup.about_to_popup.connect(_on_copy_menu_about_to_popup)

	if preset_menu_button:
		var preset_popup := preset_menu_button.get_popup()
		preset_popup.id_pressed.connect(_on_preset_menu_id_pressed)
		preset_popup.about_to_popup.connect(_on_preset_menu_about_to_popup)

	if tile_preset_save_dialog:
		tile_preset_save_dialog.confirmed.connect(_on_tile_preset_save_confirmed)
	if tile_preset_name_edit:
		tile_preset_name_edit.text_submitted.connect(func(_text): tile_preset_save_dialog.accept())
	if tile_preset_delete_dialog:
		tile_preset_delete_dialog.confirmed.connect(_on_tile_preset_delete_confirmed)


func _on_symmetry_option_selected(index: int) -> void:
	if not current_tile:
		return
	var values := Tile.Symmetry.values()
	if index >= 0 and index < values.size():
		current_tile.symmetry = values[index]
		save_tile_changes()

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

func add_tag(tag: String) -> TagControl:
	var tag_item: TagControl = TagControl.instantiate()
	tags_container.add_child(tag_item)
	tag_item.apply_tag_name(tag)
	tag_item.name_changed.connect(_on_tag_name_changed.bind(tag_item))
	tag_item.deleted.connect(_on_tag_delete_requested.bind(tag_item))
	return tag_item


func _on_tag_name_changed(old_name: String, new_name: String, tag_item: TagControl) -> void:
	if not current_tile:
		return

	var trimmed_old := old_name.strip_edges()
	var trimmed_new := new_name.strip_edges()

	if trimmed_new.is_empty():
		if tag_item:
			tag_item.queue_free()
		_rebuild_tags_from_ui()
		save_tile_changes()
		return

	for child in tags_container.get_children():
		if child is TagControl and child != tag_item:
			var other_name: String = child.tag_name.strip_edges()
			if other_name.to_lower() == trimmed_new.to_lower():
				push_warning("Tag '%s' already exists on this tile" % trimmed_new)
				if tag_item:
					tag_item.apply_tag_name(trimmed_old)
				return

	if tag_item:
		tag_item.apply_tag_name(trimmed_new)

	_rebuild_tags_from_ui()
	save_tile_changes()


func _on_tag_delete_requested(tag_name: String, tag_item: TagControl) -> void:
	if tag_item:
		tag_item.queue_free()
	_rebuild_tags_from_ui()
	save_tile_changes()


func _rebuild_tags_from_ui() -> void:
	if not current_tile:
		return
	var rebuilt: Array[String] = []
	for child in tags_container.get_children():
		if child is TagControl:
			var sanitized: String = child.tag_name.strip_edges()
			if sanitized.is_empty():
				continue
			if sanitized in rebuilt:
				continue
			rebuilt.append(sanitized)
	current_tile.tags = rebuilt


func _on_add_tag() -> void:
	if not current_tile:
		return

	var tag_control := add_tag("")
	if tag_control:
		tag_control.focus_edit()


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
	clear_symetry()
	clear_sockets()
	clear_tags()
	clear_requirements()


func _populate_ui(tile: Tile) -> void:
	"""Populate UI with tile data. Assumes current_tile and current_library are already set."""
	name_label.text = "Tile: %s" % tile.name

	symmetry_option_button.selected = int(tile.symmetry)

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

func clear_symetry() -> void:
	"""Clear symmetry selection"""
	symmetry_option_button.selected = 0

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


# ============================================================================
# Copy / Paste Toolbar Handlers
# ============================================================================

func _on_copy_menu_about_to_popup() -> void:
	if not copy_menu_button:
		return
	var popup := copy_menu_button.get_popup()
	var has_tile := current_tile != null
	_set_menu_item_disabled(popup, COPY_MENU_COPY_TILE, not has_tile)
	_set_menu_item_disabled(popup, COPY_MENU_COPY_TAGS, not has_tile)
	_set_menu_item_disabled(popup, COPY_MENU_COPY_REQUIREMENTS, not has_tile)
	_set_menu_item_disabled(popup, COPY_MENU_COPY_SOCKETS, not has_tile)
	_set_menu_item_disabled(popup, COPY_MENU_PASTE_TILE, (not has_tile) or not TileClipboard.has_tile_payload())
	_set_menu_item_disabled(popup, COPY_MENU_PASTE_TAGS, (not has_tile) or not TileClipboard.has_tags_payload())
	_set_menu_item_disabled(popup, COPY_MENU_PASTE_REQUIREMENTS, (not has_tile) or not TileClipboard.has_requirements_payload())
	_set_menu_item_disabled(popup, COPY_MENU_PASTE_SOCKETS, (not has_tile) or not TileClipboard.has_sockets_payload())


func _on_copy_menu_id_pressed(id: int) -> void:
	if not current_tile:
		# All copy actions are disabled without a tile, but guard anyway.
		return
	match id:
		COPY_MENU_COPY_TILE:
			TileClipboard.copy_tile(current_tile)
		COPY_MENU_PASTE_TILE:
			if TileClipboard.paste_tile(current_tile, current_library):
				_after_tile_data_modified()
		COPY_MENU_COPY_TAGS:
			TileClipboard.copy_tags(current_tile)
		COPY_MENU_PASTE_TAGS:
			if TileClipboard.paste_tags(current_tile):
				_after_tile_data_modified()
		COPY_MENU_COPY_REQUIREMENTS:
			TileClipboard.copy_requirements(current_tile)
		COPY_MENU_PASTE_REQUIREMENTS:
			if TileClipboard.paste_requirements(current_tile):
				_after_tile_data_modified()
		COPY_MENU_COPY_SOCKETS:
			TileClipboard.copy_all_sockets(current_tile)
		COPY_MENU_PASTE_SOCKETS:
			if TileClipboard.paste_all_sockets(current_tile, current_library):
				_after_tile_data_modified()


func _on_preset_menu_about_to_popup() -> void:
	if not preset_menu_button:
		return
	var popup := preset_menu_button.get_popup()
	popup.clear()
	var presets := TilePresetStore.list_presets()
	popup.add_item("Save Preset...", PRESET_MENU_SAVE)
	_set_menu_item_disabled(popup, PRESET_MENU_SAVE, current_tile == null)
	popup.add_item("Delete Preset...", PRESET_MENU_DELETE)
	_set_menu_item_disabled(popup, PRESET_MENU_DELETE, presets.is_empty())
	popup.add_separator()
	if presets.is_empty():
		popup.add_item("No presets saved", PRESET_MENU_PLACEHOLDER)
		_set_menu_item_disabled(popup, PRESET_MENU_PLACEHOLDER, true)
	else:
		for i in range(presets.size()):
			var preset: Dictionary = presets[i]
			var label := "Apply \"%s\"" % preset.get("name", preset.get("id", "Preset"))
			var item_id := PRESET_MENU_APPLY_BASE + i
			popup.add_item(label, item_id)
			popup.set_item_metadata(popup.get_item_count() - 1, preset)
			_set_menu_item_disabled(popup, item_id, current_tile == null)


func _on_preset_menu_id_pressed(id: int) -> void:
	match id:
		PRESET_MENU_SAVE:
			_show_tile_preset_save_dialog()
		PRESET_MENU_DELETE:
			_show_tile_preset_delete_dialog()
		PRESET_MENU_PLACEHOLDER:
			pass
		_:
			if id >= PRESET_MENU_APPLY_BASE:
				_apply_preset_from_menu(id)


func _show_tile_preset_save_dialog() -> void:
	if not tile_preset_save_dialog or not tile_preset_name_edit or not current_tile:
		return
	var default_name := current_tile.name
	if default_name.strip_edges().is_empty():
		default_name = "Tile Preset"
	tile_preset_name_edit.text = default_name
	tile_preset_name_edit.select_all()
	tile_preset_save_dialog.popup_centered()
	tile_preset_name_edit.grab_focus()


func _on_tile_preset_save_confirmed() -> void:
	if not current_tile or not tile_preset_name_edit:
		return
	var preset_name := tile_preset_name_edit.text.strip_edges()
	if preset_name.is_empty():
		push_warning("Preset name cannot be empty")
		return
	var err := TilePresetStore.save_preset(preset_name, current_tile)
	if err != OK:
		push_warning("Failed to save preset: %s" % error_string(err))


func _show_tile_preset_delete_dialog() -> void:
	if not tile_preset_delete_dialog or not tile_preset_delete_option:
		return
	var presets := TilePresetStore.list_presets()
	tile_preset_delete_option.clear()
	for i in range(presets.size()):
		var preset: Dictionary = presets[i]
		tile_preset_delete_option.add_item(preset.get("name", preset.get("id", "Preset")), i)
		tile_preset_delete_option.set_item_metadata(i, preset.get("id", ""))
	if presets.is_empty():
		var ok_button := tile_preset_delete_dialog.get_ok_button()
		if ok_button:
			ok_button.disabled = true
	else:
		var ok_button := tile_preset_delete_dialog.get_ok_button()
		if ok_button:
			ok_button.disabled = false
		tile_preset_delete_option.select(0)
	tile_preset_delete_dialog.popup_centered()


func _on_tile_preset_delete_confirmed() -> void:
	if not tile_preset_delete_option:
		return
	var selected := tile_preset_delete_option.selected
	if selected < 0:
		return
	var preset_id := tile_preset_delete_option.get_item_metadata(selected)
	if typeof(preset_id) != TYPE_STRING or preset_id == "":
		return
	var err := TilePresetStore.delete_preset(preset_id)
	if err != OK:
		push_warning("Failed to delete preset: %s" % error_string(err))


func _apply_preset_from_menu(id: int) -> void:
	if not preset_menu_button or not current_tile:
		return
	var popup := preset_menu_button.get_popup()
	var index := popup.get_item_index(id)
	if index == -1:
		return
	var metadata := popup.get_item_metadata(index)
	if metadata is Dictionary:
		var preset_id: String = str(metadata.get("id", ""))
		if preset_id != "":
			var payload := TilePresetStore.load_preset(preset_id)
			if payload.is_empty():
				push_warning("Failed to load preset: %s" % metadata.get("name", preset_id))
				return
			if TileClipboard.apply_payload(current_tile, current_library, payload):
				_after_tile_data_modified()


func _after_tile_data_modified() -> void:
	save_tile_changes()
	if current_tile:
		var tile := current_tile
		var library := current_library
		show_tile(tile, library)


func _set_menu_item_disabled(popup: PopupMenu, item_id: int, disabled: bool) -> void:
	var index := popup.get_item_index(item_id)
	if index != -1:
		popup.set_item_disabled(index, disabled)
