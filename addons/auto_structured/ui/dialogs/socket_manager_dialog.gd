@tool
class_name SocketManagerDialog extends ConfirmationDialog

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const SocketType = preload("res://addons/auto_structured/core/socket_type.gd")
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
	var socket_type: SocketType
	var socket_type_id: String

var _library: ModuleLibrary = null
var _tile: Tile = null
var _socket_entries: Array[SocketEntry] = []
var _current_entry: SocketEntry = null
var _suggestions_by_dir: Dictionary = {}
var _modified_types: Dictionary = {}
var _tree_edit_enabled: bool = false

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	if not canceled.is_connected(queue_free):
		canceled.connect(queue_free)
	if not close_requested.is_connected(queue_free):
		close_requested.connect(queue_free)
	if socket_list and not socket_list.item_selected.is_connected(_on_socket_selected):
		socket_list.item_selected.connect(_on_socket_selected)
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
	_modified_types.clear()
	_current_entry = null
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
		entry.socket_type = socket.socket_type if socket else null
		entry.socket_type_id = entry.socket_type.type_id.strip_edges() if entry.socket_type else ""
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
	socket_list.clear()
	var first_valid := -1
	for i in range(_socket_entries.size()):
		var entry: SocketEntry = _socket_entries[i]
		var label := _direction_to_label(entry.direction)
		if entry.socket_type_id != "":
			label += "  —  %s" % entry.socket_type_id
		elif entry.socket != null:
			label += "  —  (unnamed type)"
		else:
			label += "  —  (no socket)"
		socket_list.add_item(label)
		socket_list.set_item_metadata(i, entry)
		if entry.socket_type != null and first_valid == -1:
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
	if index < 0 or index >= _socket_entries.size():
		return
	var entry: SocketEntry = _socket_entries[index]
	_current_entry = entry
	if entry.socket == null:
		socket_info_label.text = "Direction %s has no socket defined." % _direction_to_label(entry.direction)
		_update_ui_availability(false)
		_refresh_compatibility_view()
		return
	if entry.socket_type == null:
		socket_info_label.text = "Socket in direction %s has no socket type assigned." % _direction_to_label(entry.direction)
		_update_ui_availability(false)
		_refresh_compatibility_view()
		return
	socket_info_label.text = "Managing socket '%s' (%s)" % [entry.socket_type.get_display_name(), entry.socket_type_id]
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
	compatibility_tree.columns = 3
	compatibility_tree.set_column_title(0, "Link")
	compatibility_tree.set_column_title(1, "Tile / Direction")
	compatibility_tree.set_column_title(2, "Socket Type")
	compatibility_tree.set_column_expand_ratio(0, 0.15)
	compatibility_tree.set_column_expand_ratio(1, 0.45)
	compatibility_tree.set_column_expand_ratio(2, 0.4)
	compatibility_status_label.text = ""
	suggestions_label.text = ""
	if _current_entry == null or _current_entry.socket_type == null or _library == null:
		return
	var root = compatibility_tree.create_item()
	var current_type := _current_entry.socket_type
	var summary_total := 0
	var summary_enabled := 0
	for tile in _library.tiles:
		var tile_item = compatibility_tree.create_item(root)
		tile_item.set_text(1, tile.name if tile.name != "" else "(Unnamed Tile)")
		for column in range(3):
			tile_item.set_selectable(column, false)
		for socket in tile.sockets:
			if socket.socket_type == null:
				continue
			var target_type: SocketType = socket.socket_type
			var target_id := target_type.type_id.strip_edges()
			if target_id == "":
				continue
			var child = compatibility_tree.create_item(tile_item)
			child.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			child.set_selectable(0, true)
			var is_bidirectional := _are_types_bidirectionally_compatible(current_type, target_type)
			var is_partial := _has_partial_compatibility(current_type, target_type)
			child.set_checked(0, is_bidirectional)
			child.set_metadata(0, {
				"socket_type": target_type,
				"type_id": target_id,
				"tile": tile,
				"direction": socket.direction
			})
			if is_partial and not is_bidirectional:
				child.set_indeterminate(0, true)
			else:
				child.set_indeterminate(0, false)
			child.set_text(1, _direction_to_label(socket.direction))
			child.set_text(2, target_id)
			for column in range(3):
				child.set_selectable(column, column == 0)
			var tooltip := "Tile: %s\nDirection: %s\nSocket ID: %s" % [tile.name, _direction_to_label(socket.direction), target_id]
			for column in range(3):
				child.set_tooltip_text(column, tooltip)
			if _is_suggested_target(_current_entry.direction, target_id):
				child.set_custom_color(1, Color(0.7, 0.85, 1.0))
				child.set_custom_color(2, Color(0.7, 0.85, 1.0))
			child.set_editable(0, _tree_edit_enabled)
			summary_total += 1
			if is_bidirectional:
				summary_enabled += 1
	var status := "%d of %d connections enabled" % [summary_enabled, summary_total]
	if summary_total == 0:
		status = "No other sockets available in library."
	compatibility_status_label.text = status
	_update_suggestions_label()
	compatibility_tree.hide_root = true

