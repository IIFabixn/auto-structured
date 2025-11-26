@tool
class_name TemplateEditorDialog
extends ConfirmationDialog

const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")
const DIRECTION_OPTIONS := [
	{"label": "Up", "value": Vector3i(0, 1, 0)},
	{"label": "Down", "value": Vector3i(0, -1, 0)},
	{"label": "Right", "value": Vector3i(1, 0, 0)},
	{"label": "Left", "value": Vector3i(-1, 0, 0)},
	{"label": "Forward", "value": Vector3i(0, 0, 1)},
	{"label": "Back", "value": Vector3i(0, 0, -1)}
]

const COLUMN_ENABLED := 0
const COLUMN_DIRECTION := 1
const COLUMN_SOCKET_ID := 2
const COLUMN_COMPATIBLE := 3

@onready var name_edit: LineEdit = %TemplateNameLine
@onready var description_edit: TextEdit = %TemplateDescriptionText
@onready var entries_tree: Tree = %TemplateEntriesTree

var _entries: Array = []
var _existing_names: Array[String] = []
var _on_save: Callable = Callable()
var _editing_template: SocketTemplate = null
var _last_tree_item: TreeItem = null
var _last_tree_column: int = COLUMN_SOCKET_ID

func _ready() -> void:
	set_process_unhandled_key_input(true)
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	if entries_tree:
		entries_tree.focus_mode = Control.FOCUS_ALL
		entries_tree.column_titles_visible = true
		entries_tree.set_column_title(COLUMN_ENABLED, "Use")
		entries_tree.set_column_title(COLUMN_DIRECTION, "Direction")
		entries_tree.set_column_title(COLUMN_SOCKET_ID, "Socket ID")
		entries_tree.set_column_title(COLUMN_COMPATIBLE, "Compatible IDs")
		entries_tree.set_column_expand(COLUMN_ENABLED, false)
		entries_tree.set_column_custom_minimum_width(COLUMN_ENABLED, 50.0)
		entries_tree.set_column_expand(COLUMN_DIRECTION, false)
		entries_tree.set_column_custom_minimum_width(COLUMN_DIRECTION, 110.0)
		entries_tree.set_column_custom_minimum_width(COLUMN_SOCKET_ID, 140.0)
		entries_tree.item_edited.connect(_on_entries_tree_item_edited)
		entries_tree.cell_selected.connect(_on_entries_tree_cell_selected)
	if description_edit and not description_edit.gui_input.is_connected(_on_description_gui_input):
		description_edit.gui_input.connect(_on_description_gui_input)

func open_editor(title: String, template: SocketTemplate, existing_names: Array[String], on_save: Callable) -> void:
	self.title = title
	_editing_template = template
	_entries.clear()
	_existing_names.clear()
	for name in existing_names:
		var normalized = _normalize_name(name)
		if normalized != "":
			_existing_names.append(normalized)
	_on_save = on_save
	if name_edit:
		name_edit.text = template.template_name if template else ""
	if description_edit:
		description_edit.text = template.description if template else ""
	_initialize_entries(template)
	_refresh_entries_tree()
	popup_centered_ratio(0.6)
	if name_edit:
		name_edit.call_deferred("grab_focus")
		name_edit.call_deferred("select_all")

func _initialize_entries(template: SocketTemplate) -> void:
	_entries.clear()
	var source_entries: Array = template.entries if template else []
	for option in DIRECTION_OPTIONS:
		var direction: Vector3i = option["value"]
		var existing: Variant = _find_entry_by_direction(source_entries, direction)
		var entry: Dictionary
		if existing == null:
			entry = SocketTemplate.create_entry(direction, "", [], 0)
			entry["enabled"] = false
		else:
			entry = SocketTemplate.normalize_entry(existing)
			entry["enabled"] = true
		_entries.append(entry)

