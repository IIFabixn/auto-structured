@tool
class_name SocketSuggestionDialog extends AcceptDialog

signal suggestions_accepted(tile: Tile, selections: Array)
signal modify_requested(tile: Tile, selections: Array)
signal suggestions_rejected(tile: Tile)

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const SocketSuggestionBuilder := preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const SocketTemplateLibrary := preload("res://addons/auto_structured/ui/utils/socket_template_library.gd")
const SocketTemplate := preload("res://addons/auto_structured/ui/utils/socket_template.gd")

@onready var summary_label: Label = %SummaryLabel
@onready var suggestion_tree: Tree = %SuggestionTree
@onready var template_panel: HBoxContainer = %TemplatePanel
@onready var template_option: OptionButton = %TemplateOption
@onready var apply_template_button: Button = %ApplyTemplateButton
@onready var socket_type_option: OptionButton = %SocketTypeOption
@onready var socket_type_hint: Label = %SocketTypeHint

var _current_tile: Tile = null
var _current_library: ModuleLibrary = null
var _suggestions: Array = []
var _modify_button: Button
var _selected_item: TreeItem = null
var _selected_index: int = -1
var _is_updating_socket_type_option := false
var _pending_new_type_dialog: AcceptDialog = null
var _template_cache: Array[SocketTemplate] = []
var _pending_tree_refresh := false

const PLACEHOLDER_TYPE_ID := -1
const ADD_NEW_TYPE_ID := -9999
const TEMPLATE_PLACEHOLDER_ID := -1

func _ready() -> void:
	title = "Socket Suggestions"
	get_ok_button().text = "Accept"
	add_cancel_button("Reject")
	_modify_button = add_button("Modify…", true, "modify")
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	custom_action.connect(_on_custom_action)
	_setup_tree()
	_setup_template_controls()
	_setup_socket_type_option()
	_sync_ui_state()

func show_for_tile(tile: Tile, library: ModuleLibrary, suggestions: Array) -> void:
	_current_tile = tile
	_current_library = library
	_suggestions = suggestions.duplicate()
	_update_summary()
	if suggestion_tree == null:
		_pending_tree_refresh = true
	else:
		_populate_tree()
	var has_suggestions := not _suggestions.is_empty()
	_update_accept_button_state()
	if _modify_button:
		_modify_button.disabled = tile == null
	_update_template_controls_state()
	_update_type_editor_state()
	if is_inside_tree():
		popup_centered_ratio(0.5)
	else:
		call_deferred("popup_centered_ratio", 0.5)

func _setup_tree() -> void:
	if suggestion_tree == null:
		return
	suggestion_tree.columns = 5
	suggestion_tree.set_column_titles_visible(true)
	suggestion_tree.set_column_title(0, "Use")
	suggestion_tree.set_column_title(1, "Direction")
	suggestion_tree.set_column_title(2, "Socket Type")
	suggestion_tree.set_column_title(3, "Matched Tile")
	suggestion_tree.set_column_title(4, "Score")
	suggestion_tree.hide_root = true
	suggestion_tree.item_selected.connect(_on_tree_item_selected)
	suggestion_tree.nothing_selected.connect(_on_tree_nothing_selected)
	suggestion_tree.item_edited.connect(_on_tree_item_edited)

func _populate_tree() -> void:
	if suggestion_tree == null:
		_pending_tree_refresh = true
		return
	_pending_tree_refresh = false
	suggestion_tree.clear()
	var root := suggestion_tree.create_item()
	for i in range(_suggestions.size()):
		var entry: Dictionary = _suggestions[i]
		var item := suggestion_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, true)
		item.set_metadata(0, i)
		var direction: Vector3i = entry.get("direction", Vector3i.ZERO)
		item.set_text(1, _direction_to_label(direction))
		item.set_text(2, entry.get("socket_id", ""))
		var partner_tile: Tile = entry.get("partner_tile", null)
		item.set_text(3, partner_tile.name if partner_tile else "-")
		var score := float(entry.get("score", 0.0))
		item.set_text(4, "%.3f" % score)
	_on_tree_nothing_selected()
	_update_accept_button_state()

func _collect_selected_suggestions() -> Array:
	var selections: Array = []
	if suggestion_tree == null:
		return _suggestions.duplicate()
	var root := suggestion_tree.get_root()
	if root == null:
		return selections
	var item := root.get_first_child()
	while item:
		if item.is_checked(0):
			var index := int(item.get_metadata(0))
			if index >= 0 and index < _suggestions.size():
				selections.append(_suggestions[index])
		item = item.get_next()
	return selections

func _sync_ui_state() -> void:
	_update_summary()
	_populate_tree()
	_update_template_controls_state()
	_update_type_editor_state()
	_update_accept_button_state()

