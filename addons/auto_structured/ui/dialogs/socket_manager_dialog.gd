@tool
class_name SocketManagerDialog extends ConfirmationDialog
## Dialog for managing socket compatibility between tiles.
##
## This dialog allows users to configure which socket IDs can connect to each other.
## Socket types are dynamic - any string can be a socket ID, and users configure
## which IDs are compatible by checking/unchecking boxes in the tree.

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketSuggestionBuilder = preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const AddTileDialogScene = preload("res://addons/auto_structured/ui/dialogs/add_tile_dialog.tscn")

@onready var socket_list: ItemList = %SocketList
@onready var socket_info_label: Label = %SelectedSocketInfo
@onready var compatibility_tree: Tree = %CompatibilityTree
@onready var compatibility_status_label: Label = %CompatibilityStatusLabel
@onready var suggestions_label: Label = %SuggestionsLabel
@onready var apply_suggestions_button: Button = %ApplySuggestionsButton
@onready var add_tile_button: Button = %AddTileButton

class SocketEntry:
	var direction: Vector3i
	var socket: Socket
	var socket_id: String

var _library: ModuleLibrary = null
var _tile: Tile = null
var _socket_entries: Array[SocketEntry] = []
var _selected_entries: Array[SocketEntry] = []  # Support multi-selection
var _suggestions_by_dir: Dictionary = {}
var _modified_sockets: Dictionary = {}  # Track sockets that were modified
var _tree_edit_enabled: bool = false
var _visible_tiles: Dictionary = {}
var _visible_tile_order: Array = []
var _add_tile_dialog: AddTileDialog = null
var _remove_tile_icon: Texture2D = null
var _socket_states: Dictionary = {}
var _compatibility_refresh_pending: bool = false

static var _hidden_tile_map: Dictionary = {}

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	if not canceled.is_connected(queue_free):
		canceled.connect(queue_free)
	if not close_requested.is_connected(queue_free):
		close_requested.connect(queue_free)
	if socket_list:
		if not socket_list.item_selected.is_connected(_on_socket_selected):
			socket_list.item_selected.connect(_on_socket_selected)
		if not socket_list.multi_selected.is_connected(_on_socket_multi_selected):
			socket_list.multi_selected.connect(_on_socket_multi_selected)
	if compatibility_tree and not compatibility_tree.item_edited.is_connected(_on_tree_item_edited):
		compatibility_tree.item_edited.connect(_on_tree_item_edited)
	_connect_tree_button_signal()
	if apply_suggestions_button and not apply_suggestions_button.pressed.is_connected(_on_apply_suggestions_pressed):
		apply_suggestions_button.pressed.connect(_on_apply_suggestions_pressed)
	if add_tile_button and not add_tile_button.pressed.is_connected(_on_add_tile_button_pressed):
		add_tile_button.pressed.connect(_on_add_tile_button_pressed)
	_remove_tile_icon = _load_remove_tile_icon()
	_update_ui_availability(false)

func setup(library: ModuleLibrary, tile: Tile) -> void:
	_library = library
	_tile = tile
	_rebuild_state()

func _rebuild_state() -> void:
	_socket_entries.clear()
	_suggestions_by_dir.clear()
	_modified_sockets.clear()
	_socket_states.clear()
	_selected_entries.clear()
	_visible_tiles.clear()
	_visible_tile_order.clear()
	if _library == null or _tile == null:
		_refresh_socket_list()
		_refresh_compatibility_view()
		return
	_build_socket_entries()
	_build_suggestions()
	_initialize_visible_tiles()
	_refresh_socket_list()
	if _socket_entries.is_empty():
		_refresh_compatibility_view()
	else:
		_select_initial_socket()