func _refresh_entries_tree() -> void:
	if entries_tree == null:
		return
	entries_tree.clear()
	_last_tree_item = null
	_last_tree_column = COLUMN_SOCKET_ID
	var root = entries_tree.create_item()
	for i in range(_entries.size()):
		var normalized = _normalize_entry(_entries[i])
		var item = entries_tree.create_item(root)
		item.set_cell_mode(COLUMN_ENABLED, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_ENABLED, true)
		item.set_checked(COLUMN_ENABLED, normalized.get("enabled", false))
		item.set_metadata(COLUMN_ENABLED, i)
		var direction = normalized.get("direction", Vector3i.UP)
		item.set_text(COLUMN_DIRECTION, _direction_to_label(direction))
		item.set_metadata(COLUMN_DIRECTION, i)
		var socket_id = normalized.get("socket_id", "")
		item.set_text(COLUMN_SOCKET_ID, socket_id)
		item.set_metadata(COLUMN_SOCKET_ID, i)
		item.set_editable(COLUMN_SOCKET_ID, true)
		var compat: Array = normalized.get("compatible", [])
		item.set_text(COLUMN_COMPATIBLE, ", ".join(compat))
		item.set_metadata(COLUMN_COMPATIBLE, i)
		item.set_editable(COLUMN_COMPATIBLE, true)

func _on_dialog_confirmed() -> void:
	var data = _collect_template_data()
	if data.is_empty():
		return
	if _on_save.is_valid():
		_on_save.call(data)
	hide()

func _collect_template_data() -> Dictionary:
	var name = name_edit.text.strip_edges() if name_edit else ""
	if name.is_empty():
		_show_warning("Template name cannot be empty.")
		return {}
	var normalized_name = _normalize_name(name)
	if normalized_name != "" and _existing_names.has(normalized_name):
		_show_warning("Template name must be unique.")
		return {}
	var enabled_entries = _get_enabled_entries()
	if enabled_entries.is_empty():
		_show_warning("Enable at least one socket direction.")
		return {}
	var description = description_edit.text.strip_edges() if description_edit else ""
	var data_entries: Array = []
	for entry_data in enabled_entries:
		var normalized_entry = SocketTemplate.normalize_entry(entry_data)
		var socket_id: String = normalized_entry.get("socket_id", "").strip_edges()
		if socket_id == "":
			_show_warning("Socket ID cannot be empty for enabled directions.")
			return {}
		data_entries.append(SocketTemplate.create_entry(
			normalized_entry.get("direction", Vector3i.UP),
			socket_id,
			normalized_entry.get("compatible", []),
			normalized_entry.get("minimum_rotation_degrees", 0)
		))
	return {
		"name": name,
		"description": description,
		"entries": data_entries
	}

func _on_entries_tree_item_edited() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_edited()
	if item == null:
		return
	var column = entries_tree.get_edited_column()
	var index = _get_entry_index(item)
	if index < 0 or index >= _entries.size():
		return
	var entry = _normalize_entry(_entries[index])
	var text_entered := false
	match column:
		COLUMN_ENABLED:
			entry["enabled"] = item.is_checked(column)
		COLUMN_SOCKET_ID:
			var socket_text := item.get_text(column).strip_edges()
			entry["socket_id"] = socket_text
			text_entered = socket_text != ""
		COLUMN_COMPATIBLE:
			var compat_text = item.get_text(column)
			var compat: Array[String] = []
			for token in compat_text.split(",", false):
				var clean = String(token).strip_edges()
				if clean != "":
					compat.append(clean)
			entry["compatible"] = compat
			item.set_text(column, ", ".join(compat))
			text_entered = compat.size() > 0
	if text_entered and not entry.get("enabled", false):
		entry["enabled"] = true
		item.set_checked(COLUMN_ENABLED, true)
	_entries[index] = entry

func _on_entries_tree_cell_selected() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_selected()
	_last_tree_item = item
	if item == null:
		_last_tree_column = COLUMN_SOCKET_ID
		return
	var column = entries_tree.get_selected_column()
	if column == -1:
		column = COLUMN_SOCKET_ID
	_last_tree_column = column