func _on_confirmed() -> void:
	var selections := _collect_selected_suggestions()
	emit_signal("suggestions_accepted", _current_tile, selections)
	hide()
	_on_tree_nothing_selected()

func _on_canceled() -> void:
	emit_signal("suggestions_rejected", _current_tile)

func _on_custom_action(action: StringName) -> void:
	if action == StringName("modify"):
		var selections := _collect_selected_suggestions()
		emit_signal("modify_requested", _current_tile, selections)
		hide()
		_on_tree_nothing_selected()

func _update_summary() -> void:
	if summary_label == null:
		return
	if _current_tile == null:
		summary_label.text = ""
		return
	var count := _suggestions.size()
	if count == 0:
		summary_label.text = "No matching sockets were detected for '%s'." % _current_tile.name
	else:
		summary_label.text = "Found %d potential socket match%s for '%s'." % [count, "es" if count != 1 else "", _current_tile.name]

func _setup_template_controls() -> void:
	if template_option == null or apply_template_button == null:
		return
	template_option.item_selected.connect(_on_template_option_selected)
	apply_template_button.pressed.connect(_on_apply_template_pressed)
	_update_template_controls_state()

func _refresh_template_option() -> void:
	if template_option == null:
		return
	var previous_block := template_option.is_blocking_signals()
	template_option.set_block_signals(true)
	_template_cache = SocketTemplateLibrary.get_all_templates()
	template_option.clear()
	template_option.add_item("-- Select Template --", TEMPLATE_PLACEHOLDER_ID)
	template_option.set_item_disabled(0, true)
	for i in range(_template_cache.size()):
		var tpl := _template_cache[i]
		var label := tpl.template_name if tpl.template_name.strip_edges() != "" else "Template %d" % i
		template_option.add_item(label, i)
		template_option.set_item_tooltip(i + 1, tpl.description)
	template_option.select(0)
	template_option.set_block_signals(previous_block)

func _update_template_controls_state() -> void:
	if template_option == null or apply_template_button == null:
		return
	_refresh_template_option()
	var has_context := _current_tile != null and _current_library != null
	var has_templates := not _template_cache.is_empty()
	template_option.disabled = not has_context or not has_templates
	apply_template_button.disabled = true
	if template_panel:
		template_panel.visible = has_templates

func _on_template_option_selected(index: int) -> void:
	if template_option == null or apply_template_button == null:
		return
	var item_id := template_option.get_item_id(index)
	var valid := item_id >= 0 and item_id < _template_cache.size() and _current_tile != null and _current_library != null
	apply_template_button.disabled = not valid

func _on_apply_template_pressed() -> void:
	if template_option == null:
		return
	var template_id := template_option.get_selected_id()
	_apply_template_from_cache(template_id)

func _apply_template_from_cache(template_id: int) -> void:
	if _current_tile == null or _current_library == null:
		return
	if template_id < 0 or template_id >= _template_cache.size():
		return
	var template := _template_cache[template_id]
	SocketTemplateLibrary.apply_template(_current_tile, template, _current_library)
	_suggestions = SocketSuggestionBuilder.build_suggestions(_current_tile, _current_library)
	_update_summary()
	_populate_tree()
	_on_tree_nothing_selected()
	_update_type_editor_state()
	_update_accept_button_state()

func _setup_socket_type_option() -> void:
	if socket_type_option == null:
		return
	socket_type_option.item_selected.connect(_on_socket_type_option_selected)
	var popup := socket_type_option.get_popup()
	if popup:
		popup.about_to_popup.connect(_refresh_socket_type_option)
	_update_type_editor_state()

func _refresh_socket_type_option() -> void:
	if socket_type_option == null:
		return
	socket_type_option.set_block_signals(true)
	socket_type_option.clear()
	if _current_library == null:
		socket_type_option.add_item("No library available", PLACEHOLDER_TYPE_ID)
		socket_type_option.set_item_disabled(0, true)
		socket_type_option.disabled = true
		socket_type_option.set_block_signals(false)
		return
	var types := _current_library.get_socket_types()
	socket_type_option.disabled = false
	socket_type_option.add_item("-- Select Socket Type --", PLACEHOLDER_TYPE_ID)
	socket_type_option.set_item_disabled(socket_type_option.get_item_count() - 1, true)
	for type_name in types:
		socket_type_option.add_item(type_name)
	socket_type_option.add_separator()
	socket_type_option.add_item("+ Add New Type…", ADD_NEW_TYPE_ID)
	socket_type_option.set_block_signals(false)

