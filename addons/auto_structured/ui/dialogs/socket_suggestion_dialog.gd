@tool
class_name SocketEditorDialog extends AcceptDialog

signal changes_applied(tile: Tile, changed_tiles: Array)
signal suggestions_skipped(tile: Tile)

const Tile := preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const SocketSuggestionBuilder := preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const SocketTemplateLibrary := preload("res://addons/auto_structured/ui/utils/socket_template_library.gd")
const SocketTemplate := preload("res://addons/auto_structured/ui/utils/socket_template.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")
const Requirement := preload("res://addons/auto_structured/core/requirements/requirement.gd")
const RotationRequirement := preload("res://addons/auto_structured/core/requirements/rotation_requirement.gd")

enum Mode {
	SUGGESTIONS,
	EDITOR
}

@onready var mode_tabs: TabContainer = %ModeTabs
@onready var summary_label: Label = %SummaryLabel
@onready var summary_warnings_label: RichTextLabel = %SummaryWarningsLabel
@onready var wizard_guidance_label: RichTextLabel = %WizardGuidanceLabel
@onready var suggestion_tree: Tree = %SuggestionTree
@onready var template_panel: HBoxContainer = %TemplatePanel
@onready var template_option: OptionButton = %TemplateOption
@onready var apply_template_button: Button = %ApplyTemplateButton
@onready var socket_type_option: OptionButton = %SocketTypeOption
@onready var socket_type_hint: Label = %SocketTypeHint
@onready var include_self_toggle: CheckBox = %IncludeSelfToggle
@onready var editor_tile_label: Label = %EditorTileLabel
@onready var editor_template_option: OptionButton = %EditorTemplateOption
@onready var editor_apply_template_button: Button = %EditorApplyTemplateButton
@onready var editor_socket_list: ItemList = %EditorSocketList
@onready var editor_socket_header: Label = %EditorSocketHeader
@onready var editor_issues_label: RichTextLabel = %EditorIssuesLabel
@onready var editor_socket_type_option: OptionButton = %EditorSocketTypeOption
@onready var editor_allow_self_checkbox: CheckBox = %EditorAllowSelfCheckBox
@onready var editor_rotation_option: OptionButton = %EditorRotationOption
@onready var editor_bulk_apply_type_button: Button = %EditorBulkApplyTypeButton
@onready var editor_bulk_allow_self_button: Button = %EditorBulkAllowSelfButton
@onready var editor_reciprocal_checkbox: CheckBox = %EditorReciprocalCheckBox
@onready var editor_connections_container: VBoxContainer = %EditorConnectionsContainer
@onready var editor_connections_info: Label = %EditorConnectionsInfo

var _current_tile: Tile = null
var _current_library: ModuleLibrary = null
var _suggestions: Array = []
var _base_suggestions: Array = []
var _self_suggestions: Array = []
var _modify_button: Button
var _selected_item: TreeItem = null
var _selected_index: int = -1
var _is_updating_socket_type_option := false
var _is_updating_self_toggle := false
var _include_self_matches := false
var _pending_new_type_dialog: AcceptDialog = null
var _suggestion_template_cache: Array[SocketTemplate] = []
var _pending_tree_refresh := false
var _current_analysis: Dictionary = {}

var _current_mode: int = Mode.SUGGESTIONS

var _editor_socket_states: Array = []
var _editor_template_cache: Array[SocketTemplate] = []
var _editor_current_socket_index: int = -1

const PLACEHOLDER_TYPE_ID := -1
const ADD_NEW_TYPE_ID := -9999
const TEMPLATE_PLACEHOLDER_ID := -1
const CUSTOM_SOCKET_TYPE_TOKEN := "__custom__"
const EDITOR_ADD_NEW_TYPE_TOKEN := "__add_new__"

var _cancel_button: Button = null

func _ready() -> void:
	title = "Socket Editor"
	get_ok_button().text = "Apply Suggestions"
	_cancel_button = add_cancel_button("Skip")
	_modify_button = add_button("Open Editor", true, "open_editor")
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	custom_action.connect(_on_custom_action)
	_setup_tree()
	_setup_template_controls()
	_setup_socket_type_option()
	_setup_include_self_toggle()
	_setup_editor_controls()
	if mode_tabs:
		mode_tabs.tab_changed.connect(_on_mode_tab_changed)
	_update_mode_ui()
	_sync_ui_state()

func show_for_tile(tile: Tile, library: ModuleLibrary, suggestions: Array = [], start_mode: int = Mode.SUGGESTIONS) -> void:
	_current_tile = tile
	_current_library = library
	_include_self_matches = false
	_set_include_self_toggle(false)
	_base_suggestions = suggestions.duplicate(true) if suggestions else []
	_base_suggestions = _normalize_suggestion_list(_base_suggestions)
	_self_suggestions = []
	_suggestions.clear()
	_apply_suggestion_source()
	_setup_editor_state()
	_set_mode(start_mode)
	_update_accept_button_state()
	if _modify_button:
		_modify_button.disabled = tile == null or mode_tabs == null
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
		var should_use := bool(entry.get("use", true))
		item.set_checked(0, should_use)
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
	_capture_tree_checks_into_suggestions()
	if suggestion_tree == null:
		for entry in _suggestions:
			if bool(entry.get("use", true)):
				selections.append(entry)
		return selections
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

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
	_update_self_toggle_state()