func _build_socket_entries() -> void:
	var directions = [
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.LEFT,
		Vector3i.RIGHT,
		Vector3i.FORWARD,
		Vector3i.BACK
	]
	for direction in directions:
		var sockets_in_dir := _tile.get_sockets_in_direction(direction)
		var socket: Socket = null if sockets_in_dir.is_empty() else sockets_in_dir[0]
		var entry := SocketEntry.new()
		entry.direction = direction
		entry.socket = socket
		entry.socket_id = socket.socket_id.strip_edges() if socket else ""
		if socket:
			_ensure_socket_state(socket)
		_socket_entries.append(entry)

func _build_suggestions() -> void:
	var suggestions = SocketSuggestionBuilder.build_suggestions(_tile, _library)
	for suggestion in suggestions:
		var direction: Vector3i = suggestion.get("direction", Vector3i.ZERO)
		if not _suggestions_by_dir.has(direction):
			_suggestions_by_dir[direction] = []
		_suggestions_by_dir[direction].append(suggestion)

func _ensure_socket_state(socket: Socket) -> Dictionary:
	if socket == null:
		return {}
	if _socket_states.has(socket):
		return _socket_states[socket]
	var pending: Array[String] = []
	if socket.compatible_sockets:
		pending.assign(socket.compatible_sockets)
	pending.sort()
	var state := {
		"pending": pending,
		"original": pending.duplicate()
	}
	_socket_states[socket] = state
	return state

func _get_pending_socket_guids(socket: Socket) -> Array[String]:
	if socket == null:
		return []
	var state := _ensure_socket_state(socket)
	return state.get("pending", [])

func _pending_contains(socket: Socket, socket_guid: String) -> bool:
	if socket == null:
		return false
	var target_guid := String(socket_guid).strip_edges()
	if target_guid == "":
		return false
	return target_guid in _get_pending_socket_guids(socket)

func _set_socket_modified_state(socket: Socket) -> void:
	if socket == null:
		return
	var state := _ensure_socket_state(socket)
	var pending: Array = state.get("pending", [])
	var original: Array = state.get("original", [])
	if pending == original:
		if _modified_sockets.has(socket):
			_modified_sockets.erase(socket)
	else:
		_modified_sockets[socket] = true

func _initialize_visible_tiles() -> void:
	if _tile:
		_add_visible_tile(_tile, true)
	if _library == null:
		_update_add_tile_button_state()
		return
	for tile in _library.tiles:
		if tile == null or tile == _tile:
			continue
		if _is_tile_hidden(tile):
			continue
		if _tile_has_existing_link(tile):
			_add_visible_tile(tile)
	_update_add_tile_button_state()


func _tile_has_existing_link(other_tile: Tile) -> bool:
	if _tile == null or other_tile == null or other_tile == _tile:
		return false
	for source_socket in _tile.sockets:
		if source_socket == null:
			continue
		source_socket.ensure_guid()
		var source_guid := String(source_socket.socket_guid).strip_edges()
		if source_guid == "":
			continue
		for target_socket in other_tile.sockets:
			if target_socket == null:
				continue
			target_socket.ensure_guid()
			var target_guid := String(target_socket.socket_guid).strip_edges()
			if target_guid == "":
				continue
			if _pending_contains(source_socket, target_guid) or _pending_contains(target_socket, source_guid):
				return true
	return false

func _add_visible_tile(tile: Tile, force: bool = false) -> void:
	if tile == null:
		return
	_unhide_tile(tile)
	if not _visible_tiles.has(tile):
		_visible_tiles[tile] = {"force": force}
		_visible_tile_order.append(tile)
	elif force:
		var entry: Dictionary = _visible_tiles.get(tile, {})
		entry["force"] = true
		_visible_tiles[tile] = entry

func _tile_display_name(tile: Tile) -> String:
	if tile == null:
		return "(Unnamed Tile)"
	var name := tile.name.strip_edges()
	return name if name != "" else "(Unnamed Tile)"

func _has_additional_tiles_available() -> bool:
	return not _get_addable_tiles().is_empty()

func _update_add_tile_button_state() -> void:
	if add_tile_button == null:
		return
	var has_selection := not _selected_entries.is_empty()
	var can_add := has_selection and _library != null and _has_additional_tiles_available()
	add_tile_button.disabled = not can_add

