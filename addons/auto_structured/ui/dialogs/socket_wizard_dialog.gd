@tool
class_name SocketWizardDialog extends AcceptDialog

signal wizard_applied(tile: Tile, changed_tiles: Array)

const Socket := preload("res://addons/auto_structured/core/socket.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Requirement := preload("res://addons/auto_structured/core/requirements/requirement.gd")
const RotationRequirement := preload("res://addons/auto_structured/core/requirements/rotation_requirement.gd")
const SocketTemplate := preload("res://addons/auto_structured/ui/utils/socket_template.gd")
const SocketTemplateLibrary := preload("res://addons/auto_structured/ui/utils/socket_template_library.gd")

@onready var tile_label: Label = %TileLabel
@onready var socket_list: ItemList = %SocketList
@onready var socket_header: Label = %SocketHeader
@onready var socket_type_option: OptionButton = %SocketTypeOption
@onready var allow_self_checkbox: CheckBox = %AllowSelfCheckBox
@onready var rotation_option: OptionButton = %RotationOption
@onready var reciprocal_checkbox: CheckBox = %ReciprocalCheckBox
@onready var connections_container: VBoxContainer = %ConnectionsContainer
@onready var connections_info: Label = %ConnectionsInfo
@onready var template_option: OptionButton = %TemplateOption
@onready var apply_template_button: Button = $Margin/VBox/TemplatePanel/TemplateHeader/ApplyTemplateButton

var tile: Tile = null
var library: ModuleLibrary = null
var socket_states: Array = []  ## Array of dictionaries storing working state per socket
var template_cache: Array[SocketTemplate] = []
var current_socket_index: int = -1

const CUSTOM_SOCKET_TYPE_TOKEN := "__custom__"
const ADD_NEW_TYPE_TOKEN := "__add_new__"

func _ready() -> void:
	confirmed.connect(_on_confirmed)
	socket_list.item_selected.connect(_on_socket_selected)
	allow_self_checkbox.toggled.connect(_on_allow_self_toggled)
	rotation_option.item_selected.connect(_on_rotation_selected)
	socket_type_option.item_selected.connect(_on_socket_type_selected)
	reciprocal_checkbox.toggled.connect(_on_global_reciprocal_toggled)
	template_option.item_selected.connect(_on_template_selected)
	apply_template_button.pressed.connect(_on_apply_template_pressed)
	_setup_rotation_option()

func initialize(p_tile: Tile, p_library: ModuleLibrary) -> void:
	tile = p_tile
	library = p_library
	if tile_label:
		tile_label.text = "Tile: %s" % tile.name
	_load_templates()
	_build_socket_states()
	if socket_states.is_empty():
		socket_header.text = "No sockets available"
	else:
		socket_list.select(0)
		_on_socket_selected(0)

func _load_templates() -> void:
	if not template_option:
		return
	template_cache = SocketTemplateLibrary.get_all_templates()
	template_option.clear()
	template_option.add_item("Select a template", -1)
	for i in range(template_cache.size()):
		var tpl: SocketTemplate = template_cache[i]
		template_option.add_item("%s" % tpl.template_name, i)
		template_option.set_item_metadata(template_option.item_count - 1, i)

func _setup_rotation_option() -> void:
	if not rotation_option:
		return
	rotation_option.clear()
	rotation_option.add_item("No minimum", 0)
	rotation_option.set_item_metadata(0, 0)
	rotation_option.add_item(">= 90°", 1)
	rotation_option.set_item_metadata(1, 90)
	rotation_option.add_item(">= 180°", 2)
	rotation_option.set_item_metadata(2, 180)

func _build_socket_states() -> void:
	socket_states.clear()
	if not socket_list:
		return
	socket_list.clear()
	if tile == null:
		return

	var directions := [
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.RIGHT,
		Vector3i.LEFT,
		Vector3i.FORWARD,
		Vector3i.BACK
	]

	for direction in directions:
		var socket := tile.get_socket_by_direction(direction)
		if socket == null:
			continue
		var working_socket: Socket = socket.duplicate(true)
		var state := {
			"direction": direction,
			"original": socket,
			"working": working_socket,
			"allow_self": socket.socket_id != "" and socket.socket_id in socket.compatible_sockets,
			"rotation": _extract_rotation_requirement(socket),
			"connection_rows": [],
			"connection_data": {}
		}
		_apply_rotation_to_socket_resource(working_socket, state["rotation"])
		socket_states.append(state)
		socket_list.add_item(_format_socket_label(direction, working_socket.socket_id))

func _format_socket_label(direction: Vector3i, socket_id: String) -> String:
	var dir_name := _direction_to_label(direction)
	var id_label := socket_id if socket_id.strip_edges() != "" else "(unset)"
	return "%s — %s" % [dir_name, id_label]

func _direction_to_label(direction: Vector3i) -> String:
	match direction:
		Vector3i.UP:
			return "Up"
		Vector3i.DOWN:
			return "Down"
		Vector3i.RIGHT:
			return "Right"
		Vector3i.LEFT:
			return "Left"
		Vector3i.FORWARD:
			return "Forward"
		Vector3i.BACK:
			return "Back"
		_:
			return str(direction)

func _on_socket_selected(index: int) -> void:
	if index < 0 or index >= socket_states.size():
		return
	if current_socket_index >= 0 and current_socket_index < socket_states.size():
		_capture_connection_rows(socket_states[current_socket_index])
	current_socket_index = index
	var state: Dictionary = socket_states[index]
	_update_socket_editor(state)

func _update_socket_editor(state: Dictionary) -> void:
	if not socket_header:
		return
	var working: Socket = state["working"]
	socket_header.text = "%s socket (%s)" % [_direction_to_label(state["direction"]), working.socket_id if working.socket_id != "" else "unset"]
	_allow_self_ui_update(state)
	_update_socket_type_option(state)
	_update_rotation_option(state)
	_build_connections_ui(state)
	_refresh_connections_hint(state)

func _capture_connection_rows(state: Dictionary) -> void:
	if state == null:
		return
	var data_map: Dictionary = state.get("connection_data", {})
	var rows: Array = state.get("connection_rows", [])
	for row_data in rows:
		if row_data == null:
			continue
		var entry: Dictionary = row_data.get("entry", null)
		if entry == null:
			var tile_ref: Tile = row_data.get("tile", null)
			if tile_ref and data_map.has(tile_ref):
				entry = data_map[tile_ref]
		if entry == null:
			continue
		var checkbox: CheckBox = row_data.get("checkbox")
		if checkbox and is_instance_valid(checkbox):
			entry["connect"] = checkbox.button_pressed
		var reciprocal: CheckBox = row_data.get("reciprocal")
		if reciprocal and is_instance_valid(reciprocal):
			entry["reciprocal"] = reciprocal.button_pressed
		var option: OptionButton = row_data.get("option")
		if option and is_instance_valid(option):
			var metadata: Dictionary = option.get_item_metadata(option.selected)
			if metadata:
				entry["direction"] = metadata.get("direction", entry.get("direction", Vector3i.ZERO))
				entry["socket"] = metadata.get("socket", entry.get("socket", null))
		var socket_ref: Socket = entry.get("socket", null)
		if socket_ref == null or socket_ref.socket_id.strip_edges() == "":
			entry["connect"] = false
			entry["reciprocal"] = false
	state["connection_rows"] = []

func _ensure_connection_data(state: Dictionary) -> void:
	if state == null:
		return
	if not state.has("connection_data") or state["connection_data"] == null:
		state["connection_data"] = {}
	var data_map: Dictionary = state["connection_data"]
	var working: Socket = state.get("working")
	if working == null or library == null:
		state["connection_data"] = {}
		return
	var dir: Vector3i = state["direction"]
	var opposite_dir := Vector3i(-dir.x, -dir.y, -dir.z)
	var working_id := working.socket_id.strip_edges()
	var tiles_present: Dictionary = {}
	for other_tile in library.tiles:
		tiles_present[other_tile] = true
		if other_tile == tile:
			continue
		var entry: Dictionary = data_map.get(other_tile, {})
		if entry.is_empty():
			var default_socket := other_tile.get_socket_by_direction(opposite_dir)
			var partner_id := ""
			if default_socket:
				partner_id = default_socket.socket_id.strip_edges()
			entry = {
				"tile": other_tile,
				"direction": opposite_dir,
				"socket": default_socket,
				"connect": partner_id != "" and partner_id in working.compatible_sockets,
				"reciprocal": default_socket != null and working_id != "" and default_socket.compatible_sockets.has(working_id)
			}
		else:
			entry["tile"] = other_tile
			if not entry.has("direction"):
				entry["direction"] = opposite_dir
			var socket_ref: Socket = entry.get("socket", null)
			if socket_ref and socket_ref not in other_tile.sockets:
				socket_ref = null
				entry["socket"] = other_tile.get_socket_by_direction(entry.get("direction", opposite_dir))
			if not entry.has("connect"):
				entry["connect"] = false
			if not entry.has("reciprocal"):
				entry["reciprocal"] = false
			if entry["socket"] == null:
				entry["connect"] = false
				entry["reciprocal"] = false
		data_map[other_tile] = entry
	var data_keys := data_map.keys()
	for stored_tile in data_keys:
		if stored_tile == tile:
			data_map.erase(stored_tile)
			continue
		if not tiles_present.has(stored_tile):
			data_map.erase(stored_tile)

func _allow_self_ui_update(state: Dictionary) -> void:
	if allow_self_checkbox:
		allow_self_checkbox.button_pressed = state["allow_self"]

func _update_socket_type_option(state: Dictionary) -> void:
	if not socket_type_option:
		return
	var previous_block := socket_type_option.is_blocking_signals()
	socket_type_option.set_block_signals(true)
	socket_type_option.clear()
	socket_type_option.add_item("(unset)")
	socket_type_option.set_item_metadata(0, "")
	var types: Array[String] = []
	if library:
		types = library.get_socket_types()
	for type in types:
		socket_type_option.add_item(type)
		socket_type_option.set_item_metadata(socket_type_option.item_count - 1, type)

	var current_id: String = state["working"].socket_id
	if current_id.strip_edges() != "" and current_id not in types:
		socket_type_option.add_separator()
		socket_type_option.add_item("%s (custom)" % current_id)
		socket_type_option.set_item_metadata(socket_type_option.item_count - 1, CUSTOM_SOCKET_TYPE_TOKEN)

	socket_type_option.add_separator()
	socket_type_option.add_item("+ Add New Type…")
	socket_type_option.set_item_metadata(socket_type_option.item_count - 1, ADD_NEW_TYPE_TOKEN)

	var target_index := 0
	for i in range(socket_type_option.item_count):
		if socket_type_option.is_item_separator(i):
			continue
		var metadata = socket_type_option.get_item_metadata(i)
		if metadata == current_id:
			target_index = i
			break
		if metadata == CUSTOM_SOCKET_TYPE_TOKEN and current_id.strip_edges() != "":
			target_index = i
	socket_type_option.select(target_index)
	socket_type_option.set_block_signals(previous_block)

func _update_rotation_option(state: Dictionary) -> void:
	if not rotation_option:
		return
	var prev_block := rotation_option.is_blocking_signals()
	rotation_option.set_block_signals(true)
	var current_rotation: int = int(state["rotation"])
	var target_index := 0
	for i in range(rotation_option.item_count):
		var val = int(rotation_option.get_item_metadata(i))
		if val == current_rotation:
			target_index = i
	rotation_option.select(target_index)
	rotation_option.set_block_signals(prev_block)

func _build_connections_ui(state: Dictionary) -> void:
	if not connections_container:
		return
	for child in connections_container.get_children():
		child.queue_free()
	state["connection_rows"] = []

	if library == null:
		connections_info.text = "No library available to build connections."
		return

	_ensure_connection_data(state)
	var data_map: Dictionary = state["connection_data"]
	var rows: Array = []
	for other_tile in library.tiles:
		if other_tile == tile:
			continue
		if not data_map.has(other_tile):
			continue
		var entry: Dictionary = data_map[other_tile]
		var default_direction := entry.get("direction", Vector3i(-state["direction"].x, -state["direction"].y, -state["direction"].z))
		var row := _create_connection_row(state, entry, default_direction)
		rows.append(row)
	state["connection_rows"] = rows
	if rows.is_empty():
		var info := Label.new()
		info.text = "No other tiles in the library yet."
		connections_container.add_child(info)
	_refresh_connections_hint(state)

func _create_connection_row(state: Dictionary, entry: Dictionary, default_direction: Vector3i) -> Dictionary:
	var other_tile: Tile = entry.get("tile")
	var row_container := HBoxContainer.new()
	row_container.custom_minimum_size = Vector2(0, 28)
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var toggle := CheckBox.new()
	toggle.text = other_tile.name if other_tile else "Unknown Tile"
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.button_pressed = entry.get("connect", false)
	row_container.add_child(toggle)

	var partner_option := OptionButton.new()
	partner_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_container.add_child(partner_option)

	var reciprocal := CheckBox.new()
	reciprocal.text = "↔"
	reciprocal.tooltip_text = "When enabled, update the partner tile to accept this socket type."
	reciprocal.button_pressed = entry.get("reciprocal", reciprocal_checkbox and reciprocal_checkbox.button_pressed)
	row_container.add_child(reciprocal)

	connections_container.add_child(row_container)

	_populate_partner_option(partner_option, entry, default_direction)
	var socket_ref: Socket = entry.get("socket", null)
	if socket_ref == null or socket_ref.socket_id.strip_edges() == "":
		entry["connect"] = false
		toggle.button_pressed = false
		reciprocal.button_pressed = false

	toggle.toggled.connect(func(pressed: bool) -> void:
		var current_entry := entry
		if pressed:
			var current_socket: Socket = current_entry.get("socket", null)
			if current_socket == null or current_socket.socket_id.strip_edges() == "":
				current_entry["connect"] = false
				toggle.set_pressed_no_signal(false)
				current_entry["reciprocal"] = false
				reciprocal.set_pressed_no_signal(false)
				_refresh_connections_hint(state)
				return
		current_entry["connect"] = pressed
		_refresh_connections_hint(state)
	)

	partner_option.item_selected.connect(func(_index: int) -> void:
		var metadata: Dictionary = partner_option.get_item_metadata(partner_option.selected)
		entry["direction"] = metadata.get("direction", default_direction)
		entry["socket"] = metadata.get("socket", null)
		var selected_socket: Socket = entry.get("socket", null)
		if selected_socket == null or selected_socket.socket_id.strip_edges() == "":
			entry["connect"] = false
			toggle.set_pressed_no_signal(false)
			entry["reciprocal"] = false
			reciprocal.set_pressed_no_signal(false)
		_refresh_connections_hint(state)
	)

	reciprocal.toggled.connect(func(pressed: bool) -> void:
		entry["reciprocal"] = pressed
	)

	return {
		"entry": entry,
		"tile": other_tile,
		"checkbox": toggle,
		"option": partner_option,
		"reciprocal": reciprocal
	}

func _populate_partner_option(option: OptionButton, entry: Dictionary, default_direction: Vector3i) -> void:
	option.clear()
	var other_tile: Tile = entry.get("tile", null)
	if other_tile == null:
		option.add_item("%s (new)" % _direction_to_label(default_direction))
		option.set_item_metadata(0, {"direction": default_direction, "socket": null})
		option.select(0)
		entry["direction"] = default_direction
		entry["socket"] = null
		return
	var sockets: Array[Socket] = other_tile.sockets
	var selected_index := -1
	for i in range(sockets.size()):
		var socket: Socket = sockets[i]
		var label := "%s (%s)" % [_direction_to_label(socket.direction), socket.socket_id if socket.socket_id != "" else "unset"]
		option.add_item(label)
		var metadata := {
			"direction": socket.direction,
			"socket": socket
		}
		option.set_item_metadata(i, metadata)
		if entry.has("socket") and entry["socket"] == socket:
			selected_index = i
	if sockets.is_empty():
		option.add_item("%s (new)" % _direction_to_label(default_direction))
		option.set_item_metadata(0, {"direction": default_direction, "socket": null})
		selected_index = 0
	elif selected_index == -1:
		for i in range(option.item_count):
			var metadata: Dictionary = option.get_item_metadata(i)
			if metadata and metadata.get("direction") == entry.get("direction", default_direction):
				selected_index = i
				break
	if selected_index == -1:
		selected_index = 0
	option.select(selected_index)
	var current_metadata: Dictionary = option.get_item_metadata(option.selected)
	if current_metadata:
		entry["direction"] = current_metadata.get("direction", default_direction)
		entry["socket"] = current_metadata.get("socket", null)

func _refresh_connections_hint(state: Dictionary) -> void:
	if not connections_info:
		return
	var count := 0
	var data_map: Dictionary = state.get("connection_data", {})
	for entry in data_map.values():
		if entry.get("connect", false):
			count += 1
	var working: Socket = state["working"]
	connections_info.text = "Socket '%s' currently allows %d partner types." % [
		working.socket_id if working.socket_id != "" else "unset",
		count
	]

func _on_allow_self_toggled(pressed: bool) -> void:
	if current_socket_index < 0 or current_socket_index >= socket_states.size():
		return
	socket_states[current_socket_index]["allow_self"] = pressed

func _on_rotation_selected(index: int) -> void:
	if current_socket_index < 0 or current_socket_index >= socket_states.size():
		return
	var degrees := int(rotation_option.get_item_metadata(index))
	socket_states[current_socket_index]["rotation"] = degrees

func _on_socket_type_selected(index: int) -> void:
	if current_socket_index < 0 or current_socket_index >= socket_states.size():
		return
	var metadata = socket_type_option.get_item_metadata(index)
	if metadata == ADD_NEW_TYPE_TOKEN:
		_prompt_new_socket_type()
		return
	var state: Dictionary = socket_states[current_socket_index]
	var working: Socket = state["working"]
	var new_id := ""
	if metadata == CUSTOM_SOCKET_TYPE_TOKEN:
		new_id = working.socket_id
	else:
		new_id = str(metadata)
	working.socket_id = new_id.strip_edges()
	_refresh_socket_list_labels()
	_refresh_connections_hint(state)

func _prompt_new_socket_type() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Add Socket Type"
	dialog.dialog_text = "Enter a new socket type identifier:"
	var input := LineEdit.new()
	input.placeholder_text = "e.g. wall_side"
	dialog.add_child(input)
	dialog.confirmed.connect(func():
		var new_id := input.text.strip_edges()
		if new_id == "":
			dialog.queue_free()
			return
		if library:
			library.register_socket_type(new_id)
		if current_socket_index >= 0 and current_socket_index < socket_states.size():
			var state: Dictionary = socket_states[current_socket_index]
			state["working"].socket_id = new_id
			_refresh_socket_type_option(state)
			_refresh_socket_list_labels()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	input.grab_focus()

func _refresh_socket_type_option(state: Dictionary) -> void:
	_update_socket_type_option(state)

func _refresh_socket_list_labels() -> void:
	for i in range(socket_states.size()):
		var state: Dictionary = socket_states[i]
		socket_list.set_item_text(i, _format_socket_label(state["direction"], state["working"].socket_id))

func _on_global_reciprocal_toggled(_pressed: bool) -> void:
	if current_socket_index < 0 or current_socket_index >= socket_states.size():
		return
	var state: Dictionary = socket_states[current_socket_index]
	var desired := reciprocal_checkbox.button_pressed
	for row_data in state["connection_rows"]:
		var entry: Dictionary = row_data.get("entry", {})
		entry["reciprocal"] = desired
		var reciprocal: CheckBox = row_data.get("reciprocal")
		if reciprocal and is_instance_valid(reciprocal):
			reciprocal.button_pressed = desired
	var data_map: Dictionary = state.get("connection_data", {})
	for entry in data_map.values():
		entry["reciprocal"] = desired

func _on_template_selected(_index: int) -> void:
	# No immediate action needed; template applied via button.
	pass

func _on_apply_template_pressed() -> void:
	if current_socket_index < 0 or current_socket_index >= socket_states.size():
		return
	var index := template_option.get_item_metadata(template_option.selected)
	if index == null or int(index) < 0:
		return
	if index < 0 or index >= template_cache.size():
		return
	var template: SocketTemplate = template_cache[index]
	_apply_template_to_states(template)
	_refresh_socket_list_labels()
	_update_socket_editor(socket_states[current_socket_index])

func _apply_template_to_states(template: SocketTemplate) -> void:
	var normalized: Dictionary = {}
	for raw_entry in template.entries:
		var entry := SocketTemplate.normalize_entry(raw_entry)
		normalized[entry["direction"]] = entry

	for state in socket_states:
		var entry: Dictionary = normalized.get(state["direction"], {})
		var working: Socket = state["working"]
		if entry.is_empty():
			working.socket_id = ""
			working.compatible_sockets = []
			state["allow_self"] = false
			state["rotation"] = 0
			_apply_rotation_to_socket_resource(working, 0)
			continue
		working.socket_id = str(entry["socket_id"]).strip_edges()
		var compat: Array[String] = []
		var raw_compat = entry["compatible"]
		for compat_id in raw_compat:
			if str(compat_id).strip_edges() != "":
				compat.append(str(compat_id))
		working.compatible_sockets = compat
		state["allow_self"] = compat.has(working.socket_id) and working.socket_id != ""
		state["rotation"] = int(entry["minimum_rotation_degrees"])
		_apply_rotation_to_socket_resource(working, state["rotation"])

func _on_confirmed() -> void:
	if tile == null:
		return
	_apply_changes()

func _apply_changes() -> void:
	var changed_tiles: Dictionary = {}
	changed_tiles[tile] = true

	for state in socket_states:
		_capture_connection_rows(state)
		_ensure_connection_data(state)
		var working: Socket = state["working"]
		var socket_id := working.socket_id.strip_edges()
		working.socket_id = socket_id
		var compat_ids: Array[String] = []
		if state["allow_self"] and socket_id != "":
			compat_ids.append(socket_id)

		var data_map: Dictionary = state.get("connection_data", {})
		for entry in data_map.values():
			var partner_tile: Tile = entry.get("tile", null)
			if partner_tile == null:
				continue
			var connect: bool = bool(entry.get("connect", false))
			var reciprocal_enabled: bool = bool(entry.get("reciprocal", false))
			var metadata := {
				"direction": entry.get("direction", Vector3i.ZERO),
				"socket": entry.get("socket", null)
			}
			if not connect:
				if _remove_partner_compat_if_needed(partner_tile, metadata, socket_id):
					changed_tiles[partner_tile] = true
				continue

			if socket_id == "":
				push_warning("Cannot link tiles without assigning a socket type first.")
				continue

			var partner_socket := _ensure_partner_socket(partner_tile, metadata)
			entry["socket"] = partner_socket
			if partner_socket == null:
				continue

			var partner_modified := false
			var partner_id := partner_socket.socket_id.strip_edges()
			if partner_id == "" or partner_id == "none":
				partner_id = socket_id
				partner_socket.socket_id = partner_id
				partner_modified = true
			if library:
				library.register_socket_type(partner_id)

			if partner_id != "" and partner_id not in compat_ids:
				compat_ids.append(partner_id)

			if reciprocal_enabled and socket_id != "":
				partner_modified = _add_unique_socket_id(partner_socket, socket_id) or partner_modified
			else:
				partner_modified = _remove_socket_id(partner_socket, socket_id) or partner_modified

			if partner_modified:
				# Ensure partner keeps its array type consistent
				partner_socket.compatible_sockets = _string_array(partner_socket.compatible_sockets)
				partner_tile.sockets = partner_tile.sockets  # trigger cache rebuild
				changed_tiles[partner_tile] = true

		working.compatible_sockets = compat_ids
		_apply_rotation_to_socket_resource(working, state["rotation"])
		if library and socket_id != "":
			library.register_socket_type(socket_id)

	# Apply working sockets back to tile
	for state in socket_states:
		var original: Socket = state["original"]
		var working: Socket = state["working"]
		original.socket_id = working.socket_id
		original.compatible_sockets = _string_array(working.compatible_sockets)
		original.requirements = _duplicate_requirements(working.requirements)

	tile.sockets = tile.sockets  # rebuild cache

	var changed_list: Array[Tile] = []
	for key in changed_tiles.keys():
		changed_list.append(key)

	wizard_applied.emit(tile, changed_list)

func _remove_partner_compat_if_needed(partner_tile: Tile, metadata: Dictionary, socket_id: String) -> bool:
	if socket_id == "":
		return false
	if metadata.is_empty():
		return false
	var partner_socket := metadata.get("socket", null)
	if partner_socket == null:
		return false
	var changed := _remove_socket_id(partner_socket, socket_id)
	if not changed:
		return false
	partner_socket.compatible_sockets = _string_array(partner_socket.compatible_sockets)
	partner_tile.sockets = partner_tile.sockets
	return true

func _ensure_partner_socket(partner_tile: Tile, metadata: Dictionary) -> Socket:
	var partner_socket: Socket = null
	if metadata.has("socket") and metadata["socket"] is Socket:
		partner_socket = metadata["socket"]
	if partner_socket != null:
		return partner_socket

	var direction: Vector3i = metadata.get("direction", Vector3i.LEFT)
	partner_socket = partner_tile.get_socket_by_direction(direction)
	if partner_socket == null:
		partner_socket = Socket.new()
		partner_socket.direction = direction
		partner_tile.add_socket(partner_socket)
	metadata["socket"] = partner_socket
	return partner_socket

func _add_unique_socket_id(socket: Socket, socket_id: String) -> bool:
	if socket_id == "":
		return false
	var compat := _string_array(socket.compatible_sockets)
	if socket_id in compat:
		return false
	compat.append(socket_id)
	socket.compatible_sockets = compat
	return true

func _remove_socket_id(socket: Socket, socket_id: String) -> bool:
	if socket_id == "":
		return false
	var compat := _string_array(socket.compatible_sockets)
	if socket_id not in compat:
		return false
	compat.erase(socket_id)
	socket.compatible_sockets = compat
	return true

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

func _duplicate_requirements(requirements: Array[Requirement]) -> Array[Requirement]:
	var copy: Array[Requirement] = []
	for req in requirements:
		if req:
			copy.append(req.duplicate(true))
	return copy

func _extract_rotation_requirement(socket: Socket) -> int:
	for req in socket.requirements:
		if req is RotationRequirement:
			return int(req.minimum_rotation_degrees)
	return 0

func _apply_rotation_to_socket_resource(socket: Socket, degrees: int) -> void:
	var requirements: Array[Requirement] = []
	for req in socket.requirements:
		if req is RotationRequirement:
			continue
		requirements.append(req)
	if degrees > 0:
		var rotation_req := RotationRequirement.new()
		rotation_req.minimum_rotation_degrees = degrees
		requirements.append(rotation_req)
	socket.requirements = requirements