func _apply_suggestions_to_tile(tile: Tile, selections: Array) -> Array[Tile]:
	var changed_tiles: Dictionary = {}
	if tile == null:
		return []
	if selections.is_empty():
		return []
	for selection in selections:
		var suggestion: Dictionary = selection
		var socket_id := str(suggestion.get("socket_id", "")).strip_edges()
		if socket_id == "" or socket_id == "none":
			continue
		var direction: Vector3i = suggestion.get("direction", Vector3i.ZERO)
		if direction == Vector3i.ZERO:
			continue
		var socket := tile.get_socket_by_direction(direction)
		if socket == null:
			socket = Socket.new()
			socket.direction = direction
			tile.add_socket(socket)
		var compat_set := {}
		for compat in suggestion.get("compatible", []):
			var compat_id := str(compat).strip_edges()
			if compat_id == "":
				continue
			compat_set[compat_id] = true
		var partner_socket: Socket = suggestion.get("partner_socket", null)
		var partner_socket_id := ""
		if partner_socket:
			partner_socket_id = str(partner_socket.socket_id).strip_edges()
			if partner_socket_id != "" and partner_socket_id != "none":
				compat_set[partner_socket_id] = true
		elif _current_library:
			var partner_tile: Tile = suggestion.get("partner_tile", null)
			var partner_direction: Vector3i = suggestion.get("partner_direction", Vector3i.ZERO)
			if partner_tile and partner_direction != Vector3i.ZERO:
				partner_socket = partner_tile.get_socket_by_direction(partner_direction)
				if partner_socket == null:
					partner_socket = Socket.new()
					partner_socket.direction = partner_direction
					partner_socket.socket_id = "none"
					partner_tile.add_socket(partner_socket)
				partner_socket_id = str(partner_socket.socket_id).strip_edges()
				if partner_socket_id != "" and partner_socket_id != "none":
					compat_set[partner_socket_id] = true
		var compat_list: Array[String] = []
		for compat_id in compat_set.keys():
			compat_list.append(str(compat_id))
		compat_list.sort()
		socket.socket_id = socket_id
		socket.compatible_sockets = _string_array(compat_list)
		if _current_library:
			_current_library.register_socket_type(socket_id)
			for compat_id in compat_list:
				_current_library.register_socket_type(compat_id)
		if partner_socket:
			var partner_compats: Array[String] = []
			partner_compats.assign(partner_socket.compatible_sockets)
			if socket_id not in partner_compats:
				partner_compats.append(socket_id)
			var partner_array := _string_array(partner_compats)
			partner_array.sort()
			partner_socket.compatible_sockets = partner_array
			var partner_tile: Tile = suggestion.get("partner_tile", null)
			if partner_tile:
				partner_tile.sockets = partner_tile.sockets
				changed_tiles[partner_tile] = true
		changed_tiles[tile] = true
	if tile != null and changed_tiles.has(tile):
		tile.sockets = tile.sockets
	var result: Array[Tile] = []
	for changed_tile in changed_tiles.keys():
		result.append(changed_tile)
	return result

func _on_confirmed() -> void:
	if _current_tile == null or _current_library == null:
		hide()
		return
	var changed_tiles: Array[Tile] = []
	if _current_mode == Mode.EDITOR:
		changed_tiles = _editor_apply_changes()
	else:
		var selections := _collect_selected_suggestions()
		changed_tiles = _apply_suggestions_to_tile(_current_tile, selections)
		_apply_suggestion_source(true)
		_setup_editor_state()
	if not changed_tiles:
		changed_tiles = []
	emit_signal("changes_applied", _current_tile, changed_tiles)
	hide()
	_on_tree_nothing_selected()

func _on_canceled() -> void:
	emit_signal("suggestions_skipped", _current_tile)
	hide()

func _on_custom_action(action: StringName) -> void:
	if action == StringName("open_editor"):
		_set_mode(Mode.EDITOR)

func _update_summary() -> void:
	if summary_label == null:
		return
	if _current_tile == null:
		summary_label.text = ""
		_update_summary_warnings_display([])
		return
	var count := _suggestions.size()
	if count == 0:
		summary_label.text = "No matching sockets were detected for '%s'." % _current_tile.name
	else:
		summary_label.text = "Found %d potential socket match%s for '%s'." % [count, "es" if count != 1 else "", _current_tile.name]
	_update_summary_warnings_display(_compute_suggestion_warnings())
	_update_wizard_guidance_display()

func _update_summary_warnings_display(warnings: Array[String]) -> void:
	if summary_warnings_label == null:
		return
	if warnings.is_empty():
		summary_warnings_label.visible = false
		summary_warnings_label.text = ""
		return
	summary_warnings_label.visible = true
	var lines: Array[String] = []
	for warning in warnings:
		lines.append("[color=yellow]• %s[/color]" % warning)
	summary_warnings_label.text = "\n".join(lines)

func _compute_suggestion_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if _current_tile == null:
		return warnings
	var directions_seen: Dictionary = {}
	for entry in _suggestions:
		if entry == null:
			continue
		var direction: Vector3i = entry.get("direction", Vector3i.ZERO)
		var dir_label := _direction_to_label(direction)
		if directions_seen.has(direction):
			warnings.append("Multiple suggestions target the %s side; verify duplicates." % dir_label)
		else:
			directions_seen[direction] = true
		var socket_id := String(entry.get("socket_id", "")).strip_edges()
		if socket_id == "" or socket_id == "none":
			warnings.append("Suggestion on %s side is missing a socket type." % dir_label)
		var partner_tile: Tile = entry.get("partner_tile", null)
		var partner_socket: Socket = entry.get("partner_socket", null)
		if partner_tile and partner_socket == null:
			warnings.append("Suggestion on %s links to '%s' but no specific socket was identified." % [dir_label, partner_tile.name])
		elif partner_socket:
			var partner_id := String(partner_socket.socket_id).strip_edges()
			if partner_id == "" or partner_id == "none":
				var partner_name := partner_tile.name if partner_tile else "partner tile"
				warnings.append("Partner socket on '%s' for the %s side lacks a socket type." % [partner_name, dir_label])
	return warnings