func _ensure_add_tile_dialog() -> void:
	if _add_tile_dialog and is_instance_valid(_add_tile_dialog):
		return
	if AddTileDialogScene == null:
		return
	var dialog_instance := AddTileDialogScene.instantiate() as AddTileDialog
	if dialog_instance == null:
		return
	_add_tile_dialog = dialog_instance
	_add_tile_dialog.tiles_selected.connect(_on_add_tile_dialog_tiles_selected)
	add_child(_add_tile_dialog)

func _connect_tree_button_signal() -> void:
	if compatibility_tree == null:
		return
	var callable := Callable(self, "_on_compatibility_tree_item_button_pressed")
	var candidates := ["item_button_pressed", "button_pressed", "button_clicked"]
	for signal_name in candidates:
		if compatibility_tree.has_signal(signal_name):
			if not compatibility_tree.is_connected(signal_name, callable):
				compatibility_tree.connect(signal_name, callable)
			return
	push_warning("SocketManagerDialog: tree button signal unavailable; remove buttons disabled.")

func _get_addable_tiles() -> Array:
	var available: Array = []
	if _library == null:
		return available
	for tile in _library.tiles:
		if tile == null:
			continue
		if tile == _tile:
			continue
		if _visible_tiles.has(tile):
			continue
		available.append(tile)
	available.sort_custom(func(a, b):
		return _tile_display_name(a) < _tile_display_name(b)
	)
	return available

func _is_valid_socket_id(socket_id: String) -> bool:
	if socket_id == "":
		return false
	var lowered := socket_id.strip_edges().to_lower()
	return lowered != "none" and lowered != "any"

func _load_remove_tile_icon() -> Texture2D:
	if has_theme_icon("Remove", "EditorIcons"):
		return get_theme_icon("Remove", "EditorIcons")
	if has_theme_icon("Close", "EditorIcons"):
		return get_theme_icon("Close", "EditorIcons")
	if has_theme_icon("Clear", "EditorIcons"):
		return get_theme_icon("Clear", "EditorIcons")
	return _create_fallback_remove_icon()

func _create_fallback_remove_icon() -> Texture2D:
	var size := 12
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var clear := Color(0, 0, 0, 0)
	var stroke := Color(1.0, 0.35, 0.35, 1.0)
	image.fill(clear)
	for i in range(size):
		image.set_pixel(i, i, stroke)
		image.set_pixel(size - 1 - i, i, stroke)
	return ImageTexture.create_from_image(image)

func _tile_storage_key(tile: Tile) -> String:
	if tile == null:
		return ""
	if tile.resource_path.strip_edges() != "":
		return tile.resource_path.strip_edges()
	return "inst:%d" % tile.get_instance_id()

func _owner_storage_key() -> String:
	return _tile_storage_key(_tile)

func _hidden_tiles_for_owner(owner_key: String) -> Dictionary:
	if owner_key == "":
		return {}
	if not _hidden_tile_map.has(owner_key):
		_hidden_tile_map[owner_key] = {}
	return _hidden_tile_map[owner_key]

func _is_tile_hidden(tile: Tile) -> bool:
	var owner_key := _owner_storage_key()
	if owner_key == "":
		return false
	var hidden: Dictionary = _hidden_tiles_for_owner(owner_key)
	var tile_key := _tile_storage_key(tile)
	return tile_key != "" and hidden.has(tile_key)

func _mark_tile_hidden(tile: Tile) -> void:
	var owner_key := _owner_storage_key()
	var tile_key := _tile_storage_key(tile)
	if owner_key == "" or tile_key == "":
		return
	var hidden: Dictionary = _hidden_tiles_for_owner(owner_key)
	hidden[tile_key] = true
	_hidden_tile_map[owner_key] = hidden

