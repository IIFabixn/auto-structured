@tool
class_name TemplateEditorDialog
extends ConfirmationDialog

const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")
const DIRECTION_OPTIONS := [
	{"label": "+Y (0, 1, 0)", "value": Vector3i(0, 1, 0)},
	{"label": "-Y (0, -1, 0)", "value": Vector3i(0, -1, 0)},
	{"label": "+X (1, 0, 0)", "value": Vector3i(1, 0, 0)},
	{"label": "-X (-1, 0, 0)", "value": Vector3i(-1, 0, 0)},
	{"label": "+Z (0, 0, 1)", "value": Vector3i(0, 0, 1)},
	{"label": "-Z (0, 0, -1)", "value": Vector3i(0, 0, -1)}
]

const COLUMN_DIRECTION := 0
const COLUMN_SOCKET_ID := 1
const COLUMN_COMPATIBLE := 2
const COLUMN_ROTATION := 3

@onready var name_edit: LineEdit = %TemplateNameLine
@onready var description_edit: TextEdit = %TemplateDescriptionText
@onready var entries_tree: Tree = %TemplateEntriesTree
@onready var add_entry_button: Button = %TemplateAddEntryButton
@onready var edit_entry_button: Button = %TemplateEditEntryButton
@onready var delete_entry_button: Button = %TemplateDeleteEntryButton

var _entries: Array = []
var _existing_names: Array[String] = []
var _on_save: Callable = Callable()
var _editing_template: SocketTemplate = null
var _direction_popup: PopupMenu = null
var _direction_popup_target_index: int = -1

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	if entries_tree:
		entries_tree.column_titles_visible = true
		entries_tree.set_column_title(COLUMN_DIRECTION, "Direction")
		entries_tree.set_column_title(COLUMN_SOCKET_ID, "Socket ID")
		entries_tree.set_column_title(COLUMN_COMPATIBLE, "Compatible IDs")
		entries_tree.set_column_title(COLUMN_ROTATION, "Min Rotation")
		entries_tree.set_column_expand(COLUMN_DIRECTION, false)
		entries_tree.set_column_custom_minimum_width(COLUMN_DIRECTION, 130.0)
		entries_tree.set_column_custom_minimum_width(COLUMN_SOCKET_ID, 140.0)
		entries_tree.item_selected.connect(func():
			_update_entry_buttons()
		)
		entries_tree.item_activated.connect(func():
			_on_edit_entry_pressed()
		)
		entries_tree.item_edited.connect(_on_entries_tree_item_edited)
		entries_tree.gui_input.connect(_on_entries_tree_gui_input)
	if add_entry_button:
		add_entry_button.pressed.connect(_on_add_entry_pressed)
	if edit_entry_button:
		edit_entry_button.pressed.connect(_on_edit_entry_pressed)
	if delete_entry_button:
		delete_entry_button.pressed.connect(_on_delete_entry_pressed)
	_create_direction_popup()
	_update_entry_buttons()

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
	if template != null:
		for entry_data in template.entries:
			_entries.append(SocketTemplate.normalize_entry(entry_data))
	_refresh_entries_tree()
	popup_centered_ratio(0.6)
	if name_edit:
		name_edit.call_deferred("grab_focus")
		name_edit.call_deferred("select_all")

func _on_dialog_confirmed() -> void:
	var data = _collect_template_data()
	if data.is_empty():
		return
	if _on_save.is_valid():
		_on_save.call(data)
	hide()

func _on_add_entry_pressed() -> void:
	var new_entry = SocketTemplate.create_entry(Vector3i.UP, "none", [], 0)
	_entries.append(SocketTemplate.normalize_entry(new_entry))
	_refresh_entries_tree()
	_select_tree_item(_entries.size() - 1, COLUMN_SOCKET_ID, true)

func _on_edit_entry_pressed() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_selected()
	if item == null:
		return
	var column = _get_selected_column()
	if column == COLUMN_DIRECTION:
		_show_direction_popup(item)
	else:
		entries_tree.edit_item(item, column if column >= 0 else COLUMN_SOCKET_ID)