func _update_suggestions_label() -> void:
	if suggestions_label == null or _current_entry == null:
		return
	var suggestions: Array = _suggestions_by_dir.get(_current_entry.direction, [])
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
	if item == null or _current_entry == null or _current_entry.socket_type == null:
		return
	var column := compatibility_tree.get_edited_column()
	if column != 0:
		return
	var data = item.get_metadata(0)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var target_type: SocketType = data.get("socket_type")
	if target_type == null:
		return
	var desired := item.is_checked(0)
	_apply_bidirectional_change(_current_entry.socket_type, target_type, desired)
	_refresh_compatibility_view()

func _apply_bidirectional_change(source: SocketType, target: SocketType, enable: bool) -> void:
	if source == null or target == null or source == target:
		return
	if enable:
		var changed := _ensure_bidirectional(source, target)
		if changed:
			_mark_modified(source)
			_mark_modified(target)
	else:
		var changed := _remove_bidirectional(source, target)
		if changed:
			_mark_modified(source)
			_mark_modified(target)

func _ensure_bidirectional(source: SocketType, target: SocketType) -> bool:
	var changed := false
	if not source.compatible_types.has(target.type_id):
		source.add_compatible_type(target.type_id)
		changed = true
	if not target.compatible_types.has(source.type_id):
		target.add_compatible_type(source.type_id)
		changed = true
	return changed

func _remove_bidirectional(source: SocketType, target: SocketType) -> bool:
	var changed := false
	if source.compatible_types.has(target.type_id):
		source.remove_compatible_type(target.type_id)
		changed = true
	if target.compatible_types.has(source.type_id):
		target.remove_compatible_type(source.type_id)
		changed = true
	return changed

func _mark_modified(socket_type: SocketType) -> void:
	if socket_type == null:
		return
	_modified_types[socket_type] = true

func _are_types_bidirectionally_compatible(a: SocketType, b: SocketType) -> bool:
	if a == null or b == null:
		return false
	return a.compatible_types.has(b.type_id) and b.compatible_types.has(a.type_id)

func _has_partial_compatibility(a: SocketType, b: SocketType) -> bool:
	if a == null or b == null:
		return false
	var forward := a.compatible_types.has(b.type_id)
	var backward := b.compatible_types.has(a.type_id)
	return forward != backward

func _is_suggested_target(direction: Vector3i, socket_id: String) -> bool:
	var suggestions: Array = _suggestions_by_dir.get(direction, [])
	for suggestion in suggestions:
		var suggested_id: String = suggestion.get("socket_id", "")
		if suggested_id == socket_id:
			return true
	return false

func _on_apply_suggestions_pressed() -> void:
	if _current_entry == null or _current_entry.socket_type == null:
		return
	var suggestions: Array = _suggestions_by_dir.get(_current_entry.direction, [])
	var changed := false
	for suggestion in suggestions:
		var target_type: SocketType = null
		var partner_socket: Socket = suggestion.get("partner_socket", null)
		if partner_socket and partner_socket.socket_type:
			target_type = partner_socket.socket_type
		else:
			target_type = suggestion.get("socket_type", null)
		if target_type == null:
			var socket_id: String = suggestion.get("socket_id", "")
			if socket_id != "" and _library != null:
				target_type = _library.get_socket_type_by_id(socket_id)
		if target_type == null:
			continue
		if _ensure_bidirectional(_current_entry.socket_type, target_type):
			_mark_modified(_current_entry.socket_type)
			_mark_modified(target_type)
			changed = true
	if changed:
		_refresh_compatibility_view()

func _on_dialog_confirmed() -> void:
	if _library == null:
		return
	for socket_type in _modified_types.keys():
		if socket_type is SocketType:
			_library.notify_socket_type_compatibility_changed(socket_type)

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
