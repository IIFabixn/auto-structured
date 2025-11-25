@tool
class_name LibraryManagerDialog extends ConfirmationDialog

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")

@onready var tabs: TabContainer = %TabContainer
@onready var tags_search: LineEdit = %TagsSearchLine
@onready var tags_tree: Tree = %TagsTree
@onready var tags_add_button: Button = %TagsAddButton
@onready var tags_rename_button: Button = %TagsRenameButton
@onready var tags_delete_button: Button = %TagsDeleteButton
@onready var tags_usage_title: Label = %TagsUsageTitle
@onready var tags_usage_summary: Label = %TagsUsageSummary
@onready var tags_usage_tree: Tree = %TagsUsageTree
@onready var tags_apply_button: Button = %TagsApplyButton
@onready var tags_revoke_button: Button = %TagsRevokeButton

@onready var sockets_search: LineEdit = %SocketsSearchLine
@onready var sockets_tree: Tree = %SocketsTree
@onready var sockets_add_button: Button = %SocketsAddButton
@onready var sockets_rename_button: Button = %SocketsRenameButton
@onready var sockets_delete_button: Button = %SocketsDeleteButton
@onready var sockets_usage_title: Label = %SocketsUsageTitle
@onready var sockets_usage_summary: Label = %SocketsUsageSummary
@onready var sockets_usage_tree: Tree = %SocketsUsageTree
@onready var sockets_assign_button: Button = %SocketsAssignButton
@onready var sockets_revoke_button: Button = %SocketsRevokeButton

var _library: ModuleLibrary = null

var _tags_original: Array[String] = []
var _tags_pending: Array[String] = []
var _tag_forward_map: Dictionary = {}
var _tag_reverse_map: Dictionary = {}
var _tags_added: Dictionary = {}
var _tags_removed_originals: Dictionary = {}

class SocketRecord:
	var original_id: String
	var current_id: String
	var display_name: String = ""
	var compatibility: Array[String] = []

var _socket_records: Dictionary = {} ## current_id -> SocketRecord
var _socket_forward_map: Dictionary = {} ## original_id -> current_id
var _socket_reverse_map: Dictionary = {} ## current_id -> original_id
var _sockets_added: Dictionary = {}
var _sockets_removed_originals: Dictionary = {}

var _selected_tag: String = ""
var _selected_socket_id: String = ""
var _tags_filter: String = ""
var _sockets_filter: String = ""

var _ui_connected := false

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	_initialize_lists()
	_connect_ui()
	_refresh_all()

func _initialize_lists() -> void:
	if tags_tree:
		tags_tree.columns = 1
		tags_tree.hide_root = true
		tags_tree.column_titles_visible = true
		tags_tree.set_column_title(0, "Tag")
	if sockets_tree:
		sockets_tree.columns = 1
		sockets_tree.hide_root = true
		sockets_tree.column_titles_visible = true
		sockets_tree.set_column_title(0, "Socket Type")
	if tags_usage_tree:
		tags_usage_tree.columns = 2
		tags_usage_tree.hide_root = true
		tags_usage_tree.column_titles_visible = true
		tags_usage_tree.set_column_title(0, "Tile")
		tags_usage_tree.set_column_title(1, "Notes")
	if sockets_usage_tree:
		sockets_usage_tree.columns = 2
		sockets_usage_tree.hide_root = true
		sockets_usage_tree.column_titles_visible = true
		sockets_usage_tree.set_column_title(0, "Tile")
		sockets_usage_tree.set_column_title(1, "Direction")