func _update_wizard_guidance_display() -> void:
	if wizard_guidance_label == null:
		return
	if _current_tile == null or _current_library == null:
		wizard_guidance_label.visible = false
		wizard_guidance_label.text = ""
		return
	var lines: Array[String] = []
	if not _current_analysis.is_empty():
		var priority := [
			Vector3i.UP,
			Vector3i.DOWN,
			Vector3i.RIGHT,
			Vector3i.LEFT,
			Vector3i.FORWARD,
			Vector3i.BACK
		]
		var ordered: Array[Vector3i] = []
		for dir in priority:
			if _current_analysis.has(dir):
				ordered.append(dir)
		for dir_key in _current_analysis.keys():
			if dir_key in ordered:
				continue
			ordered.append(dir_key)
		for direction in ordered:
			var info: Dictionary = _current_analysis.get(direction, {})
			if info.is_empty():
				continue
			var entry := _build_guidance_entry_for_analysis(info)
			if entry != "":
				lines.append(entry)
	var helper_lines: Array[String] = []
	if editor_bulk_apply_type_button:
		var bulk_label := editor_bulk_apply_type_button.text if editor_bulk_apply_type_button.text.strip_edges() != "" else "Apply type to all"
		helper_lines.append("• Tip: After assigning a socket type, press [i]%s[/i] to mirror it across this tile." % bulk_label)
	if editor_bulk_allow_self_button:
		var self_label := editor_bulk_allow_self_button.text if editor_bulk_allow_self_button.text.strip_edges() != "" else "Sync self-allow"
		helper_lines.append("• Tip: Use [i]%s[/i] to copy the self-matching setting to every socket." % self_label)
	if not _include_self_matches:
		helper_lines.append("• Need this tile to connect to itself? Enable [i]Allow self matches[/i] above.")
	if lines.is_empty() and helper_lines.is_empty():
		lines.append("• Review sockets in the Editor tab to assign types and partners.")
	lines.append_array(helper_lines)
	if lines.is_empty():
		wizard_guidance_label.visible = false
		wizard_guidance_label.text = ""
		return
	wizard_guidance_label.visible = true
	wizard_guidance_label.text = "\n".join(lines)