func _unhide_tile(tile: Tile) -> void:
	var owner_key := _owner_storage_key()
	var tile_key := _tile_storage_key(tile)
	if owner_key == "" or tile_key == "":
		return
	if not _hidden_tile_map.has(owner_key):
		return
	var hidden: Dictionary = _hidden_tile_map[owner_key]
	if hidden.erase(tile_key):
		_hidden_tile_map[owner_key] = hidden

func _on_add_tile_dialog_tiles_selected(tiles: Array) -> void:
	for tile in tiles:
		if tile:
			_add_visible_tile(tile, true)
	_request_compatibility_refresh()
	_update_add_tile_button_state()

func _on_add_tile_button_pressed() -> void:
	if _library == null:
		return
	_ensure_add_tile_dialog()
	if _add_tile_dialog == null:
		return
	var available := _get_addable_tiles()
	_add_tile_dialog.set_available_tiles(available)
	_add_tile_dialog.popup_centered()

func _remove_visible_tile(tile: Tile) -> void:
	if tile == null or tile == _tile:
		return
	_clear_connections_to_tile(tile)
	if _visible_tiles.has(tile):
		_visible_tiles.erase(tile)
	_visible_tile_order.erase(tile)
	_mark_tile_hidden(tile)
	_request_compatibility_refresh()
	_update_add_tile_button_state()

func _clear_connections_to_tile(tile: Tile) -> void:
	if tile == null:
		return
	var source_sockets: Array = []
	if _selected_entries.is_empty():
		if _tile:
			for socket in _tile.sockets:
				source_sockets.append(socket)
	else:
		for entry in _selected_entries:
			if entry and entry.socket:
				source_sockets.append(entry.socket)
	for source_socket in source_sockets:
		if source_socket == null:
			continue
		source_socket.ensure_guid()
		var source_guid := String(source_socket.socket_guid).strip_edges()
		if source_guid == "":
			continue
		for target_socket in tile.sockets:
			if target_socket == null:
				continue
			target_socket.ensure_guid()
			var target_guid := String(target_socket.socket_guid).strip_edges()
			if target_guid == "":
				continue
			if _pending_contains(source_socket, target_guid) or _pending_contains(target_socket, source_guid):
				_apply_bidirectional_change(source_socket, target_socket, false)

func _resolve_tile_from_item(item: TreeItem) -> Tile:
	if compatibility_tree == null:
		return null
	var current := item
	while current and current != compatibility_tree.get_root():
		var meta := current.get_metadata(1)
		if typeof(meta) == TYPE_DICTIONARY:
			var row_type := String(meta.get("row_type", ""))
			if row_type == "tile":
				return meta.get("tile", null)
		current = current.get_parent()
	return null

func _on_compatibility_tree_item_button_pressed(item: TreeItem, column: int, _id: int, _mouse_button_index: int) -> void:
	if column != 3:
		return
	var tile_meta := item.get_metadata(column)
	var tile: Tile = null
	if typeof(tile_meta) == TYPE_DICTIONARY:
		tile = tile_meta.get("tile", null)
	if tile == null:
		tile = _resolve_tile_from_item(item)
	if tile == null or tile == _tile:
		return
	_remove_visible_tile(tile)

func _refresh_socket_list() -> void:
	if socket_list == null:
		return
	
	# Ensure signals are connected
	if not socket_list.item_selected.is_connected(_on_socket_selected):
		socket_list.item_selected.connect(_on_socket_selected)
	if not socket_list.multi_selected.is_connected(_on_socket_multi_selected):
		socket_list.multi_selected.connect(_on_socket_multi_selected)
	
	socket_list.clear()
	var first_valid := -1
	for i in range(_socket_entries.size()):
		var entry: SocketEntry = _socket_entries[i]
		var label := _direction_to_label(entry.direction)
		if entry.socket_id != "":
			label += "  —  %s" % entry.socket_id
		elif entry.socket != null:
			label += "  —  (unnamed type)"
		else:
			label += "  —  (no socket)"
		socket_list.add_item(label)
		socket_list.set_item_metadata(i, entry)
		# Ensure item is selectable
		socket_list.set_item_selectable(i, true)
		if entry.socket_id != "" and first_valid == -1:
			first_valid = i
	if _socket_entries.size() > 0:
		var index_to_select := first_valid if first_valid != -1 else 0
		socket_list.select(index_to_select)
		_on_socket_selected(index_to_select)
	else:
		socket_info_label.text = "No sockets detected on this tile."
		_update_ui_availability(false)

