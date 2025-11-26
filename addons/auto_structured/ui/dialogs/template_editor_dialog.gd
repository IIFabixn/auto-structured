@tool
class_name TemplateEditorDialog
extends ConfirmationDialog

const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")

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

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	if entries_tree:
		entries_tree.create_item() # ensure columns configured
		entries_tree.column_titles_visible = true
		entries_tree.set_column_title(0, "Direction")
		entries_tree.set_column_title(1, "Socket ID")
		entries_tree.set_column_title(2, "Compatible IDs")
		entries_tree.item_selected.connect(func():
			_update_entry_buttons()
		)
		entries_tree.item_activated.connect(func():
			_on_edit_entry_pressed()
		)
	if add_entry_button:
		add_entry_button.pressed.connect(_on_add_entry_pressed)
	if edit_entry_button:
		edit_entry_button.pressed.connect(_on_edit_entry_pressed)
	if delete_entry_button:
		delete_entry_button.pressed.connect(_on_delete_entry_pressed)
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
	_open_entry_editor("Add Entry", {}, func(entry: Dictionary):
		_entries.append(entry)
		_refresh_entries_tree()
	)

func _on_edit_entry_pressed() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_selected()
	if item == null:
		return
	var index = int(item.get_metadata(0))
	if index < 0 or index >= _entries.size():
		return
	var entry = _entries[index]
	_open_entry_editor("Edit Entry", entry, func(updated: Dictionary):
		_entries[index] = updated
		_refresh_entries_tree()
	)

func _on_delete_entry_pressed() -> void:
	if entries_tree == null:
		return
	var item = entries_tree.get_selected()
	if item == null:
		return
	var index = int(item.get_metadata(0))
	if index < 0 or index >= _entries.size():
		return
	_entries.remove_at(index)
	_refresh_entries_tree()

func _refresh_entries_tree() -> void:
	if entries_tree == null:
		return
	entries_tree.clear()
	var root = entries_tree.create_item()
	for i in range(_entries.size()):
		var normalized = SocketTemplate.normalize_entry(_entries[i])
		var item = entries_tree.create_item(root)
		item.set_text(0, _direction_to_string(normalized.get("direction", Vector3i.UP)))
		item.set_text(1, normalized.get("socket_id", "none"))
		var compat: Array = normalized.get("compatible", [])
		item.set_text(2, ", ".join(compat))
		item.set_metadata(0, i)
	_update_entry_buttons()

func _update_entry_buttons() -> void:
	var has_selection := entries_tree != null and entries_tree.get_selected() != null
	if edit_entry_button:
		edit_entry_button.disabled = not has_selection
	if delete_entry_button:
		delete_entry_button.disabled = not has_selection

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

func _open_entry_editor(title: String, entry: Dictionary, on_save: Callable) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.popup_window = true
	dialog.exclusive = false
	var content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(360, 0)

	var dir_label = Label.new()
	dir_label.text = "Direction (Vector3i)"
	content.add_child(dir_label)
	var dir_row = HBoxContainer.new()
	var dir_x = SpinBox.new()
	dir_x.min_value = -4
	dir_x.max_value = 4
	dir_x.step = 1
	dir_x.custom_minimum_size = Vector2(80, 0)
	dir_row.add_child(dir_x)
	var dir_y = SpinBox.new()
	dir_y.min_value = -4
	dir_y.max_value = 4
	dir_y.step = 1
	dir_y.custom_minimum_size = Vector2(80, 0)
	dir_row.add_child(dir_y)
	var dir_z = SpinBox.new()
	dir_z.min_value = -4
	dir_z.max_value = 4
	dir_z.step = 1
	dir_z.custom_minimum_size = Vector2(80, 0)
	dir_row.add_child(dir_z)
	content.add_child(dir_row)

	var socket_label = Label.new()
	socket_label.text = "Socket ID"
	content.add_child(socket_label)
	var socket_edit = LineEdit.new()
	socket_edit.placeholder_text = "socket_id"
	content.add_child(socket_edit)

	var compat_label = Label.new()
	compat_label.text = "Compatible IDs (comma separated)"
	content.add_child(compat_label)
	var compat_edit = LineEdit.new()
	compat_edit.placeholder_text = "id_a, id_b"
	content.add_child(compat_edit)

	var rotation_label = Label.new()
	rotation_label.text = "Minimum rotation (degrees)"
	content.add_child(rotation_label)
	var rotation_spin = SpinBox.new()
	rotation_spin.min_value = 0
	rotation_spin.max_value = 360
	rotation_spin.step = 15
	content.add_child(rotation_spin)

	var normalized = SocketTemplate.normalize_entry(entry)
	var dir: Vector3i = normalized.get("direction", Vector3i.UP)
	dir_x.value = dir.x
	dir_y.value = dir.y
	dir_z.value = dir.z
	socket_edit.text = normalized.get("socket_id", "none")
	var compat: Array = normalized.get("compatible", [])
	compat_edit.text = ", ".join(compat)
	rotation_spin.value = normalized.get("minimum_rotation_degrees", 0)

	dialog.set_meta("entry_dir_x", dir_x)
	dialog.set_meta("entry_dir_y", dir_y)
	dialog.set_meta("entry_dir_z", dir_z)
	dialog.set_meta("entry_socket_edit", socket_edit)
	dialog.set_meta("entry_compat_edit", compat_edit)
	dialog.set_meta("entry_rotation_spin", rotation_spin)

	if dialog.has_method("get_vbox"):
		dialog.get_vbox().add_child(content)
	else:
		dialog.add_child(content)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var data = _collect_template_entry_data(dialog)
		if data.is_empty():
			dialog.popup_centered_ratio(0.45)
			return
		on_save.call(data)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.45)
	socket_edit.call_deferred("grab_focus")
	socket_edit.call_deferred("select_all")

func _collect_template_entry_data(dialog: AcceptDialog) -> Dictionary:
	var dir_x: SpinBox = dialog.get_meta("entry_dir_x") if dialog.has_meta("entry_dir_x") else null
	var dir_y: SpinBox = dialog.get_meta("entry_dir_y") if dialog.has_meta("entry_dir_y") else null
	var dir_z: SpinBox = dialog.get_meta("entry_dir_z") if dialog.has_meta("entry_dir_z") else null
	var socket_edit: LineEdit = dialog.get_meta("entry_socket_edit") if dialog.has_meta("entry_socket_edit") else null
	var compat_edit: LineEdit = dialog.get_meta("entry_compat_edit") if dialog.has_meta("entry_compat_edit") else null
	var rotation_spin: SpinBox = dialog.get_meta("entry_rotation_spin") if dialog.has_meta("entry_rotation_spin") else null
	if socket_edit == null or dir_x == null or dir_y == null or dir_z == null:
		return {}
	var socket_id = socket_edit.text.strip_edges()
	if socket_id.is_empty():
		_show_warning("Socket ID cannot be empty.")
		return {}
	var direction = Vector3i(int(dir_x.value), int(dir_y.value), int(dir_z.value))
	var compat: Array[String] = []
	if compat_edit:
		var raw_tokens = compat_edit.text.split(",", false)
		for token in raw_tokens:
			var clean = String(token).strip_edges()
			if clean != "":
				compat.append(clean)
	var min_rotation = int(rotation_spin.value) if rotation_spin else 0
	return SocketTemplate.create_entry(direction, socket_id, compat, min_rotation)

func _direction_to_string(direction: Vector3i) -> String:
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]

func _normalize_name(name: String) -> String:
	return String(name).strip_edges().to_lower()

func _show_warning(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