func _connect_ui() -> void:
	if _ui_connected:
		return
	_ui_connected = true
	if tags_search:
		tags_search.text_changed.connect(func(value: String):
			_tags_filter = value.strip_edges().to_lower()
			_refresh_tags_list()
		)
	if tags_add_button:
		tags_add_button.pressed.connect(_on_add_tag_pressed)
	if tags_rename_button:
		tags_rename_button.pressed.connect(_on_rename_tag_pressed)
	if tags_delete_button:
		tags_delete_button.pressed.connect(_on_delete_tag_pressed)
	if tags_apply_button:
		tags_apply_button.pressed.connect(_on_apply_tag_to_tiles_pressed)
	if tags_revoke_button:
		tags_revoke_button.pressed.connect(_on_revoke_tag_from_tiles_pressed)
	if tags_tree:
		tags_tree.item_selected.connect(_on_tag_selected)
		tags_tree.item_activated.connect(_on_tag_activated)
		tags_tree.gui_input.connect(_on_tag_tree_gui_input)
	if sockets_search:
		sockets_search.text_changed.connect(func(value: String):
			_sockets_filter = value.strip_edges().to_lower()
			_refresh_sockets_list()
		)
	if sockets_add_button:
		sockets_add_button.pressed.connect(_on_add_socket_pressed)
	if sockets_rename_button:
		sockets_rename_button.pressed.connect(_on_rename_socket_pressed)
	if sockets_delete_button:
		sockets_delete_button.pressed.connect(_on_delete_socket_pressed)
	if sockets_assign_button:
		sockets_assign_button.pressed.connect(_on_assign_socket_to_sockets_pressed)
	if sockets_revoke_button:
		sockets_revoke_button.pressed.connect(_on_revoke_socket_from_sockets_pressed)
	if sockets_tree:
		sockets_tree.item_selected.connect(_on_socket_selected)
		sockets_tree.item_activated.connect(_on_socket_activated)
		sockets_tree.gui_input.connect(_on_socket_tree_gui_input)

func setup(library: ModuleLibrary) -> void:
	_library = library
	_reset_state()
	_refresh_all()

func _reset_state() -> void:
	_tags_original.clear()
	_tags_pending.clear()
	_tag_forward_map.clear()
	_tag_reverse_map.clear()
	_tags_added.clear()
	_tags_removed_originals.clear()
	_socket_records.clear()
	_socket_forward_map.clear()
	_socket_reverse_map.clear()
	_sockets_added.clear()
	_sockets_removed_originals.clear()
	_selected_tag = ""
	_selected_socket_id = ""
	_tags_filter = ""
	_sockets_filter = ""
	if tags_search:
		tags_search.clear()
	if sockets_search:
		sockets_search.clear()
	if _library == null:
		return
	_tags_original = _library.get_available_tags()
	_tags_original.sort()
	_tags_pending = _tags_original.duplicate()
	for tag in _tags_original:
		_tag_forward_map[tag] = tag
		_tag_reverse_map[tag] = tag
	for socket_type in _library.get_socket_type_resources():
		var record := SocketRecord.new()
		record.original_id = socket_type.type_id
		record.current_id = socket_type.type_id
		record.display_name = socket_type.display_name
		record.compatibility = socket_type.compatible_types.duplicate()
		_socket_records[record.current_id] = record
		_socket_forward_map[record.original_id] = record.current_id
		_socket_reverse_map[record.current_id] = record.original_id

func _refresh_all() -> void:
	_refresh_tags_list()
	_refresh_sockets_list()
	_update_tag_usage()
	_update_socket_usage()
	_update_buttons_state()

func _refresh_tags_list() -> void:
	if tags_tree == null:
		return
	tags_tree.clear()
	var root = tags_tree.create_item()
	var filter = _tags_filter

	var sorted_tags := _tags_pending.duplicate()
	sorted_tags.sort()
	for tag in sorted_tags:
		if not filter.is_empty() and not tag.to_lower().contains(filter):
			continue
		var item = tags_tree.create_item(root)
		item.set_text(0, tag)
		item.set_metadata(0, tag)
		if tag == _selected_tag:
			item.select(0)

	_update_buttons_state()