func _on_delete_entry_pressed() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_selected()
	if item == null:
		return
	var index = _get_entry_index(item)
	if index < 0 or index >= _entries.size():
		return
	_entries.remove_at(index)
	_refresh_entries_tree()
	_select_tree_item(min(index, _entries.size() - 1))

func _refresh_entries_tree() -> void:
	if entries_tree == null:
		return
	entries_tree.clear()
	var root = entries_tree.create_item()
	for i in range(_entries.size()):
		var normalized = SocketTemplate.normalize_entry(_entries[i])
		var item = entries_tree.create_item(root)
		var direction = normalized.get("direction", Vector3i.UP)
		item.set_text(COLUMN_DIRECTION, _direction_to_label(direction))
		item.set_metadata(COLUMN_DIRECTION, i)
		item.set_editable(COLUMN_DIRECTION, false)
		var socket_id = normalized.get("socket_id", "none")
		item.set_text(COLUMN_SOCKET_ID, socket_id)
		item.set_metadata(COLUMN_SOCKET_ID, i)
		item.set_editable(COLUMN_SOCKET_ID, true)
		var compat: Array = normalized.get("compatible", [])
		var compat_text = ", ".join(compat)
		item.set_text(COLUMN_COMPATIBLE, compat_text)
		item.set_metadata(COLUMN_COMPATIBLE, i)
		item.set_editable(COLUMN_COMPATIBLE, true)
		item.set_cell_mode(COLUMN_ROTATION, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(COLUMN_ROTATION, 0, 360, 15, true)
		item.set_range(COLUMN_ROTATION, normalized.get("minimum_rotation_degrees", 0))
		item.set_metadata(COLUMN_ROTATION, i)
		item.set_editable(COLUMN_ROTATION, true)
	_update_entry_buttons()

func _update_entry_buttons() -> void:
	var has_selection := entries_tree != null and entries_tree.get_selected() != null
	if edit_entry_button:
		edit_entry_button.disabled = not has_selection
	if delete_entry_button:
		delete_entry_button.disabled = not has_selection

func _create_direction_popup() -> void:
	_direction_popup = PopupMenu.new()
	add_child(_direction_popup)
	for option in DIRECTION_OPTIONS:
		_direction_popup.add_radio_check_item(option["label"])
		var idx = _direction_popup.get_item_count() - 1
		_direction_popup.set_item_metadata(idx, option["value"])
	_direction_popup.id_pressed.connect(_on_direction_popup_id_pressed)

func _collect_template_data() -> Dictionary:
	var name = name_edit.text.strip_edges() if name_edit else ""
	if name.is_empty():
		_show_warning("Template name cannot be empty.")
		return {}
	var normalized = _normalize_name(name)
	if normalized != "" and _existing_names.has(normalized):
		_show_warning("Template name must be unique.")
		return {}
	if _entries.is_empty():
		_show_warning("Add at least one socket entry.")
		return {}
	var description = description_edit.text.strip_edges() if description_edit else ""
	var data_entries: Array = []
	for entry_data in _entries:
		var normalized_entry = SocketTemplate.normalize_entry(entry_data)
		data_entries.append(SocketTemplate.create_entry(
			normalized_entry.get("direction", Vector3i.UP),
			normalized_entry.get("socket_id", "none"),
			normalized_entry.get("compatible", []),
			normalized_entry.get("minimum_rotation_degrees", 0)
		))
	return {
		"name": name,
		"description": description,
		"entries": data_entries
	}

func _direction_to_label(direction: Vector3i) -> String:
	for option in DIRECTION_OPTIONS:
		if option["value"] == direction:
			return option["label"]
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]

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
	var entry = SocketTemplate.normalize_entry(_entries[index])
	match column:
		COLUMN_SOCKET_ID:
			var socket_id = item.get_text(column).strip_edges()
			if socket_id.is_empty():
				socket_id = "none"
			item.set_text(column, socket_id)
			entry["socket_id"] = socket_id
		COLUMN_COMPATIBLE:
			var compat_text = item.get_text(column)
			var compat: Array[String] = []
			for token in compat_text.split(",", false):
				var clean = String(token).strip_edges()
				if clean != "":
					compat.append(clean)
			entry["compatible"] = compat
			item.set_text(column, ", ".join(compat))
		COLUMN_ROTATION:
			var rotation = int(round(item.get_range(column)))
			rotation = clamp(rotation, 0, 360)
			item.set_range(column, rotation)
			entry["minimum_rotation_degrees"] = rotation
	_entries[index] = entry