func _select_socket_type_in_option(socket_id: String) -> void:
	if socket_type_option == null:
		return
	var trimmed := socket_id.strip_edges()
	if trimmed.is_empty():
		socket_type_option.selected = 0
		return
	for i in range(socket_type_option.item_count):
		if socket_type_option.get_item_text(i) == trimmed:
			socket_type_option.selected = i
			return
	# If not found (e.g. new type), register and refresh.
	if _current_library:
		_current_library.register_socket_type(trimmed)
	_refresh_socket_type_option()
	for i in range(socket_type_option.item_count):
		if socket_type_option.get_item_text(i) == trimmed:
			socket_type_option.selected = i
			return

func _on_tree_item_selected() -> void:
	if suggestion_tree == null:
		_on_tree_nothing_selected()
		return
	var selected := suggestion_tree.get_selected()
	if selected == null:
		_on_tree_nothing_selected()
		return
	var index := int(selected.get_metadata(0))
	if index < 0 or index >= _suggestions.size():
		_on_tree_nothing_selected()
		return
	_selected_item = selected
	_selected_index = index
	_update_type_editor_state()

func _on_tree_nothing_selected() -> void:
	_selected_item = null
	_selected_index = -1
	_update_type_editor_state()

func _update_type_editor_state() -> void:
	if socket_type_option == null:
		return
	var allow_edit := _selected_index >= 0 and _selected_index < _suggestions.size()
	_refresh_socket_type_option()
	socket_type_option.disabled = not allow_edit
	if socket_type_hint:
		socket_type_hint.visible = allow_edit
	var container := socket_type_option.get_parent()
	if container:
		container.visible = allow_edit
	if allow_edit:
		var entry: Dictionary = _suggestions[_selected_index]
		var socket_id := str(entry.get("socket_id", ""))
		_is_updating_socket_type_option = true
		_select_socket_type_in_option(socket_id)
		_is_updating_socket_type_option = false
	else:
		_is_updating_socket_type_option = true
		socket_type_option.selected = 0
		_is_updating_socket_type_option = false

func _on_socket_type_option_selected(index: int) -> void:
	if _is_updating_socket_type_option:
		return
	if socket_type_option == null:
		return
	if _selected_index < 0 or _selected_index >= _suggestions.size():
		return
	var item_id := socket_type_option.get_item_id(index)
	if item_id == ADD_NEW_TYPE_ID:
		_show_add_new_type_dialog()
		return
	var selected_type := socket_type_option.get_item_text(index).strip_edges()
	if selected_type.is_empty() or item_id == PLACEHOLDER_TYPE_ID:
		return
	_apply_selected_socket_type(selected_type)

func _apply_selected_socket_type(socket_type: String) -> void:
	if _selected_index < 0 or _selected_index >= _suggestions.size():
		return
	var trimmed := socket_type.strip_edges()
	if trimmed.is_empty():
		return
	if _current_library:
		_current_library.register_socket_type(trimmed)
	var entry: Dictionary = _suggestions[_selected_index]
	entry["socket_id"] = trimmed
	_suggestions[_selected_index] = entry
	if _selected_item:
		_selected_item.set_text(2, trimmed)
	_update_accept_button_state()

func _show_add_new_type_dialog() -> void:
	if _pending_new_type_dialog:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Add New Socket Type"
	dialog.dialog_text = "Enter new socket type ID:"
	var field := LineEdit.new()
	field.placeholder_text = "e.g. doorway_forward"
	dialog.add_child(field)
	dialog.confirmed.connect(func():
		var new_type := field.text.strip_edges()
		if new_type.is_empty():
			dialog.queue_free()
			_pending_new_type_dialog = null
			_update_type_editor_state()
			return
		if _current_library:
			_current_library.register_socket_type(new_type)
		_refresh_socket_type_option()
		_is_updating_socket_type_option = true
		_select_socket_type_in_option(new_type)
		_is_updating_socket_type_option = false
		_apply_selected_socket_type(new_type)
		dialog.queue_free()
		_pending_new_type_dialog = null
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		_pending_new_type_dialog = null
		_update_type_editor_state()
	)
	_pending_new_type_dialog = dialog
	add_child(dialog)
	dialog.popup_centered(Vector2i(340, 0))
	field.call_deferred("grab_focus")

func _on_tree_item_edited() -> void:
	_update_accept_button_state()

func _update_accept_button_state() -> void:
	var button := get_ok_button()
	if button == null:
		return
	if _current_tile == null:
		button.disabled = true
		return
	button.disabled = false

static func _direction_to_label(direction: Vector3i) -> String:
	match direction:
		Vector3i.RIGHT:
			return "Right"
		Vector3i.LEFT:
			return "Left"
		Vector3i.UP:
			return "Up"
		Vector3i.DOWN:
			return "Down"
		Vector3i.FORWARD:
			return "Forward"
		Vector3i.BACK:
			return "Back"
		_:
			return str(direction)
