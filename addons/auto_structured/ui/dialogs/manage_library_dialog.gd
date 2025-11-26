@tool
class_name LibraryManagerDialog extends ConfirmationDialog

const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")
const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")
const TemplateEditorDialogScene = preload("res://addons/auto_structured/ui/dialogs/template_editor_dialog.tscn")

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

@onready var templates_search: LineEdit = %TemplatesSearchLine
@onready var templates_tree: Tree = %TemplatesTree
@onready var template_add_button: Button = %TemplateAddButton
@onready var template_edit_button: Button = %TemplateEditButton
@onready var template_delete_button: Button = %TemplateDeleteButton
@onready var template_restore_button: Button = %TemplateRestoreButton
@onready var template_title_label: Label = %TemplateTitleLabel
@onready var template_summary_label: Label = %TemplateSummaryLabel
@onready var template_description_label: Label = %TemplateDescriptionLabel
@onready var template_entries_tree: Tree = %TemplateEntriesTree
@onready var template_apply_button: Button = %TemplateApplyButton

var _library: ModuleLibrary = null
var _template_editor_dialog: TemplateEditorDialog = null

var _tags_original: Array[String] = []
var _tags_pending: Array[String] = []
var _tag_forward_map: Dictionary = {}
var _tag_reverse_map: Dictionary = {}
var _tags_added: Dictionary = {}
var _tags_removed_originals: Dictionary = {}

var _templates: Array = []

var _selected_tag: String = ""
var _selected_template_index: int = -1
var _tags_filter: String = ""
var _template_filter: String = ""

var _ui_connected := false

func _ready() -> void:
	if not confirmed.is_connected(_on_dialog_confirmed):
		confirmed.connect(_on_dialog_confirmed)
	_initialize_lists()
	_connect_ui()
	_ensure_template_editor_dialog()
	_refresh_all()

func _initialize_lists() -> void:
	if tags_tree:
		tags_tree.columns = 1
		tags_tree.hide_root = true
		tags_tree.column_titles_visible = true
		tags_tree.set_column_title(0, "Tag")
	if tags_usage_tree:
		tags_usage_tree.columns = 2
		tags_usage_tree.hide_root = true
		tags_usage_tree.column_titles_visible = true
		tags_usage_tree.set_column_title(0, "Tile")
		tags_usage_tree.set_column_title(1, "Notes")
	if templates_tree:
		templates_tree.columns = 1
		templates_tree.hide_root = true
		templates_tree.column_titles_visible = true
		templates_tree.set_column_title(0, "Template")
	if template_entries_tree:
		template_entries_tree.columns = 2
		template_entries_tree.hide_root = true
		template_entries_tree.column_titles_visible = true
		template_entries_tree.set_column_title(0, "Direction")
		template_entries_tree.set_column_title(1, "Socket ID")

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
	if templates_search:
		templates_search.text_changed.connect(func(value: String):
			_template_filter = value.strip_edges().to_lower()
			_refresh_templates_list()
		)
	if template_add_button:
		template_add_button.pressed.connect(_on_add_template_pressed)
	if template_edit_button:
		template_edit_button.pressed.connect(_on_edit_template_pressed)
	if template_delete_button:
		template_delete_button.pressed.connect(_on_delete_template_pressed)
	if template_restore_button:
		template_restore_button.pressed.connect(_on_restore_templates_pressed)
	if template_apply_button:
		template_apply_button.pressed.connect(_on_apply_template_pressed)
	if templates_tree:
		templates_tree.item_selected.connect(_on_template_selected)
		templates_tree.item_activated.connect(_on_template_activated)

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
	_selected_tag = ""
	_selected_template_index = -1
	_tags_filter = ""
	_template_filter = ""
	if tags_search:
		tags_search.clear()
	if templates_search:
		templates_search.clear()
	_reload_templates_cache()
	if _library == null:
		return
	_tags_original = _library.get_available_tags()
	_tags_original.sort()
	_tags_pending = _tags_original.duplicate()
	for tag in _tags_original:
		_tag_forward_map[tag] = tag
		_tag_reverse_map[tag] = tag