func _select_initial_socket() -> void:
	if socket_list == null:
		return
	var selected := socket_list.get_selected_items()
	if selected.is_empty():
		return
	_on_socket_selected(selected[0])

func _on_socket_selected(index: int) -> void:
	# Single selection or first item in multi-select
	call_deferred("_update_selection")

func _on_socket_multi_selected(index: int, selected: bool) -> void:
	# Handle multi-select changes (Ctrl+Click, Shift+Click)
	call_deferred("_update_selection")

func _update_selection() -> void:
	"""Update the selected entries based on ItemList selection state."""
	if socket_list == null:
		return
	
	# Get all currently selected items
	var selected_indices := socket_list.get_selected_items()
	_selected_entries.clear()
	
	for idx in selected_indices:
		if idx >= 0 and idx < _socket_entries.size():
			var entry: SocketEntry = _socket_entries[idx]
			if entry.socket != null and entry.socket_id != "":
				_selected_entries.append(entry)
	
	if _selected_entries.is_empty():
		socket_info_label.text = "Select sockets from the left to edit their compatibility."
		_update_ui_availability(false)
		_request_compatibility_refresh()
		return
	
	# Update label based on selection count
	if _selected_entries.size() == 1:
		var dir_label := _direction_to_label(_selected_entries[0].direction)
		socket_info_label.text = "Editing: %s socket '%s'" % [dir_label, _selected_entries[0].socket_id]
	else:
		var parts := []
		for entry in _selected_entries:
			parts.append("%s (%s)" % [entry.socket_id, _direction_to_label(entry.direction)])
		socket_info_label.text = "Editing %d sockets: %s" % [_selected_entries.size(), ", ".join(parts)]
	
	_update_ui_availability(true)
	_request_compatibility_refresh()
	_update_add_tile_button_state()

func _update_ui_availability(enable: bool) -> void:
	_tree_edit_enabled = enable
	if apply_suggestions_button:
		apply_suggestions_button.disabled = not enable
	_update_add_tile_button_state()

func _request_compatibility_refresh() -> void:
	if _compatibility_refresh_pending:
		return
	_compatibility_refresh_pending = true
	call_deferred("_perform_compatibility_refresh")

func _perform_compatibility_refresh() -> void:
	_refresh_compatibility_view()