func _build_guidance_entry_for_analysis(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var direction: Vector3i = info.get("direction", Vector3i.ZERO)
	var dir_label := _direction_to_label(direction)
	var segments: Array[String] = []
	var has_socket := bool(info.get("has_socket", false))
	var suggestion: Dictionary = info.get("suggestion", {})
	var issues: Array = info.get("issues", [])
	if not has_socket:
		segments.append("Add a socket on this side so matches can be generated.")
	if not suggestion.is_empty():
		var socket_id := String(suggestion.get("socket_id", "")).strip_edges()
		var partner_tile: Tile = suggestion.get("partner_tile", null)
		var partner_name := partner_tile.name if partner_tile else "matching tile"
		if socket_id == "":
			segments.append("Assign a socket type to connect with '%s'." % partner_name)
		else:
			segments.append("Use [b]%s[/b] to pair with '%s'." % [socket_id, partner_name])
		var detail: Dictionary = suggestion.get("detail", {})
		if detail and not bool(detail.get("within_center", true)):
			var center_delta: Vector2 = detail.get("center_delta", Vector2.ZERO)
			segments.append("Offset %.3f / %.3f units — adjust geometry if needed." % [center_delta.x, center_delta.y])
	else:
		var best_candidate := info.get("best_candidate", null)
		if best_candidate == null:
			if has_socket:
				segments.append("No compatible partner modules detected yet.")
		else:
			var candidate_tile: Tile = best_candidate.get("tile", null)
			var candidate_name := candidate_tile.name if candidate_tile else "candidate tile"
			var detail: Dictionary = best_candidate.get("detail", {})
			if detail.get("within_tolerance", false):
				var partner_socket: Socket = best_candidate.get("partner_socket", null)
				var partner_id := partner_socket.socket_id.strip_edges() if partner_socket else ""
				if partner_id != "":
					segments.append("Match '%s' (%s) is close — assign this type to connect." % [candidate_name, partner_id])
				else:
					segments.append("Match '%s' needs a socket type before it can connect." % candidate_name)
			else:
				if not bool(detail.get("within_dimension", true)):
					var dim_delta: Vector2 = detail.get("dimension_delta", Vector2.ZERO)
					segments.append("Closest outline '%s' differs by %.3f / %.3f units." % [candidate_name, dim_delta.x, dim_delta.y])
				if not bool(detail.get("within_center", true)):
					var center_delta: Vector2 = detail.get("center_delta", Vector2.ZERO)
					segments.append("Center offset against '%s' is %.3f / %.3f units." % [candidate_name, center_delta.x, center_delta.y])
	for issue in issues:
		var issue_text := String(issue)
		if issue_text.begins_with("No socket defined"):
			continue
		if issue_text not in segments:
			segments.append(issue_text)
	if segments.is_empty():
		return ""
	return "• [b]%s[/b]: %s" % [dir_label, " ".join(segments)]

func _setup_template_controls() -> void:
	if template_option == null or apply_template_button == null:
		return
	template_option.item_selected.connect(_on_template_option_selected)
	apply_template_button.pressed.connect(_on_apply_template_pressed)
	_update_template_controls_state()

func _setup_include_self_toggle() -> void:
	if include_self_toggle == null:
		return
	_is_updating_self_toggle = true
	include_self_toggle.button_pressed = false
	_is_updating_self_toggle = false
	include_self_toggle.toggled.connect(_on_include_self_toggle_toggled)
	if include_self_toggle.tooltip_text.strip_edges() == "":
		include_self_toggle.tooltip_text = "When enabled, allow sockets on this tile to match compatible sockets on the same tile."
	_update_self_toggle_state()

func _set_include_self_toggle(pressed: bool) -> void:
	if include_self_toggle == null:
		return
	if include_self_toggle.button_pressed == pressed:
		return
	_is_updating_self_toggle = true
	include_self_toggle.button_pressed = pressed
	_is_updating_self_toggle = false

func _update_self_toggle_state() -> void:
	if include_self_toggle == null:
		return
	var enabled := _current_tile != null and _current_library != null
	include_self_toggle.disabled = not enabled
	if not enabled:
		_set_include_self_toggle(false)
	var container := include_self_toggle.get_parent()
	if container:
		container.visible = enabled

func _setup_editor_controls() -> void:
	if editor_socket_list and not editor_socket_list.item_selected.is_connected(_on_editor_socket_selected):
		editor_socket_list.item_selected.connect(_on_editor_socket_selected)
	if editor_allow_self_checkbox and not editor_allow_self_checkbox.toggled.is_connected(_on_editor_allow_self_toggled):
		editor_allow_self_checkbox.toggled.connect(_on_editor_allow_self_toggled)
	if editor_rotation_option and not editor_rotation_option.item_selected.is_connected(_on_editor_rotation_selected):
		editor_rotation_option.item_selected.connect(_on_editor_rotation_selected)
	if editor_socket_type_option and not editor_socket_type_option.item_selected.is_connected(_on_editor_socket_type_selected):
		editor_socket_type_option.item_selected.connect(_on_editor_socket_type_selected)
	if editor_reciprocal_checkbox and not editor_reciprocal_checkbox.toggled.is_connected(_on_editor_global_reciprocal_toggled):
		editor_reciprocal_checkbox.toggled.connect(_on_editor_global_reciprocal_toggled)
	if editor_template_option and not editor_template_option.item_selected.is_connected(_on_editor_template_selected):
		editor_template_option.item_selected.connect(_on_editor_template_selected)
	if editor_apply_template_button and not editor_apply_template_button.pressed.is_connected(_on_editor_apply_template_pressed):
		editor_apply_template_button.pressed.connect(_on_editor_apply_template_pressed)
	if editor_bulk_apply_type_button and not editor_bulk_apply_type_button.pressed.is_connected(_on_editor_bulk_apply_type_pressed):
		editor_bulk_apply_type_button.pressed.connect(_on_editor_bulk_apply_type_pressed)
	if editor_bulk_allow_self_button and not editor_bulk_allow_self_button.pressed.is_connected(_on_editor_bulk_allow_self_pressed):
		editor_bulk_allow_self_button.pressed.connect(_on_editor_bulk_allow_self_pressed)
	_editor_setup_rotation_option()

func _setup_editor_state() -> void:
	_editor_load_templates()
	_editor_build_socket_states()
	if editor_tile_label:
		editor_tile_label.text = "Tile: %s" % (_current_tile.name if _current_tile else "(none)")
	if _editor_socket_states.is_empty():
		if editor_socket_header:
			editor_socket_header.text = "No sockets available"
		if editor_allow_self_checkbox:
			editor_allow_self_checkbox.button_pressed = false
	else:
		if editor_socket_list:
			editor_socket_list.select(0)
		_on_editor_socket_selected(0)
	_editor_refresh_socket_list_labels()

func _set_mode(mode: int) -> void:
	if mode_tabs == null:
		_current_mode = Mode.SUGGESTIONS
		return
	_current_mode = mode
	mode_tabs.current_tab = mode
	_update_mode_ui()

func _on_mode_tab_changed(index: int) -> void:
	_current_mode = index
	_update_mode_ui()

func _update_mode_ui() -> void:
	var ok_button := get_ok_button()
	if ok_button:
		if _current_mode == Mode.EDITOR:
			ok_button.text = "Apply Changes"
		else:
			ok_button.text = "Apply Suggestions"
	if _cancel_button:
		_cancel_button.text = "Close" if _current_mode == Mode.EDITOR else "Skip"
	if _modify_button:
		_modify_button.visible = _current_mode == Mode.SUGGESTIONS
	if mode_tabs:
		mode_tabs.set_tab_disabled(Mode.SUGGESTIONS, _current_tile == null or _current_library == null)
		mode_tabs.set_tab_disabled(Mode.EDITOR, _current_tile == null or _current_library == null)

func _on_include_self_toggle_toggled(pressed: bool) -> void:
	if _is_updating_self_toggle:
		return
	_store_current_suggestions_for_mode(_include_self_matches)
	_include_self_matches = pressed
	_apply_suggestion_source()

func _store_current_suggestions_for_mode(include_self: bool) -> void:
	_capture_tree_checks_into_suggestions()
	var copy := _suggestions.duplicate(true)
	copy = _normalize_suggestion_list(copy)
	if include_self:
		_self_suggestions = copy
	else:
		_base_suggestions = copy

func _capture_tree_checks_into_suggestions() -> void:
	if suggestion_tree == null:
		return
	var root := suggestion_tree.get_root()
	if root == null:
		return
	var item := root.get_first_child()
	while item:
		var index := int(item.get_metadata(0))
		if index >= 0 and index < _suggestions.size():
			var entry: Dictionary = _suggestions[index]
			entry["use"] = item.is_checked(0)
			_suggestions[index] = entry
		item = item.get_next()

func _normalize_suggestion_list(list: Array) -> Array:
	for i in range(list.size()):
		var entry: Dictionary = list[i]
		if entry == null:
			entry = {}
		if not entry.has("use"):
			entry["use"] = true
		list[i] = entry
	return list

func _apply_suggestion_source(force_rebuild: bool = false) -> void:
	if _current_tile == null or _current_library == null:
		if force_rebuild:
			_base_suggestions = []
			_self_suggestions = []
		_suggestions = []
		_current_analysis = {}
		_update_summary()
		if suggestion_tree == null:
			_pending_tree_refresh = true
		else:
			_populate_tree()
		_on_tree_nothing_selected()
		_update_type_editor_state()
		_update_accept_button_state()
		_update_self_toggle_state()
		return

	if force_rebuild:
		_base_suggestions = SocketSuggestionBuilder.build_suggestions(_current_tile, _current_library, false)
		_base_suggestions = _normalize_suggestion_list(_base_suggestions)
		if _include_self_matches:
			_self_suggestions = SocketSuggestionBuilder.build_suggestions(_current_tile, _current_library, true)
			_self_suggestions = _normalize_suggestion_list(_self_suggestions)
		else:
			_self_suggestions = []
	else:
		if not _include_self_matches and _base_suggestions.is_empty():
			_base_suggestions = SocketSuggestionBuilder.build_suggestions(_current_tile, _current_library, false)
			_base_suggestions = _normalize_suggestion_list(_base_suggestions)
		if _include_self_matches and _self_suggestions.is_empty():
			_self_suggestions = SocketSuggestionBuilder.build_suggestions(_current_tile, _current_library, true)
			_self_suggestions = _normalize_suggestion_list(_self_suggestions)

	var source := _self_suggestions if _include_self_matches else _base_suggestions
	_suggestions = source.duplicate(true)
	_suggestions = _normalize_suggestion_list(_suggestions)
	_current_analysis = SocketSuggestionBuilder.analyze_faces(_current_tile, _current_library, _include_self_matches)
	_update_summary()
	if suggestion_tree == null:
		_pending_tree_refresh = true
	else:
		_populate_tree()
	_on_tree_nothing_selected()
	_update_type_editor_state()
	_update_accept_button_state()
	_update_self_toggle_state()

func _refresh_template_option() -> void:
	if template_option == null:
		return
	var previous_block := template_option.is_blocking_signals()
	template_option.set_block_signals(true)
	_suggestion_template_cache = SocketTemplateLibrary.get_all_templates()
	template_option.clear()
	template_option.add_item("-- Select Template --", TEMPLATE_PLACEHOLDER_ID)
	template_option.set_item_disabled(0, true)
	for i in range(_suggestion_template_cache.size()):
		var tpl := _suggestion_template_cache[i]
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
	var has_templates := not _suggestion_template_cache.is_empty()
	template_option.disabled = not has_context or not has_templates
	apply_template_button.disabled = true
	if template_panel:
		template_panel.visible = has_templates

func _on_template_option_selected(index: int) -> void:
	if template_option == null or apply_template_button == null:
		return
	var item_id := template_option.get_item_id(index)
	var valid := item_id >= 0 and item_id < _suggestion_template_cache.size() and _current_tile != null and _current_library != null
	apply_template_button.disabled = not valid

func _on_apply_template_pressed() -> void:
	if template_option == null:
		return
	var template_id := template_option.get_selected_id()
	_apply_template_from_cache(template_id)

func _apply_template_from_cache(template_id: int) -> void:
	if _current_tile == null or _current_library == null:
		return
	if template_id < 0 or template_id >= _suggestion_template_cache.size():
		return
	var template := _suggestion_template_cache[template_id]
	SocketTemplateLibrary.apply_template(_current_tile, template, _current_library)
	_apply_suggestion_source(true)

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
	_capture_tree_checks_into_suggestions()
	_update_accept_button_state()

func _update_accept_button_state() -> void:
	var button := get_ok_button()
	if button == null:
		return
	if _current_tile == null:
		button.disabled = true
		return
	button.disabled = false

func _editor_load_templates() -> void:
	if editor_template_option == null:
		return
	_editor_template_cache = SocketTemplateLibrary.get_all_templates()
	editor_template_option.clear()
	editor_template_option.add_item("Select a template", -1)
	for i in range(_editor_template_cache.size()):
		var tpl: SocketTemplate = _editor_template_cache[i]
		editor_template_option.add_item("%s" % tpl.template_name, i)
		editor_template_option.set_item_metadata(editor_template_option.item_count - 1, i)

func _editor_setup_rotation_option() -> void:
	if editor_rotation_option == null:
		return
	editor_rotation_option.clear()
	editor_rotation_option.add_item("No minimum", 0)
	editor_rotation_option.set_item_metadata(0, 0)
	editor_rotation_option.add_item(">= 90°", 1)
	editor_rotation_option.set_item_metadata(1, 90)
	editor_rotation_option.add_item(">= 180°", 2)
	editor_rotation_option.set_item_metadata(2, 180)

func _editor_build_socket_states() -> void:
	_editor_socket_states.clear()
	if editor_socket_list:
		editor_socket_list.clear()
	if _current_tile == null:
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
		var socket := _current_tile.get_socket_by_direction(direction)
		if socket == null:
			continue
		var working: Socket = socket.duplicate(true)
		var state := {
			"direction": direction,
			"original": socket,
			"working": working,
			"allow_self": working.socket_id != "" and working.socket_id in working.compatible_sockets,
			"rotation": _editor_extract_rotation_requirement(socket),
			"connection_rows": [],
			"connection_data": {}
		}
		_editor_apply_rotation_to_socket_resource(working, state["rotation"])
		_editor_sync_self_compatibility(state)
		_editor_socket_states.append(state)
		if editor_socket_list:
			editor_socket_list.add_item(_editor_format_socket_label(direction, working.socket_id))

func _editor_format_socket_label(direction: Vector3i, socket_id: String) -> String:
	var dir_name := _direction_to_label(direction)
	var id_label := socket_id if socket_id.strip_edges() != "" else "(unset)"
	return "%s — %s" % [dir_name, id_label]

func _on_editor_socket_selected(index: int) -> void:
	if index < 0 or index >= _editor_socket_states.size():
		return
	if _editor_current_socket_index >= 0 and _editor_current_socket_index < _editor_socket_states.size():
		_editor_capture_connection_rows(_editor_socket_states[_editor_current_socket_index])
	_editor_current_socket_index = index
	var state: Dictionary = _editor_socket_states[index]
	_editor_update_socket_editor(state)

func _editor_update_socket_editor(state: Dictionary) -> void:
	if editor_socket_header == null:
		return
	var working: Socket = state.get("working")
	editor_socket_header.text = "%s socket (%s)" % [_direction_to_label(state.get("direction")), working.socket_id if working.socket_id != "" else "unset"]
	_editor_allow_self_ui_update(state)
	_editor_refresh_socket_type_option(state)
	_editor_update_rotation_option(state)
	_editor_build_connections_ui(state)
	_editor_refresh_connections_hint(state)
	_refresh_editor_warnings()

func _editor_capture_connection_rows(state: Dictionary) -> void:
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

func _editor_ensure_connection_data(state: Dictionary) -> void:
	if state == null:
		return
	if not state.has("connection_data") or state["connection_data"] == null:
		state["connection_data"] = {}
	var data_map: Dictionary = state["connection_data"]
	var working: Socket = state.get("working")
	if working == null or _current_library == null:
		state["connection_data"] = {}
		return
	var dir: Vector3i = state.get("direction", Vector3i.ZERO)
	var opposite_dir := Vector3i(-dir.x, -dir.y, -dir.z)
	var working_id := working.socket_id.strip_edges()
	var tiles_present: Dictionary = {}
	for other_tile in _current_library.tiles:
		tiles_present[other_tile] = true
		if other_tile == _current_tile:
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
		if stored_tile == _current_tile:
			data_map.erase(stored_tile)
			continue
		if not tiles_present.has(stored_tile):
			data_map.erase(stored_tile)

func _editor_extract_rotation_requirement(socket: Socket) -> int:
	for req in socket.requirements:
		if req is RotationRequirement:
			return int(req.minimum_rotation_degrees)
	return 0

func _editor_apply_rotation_to_socket_resource(socket: Socket, degrees: int) -> void:
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

func _editor_sync_self_compatibility(state: Dictionary, socket_id_override: String = "") -> void:
	if state == null:
		return
	var working: Socket = state.get("working", null)
	if working == null:
		return
	var resolved_id := String(socket_id_override if socket_id_override != "" else working.socket_id).strip_edges()
	var compat: Array[String] = []
	compat.assign(working.compatible_sockets)
	if bool(state.get("allow_self", false)) and resolved_id != "":
		if resolved_id not in compat:
			compat.append(resolved_id)
	else:
		if resolved_id in compat:
			compat.erase(resolved_id)
	working.compatible_sockets = _string_array(compat)

func _editor_allow_self_ui_update(state: Dictionary) -> void:
	if editor_allow_self_checkbox:
		editor_allow_self_checkbox.button_pressed = state.get("allow_self", false)

func _editor_refresh_socket_type_option(state: Dictionary) -> void:
	if editor_socket_type_option == null:
		return
	var previous_block := editor_socket_type_option.is_blocking_signals()
	editor_socket_type_option.set_block_signals(true)
	editor_socket_type_option.clear()
	editor_socket_type_option.add_item("(unset)")
	editor_socket_type_option.set_item_metadata(0, "")
	var types: Array[String] = []
	if _current_library:
		types = _current_library.get_socket_types()
	for type_name in types:
		editor_socket_type_option.add_item(type_name)
		editor_socket_type_option.set_item_metadata(editor_socket_type_option.item_count - 1, type_name)
	var working: Socket = state.get("working", null)
	var current_id := working.socket_id if working else ""
	current_id = current_id.strip_edges()
	if current_id != "" and current_id not in types:
		editor_socket_type_option.add_separator()
		editor_socket_type_option.add_item("%s (custom)" % current_id)
		editor_socket_type_option.set_item_metadata(editor_socket_type_option.item_count - 1, CUSTOM_SOCKET_TYPE_TOKEN)
	editor_socket_type_option.add_separator()
	editor_socket_type_option.add_item("+ Add New Type…")
	editor_socket_type_option.set_item_metadata(editor_socket_type_option.item_count - 1, EDITOR_ADD_NEW_TYPE_TOKEN)
	var target_index := 0
	for i in range(editor_socket_type_option.item_count):
		if editor_socket_type_option.is_item_separator(i):
			continue
		var metadata := editor_socket_type_option.get_item_metadata(i)
		if metadata == current_id:
			target_index = i
			break
		if metadata == CUSTOM_SOCKET_TYPE_TOKEN and current_id != "":
			target_index = i
	editor_socket_type_option.select(target_index)
	editor_socket_type_option.set_block_signals(previous_block)

func _editor_update_rotation_option(state: Dictionary) -> void:
	if editor_rotation_option == null:
		return
	var prev_block := editor_rotation_option.is_blocking_signals()
	editor_rotation_option.set_block_signals(true)
	var current_rotation: int = int(state.get("rotation", 0))
	var target_index := 0
	for i in range(editor_rotation_option.item_count):
		var val := int(editor_rotation_option.get_item_metadata(i))
		if val == current_rotation:
			target_index = i
	editor_rotation_option.select(target_index)
	editor_rotation_option.set_block_signals(prev_block)

func _editor_build_connections_ui(state: Dictionary) -> void:
	if editor_connections_container == null:
		return
	for child in editor_connections_container.get_children():
		child.queue_free()
	state["connection_rows"] = []
	if _current_library == null:
		if editor_connections_info:
			editor_connections_info.text = "No library available to build connections."
		return
	_editor_ensure_connection_data(state)
	var data_map: Dictionary = state.get("connection_data", {})
	var rows: Array = []
	for other_tile in _current_library.tiles:
		if other_tile == _current_tile:
			continue
		if not data_map.has(other_tile):
			continue
		var entry: Dictionary = data_map[other_tile]
		var default_direction := entry.get("direction", Vector3i(-state.get("direction", Vector3i.ZERO).x, -state.get("direction", Vector3i.ZERO).y, -state.get("direction", Vector3i.ZERO).z))
		var row := _editor_create_connection_row(state, entry, default_direction)
		rows.append(row)
	state["connection_rows"] = rows
	if rows.is_empty():
		var info := Label.new()
		info.text = "No other tiles in the library yet."
		editor_connections_container.add_child(info)
	_editor_refresh_connections_hint(state)
	_refresh_editor_warnings()

func _editor_create_connection_row(state: Dictionary, entry: Dictionary, default_direction: Vector3i) -> Dictionary:
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
	reciprocal.button_pressed = entry.get("reciprocal", editor_reciprocal_checkbox and editor_reciprocal_checkbox.button_pressed)
	row_container.add_child(reciprocal)

	editor_connections_container.add_child(row_container)

	_editor_populate_partner_option(partner_option, entry, default_direction)
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
				_editor_refresh_connections_hint(state)
				_refresh_editor_warnings()
				return
		current_entry["connect"] = pressed
		_editor_refresh_connections_hint(state)
		_refresh_editor_warnings()
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
		_editor_refresh_connections_hint(state)
		_refresh_editor_warnings()
	)

	reciprocal.toggled.connect(func(pressed: bool) -> void:
		entry["reciprocal"] = pressed
		_refresh_editor_warnings()
	)

	return {
		"entry": entry,
		"tile": other_tile,
		"checkbox": toggle,
		"option": partner_option,
		"reciprocal": reciprocal
	}

