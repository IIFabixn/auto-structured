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

@onready var socket_list: ItemList = %SocketList
@onready var socket_info_label: Label = %SelectedSocketInfo
@onready var compatibility_tree: Tree = %CompatibilityTree
@onready var compatibility_status_label: Label = %CompatibilityStatusLabel
@onready var suggestions_label: Label = %SuggestionsLabel
@onready var apply_suggestions_button: Button = %ApplySuggestionsButton

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
	if apply_suggestions_button and not apply_suggestions_button.pressed.is_connected(_on_apply_suggestions_pressed):
		apply_suggestions_button.pressed.connect(_on_apply_suggestions_pressed)
	_update_ui_availability(false)

func setup(library: ModuleLibrary, tile: Tile) -> void:
	_library = library
	_tile = tile
	_rebuild_state()

func _rebuild_state() -> void:
	_socket_entries.clear()
	_suggestions_by_dir.clear()
	_modified_sockets.clear()
	_selected_entries.clear()
	if _library == null or _tile == null:
		_refresh_socket_list()
		_refresh_compatibility_view()
		return
	_build_socket_entries()
	_build_suggestions()
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
		_socket_entries.append(entry)

func _build_suggestions() -> void:
	var suggestions = SocketSuggestionBuilder.build_suggestions(_tile, _library)
	for suggestion in suggestions:
		var direction: Vector3i = suggestion.get("direction", Vector3i.ZERO)
		if not _suggestions_by_dir.has(direction):
			_suggestions_by_dir[direction] = []
		_suggestions_by_dir[direction].append(suggestion)

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
		_refresh_compatibility_view()
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
	_refresh_compatibility_view()

func _update_ui_availability(enable: bool) -> void:
	_tree_edit_enabled = enable
	if apply_suggestions_button:
		apply_suggestions_button.disabled = not enable

func _refresh_compatibility_view() -> void:
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
	var selected_socket_ids: Array[String] = []
	for entry in _selected_entries:
		selected_socket_ids.append(entry.socket_id)
	var summary_total := 0
	var summary_enabled := 0
	var summary_bidirectional := 0
	
	# Build tree organized by tile -> sockets
	for tile in _library.tiles:
		var tile_has_valid_sockets := false
		var tile_item: TreeItem = null
		
		# Check if this tile has any valid sockets to show
		for socket in tile.sockets:
			var target_id := socket.socket_id.strip_edges()
			if target_id != "" and target_id not in selected_socket_ids:
				tile_has_valid_sockets = true
				break
		
		if not tile_has_valid_sockets:
			continue
		
		# Create tile header item
		tile_item = compatibility_tree.create_item(root)
		tile_item.set_text(1, tile.name if tile.name != "" else "(Unnamed Tile)")
		tile_item.set_selectable(0, false)
		tile_item.set_selectable(1, false)
		tile_item.set_selectable(2, false)
		tile_item.set_selectable(3, false)
		
		# TODO: Add thumbnail icon here when available
		# tile_item.set_icon(1, tile.thumbnail)
		
		# Add each socket as a child
		for socket in tile.sockets:
			var target_id := socket.socket_id.strip_edges()
			if target_id == "" or target_id in selected_socket_ids:
				continue  # Skip empty and currently selected sockets
			
			var socket_item = compatibility_tree.create_item(tile_item)
			
			# Column 0: Connect checkbox
			socket_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			socket_item.set_editable(0, _tree_edit_enabled)
			
			# Check if ANY selected socket can connect to this target
			var can_connect := _can_any_selected_connect_to(socket)
			socket_item.set_checked(0, can_connect)
			
			# Column 1: Direction
			socket_item.set_text(1, "  " + _direction_to_label(socket.direction))
			
			# Column 2: Socket ID
			socket_item.set_text(2, target_id)
			
			# Column 3: Bidirectional checkbox
			socket_item.set_cell_mode(3, TreeItem.CELL_MODE_CHECK)
			socket_item.set_editable(3, _tree_edit_enabled)
			
			# Check if connection is bidirectional for ALL selected sockets
			var is_bidirectional := _are_all_selected_bidirectional_with(socket)
			socket_item.set_checked(3, is_bidirectional)
			
			# Make only checkbox columns selectable
			socket_item.set_selectable(0, true)
			socket_item.set_selectable(1, false)
			socket_item.set_selectable(2, false)
			socket_item.set_selectable(3, true)
			
			# Store metadata
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
			
			# Highlight suggested connections
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
	
	_refresh_compatibility_view()

func _apply_connection_change(source: Socket, target: Socket, enable: bool) -> void:
	"""Apply one-way connection change from source to target."""
	if source == null or target == null or source == target:
		return
	
	var target_id := target.socket_id
	if target_id == "":
		return
	
	if enable:
		# Add one-way compatibility (source -> target)
		if target_id not in source.compatible_sockets:
			source.add_compatible_socket(target_id)
			_modified_sockets[source] = true
	else:
		# Remove one-way compatibility
		if target_id in source.compatible_sockets:
			source.remove_compatible_socket(target_id)
			_modified_sockets[source] = true

func _apply_bidirectional_change(source: Socket, target: Socket, enable: bool) -> void:
	"""Apply bidirectional compatibility change between two sockets."""
	if source == null or target == null or source == target:
		return
	
	var source_id := source.socket_id
	var target_id := target.socket_id
	
	if source_id == "" or target_id == "":
		return
	
	if enable:
		# Add bidirectional compatibility
		if target_id not in source.compatible_sockets:
			source.add_compatible_socket(target_id)
			_modified_sockets[source] = true
		if source_id not in target.compatible_sockets:
			target.add_compatible_socket(source_id)
			_modified_sockets[target] = true
	else:
		# Remove bidirectional compatibility
		if target_id in source.compatible_sockets:
			source.remove_compatible_socket(target_id)
			_modified_sockets[source] = true
		if source_id in target.compatible_sockets:
			target.remove_compatible_socket(source_id)
			_modified_sockets[target] = true

func _are_sockets_bidirectionally_compatible(a: Socket, b: Socket) -> bool:
	"""Check if two sockets have bidirectional compatibility."""
	if a == null or b == null:
		return false
	return b.socket_id in a.compatible_sockets and a.socket_id in b.compatible_sockets

func _has_partial_compatibility(a: Socket, b: Socket) -> bool:
	"""Check if sockets have partial (one-way) compatibility."""
	if a == null or b == null:
		return false
	var forward := b.socket_id in a.compatible_sockets
	var backward := a.socket_id in b.compatible_sockets
	return forward != backward

func _can_any_selected_connect_to(target: Socket) -> bool:
	"""Check if ANY selected socket can connect to target (one-way or bidirectional)."""
	if _selected_entries.is_empty() or target == null:
		return false
	var target_id := target.socket_id
	for entry in _selected_entries:
		if target_id in entry.socket.compatible_sockets:
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
	
	_refresh_compatibility_view()

func _on_dialog_confirmed() -> void:
	"""Handle dialog confirmation - notify library of changes."""
	if _library == null:
		return
	
	# Notify library that socket compatibility was changed
	if not _modified_sockets.is_empty():
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