func _refresh_all() -> void:
	_refresh_tags_list()
	_refresh_templates_list()
	_update_tag_usage()
	_update_template_details()
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

func _ensure_template_editor_dialog() -> void:
	if _template_editor_dialog != null:
		return
	if TemplateEditorDialogScene == null:
		return
	_template_editor_dialog = TemplateEditorDialogScene.instantiate() as TemplateEditorDialog
	add_child(_template_editor_dialog)

func _reload_templates_cache() -> void:
	_templates.clear()
	var custom_records: Array = []
	var override_keys: Dictionary = {}
	if _library != null and _library.custom_socket_templates != null:
		for template in _library.custom_socket_templates:
			if template == null:
				continue
			var key = _normalize_template_name(template.template_name)
			if key != "":
				override_keys[key] = true
			custom_records.append({
				"template": template,
				"is_custom": true
			})
	var builtin := LibraryPresets.get_socket_templates()
	for template in builtin:
		if template == null:
			continue
		if _library != null:
			if _library.is_builtin_template_hidden(template.template_name):
				continue
			var key = _normalize_template_name(template.template_name)
			if key != "" and override_keys.has(key):
				continue
		_templates.append({
			"template": template,
			"is_custom": false
		})
	_templates.append_array(custom_records)
	_sort_templates_cache()

func _get_template_record(index: int) -> Dictionary:
	if index < 0 or index >= _templates.size():
		return {}
	var record = _templates[index]
	if record is Dictionary:
		return record
	if record == null:
		return {}
	return {
		"template": record,
		"is_custom": false
	}

func _get_template_from_index(index: int) -> SocketTemplate:
	var record = _get_template_record(index)
	return record.get("template", null)

func _is_template_custom(index: int) -> bool:
	var record = _get_template_record(index)
	return record.get("is_custom", false)

func _find_template_index(template: SocketTemplate) -> int:
	if template == null:
		return -1
	for i in range(_templates.size()):
		var record = _get_template_record(i)
		if record.get("template") == template:
			return i
	return -1

func _normalize_template_name(name: String) -> String:
	return String(name).strip_edges().to_lower()

func _sort_templates_cache() -> void:
	if _templates.size() <= 1:
		return
	_templates.sort_custom(Callable(self, "_compare_template_records"))

func _compare_template_records(a, b) -> bool:
	var template_a: SocketTemplate = a.get("template", null)
	var template_b: SocketTemplate = b.get("template", null)
	if template_a == null:
		return false
	if template_b == null:
		return true
	return template_a.template_name.nocasecmp_to(template_b.template_name) < 0

func _refresh_templates_after_mutation(preferred_template: SocketTemplate = null) -> void:
	_reload_templates_cache()
	var next_index = _selected_template_index
	if preferred_template != null:
		next_index = _find_template_index(preferred_template)
	if _templates.is_empty():
		next_index = -1
	else:
		next_index = clamp(next_index, 0, _templates.size() - 1)
	_selected_template_index = next_index
	_refresh_templates_list()
	_update_template_details()
	_update_buttons_state()

func _ensure_template_is_custom(index: int) -> int:
	if _library == null:
		return -1
	if index < 0 or index >= _templates.size():
		return -1
	if _is_template_custom(index):
		return index
	var source = _get_template_from_index(index)
	if source == null:
		return -1
	var duplicate = _duplicate_template_resource(source)
	if duplicate == null:
		return -1
	_library.add_custom_socket_template(duplicate)
	_refresh_templates_after_mutation(duplicate)
	return _find_template_index(duplicate)

func _duplicate_template_resource(template: SocketTemplate) -> SocketTemplate:
	if template == null:
		return null
	var duplicate = SocketTemplate.new()
	duplicate.template_name = template.template_name
	duplicate.description = template.description
	duplicate.entries = []
	for entry_data in template.entries:
		var normalized = SocketTemplate.normalize_entry(entry_data)
		duplicate.entries.append(SocketTemplate.create_entry(
			normalized.get("direction", Vector3i.UP),
			normalized.get("socket_id", "none"),
			normalized.get("compatible", []),
			normalized.get("minimum_rotation_degrees", 0)
		))
	return duplicate