func _editor_populate_partner_option(option: OptionButton, entry: Dictionary, default_direction: Vector3i) -> void:
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

func _editor_refresh_connections_hint(state: Dictionary) -> void:
	if editor_connections_info == null:
		return
	var count := 0
	var data_map: Dictionary = state.get("connection_data", {})
	for entry in data_map.values():
		if entry.get("connect", false):
			count += 1
	var working: Socket = state.get("working")
	editor_connections_info.text = "Socket '%s' currently allows %d partner types." % [
		working.socket_id if working.socket_id != "" else "unset",
		count
	]

func _refresh_editor_warnings() -> void:
	if editor_issues_label == null:
		return
	var warnings := _compute_editor_warnings()
	if warnings.is_empty():
		editor_issues_label.visible = false
		editor_issues_label.text = ""
		return
	editor_issues_label.visible = true
	var lines: Array[String] = []
	for warning in warnings:
		lines.append("[color=yellow]• %s[/color]" % warning)
	editor_issues_label.text = "\n".join(lines)

func _compute_editor_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if _current_tile == null:
		return warnings
	for state in _editor_socket_states:
		if state == null:
			continue
		var working: Socket = state.get("working")
		if working == null:
			continue
		var dir_label := _direction_to_label(state.get("direction", Vector3i.ZERO))
		var socket_id := working.socket_id.strip_edges()
		if socket_id == "":
			warnings.append("%s socket has no type assigned." % dir_label)
		if state.get("allow_self", false) and socket_id == "":
			warnings.append("%s socket allows self connections but lacks a socket type." % dir_label)
		_editor_ensure_connection_data(state)
		var data_map: Dictionary = state.get("connection_data", {})
		for entry in data_map.values():
			if entry == null:
				continue
			if not bool(entry.get("connect", false)):
				continue
			var partner_tile: Tile = entry.get("tile", null)
			var partner_name := partner_tile.name if partner_tile else "partner tile"
			var partner_socket: Socket = entry.get("socket", null)
			if partner_socket == null:
				warnings.append("%s socket connects to '%s' but no socket was chosen." % [dir_label, partner_name])
				continue
			var partner_id := partner_socket.socket_id.strip_edges()
			if partner_id == "" or partner_id == "none":
				warnings.append("%s socket links to '%s' but the partner socket lacks a type." % [dir_label, partner_name])
			if not bool(entry.get("reciprocal", false)):
				warnings.append("%s socket links to '%s' without reciprocal permissions." % [dir_label, partner_name])
	return warnings