func _find_entry_by_direction(entries: Array, direction: Vector3i) -> Variant:
	for entry_data in entries:
		var normalized = SocketTemplate.normalize_entry(entry_data)
		if normalized.get("direction", Vector3i.ZERO) == direction:
			return normalized
	return null

func _get_enabled_entries() -> Array:
	var enabled: Array = []
	for entry in _entries:
		var normalized = _normalize_entry(entry)
		if normalized.get("enabled", false):
			enabled.append(normalized)
	return enabled

func _get_entry_index(item: TreeItem) -> int:
	if item == null:
		return -1
	var index = item.get_metadata(COLUMN_DIRECTION)
	return int(index) if typeof(index) in [TYPE_INT, TYPE_FLOAT] else -1

func _direction_to_label(direction: Vector3i) -> String:
	for option in DIRECTION_OPTIONS:
		if option["value"] == direction:
			return option["label"]
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]

func _normalize_entry(entry: Dictionary) -> Dictionary:
	var normalized = SocketTemplate.normalize_entry(entry)
	normalized["enabled"] = entry.get("enabled", false)
	return normalized

func _normalize_name(name: String) -> String:
	return String(name).strip_edges().to_lower()

func _focus_first_tree_cell(forward: bool) -> bool:
	var cells = _get_tree_focus_cells()
	if cells.is_empty():
		return false
	var index = 0 if forward else cells.size() - 1
	return _focus_tree_cell(cells[index])

func _focus_next_tree_cell(forward: bool) -> bool:
	var cells = _get_tree_focus_cells()
	if cells.is_empty():
		return false
	var current_item: TreeItem = entries_tree.get_edited()
	var current_column: int = entries_tree.get_edited_column()
	if current_item == null:
		current_item = _last_tree_item
		current_column = _last_tree_column
	var current_index := -1
	for i in range(cells.size()):
		var cell = cells[i]
		if cell.get("item") == current_item and int(cell.get("column", -1)) == current_column:
			current_index = i
			break
	var next_index = current_index + (1 if forward else -1)
	if current_index == -1:
		next_index = 0 if forward else cells.size() - 1
	if next_index < 0 or next_index >= cells.size():
		return false
	return _focus_tree_cell(cells[next_index])

func _focus_tree_cell(cell: Dictionary) -> bool:
	if entries_tree == null:
		return false
	var item: TreeItem = cell.get("item")
	if item == null:
		return false
	var column: int = int(cell.get("column", COLUMN_SOCKET_ID))
	entries_tree.set_selected(item, column)
	item.select(column)
	entries_tree.scroll_to_item(item)
	entries_tree.edit_item(item, column)
	_last_tree_item = item
	_last_tree_column = column
	return true

func _get_tree_focus_cells() -> Array:
	var cells: Array = []
	if entries_tree == null:
		return cells
	var root = entries_tree.get_root()
	if root == null:
		return cells
	var item = root.get_first_child()
	while item:
		cells.append({"item": item, "column": COLUMN_SOCKET_ID})
		cells.append({"item": item, "column": COLUMN_COMPATIBLE})
		item = item.get_next()
	return cells

func _on_description_gui_input(event: InputEvent) -> void:
	if description_edit == null:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_TAB:
		return
	if key_event.shift_pressed:
		if name_edit:
			name_edit.grab_focus()
	else:
		var focused = _focus_first_tree_cell(true)
		if not focused and entries_tree:
			entries_tree.grab_focus()
	description_edit.accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if _handle_tree_tab_navigation(event):
		event.accepted = true

func _handle_tree_tab_navigation(event: InputEvent) -> bool:
	if entries_tree == null:
		return false
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_TAB:
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	if focus_owner != entries_tree and not entries_tree.is_ancestor_of(focus_owner):
		return false
	var forward = not key_event.shift_pressed
	if _focus_next_tree_cell(forward):
		return true
	if forward:
		var ok_button: BaseButton = get_ok_button()
		if ok_button:
			ok_button.grab_focus()
			return true
	else:
		if description_edit:
			description_edit.grab_focus()
			return true
	return false

func _show_warning(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