func _refresh_compatibility_view() -> void:
	_compatibility_refresh_pending = false
	if compatibility_tree == null:
		return
	compatibility_tree.clear()
	compatibility_tree.columns = 4
	compatibility_tree.set_column_title(0, "Connect")
	compatibility_tree.set_column_title(1, "Tile / Direction")
	compatibility_tree.set_column_title(2, "Socket ID")
	compatibility_tree.set_column_title(3, "↔")
	compatibility_tree.set_column_expand(0, false)
	compatibility_tree.set_column_expand(3, false)
	compatibility_tree.set_column_custom_minimum_width(0, 80)
	compatibility_tree.set_column_custom_minimum_width(3, 80)
	compatibility_tree.set_column_expand_ratio(1, 1.2)
	compatibility_tree.set_column_expand_ratio(2, 1.0)
	compatibility_status_label.text = ""
	suggestions_label.text = ""
	
	if _selected_entries.is_empty() or _library == null:
		return
	
	var root = compatibility_tree.create_item()
	var selected_socket_refs: Dictionary = {}
	for entry in _selected_entries:
		if entry.socket:
			selected_socket_refs[entry.socket] = true
	var summary_total := 0
	var summary_enabled := 0
	var summary_bidirectional := 0
	
	# Build tree organized by tile -> sockets
	for tile in _visible_tile_order:
		if tile == null:
			continue
		var visibility := _visible_tiles.get(tile, {})
		var force_show := bool(visibility.get("force", false))
		var sockets_to_show: Array = []
		for socket in tile.sockets:
			if selected_socket_refs.has(socket):
				continue
			var target_id := String(socket.socket_id).strip_edges()
			if target_id == "":
				continue
			if tile != _tile and not _is_valid_socket_id(target_id):
				continue
			_ensure_socket_state(socket)
			sockets_to_show.append(socket)
		if sockets_to_show.is_empty() and not force_show:
			continue
		var tile_item := compatibility_tree.create_item(root)
		tile_item.set_text(1, _tile_display_name(tile))
		tile_item.set_selectable(0, false)
		tile_item.set_selectable(1, true)
		tile_item.set_selectable(2, false)
		tile_item.set_selectable(3, false)
		tile_item.set_metadata(1, {
			"row_type": "tile",
			"tile": tile
		})
		if tile != _tile:
			var tooltip := "Remove this tile from the compatibility list"
			if _remove_tile_icon:
				tile_item.add_button(3, _remove_tile_icon, 0, false, tooltip)
			else:
				tile_item.set_text(3, "Remove")
				tile_item.set_selectable(3, true)
				tile_item.set_metadata(3, {
				"row_type": "tile_remove",
				"tile": tile
			})
		if sockets_to_show.is_empty():
			var placeholder := compatibility_tree.create_item(tile_item)
			placeholder.set_text(1, "  No sockets available.")
			placeholder.set_selectable(0, false)
			placeholder.set_selectable(1, false)
			placeholder.set_selectable(2, false)
			placeholder.set_selectable(3, false)
			continue
		for socket in sockets_to_show:
			var target_id := String(socket.socket_id).strip_edges()
			var socket_item := compatibility_tree.create_item(tile_item)
			socket_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			socket_item.set_editable(0, _tree_edit_enabled)
			var can_connect := _can_any_selected_connect_to(socket)
			socket_item.set_checked(0, can_connect)
			socket_item.set_text(1, "  " + _direction_to_label(socket.direction))
			socket_item.set_text(2, target_id)
			socket_item.set_cell_mode(3, TreeItem.CELL_MODE_CHECK)
			socket_item.set_editable(3, _tree_edit_enabled)
			var is_bidirectional := _are_all_selected_bidirectional_with(socket)
			socket_item.set_checked(3, is_bidirectional)
			socket_item.set_selectable(0, true)
			socket_item.set_selectable(1, false)
			socket_item.set_selectable(2, false)
			socket_item.set_selectable(3, true)
			socket_item.set_metadata(1, {
				"row_type": "socket",
				"tile": tile
			})
			socket_item.set_metadata(0, {
				"socket": socket,
				"socket_id": target_id,
				"tile": tile,
				"column": "connect"
			})
			socket_item.set_metadata(3, {
				"socket": socket,
				"socket_id": target_id,
				"tile": tile,
				"column": "bidirectional"
			})
			if _is_suggested_target_for_any_selected(target_id):
				socket_item.set_custom_color(1, Color(0.7, 0.85, 1.0))
				socket_item.set_custom_color(2, Color(0.7, 0.85, 1.0))
			summary_total += 1
			if can_connect:
				summary_enabled += 1
			if is_bidirectional:
				summary_bidirectional += 1
	
	var status := "%d connections (%d bidirectional) of %d sockets" % [summary_enabled, summary_bidirectional, summary_total]
	if summary_total == 0:
		status = "No other sockets available in library."
	compatibility_status_label.text = status
	_update_suggestions_label()
	compatibility_tree.hide_root = true
	_update_add_tile_button_state()

func _find_tile_for_socket(socket: Socket) -> Tile:
	"""Find which tile contains a given socket."""
	if _library == null:
		return null
	for tile in _library.tiles:
		if socket in tile.sockets:
			return tile
	return null