func _editor_refresh_socket_list_labels() -> void:
	if editor_socket_list == null:
		return
	for i in range(_editor_socket_states.size()):
		var state: Dictionary = _editor_socket_states[i]
		var label := _editor_format_socket_label(state.get("direction", Vector3i.ZERO), state.get("working", Socket.new()).socket_id)
		editor_socket_list.set_item_text(i, label)

func _on_editor_allow_self_toggled(pressed: bool) -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var state: Dictionary = _editor_socket_states[_editor_current_socket_index]
	state["allow_self"] = pressed
	_editor_sync_self_compatibility(state)
	_editor_refresh_connections_hint(state)
	_refresh_editor_warnings()

func _on_editor_rotation_selected(index: int) -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var degrees := int(editor_rotation_option.get_item_metadata(index))
	_editor_socket_states[_editor_current_socket_index]["rotation"] = degrees
	_refresh_editor_warnings()

func _on_editor_socket_type_selected(index: int) -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var metadata = editor_socket_type_option.get_item_metadata(index)
	if metadata == EDITOR_ADD_NEW_TYPE_TOKEN:
		_editor_prompt_new_socket_type()
		return
	var state: Dictionary = _editor_socket_states[_editor_current_socket_index]
	var working: Socket = state.get("working")
	var new_id := ""
	if metadata == CUSTOM_SOCKET_TYPE_TOKEN:
		new_id = working.socket_id
	else:
		new_id = str(metadata)
	working.socket_id = String(new_id).strip_edges()
	_editor_sync_self_compatibility(state, working.socket_id)
	_editor_refresh_socket_list_labels()
	_editor_refresh_connections_hint(state)
	_refresh_editor_warnings()