func _refresh_templates_list() -> void:
	if templates_tree == null:
		return
	templates_tree.clear()
	var root = templates_tree.create_item()
	var filter = _template_filter

	for i in range(_templates.size()):
		var record = _get_template_record(i)
		if record.is_empty():
			continue
		var template: SocketTemplate = record.get("template")
		if template == null:
			continue
		var label = template.template_name
		var display_label = label
		if record.get("is_custom", false):
			display_label = "%s (Custom)" % label
		var text_to_match = "%s %s" % [label.to_lower(), template.description.to_lower()]
		if not filter.is_empty() and not text_to_match.contains(filter):
			continue
		var item = templates_tree.create_item(root)
		item.set_text(0, display_label)
		item.set_metadata(0, i)
		if i == _selected_template_index:
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

	var has_template_selection := _selected_template_index >= 0 and _selected_template_index < _templates.size()
	if template_add_button:
		template_add_button.disabled = _library == null
	if template_edit_button:
		template_edit_button.disabled = not (has_template_selection and _library != null)
	if template_delete_button:
		template_delete_button.disabled = not (has_template_selection and _library != null)
	if template_restore_button:
		var disable_restore := true
		if _library != null:
			disable_restore = not _library.has_hidden_builtin_templates()
		template_restore_button.disabled = disable_restore
	if template_apply_button:
		var disable_template_apply := not has_template_selection or _library == null
		if not disable_template_apply and _library:
			disable_template_apply = _library.tiles.is_empty()
		template_apply_button.disabled = disable_template_apply

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

func _on_template_selected() -> void:
	if templates_tree == null:
		return
	var item = templates_tree.get_selected()
	_selected_template_index = -1 if item == null else int(item.get_metadata(0))
	_update_template_details()
	_update_buttons_state()

func _on_template_activated() -> void:
	_on_apply_template_pressed()

func _on_add_template_pressed() -> void:
	if _library == null:
		_show_warning("Templates require an active library.")
		return
	_open_template_editor("Create Template", null, func(data: Dictionary):
		var template := SocketTemplate.new()
		_apply_template_editor_data(template, data)
		_library.add_custom_socket_template(template)
		_refresh_templates_after_mutation(template)
	)

func _on_edit_template_pressed() -> void:
	if _library == null:
		return
	if _selected_template_index < 0:
		return
	var custom_index = _ensure_template_is_custom(_selected_template_index)
	if custom_index == -1:
		return
	_selected_template_index = custom_index
	var template = _get_template_from_index(custom_index)
	if template == null:
		return
	_open_template_editor("Edit Template", template, func(data: Dictionary):
		_apply_template_editor_data(template, data)
		_library.library_changed.emit()
		_refresh_templates_after_mutation(template)
	)

func _on_delete_template_pressed() -> void:
	if _library == null:
		return
	if _selected_template_index < 0:
		return
	var template = _get_template_from_index(_selected_template_index)
	if template == null:
		return
	if _is_template_custom(_selected_template_index):
		var confirm = _create_confirmation_dialog("Delete Template", "Delete custom template '%s'?" % template.template_name)
		confirm.confirmed.connect(func():
			if _library.remove_custom_socket_template(template):
				_refresh_templates_after_mutation()
			confirm.queue_free()
		)
		confirm.canceled.connect(confirm.queue_free)
		confirm.popup_centered()
		return
	var hide_confirm = _create_confirmation_dialog("Hide Template", "Hide built-in template '%s'? You can restore hidden templates at any time." % template.template_name)
	hide_confirm.confirmed.connect(func():
		if _library.hide_builtin_template(template.template_name):
			_refresh_templates_after_mutation()
		hide_confirm.queue_free()
	)
	hide_confirm.canceled.connect(hide_confirm.queue_free)
	hide_confirm.popup_centered()

func _on_restore_templates_pressed() -> void:
	if _library == null:
		return
	_library.restore_all_builtin_templates()
	_refresh_templates_after_mutation()