func _refresh_sockets_list() -> void:
	if sockets_tree == null:
		return
	sockets_tree.clear()
	var root = sockets_tree.create_item()
	var filter = _sockets_filter

	var ids: Array = _socket_records.keys()
	ids.sort() # alphabetical by current id
	for id in ids:
		var record: SocketRecord = _socket_records[id]
		var label = id
		if record.display_name.strip_edges() != "":
			label = "%s (%s)" % [record.display_name, id]
		var text_to_match = label.to_lower()
		if not filter.is_empty() and not text_to_match.contains(filter):
			continue
		var item = sockets_tree.create_item(root)
		item.set_text(0, label)
		item.set_metadata(0, id)
		if id == _selected_socket_id:
			item.select(0)

	_update_buttons_state()

func _update_buttons_state() -> void:
	var has_tag_selection := not _selected_tag.is_empty()
	if tags_rename_button:
		tags_rename_button.disabled = not has_tag_selection
	if tags_delete_button:
		tags_delete_button.disabled = not has_tag_selection
	if tags_apply_button:
		var disable_apply := not has_tag_selection
		if not disable_apply and _library != null:
			var clean = _selected_tag.strip_edges()
			disable_apply = true
			for tile in _library.tiles:
				if not tile.has_tag(clean):
					disable_apply = false
					break
		tags_apply_button.disabled = disable_apply
	if tags_revoke_button:
		var disable_revoke := not has_tag_selection
		if not disable_revoke and _library != null:
			disable_revoke = _get_tiles_using_tag(_selected_tag).is_empty()
		tags_revoke_button.disabled = disable_revoke

	var has_socket_selection := not _selected_socket_id.is_empty()
	var is_reserved_socket := _selected_socket_id in ["none", "any"]
	if sockets_rename_button:
		sockets_rename_button.disabled = (not has_socket_selection) or is_reserved_socket
	if sockets_delete_button:
		sockets_delete_button.disabled = (not has_socket_selection) or is_reserved_socket
	if sockets_assign_button:
		var disable_assign := not has_socket_selection or _library == null
		if not disable_assign:
			disable_assign = true
			var clean_socket = _selected_socket_id.strip_edges()
			for tile in _library.tiles:
				for socket in tile.sockets:
					var current_id = socket.socket_id
					if current_id != clean_socket:
						disable_assign = false
						break
				if not disable_assign:
					break
		sockets_assign_button.disabled = disable_assign
	if sockets_revoke_button:
		var disable_socket_revoke := (not has_socket_selection) or _library == null
		if not disable_socket_revoke:
			disable_socket_revoke = _get_socket_usage(_selected_socket_id).is_empty()
		sockets_revoke_button.disabled = disable_socket_revoke

func _on_tag_selected() -> void:
	var item = tags_tree.get_selected()
	_selected_tag = "" if item == null else String(item.get_metadata(0))
	_update_tag_usage(_selected_tag)
	_update_buttons_state()

func _on_tag_activated() -> void:
	_on_rename_tag_pressed()

func _on_tag_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			_on_delete_tag_pressed()
		elif event.keycode == KEY_F2:
			_on_rename_tag_pressed()