func _update_suggestions_label() -> void:
	if suggestions_label == null or _selected_entries.is_empty():
		return
	# Collect all suggestions for selected sockets
	var all_suggestions: Array = []
	for entry in _selected_entries:
		var suggestions: Array = _suggestions_by_dir.get(entry.direction, [])
		all_suggestions.append_array(suggestions)
	var suggestions := all_suggestions
	if suggestions.is_empty():
		suggestions_label.text = "No analyser suggestions for this socket."
		if apply_suggestions_button:
			apply_suggestions_button.disabled = true
		return
	if apply_suggestions_button:
		apply_suggestions_button.disabled = not _tree_edit_enabled
	var parts: Array[String] = []
	for suggestion in suggestions:
		var partner_tile: Tile = suggestion.get("partner_tile", null)
		var tile_name := partner_tile.name if partner_tile else "Unknown"
		var socket_id: String = suggestion.get("socket_id", "")
		parts.append("%s — %s" % [tile_name, socket_id])
	suggestions_label.text = "Suggestions: %s" % ", ".join(parts)


func _on_tree_item_edited() -> void:
	if compatibility_tree == null:
		return
	var item: TreeItem = compatibility_tree.get_edited()
	if item == null or _selected_entries.is_empty():
		return
	var column := compatibility_tree.get_edited_column()
	if column != 0 and column != 3:
		return  # Only handle checkbox columns
	
	var data = item.get_metadata(column)
	if typeof(data) != TYPE_DICTIONARY:
		return
	
	var target_socket: Socket = data.get("socket")
	if target_socket == null:
		return
	
	var desired := item.is_checked(column)
	var column_type: String = data.get("column", "")
	
	if column_type == "connect":
		# Column 0: Toggle one-way connection (source -> target)
		for entry in _selected_entries:
			_apply_connection_change(entry.socket, target_socket, desired)
	elif column_type == "bidirectional":
		# Column 3: Toggle bidirectional connection
		for entry in _selected_entries:
			_apply_bidirectional_change(entry.socket, target_socket, desired)
	
	_request_compatibility_refresh()

func _apply_connection_change(source: Socket, target: Socket, enable: bool) -> void:
	"""Apply one-way connection change from source to target."""
	if source == null or target == null or source == target:
		return
	
	source.ensure_guid()
	target.ensure_guid()
	var target_guid := String(target.socket_guid).strip_edges()
	if target_guid == "":
		return
	
	if enable:
		var pending := _get_pending_socket_guids(source)
		if target_guid not in pending:
			pending.append(target_guid)
			pending.sort()
			_set_socket_modified_state(source)
	else:
		var pending := _get_pending_socket_guids(source)
		if target_guid in pending:
			pending.erase(target_guid)
			_set_socket_modified_state(source)

func _apply_bidirectional_change(source: Socket, target: Socket, enable: bool) -> void:
	"""Apply bidirectional compatibility change between two sockets."""
	if source == null or target == null or source == target:
		return
	source.ensure_guid()
	target.ensure_guid()

	_apply_connection_change(source, target, enable)
	_apply_connection_change(target, source, enable)

func _are_sockets_bidirectionally_compatible(a: Socket, b: Socket) -> bool:
	"""Check if two sockets have bidirectional compatibility."""
	if a == null or b == null:
		return false
	a.ensure_guid()
	b.ensure_guid()
	return _pending_contains(a, b.socket_guid) and _pending_contains(b, a.socket_guid)

func _has_partial_compatibility(a: Socket, b: Socket) -> bool:
	"""Check if sockets have partial (one-way) compatibility."""
	if a == null or b == null:
		return false
	a.ensure_guid()
	b.ensure_guid()
	var forward := _pending_contains(a, b.socket_guid)
	var backward := _pending_contains(b, a.socket_guid)
	return forward != backward

func _can_any_selected_connect_to(target: Socket) -> bool:
	"""Check if ANY selected socket can connect to target (one-way or bidirectional)."""
	if _selected_entries.is_empty() or target == null:
		return false
	target.ensure_guid()
	var target_guid := String(target.socket_guid).strip_edges()
	if target_guid == "":
		return false
	for entry in _selected_entries:
		if entry.socket == null:
			continue
		var pending := _get_pending_socket_guids(entry.socket)
		if target_guid in pending:
			return true
	return false