func _editor_prompt_new_socket_type() -> void:
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
		if _current_library:
			_current_library.register_socket_type(new_id)
		if _editor_current_socket_index >= 0 and _editor_current_socket_index < _editor_socket_states.size():
			var state: Dictionary = _editor_socket_states[_editor_current_socket_index]
			var working: Socket = state.get("working")
			working.socket_id = new_id
			_editor_sync_self_compatibility(state, new_id)
			_editor_refresh_socket_type_option(state)
			_editor_refresh_socket_list_labels()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	input.grab_focus()

func _on_editor_global_reciprocal_toggled(pressed: bool) -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var state: Dictionary = _editor_socket_states[_editor_current_socket_index]
	for row_data in state.get("connection_rows", []):
		var entry: Dictionary = row_data.get("entry", {})
		entry["reciprocal"] = pressed
		var reciprocal: CheckBox = row_data.get("reciprocal")
		if reciprocal and is_instance_valid(reciprocal):
			reciprocal.button_pressed = pressed
	var data_map: Dictionary = state.get("connection_data", {})
	for entry in data_map.values():
		entry["reciprocal"] = pressed
	_refresh_editor_warnings()

func _on_editor_template_selected(_index: int) -> void:
	pass

func _on_editor_apply_template_pressed() -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var template_id := editor_template_option.get_item_metadata(editor_template_option.selected)
	if template_id == null or int(template_id) < 0:
		return
	if template_id < 0 or template_id >= _editor_template_cache.size():
		return
	var template: SocketTemplate = _editor_template_cache[template_id]
	_editor_apply_template_to_states(template)
	_editor_refresh_socket_list_labels()
	_editor_update_socket_editor(_editor_socket_states[_editor_current_socket_index])