func _on_add_tag_pressed() -> void:
	var dialog = _create_line_edit_dialog("Add Tag", "Enter tag name:")
	dialog.confirmed.connect(func():
		var name = _extract_line_edit_text(dialog)
		if _try_add_tag(name):
			_selected_tag = name.strip_edges()
			_refresh_tags_list()
			_update_tag_usage(_selected_tag)
			dialog.queue_free()
		else:
			_show_warning("Tag name must be unique and non-empty.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _try_add_tag(name: String) -> bool:
	var clean = name.strip_edges()
	if clean == "" or clean in _tags_pending:
		return false
	_tags_pending.append(clean)
	_tags_pending.sort()
	_tags_added[clean] = true
	_tag_reverse_map[clean] = clean
	return true

func _on_rename_tag_pressed() -> void:
	if _selected_tag.is_empty():
		return
	var dialog = _create_line_edit_dialog("Rename Tag", "Enter new tag name:", _selected_tag)
	dialog.confirmed.connect(func():
		var new_name = _extract_line_edit_text(dialog)
		if _try_rename_tag(_selected_tag, new_name):
			_selected_tag = new_name.strip_edges()
			_refresh_tags_list()
			_update_tag_usage(_selected_tag)
			dialog.queue_free()
		else:
			_show_warning("Tag name must be unique and non-empty.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _try_rename_tag(old_name: String, new_name: String) -> bool:
	var clean_old = old_name.strip_edges()
	var clean_new = new_name.strip_edges()
	if clean_old == "" or clean_new == "" or clean_old == clean_new:
		return clean_old == clean_new
	if clean_new in _tags_pending:
		return false
	var index = _tags_pending.find(clean_old)
	if index == -1:
		return false
	_tags_pending[index] = clean_new
	_tags_pending.sort()
	var original = _tag_reverse_map.get(clean_old, clean_old)
	_tag_reverse_map.erase(clean_old)
	_tag_reverse_map[clean_new] = original
	if not _tags_added.has(clean_old):
		_tag_forward_map[original] = clean_new
	else:
		_tags_added.erase(clean_old)
		_tags_added[clean_new] = true
	return true

func _on_delete_tag_pressed() -> void:
	if _selected_tag.is_empty():
		return
	var usage = _get_tiles_using_tag(_selected_tag)
	var message = "Delete tag '%s'?" % _selected_tag
	if usage.size() > 0:
		message += "\n\nThis will remove the tag from %d tile(s)." % usage.size()
	var confirm = _create_confirmation_dialog("Delete Tag", message)
	confirm.confirmed.connect(func():
		if _try_delete_tag(_selected_tag):
			_selected_tag = ""
			_refresh_tags_list()
			_update_tag_usage()
			confirm.queue_free()
		else:
			_show_warning("Failed to delete tag.")
	)
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func _on_apply_tag_to_tiles_pressed() -> void:
	if _library == null or _selected_tag.is_empty():
		return
	var clean = _selected_tag.strip_edges()
	if clean == "":
		return
	var candidates: Array[Tile] = []
	for tile in _library.tiles:
		if not tile.has_tag(clean):
			candidates.append(tile)
	if candidates.is_empty():
		_show_warning("All tiles already have the '%s' tag." % clean)
		return
	var dialog = _create_selection_dialog("Apply Tag", "Select tiles to add the '%s' tag:" % clean, candidates, func(tile: Tile): return tile.name)
	dialog.confirmed.connect(func():
		var selected_tiles = _get_dialog_selected_entries(dialog)
		if not selected_tiles.is_empty():
			_apply_tag_to_tiles(clean, selected_tiles)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.5)

func _on_revoke_tag_from_tiles_pressed() -> void:
	if _library == null or _selected_tag.is_empty():
		return
	var clean = _selected_tag.strip_edges()
	var candidates = _get_tiles_using_tag(clean)
	if candidates.is_empty():
		_show_warning("No tiles currently use the '%s' tag." % clean)
		return
	var dialog = _create_selection_dialog("Revoke Tag", "Select tiles to remove the '%s' tag:" % clean, candidates, func(tile: Tile): return tile.name)
	dialog.confirmed.connect(func():
		var selected_tiles = _get_dialog_selected_entries(dialog)
		if not selected_tiles.is_empty():
			_remove_tag_from_tiles(clean, selected_tiles)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.5)

func _try_delete_tag(name: String) -> bool:
	var clean = name.strip_edges()
	if clean == "":
		return false
	var index = _tags_pending.find(clean)
	if index == -1:
		return false
	_tags_pending.remove_at(index)
	var original = _tag_reverse_map.get(clean, clean)
	_tag_reverse_map.erase(clean)
	if _tags_added.has(clean):
		_tags_added.erase(clean)
	else:
		_tags_removed_originals[original] = true
		_tag_forward_map.erase(original)
	return true

func _on_socket_selected() -> void:
	var item = sockets_tree.get_selected()
	_selected_socket_id = "" if item == null else String(item.get_metadata(0))
	_update_socket_usage(_selected_socket_id)
	_update_buttons_state()

func _on_socket_activated() -> void:
	_on_rename_socket_pressed()

func _on_socket_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			_on_delete_socket_pressed()
		elif event.keycode == KEY_F2:
			_on_rename_socket_pressed()

func _on_add_socket_pressed() -> void:
	var dialog = _create_line_edit_dialog("Add Socket Type", "Enter socket type ID:")
	dialog.confirmed.connect(func():
		var id = _extract_line_edit_text(dialog)
		if _try_add_socket_type(id):
			_selected_socket_id = id.strip_edges()
			_refresh_sockets_list()
			_update_socket_usage(_selected_socket_id)
			dialog.queue_free()
		else:
			_show_warning("Socket type ID must be unique and non-empty.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _try_add_socket_type(id: String) -> bool:
	var clean = id.strip_edges()
	if clean == "" or _socket_records.has(clean):
		return false
	var record := SocketRecord.new()
	record.original_id = clean
	record.current_id = clean
	_socket_records[clean] = record
	_socket_reverse_map[clean] = clean
	_sockets_added[clean] = true
	return true

func _on_rename_socket_pressed() -> void:
	if _selected_socket_id.is_empty() or _selected_socket_id in ["none", "any"]:
		return
	var dialog = _create_line_edit_dialog("Rename Socket Type", "Enter new socket type ID:", _selected_socket_id)
	dialog.confirmed.connect(func():
		var new_id = _extract_line_edit_text(dialog)
		if _try_rename_socket_type(_selected_socket_id, new_id):
			_selected_socket_id = new_id.strip_edges()
			_refresh_sockets_list()
			_update_socket_usage(_selected_socket_id)
			dialog.queue_free()
		else:
			_show_warning("Socket type ID must be unique, non-empty, and not reserved.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _try_rename_socket_type(old_id: String, new_id: String) -> bool:
	var clean_old = old_id.strip_edges()
	var clean_new = new_id.strip_edges()
	if clean_old == "" or clean_new == "" or clean_old == clean_new:
		return clean_old == clean_new
	if clean_new in ["none", "any"]:
		return false
	if _socket_records.has(clean_new):
		return false
	var record: SocketRecord = _socket_records.get(clean_old)
	if record == null:
		return false
	_socket_records.erase(clean_old)
	record.current_id = clean_new
	_socket_records[clean_new] = record
	var original = _socket_reverse_map.get(clean_old, clean_old)
	_socket_reverse_map.erase(clean_old)
	_socket_reverse_map[clean_new] = original
	if _sockets_added.has(clean_old):
		_sockets_added.erase(clean_old)
		_sockets_added[clean_new] = true
	else:
		_socket_forward_map[original] = clean_new
	return true

func _on_delete_socket_pressed() -> void:
	if _selected_socket_id.is_empty():
		return
	if _selected_socket_id in ["none", "any"]:
		_show_warning("Cannot delete default socket types 'none' or 'any'.")
		return
	var usage = _get_socket_usage(_selected_socket_id)
	var message = "Delete socket type '%s'?" % _selected_socket_id
	if usage.size() > 0:
		message += "\n\nThis will reassign %d socket(s) to 'none'." % usage.size()
	var confirm = _create_confirmation_dialog("Delete Socket Type", message)
	confirm.confirmed.connect(func():
		if _try_delete_socket_type(_selected_socket_id):
			_selected_socket_id = ""
			_refresh_sockets_list()
			_update_socket_usage()
			confirm.queue_free()
		else:
			_show_warning("Failed to delete socket type.")
	)
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func _on_assign_socket_to_sockets_pressed() -> void:
	if _library == null or _selected_socket_id.is_empty():
		return
	var clean = _selected_socket_id.strip_edges()
	if clean == "":
		return
	var candidates = _get_sockets_not_matching_type(clean)
	if candidates.is_empty():
		_show_warning("All sockets already use the '%s' type or are unavailable." % clean)
		return
	var dialog = _create_selection_dialog("Assign Socket Type", "Select sockets to assign the '%s' type:" % clean, candidates, func(entry: SocketUsage):
		return "%s  —  %s (current: %s)" % [entry.tile.name, _direction_to_string(entry.direction), entry.socket.socket_id if not entry.socket.socket_id.is_empty() else "none"])
	dialog.confirmed.connect(func():
		var selected_entries = _get_dialog_selected_entries(dialog)
		if not selected_entries.is_empty():
			_assign_socket_type_to_entries(clean, selected_entries)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.6)

func _on_revoke_socket_from_sockets_pressed() -> void:
	if _library == null or _selected_socket_id.is_empty():
		return
	var clean = _selected_socket_id.strip_edges()
	if clean == "":
		return
	var candidates = _get_socket_usage(clean)
	if candidates.is_empty():
		_show_warning("No sockets currently use the '%s' type." % clean)
		return
	var dialog = _create_selection_dialog("Revoke Socket Type", "Select sockets to revert from the '%s' type:" % clean, candidates, func(entry: SocketUsage):
		return "%s  —  %s" % [entry.tile.name, _direction_to_string(entry.direction)])
	dialog.confirmed.connect(func():
		var selected_entries = _get_dialog_selected_entries(dialog)
		if not selected_entries.is_empty():
			_revoke_socket_type_from_entries(clean, selected_entries)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.6)

func _try_delete_socket_type(id: String) -> bool:
	var clean = id.strip_edges()
	if clean == "" or not _socket_records.has(clean):
		return false
	_socket_records.erase(clean)
	var original = _socket_reverse_map.get(clean, clean)
	_socket_reverse_map.erase(clean)
	if _sockets_added.has(clean):
		_sockets_added.erase(clean)
	else:
		_sockets_removed_originals[original] = true
		_socket_forward_map.erase(original)
	return true

func _update_tag_usage(tag: String = "") -> void:
	if tags_usage_tree == null:
		return
	tags_usage_tree.clear()
	var title = "Tiles using this tag"
	var summary = "Select a tag to view usage"
	if tag != null and tag.strip_edges() != "":
		var tiles = _get_tiles_using_tag(tag)
		title = "Tiles using '%s'" % tag
		summary = "%d tile(s)" % tiles.size()
		if tiles.is_empty():
			summary += "\nCurrently unused."
		else:
			var root = tags_usage_tree.create_item()
			for tile in tiles:
				var item = tags_usage_tree.create_item(root)
				item.set_text(0, tile.name)
				item.set_text(1, "")
				item.set_selectable(0, false)
				item.set_selectable(1, false)
	tags_usage_title.text = title
	tags_usage_summary.text = summary

func _update_socket_usage(socket_id: String = "") -> void:
	if sockets_usage_tree == null:
		return
	sockets_usage_tree.clear()
	var title = "Tile sockets using this type"
	var summary = "Select a socket type to view usage"
	if socket_id != null and socket_id.strip_edges() != "":
		var usage = _get_socket_usage(socket_id)
		title = "Sockets using '%s'" % socket_id
		summary = "%d socket(s) across %d tile(s)" % [usage.size(), _count_unique_tiles(usage)]
		if usage.is_empty():
			summary += "\nCurrently unused."
		else:
			var root = sockets_usage_tree.create_item()
			for entry in usage:
				var item = sockets_usage_tree.create_item(root)
				item.set_text(0, entry.tile.name)
				item.set_text(1, _direction_to_string(entry.direction))
				item.set_selectable(0, false)
				item.set_selectable(1, false)
	sockets_usage_title.text = title
	sockets_usage_summary.text = summary

class SocketUsage:
	var tile: Tile
	var socket: Socket
	var direction: Vector3i

func _get_tiles_using_tag(tag: String) -> Array[Tile]:
	var results: Array[Tile] = []
	if _library == null:
		return results
	var actual_names = _map_tag_to_library_names(tag)
	if actual_names.is_empty():
		return results
	for tile in _library.tiles:
		for actual in actual_names:
			if tile.has_tag(actual) and tile not in results:
				results.append(tile)
	return results

func _map_tag_to_library_names(tag: String) -> Array[String]:
	var names: Array[String] = []
	var clean = tag.strip_edges()
	if clean == "":
		return names
	if _tags_added.has(clean):
		return names
	var original = _tag_reverse_map.get(clean, clean)
	names.append(original)
	return names

func _get_socket_usage(socket_id: String) -> Array[SocketUsage]:
	var results: Array[SocketUsage] = []
	if _library == null:
		return results
	var actual_ids = _map_socket_to_library_ids(socket_id)
	if actual_ids.is_empty():
		return results
	for tile in _library.tiles:
		for socket in tile.sockets:
			var id = socket.socket_id
			if id in actual_ids:
				var usage = SocketUsage.new()
				usage.tile = tile
				usage.socket = socket
				usage.direction = socket.direction
				results.append(usage)
	return results

func _get_sockets_not_matching_type(socket_id: String) -> Array[SocketUsage]:
	var results: Array[SocketUsage] = []
	if _library == null:
		return results
	var clean = socket_id.strip_edges()
	for tile in _library.tiles:
		for socket in tile.sockets:
			var current_id = socket.socket_id
			if current_id != clean:
				var entry = SocketUsage.new()
				entry.tile = tile
				entry.socket = socket
				entry.direction = socket.direction
				results.append(entry)
	return results

func _map_socket_to_library_ids(socket_id: String) -> Array[String]:
	var ids: Array[String] = []
	var clean = socket_id.strip_edges()
	if clean == "":
		return ids
	if _sockets_added.has(clean):
		return ids
	var original = _socket_reverse_map.get(clean, clean)
	ids.append(original)
	return ids

func _count_unique_tiles(usages: Array[SocketUsage]) -> int:
	var seen: Dictionary = {}
	for usage in usages:
		seen[usage.tile] = true
	return seen.size()

func _direction_to_string(direction: Vector3i) -> String:
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]

func _extract_line_edit_text(dialog: AcceptDialog) -> String:
	if dialog == null:
		return ""
	var line_edit: LineEdit = dialog.get_meta("line_edit") if dialog.has_meta("line_edit") else null
	return "" if line_edit == null else line_edit.text

func _create_selection_dialog(title: String, message: String, entries: Array, label_func: Callable, select_all := true) -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	var list_container = VBoxContainer.new()
	list_container.custom_minimum_size = Vector2(420, 260)
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list = ItemList.new()
	list.select_mode = ItemList.SELECT_MULTI
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(entries.size()):
		var entry = entries[i]
		var label_text = label_func.call(entry) if label_func != null else String(entry)
		list.add_item(label_text)
		if select_all:
			list.select(i, true)
	list_container.add_child(list)
	if dialog.has_method("get_vbox"):
		dialog.get_vbox().add_child(list_container)
	else:
		dialog.add_child(list_container)
	dialog.set_meta("selection_entries", entries.duplicate())
	dialog.set_meta("selection_list", list)
	add_child(dialog)
	dialog.popup_window = true
	list.call_deferred("grab_focus")
	return dialog

func _get_dialog_selected_entries(dialog: AcceptDialog) -> Array:
	var result: Array = []
	if dialog == null:
		return result
	var list: ItemList = dialog.get_meta("selection_list") if dialog.has_meta("selection_list") else null
	var entries: Array = dialog.get_meta("selection_entries") if dialog.has_meta("selection_entries") else []
	if list == null or entries.is_empty():
		return result
	for index in list.get_selected_items():
		if index >= 0 and index < entries.size():
			result.append(entries[index])
	return result

func _apply_tag_to_tiles(tag: String, tiles: Array) -> void:
	var clean = tag.strip_edges()
	if clean == "" or _library == null:
		return
	_library.add_available_tag(clean)
	var modified := false
	for entry in tiles:
		if entry is Tile:
			var tile: Tile = entry
			if tile.add_tag(clean):
				_library.notify_tile_modified(tile, "tags")
				modified = true
	if modified:
		_update_tag_usage(clean)
		_update_buttons_state()

func _remove_tag_from_tiles(tag: String, tiles: Array) -> void:
	var clean = tag.strip_edges()
	if clean == "" or _library == null:
		return
	var modified := false
	for entry in tiles:
		if entry is Tile:
			var tile: Tile = entry
			if tile.has_tag(clean):
				tile.remove_tag(clean)
				_library.notify_tile_modified(tile, "tags")
				modified = true
	if modified:
		_update_tag_usage(clean)
		_update_buttons_state()

func _assign_socket_type_to_entries(socket_id: String, entries: Array) -> void:
	if _library == null:
		return
	var modified_tiles: Dictionary = {}
	for entry in entries:
		if entry is SocketUsage:
			var usage: SocketUsage = entry
			usage.socket.socket_id = socket_id
			modified_tiles[usage.tile] = true
	for tile in modified_tiles.keys():
		_library.notify_tile_modified(tile, "sockets")
	_update_socket_usage(socket_id)
	_update_buttons_state()

func _revoke_socket_type_from_entries(socket_id: String, entries: Array) -> void:
	if _library == null:
		return
	var modified_tiles: Dictionary = {}
	for entry in entries:
		if entry is SocketUsage:
			var usage: SocketUsage = entry
			usage.socket.socket_id = "none"
			modified_tiles[usage.tile] = true
	for tile in modified_tiles.keys():
		_library.notify_tile_modified(tile, "sockets")
	_update_socket_usage(socket_id)
	_update_buttons_state()

func _create_line_edit_dialog(title: String, message: String, initial: String = "") -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	var container = HBoxContainer.new()
	container.name = "InputRow"
	var line_edit = LineEdit.new()
	line_edit.name = "InputLine"
	line_edit.text = initial
	line_edit.custom_minimum_size = Vector2(260, 0)
	container.add_child(line_edit)
	if dialog.has_method("get_vbox"):
		dialog.get_vbox().add_child(container)
	else:
		dialog.add_child(container)
	dialog.set_meta("line_edit", line_edit)
	add_child(dialog)
	dialog.popup_window = true
	line_edit.call_deferred("grab_focus")
	line_edit.call_deferred("select_all")
	return dialog

func _create_confirmation_dialog(title: String, message: String) -> ConfirmationDialog:
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_window = true
	return dialog

func _show_warning(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _apply_tag_changes() -> void:
	if _library == null:
		return
	for tag_name in _tags_added.keys():
		_library.add_available_tag(tag_name)
	for original in _tags_removed_originals.keys():
		_library.remove_available_tag(original, true)
	for original in _tag_forward_map.keys():
		var current = _tag_forward_map[original]
		if original != current:
			_library.rename_available_tag(original, current)

func _apply_socket_changes() -> void:
	if _library == null:
		return
	for original in _sockets_removed_originals.keys():
		_library.delete_socket_type(original, "none")
	for original in _socket_forward_map.keys():
		var current = _socket_forward_map[original]
		if original != current and not _sockets_removed_originals.has(original):
			_library.rename_socket_type(original, current)
	for new_id in _sockets_added.keys():
		if not _library.get_socket_type_by_id(new_id):
			_library.register_socket_type(new_id)

func _on_dialog_confirmed() -> void:
	_apply_tag_changes()
	_apply_socket_changes()