func _are_all_selected_bidirectional_with(target: Socket) -> bool:
	"""Check if ALL selected sockets have bidirectional compatibility with target."""
	if _selected_entries.is_empty() or target == null:
		return false
	for entry in _selected_entries:
		if not _are_sockets_bidirectionally_compatible(entry.socket, target):
			return false
	return true

func _are_all_selected_compatible_with(target: Socket) -> bool:
	"""Check if ALL selected sockets are bidirectionally compatible with target."""
	if _selected_entries.is_empty() or target == null:
		return false
	for entry in _selected_entries:
		if not _are_sockets_bidirectionally_compatible(entry.socket, target):
			return false
	return true

func _has_any_selected_partial_compatibility(target: Socket) -> bool:
	"""Check if ANY selected socket has partial compatibility with target."""
	if _selected_entries.is_empty() or target == null:
		return false
	for entry in _selected_entries:
		if _has_partial_compatibility(entry.socket, target):
			return true
	return false

func _is_suggested_target_for_any_selected(socket_id: String) -> bool:
	"""Check if socket_id is a suggested target for any selected socket."""
	for entry in _selected_entries:
		var suggestions: Array = _suggestions_by_dir.get(entry.direction, [])
		for suggestion in suggestions:
			var suggested_id: String = suggestion.get("socket_id", "")
			if suggested_id == socket_id:
				return true
	return false

func _is_suggested_target(direction: Vector3i, socket_id: String) -> bool:
	var suggestions: Array = _suggestions_by_dir.get(direction, [])
	for suggestion in suggestions:
		var suggested_id: String = suggestion.get("socket_id", "")
		if suggested_id == socket_id:
			return true
	return false

func _on_apply_suggestions_pressed() -> void:
	"""Apply all suggestions for all selected sockets."""
	if _selected_entries.is_empty():
		return
	
	for entry in _selected_entries:
		var suggestions: Array = _suggestions_by_dir.get(entry.direction, [])
		for suggestion in suggestions:
			var partner_socket: Socket = suggestion.get("partner_socket", null)
			if partner_socket == null:
				continue
			
			# Add bidirectional compatibility
			_apply_bidirectional_change(entry.socket, partner_socket, true)
	
	_request_compatibility_refresh()

func _commit_pending_changes() -> bool:
	if _modified_sockets.is_empty():
		return false
	var sockets := _modified_sockets.keys()
	var applied := false
	for socket in sockets:
		if socket == null:
			continue
		var pending_ids := _get_pending_socket_guids(socket)
		var new_list: Array = pending_ids.duplicate()
		new_list.sort()
		var current: Array = []
		if socket.compatible_sockets:
			current.assign(socket.compatible_sockets)
		current.sort()
		if new_list != current:
			socket.compatible_sockets = new_list.duplicate()
			applied = true
		var state := _socket_states.get(socket, null)
		if state != null:
			state["original"] = new_list.duplicate()
			state["pending"] = new_list.duplicate()
			_socket_states[socket] = state
	_modified_sockets.clear()
	return applied

func _on_dialog_confirmed() -> void:
	"""Handle dialog confirmation - notify library of changes."""
	if _library == null:
		return
	
	# Apply pending compatibility changes lazily and notify subscribers
	if _commit_pending_changes():
		_library.notify_socket_compatibility_changed()

func _direction_to_label(direction: Vector3i) -> String:
	if direction == Vector3i.UP:
		return "Up"
	elif direction == Vector3i.DOWN:
		return "Down"
	elif direction == Vector3i.LEFT:
		return "Left"
	elif direction == Vector3i.RIGHT:
		return "Right"
	elif direction == Vector3i.FORWARD:
		return "Forward"
	elif direction == Vector3i.BACK:
		return "Back"
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]