func _editor_apply_template_to_states(template: SocketTemplate) -> void:
	var normalized: Dictionary = {}
	for raw_entry in template.entries:
		var entry := SocketTemplate.normalize_entry(raw_entry)
		normalized[entry["direction"]] = entry
	for state in _editor_socket_states:
		var entry: Dictionary = normalized.get(state.get("direction"), {})
		var working: Socket = state.get("working")
		if entry.is_empty():
			working.socket_id = ""
			working.compatible_sockets = []
			state["allow_self"] = false
			state["rotation"] = 0
			_editor_apply_rotation_to_socket_resource(working, 0)
			_editor_sync_self_compatibility(state)
			continue
		working.socket_id = str(entry["socket_id"]).strip_edges()
		var compat: Array[String] = []
		var raw_compat = entry.get("compatible", [])
		for compat_id in raw_compat:
			var trimmed := str(compat_id).strip_edges()
			if trimmed != "":
				compat.append(trimmed)
		working.compatible_sockets = compat
		state["allow_self"] = compat.has(working.socket_id) and working.socket_id != ""
		state["rotation"] = int(entry.get("minimum_rotation_degrees", 0))
		_editor_apply_rotation_to_socket_resource(working, state["rotation"])
		_editor_sync_self_compatibility(state)

func _on_editor_bulk_apply_type_pressed() -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var source_state: Dictionary = _editor_socket_states[_editor_current_socket_index]
	var working: Socket = source_state.get("working")
	if working == null:
		return
	var socket_id := String(working.socket_id).strip_edges()
	if socket_id == "":
		return
	if _current_library:
		_current_library.register_socket_type(socket_id)
	for i in range(_editor_socket_states.size()):
		var state: Dictionary = _editor_socket_states[i]
		var target_socket: Socket = state.get("working")
		if target_socket == null:
			continue
		target_socket.socket_id = socket_id
		_editor_sync_self_compatibility(state, socket_id)
	_editor_refresh_socket_list_labels()
	_editor_update_socket_editor(_editor_socket_states[_editor_current_socket_index])
	_refresh_editor_warnings()

func _on_editor_bulk_allow_self_pressed() -> void:
	if _editor_current_socket_index < 0 or _editor_current_socket_index >= _editor_socket_states.size():
		return
	var source_state: Dictionary = _editor_socket_states[_editor_current_socket_index]
	var enable := bool(source_state.get("allow_self", false))
	for state in _editor_socket_states:
		state["allow_self"] = enable
		_editor_sync_self_compatibility(state)
	_editor_allow_self_ui_update(source_state)
	_editor_refresh_connections_hint(source_state)
	_refresh_editor_warnings()

func _editor_apply_changes() -> Array[Tile]:
	if _current_tile == null:
		return []
	var changed_tiles: Dictionary = {}
	changed_tiles[_current_tile] = true
	for state in _editor_socket_states:
		_editor_capture_connection_rows(state)
		_editor_ensure_connection_data(state)
		var working: Socket = state.get("working")
		var socket_id := working.socket_id.strip_edges()
		working.socket_id = socket_id
		var compat_ids: Array[String] = []
		if state.get("allow_self", false) and socket_id != "":
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
				if _editor_remove_partner_compat_if_needed(partner_tile, metadata, socket_id):
					changed_tiles[partner_tile] = true
				continue
			if socket_id == "":
				push_warning("Cannot link tiles without assigning a socket type first.")
				continue
			var partner_socket := _editor_ensure_partner_socket(partner_tile, metadata)
			entry["socket"] = partner_socket
			if partner_socket == null:
				continue
			var partner_modified := false
			var partner_id := partner_socket.socket_id.strip_edges()
			if partner_id == "" or partner_id == "none":
				partner_id = socket_id
				partner_socket.socket_id = partner_id
				partner_modified = true
			if _current_library:
				_current_library.register_socket_type(partner_id)
			if partner_id != "" and partner_id not in compat_ids:
				compat_ids.append(partner_id)
			if reciprocal_enabled and socket_id != "":
				partner_modified = _editor_add_unique_socket_id(partner_socket, socket_id) or partner_modified
			else:
				partner_modified = _editor_remove_socket_id(partner_socket, socket_id) or partner_modified
			if partner_modified:
				partner_socket.compatible_sockets = _string_array(partner_socket.compatible_sockets)
				partner_tile.sockets = partner_tile.sockets
				changed_tiles[partner_tile] = true
		working.compatible_sockets = compat_ids
		_editor_apply_rotation_to_socket_resource(working, state.get("rotation", 0))
		if _current_library and socket_id != "":
			_current_library.register_socket_type(socket_id)
	for state in _editor_socket_states:
		var original: Socket = state.get("original")
		var working: Socket = state.get("working")
		original.socket_id = working.socket_id
		original.compatible_sockets = _string_array(working.compatible_sockets)
		original.requirements = _editor_duplicate_requirements(working.requirements)
	_current_tile.sockets = _current_tile.sockets
	var result: Array[Tile] = []
	for key in changed_tiles.keys():
		result.append(key)
	return result

func _editor_remove_partner_compat_if_needed(partner_tile: Tile, metadata: Dictionary, socket_id: String) -> bool:
	if socket_id == "":
		return false
	if metadata.is_empty():
		return false
	var partner_socket := metadata.get("socket", null)
	if partner_socket == null:
		return false
	var changed := _editor_remove_socket_id(partner_socket, socket_id)
	if not changed:
		return false
	partner_socket.compatible_sockets = _string_array(partner_socket.compatible_sockets)
	partner_tile.sockets = partner_tile.sockets
	return true

func _editor_ensure_partner_socket(partner_tile: Tile, metadata: Dictionary) -> Socket:
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

func _editor_add_unique_socket_id(socket: Socket, socket_id: String) -> bool:
	if socket_id == "":
		return false
	var compat := _string_array(socket.compatible_sockets)
	if socket_id in compat:
		return false
	compat.append(socket_id)
	socket.compatible_sockets = compat
	return true

func _editor_remove_socket_id(socket: Socket, socket_id: String) -> bool:
	if socket_id == "":
		return false
	var compat := _string_array(socket.compatible_sockets)
	if socket_id not in compat:
		return false
	compat.erase(socket_id)
	socket.compatible_sockets = compat
	return true

func _editor_duplicate_requirements(requirements: Array[Requirement]) -> Array[Requirement]:
	var copy: Array[Requirement] = []
	for req in requirements:
		if req:
			copy.append(req.duplicate(true))
	return copy

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