func _update_template_details() -> void:
	if template_entries_tree:
		template_entries_tree.clear()
	if template_title_label:
		template_title_label.text = "Templates"
	if template_summary_label:
		template_summary_label.text = "Select a template to view details"
	if template_description_label:
		template_description_label.text = ""
	if _selected_template_index < 0 or _selected_template_index >= _templates.size():
		return
	var template = _get_template_from_index(_selected_template_index)
	if template == null:
		return
	if template_title_label:
		template_title_label.text = template.template_name
	if template_summary_label:
		template_summary_label.text = "%d socket definitions" % template.entries.size()
	if template_description_label:
		template_description_label.text = template.description
	if template_entries_tree:
		var root = template_entries_tree.create_item()
		for entry_data in template.entries:
			var entry = entry_data if entry_data is Dictionary else {}
			var direction: Vector3i = entry.get("direction", Vector3i.UP)
			var socket_id: String = str(entry.get("socket_id", "none"))
			var item = template_entries_tree.create_item(root)
			item.set_text(0, _direction_to_string(direction))
			item.set_text(1, socket_id)
			item.set_selectable(0, false)
			item.set_selectable(1, false)

func _on_apply_template_pressed() -> void:
	if _library == null:
		return
	if _selected_template_index < 0 or _selected_template_index >= _templates.size():
		return
	if _library.tiles.is_empty():
		_show_warning("No tiles available in this library.")
		return
	var template = _get_template_from_index(_selected_template_index)
	if template == null:
		return
	var dialog = _create_selection_dialog("Apply Template", "Select tiles to apply '%s':" % template.template_name, _library.tiles, func(tile: Tile): return tile.name)
	dialog.confirmed.connect(func():
		var selected_tiles = _get_dialog_selected_entries(dialog)
		if not selected_tiles.is_empty():
			_apply_template_to_tiles(_selected_template_index, selected_tiles)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.5)

func _apply_template_to_tiles(template_index: int, tiles: Array) -> void:
	if _library == null:
		return
	if template_index < 0 or template_index >= _templates.size():
		return
	var template = _get_template_from_index(template_index)
	if template == null:
		return
	var modified := false
	for entry in tiles:
		if entry is Tile:
			var tile: Tile = entry
			LibraryPresets.apply_socket_template(tile, template, _library)
			_library.notify_tile_modified(tile, "sockets")
			modified = true
	if modified:
		_update_template_details()

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

func _direction_to_string(direction: Vector3i) -> String:
	return "(%d, %d, %d)" % [direction.x, direction.y, direction.z]

func _collect_existing_template_names(exclude_template: SocketTemplate = null) -> Array[String]:
	var names: Dictionary = {}
	var builtin = LibraryPresets.get_socket_templates()
	for template in builtin:
		if template == null:
			continue
		if exclude_template != null and template == exclude_template:
			continue
		var normalized = _normalize_template_name(template.template_name)
		if normalized != "":
			names[normalized] = true
	if _library != null and _library.custom_socket_templates != null:
		for template in _library.custom_socket_templates:
			if template == null:
				continue
			if exclude_template != null and template == exclude_template:
				continue
			var normalized = _normalize_template_name(template.template_name)
			if normalized != "":
				names[normalized] = true
	var result: Array[String] = []
	for key in names.keys():
		result.append(key)
	return result

func _open_template_editor(title: String, template: SocketTemplate, on_save: Callable) -> void:
	_ensure_template_editor_dialog()
	if _template_editor_dialog == null:
		_show_warning("Template editor is unavailable.")
		return
	var existing_names = _collect_existing_template_names(template)
	_template_editor_dialog.open_editor(title, template, existing_names, on_save)

func _apply_template_editor_data(template: SocketTemplate, data: Dictionary) -> void:
	if template == null or data.is_empty():
		return
	template.template_name = data.get("name", template.template_name)
	template.description = data.get("description", template.description)
	var entries: Array = data.get("entries", [])
	template.entries = entries.duplicate(true)

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

func _on_dialog_confirmed() -> void:
	_apply_tag_changes()