func _on_entries_tree_gui_input(event: InputEvent) -> void:
	if entries_tree == null or event == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var mouse_event := event as InputEventMouseButton
		var column = entries_tree.get_column_at_position(mouse_event.position)
		var item = entries_tree.get_item_at_position(mouse_event.position)
		if item == null or column == -1:
			return
		item.select(column)
		if column == COLUMN_DIRECTION:
			_show_direction_popup(item, mouse_event.position)
		else:
			entries_tree.edit_item(item, column)

func _show_direction_popup(item: TreeItem, cell_position: Vector2 = Vector2.ZERO) -> void:
	if item == null or _direction_popup == null or entries_tree == null:
		return
	var index = _get_entry_index(item)
	if index < 0 or index >= _entries.size():
		return
	_direction_popup_target_index = index
	var current_dir = SocketTemplate.normalize_entry(_entries[index]).get("direction", Vector3i.UP)
	for i in range(_direction_popup.get_item_count()):
		var value: Vector3i = _direction_popup.get_item_metadata(i)
		_direction_popup.set_item_checked(i, value == current_dir)
	var popup_pos = entries_tree.get_global_transform_with_canvas().origin
	if cell_position != Vector2.ZERO:
		popup_pos += cell_position
	else:
		var rect = entries_tree.get_item_rect(item, COLUMN_DIRECTION, true)
		popup_pos += rect.position + Vector2(0, rect.size.y)
	_direction_popup.popup(Rect2(popup_pos, Vector2(0, 0)))

func _on_direction_popup_id_pressed(id: int) -> void:
	if _direction_popup_target_index < 0 or _direction_popup_target_index >= _entries.size():
		return
	var direction: Vector3i = _direction_popup.get_item_metadata(id)
	var index = _direction_popup_target_index
	_direction_popup_target_index = -1
	var entry = SocketTemplate.normalize_entry(_entries[index])
	entry["direction"] = direction
	_entries[index] = entry
	var item = _get_tree_item_by_index(index)
	if item:
		item.set_text(COLUMN_DIRECTION, _direction_to_label(direction))

func _get_tree_item_by_index(index: int) -> TreeItem:
	if entries_tree == null:
		return null
	var root = entries_tree.get_root()
	if root == null:
		return null
	var item = root.get_first_child()
	var idx = 0
	while item:
		if idx == index:
			return item
		item = item.get_next()
		idx += 1
	return null

func _select_tree_item(index: int, column: int = COLUMN_DIRECTION, edit: bool = false) -> void:
	if entries_tree == null or index < 0:
		return
	var item = _get_tree_item_by_index(index)
	if item == null:
		return
	item.select(column)
	entries_tree.grab_focus()
	if edit:
		entries_tree.edit_item(item, column)

func _get_entry_index(item: TreeItem) -> int:
	if item == null:
		return -1
	var index = item.get_metadata(COLUMN_DIRECTION)
	return int(index) if typeof(index) in [TYPE_INT, TYPE_FLOAT] else -1

func _get_selected_column() -> int:
	if entries_tree == null:
		return -1
	if entries_tree.has_method("get_selected_column"):
		var column_value = entries_tree.call("get_selected_column")
		return int(column_value) if typeof(column_value) in [TYPE_INT, TYPE_FLOAT] else COLUMN_SOCKET_ID
	return COLUMN_SOCKET_ID

func _normalize_name(name: String) -> String:
	return String(name).strip_edges().to_lower()

func _show_warning(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
