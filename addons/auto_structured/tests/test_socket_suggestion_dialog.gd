extends RefCounted

const SocketEditorDialogScene := preload("res://addons/auto_structured/ui/dialogs/socket_suggestion_dialog.tscn")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const Socket := preload("res://addons/auto_structured/core/socket.gd")
const SocketTemplateLibrary := preload("res://addons/auto_structured/ui/utils/socket_template_library.gd")
const SocketSuggestionBuilder := preload("res://addons/auto_structured/core/analysis/socket_suggestion_builder.gd")
const SOCKET_EDITOR_MODE_EDITOR := 1

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}
	_run_test(
		results,
		"Applying template within suggestion dialog populates tile sockets",
		_test_apply_template_sets_sockets
	)
	_run_test(
		results,
		"Self-match toggle enables same-tile suggestions",
		_test_self_match_toggle_enables_self_suggestions
	)
	_run_test(
		results,
		"Suggestion warnings flag missing socket ids",
		_test_suggestion_warning_for_missing_socket
	)
	_run_test(
		results,
		"Editor warnings flag incomplete connections",
		_test_editor_warning_for_incomplete_connection
	)
	_run_test(
		results,
		"Wizard guidance highlights missing sockets",
		_test_wizard_guidance_for_missing_socket
	)
	_run_test(
		results,
		"Bulk editor actions synchronize sockets",
		_test_editor_bulk_actions
	)
	return results

func _run_test(results: Dictionary, name: String, fn: Callable) -> void:
	results["total"] += 1
	var outcome := fn.call()
	while outcome is Object and outcome.get_class() == "GDScriptFunctionState":
		outcome = outcome.resume()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func _create_dialog_for_test() -> SocketEditorDialog:
	var dialog := SocketEditorDialogScene.instantiate() as SocketEditorDialog
	if dialog == null:
		return null
	dialog.mode_tabs = dialog.get_node("Margin/VBox/ModeTabs")
	dialog.summary_label = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/SummaryLabel")
	dialog.summary_warnings_label = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/SummaryWarningsLabel")
	dialog.wizard_guidance_label = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/WizardGuidanceLabel")
	dialog.suggestion_tree = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/SuggestionTree")
	dialog.template_panel = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/TemplatePanel")
	dialog.template_option = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/TemplatePanel/TemplateOption")
	dialog.apply_template_button = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/TemplatePanel/ApplyTemplateButton")
	dialog.include_self_toggle = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/OptionsPanel/IncludeSelfToggle")
	dialog.socket_type_option = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/TypeEditor/SocketTypeOption")
	dialog.socket_type_hint = dialog.get_node("Margin/VBox/ModeTabs/SuggestionsTab/TypeEditor/SocketTypeHint")
	dialog.editor_tile_label = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorTileLabel")
	dialog.editor_template_option = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorTemplatePanel/EditorTemplateOption")
	dialog.editor_apply_template_button = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorTemplatePanel/EditorTemplateHeader/EditorApplyTemplateButton")
	dialog.editor_socket_list = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorSocketColumn/EditorSocketList")
	dialog.editor_socket_header = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorSocketHeader")
	dialog.editor_issues_label = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorIssuesLabel")
	dialog.editor_socket_type_option = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorSocketTypeRow/EditorSocketTypeOption")
	dialog.editor_allow_self_checkbox = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorAllowSelfCheckBox")
	dialog.editor_rotation_option = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorRotationRow/EditorRotationOption")
	dialog.editor_bulk_apply_type_button = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorBulkRow/EditorBulkApplyTypeButton")
	dialog.editor_bulk_allow_self_button = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorBulkRow/EditorBulkAllowSelfButton")
	dialog.editor_reciprocal_checkbox = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorReciprocalCheckBox")
	dialog.editor_connections_container = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorConnectionsScroll/EditorConnectionsContainer")
	dialog.editor_connections_info = dialog.get_node("Margin/VBox/ModeTabs/EditorTab/EditorMainHBox/EditorRightColumn/EditorConnectionsInfo")
	dialog._setup_tree()
	dialog._setup_template_controls()
	dialog._setup_socket_type_option()
	dialog._setup_include_self_toggle()
	dialog._setup_editor_controls()
	return dialog

func _cleanup_dialog(dialog: SocketEditorDialog) -> void:
	if dialog == null:
		return
	dialog.queue_free()
	dialog.free()

func _test_apply_template_sets_sockets() -> Variant:
	var builtin_templates := SocketTemplateLibrary.get_builtin_templates()
	if builtin_templates.is_empty():
		return "No built-in templates available"

	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var library := ModuleLibrary.new()
	library.ensure_defaults()

	var base_tile := Tile.new()
	base_tile.name = "BaseFloor"
	base_tile.ensure_all_sockets()
	SocketTemplateLibrary.apply_template(base_tile, builtin_templates[0], library)

	var new_tile := Tile.new()
	new_tile.name = "Candidate"
	new_tile.ensure_all_sockets()

	var tiles: Array[Tile] = []
	tiles.append(base_tile)
	tiles.append(new_tile)
	library.tiles = tiles

	dialog._current_library = library
	dialog._current_tile = new_tile
	dialog._suggestions = []
	dialog._update_template_controls_state()
	if dialog.template_option.item_count < 2:
		return "Template option did not populate"

	dialog._apply_template_from_cache(0)

	var right_socket := new_tile.get_socket_by_direction(Vector3i.RIGHT)
	if right_socket == null or right_socket.socket_id != "floor_side":
		return "+X socket was not assigned floor_side"

	var down_socket := new_tile.get_socket_by_direction(Vector3i.DOWN)
	if down_socket == null or down_socket.socket_id != "floor_bottom":
		return "-Y socket was not assigned floor_bottom"

	if "floor_side" not in library.socket_types:
		return "Library did not register floor_side type"

	_cleanup_dialog(dialog)
	return null

func _test_self_match_toggle_enables_self_suggestions() -> Variant:
	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var source_library := ResourceLoader.load("res://module_library.tres") as ModuleLibrary
	if source_library == null:
		_cleanup_dialog(dialog)
		return "Sample module library not available"

	var source_tile := source_library.get_tile_by_name("floor")
	if source_tile == null:
		_cleanup_dialog(dialog)
		return "Sample library missing 'floor' tile"

	var tile_copy := source_tile.duplicate(true) as Tile
	if tile_copy == null:
		_cleanup_dialog(dialog)
		return "Failed to duplicate floor tile"
	tile_copy.name = "FloorCopy"

	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tiles: Array[Tile] = []
	tiles.append(tile_copy)
	library.tiles = tiles

	for socket in tile_copy.sockets:
		var socket_id := socket.socket_id.strip_edges()
		if socket_id != "":
			library.register_socket_type(socket_id)
		for compat_id in socket.compatible_sockets:
			var trimmed := String(compat_id).strip_edges()
			if trimmed != "":
				library.register_socket_type(trimmed)

	var base_suggestions := SocketSuggestionBuilder.build_suggestions(tile_copy, library)
	dialog.show_for_tile(tile_copy, library, base_suggestions)

	if not dialog._suggestions.is_empty():
		for entry in dialog._suggestions:
			if entry.get("partner_tile") == tile_copy:
				_cleanup_dialog(dialog)
				return "Self matches should be disabled by default"

	dialog._set_include_self_toggle(true)
	dialog._on_include_self_toggle_toggled(true)

	if dialog._self_suggestions.is_empty():
		_cleanup_dialog(dialog)
		return "Enabling self matches did not produce suggestions"

	var found_self_match := false
	for entry in dialog._suggestions:
		if entry.get("partner_tile") == tile_copy:
			found_self_match = true
			break
	if not found_self_match:
		_cleanup_dialog(dialog)
		return "Self matches were not surfaced after enabling"

	_cleanup_dialog(dialog)
	return null

func _test_suggestion_warning_for_missing_socket() -> Variant:
	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tile := Tile.new()
	tile.name = "Lint"
	tile.ensure_all_sockets()

	dialog._current_tile = tile
	dialog._suggestions = [
		{
			"direction": Vector3i.RIGHT,
			"socket_id": "",
			"use": true
		}
	]
	dialog._update_summary()
	if not dialog.summary_warnings_label.visible:
		_cleanup_dialog(dialog)
		return "Warning label was not shown for missing socket type"
	if "missing" not in dialog.summary_warnings_label.text.to_lower():
		_cleanup_dialog(dialog)
		return "Warning text did not mention missing socket"
	_cleanup_dialog(dialog)
	return null

func _test_editor_warning_for_incomplete_connection() -> Variant:
	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tile := Tile.new()
	tile.name = "EditorTile"
	tile.ensure_all_sockets()

	dialog.show_for_tile(tile, library, [], SOCKET_EDITOR_MODE_EDITOR)
	if dialog._editor_socket_states.is_empty():
		_cleanup_dialog(dialog)
		return "Socket editor did not build states"
	var state: Dictionary = dialog._editor_socket_states[0]
	state["allow_self"] = true
	var working: Socket = state.get("working")
	if working:
		working.socket_id = ""
	dialog._refresh_editor_warnings()
	if not dialog.editor_issues_label.visible:
		_cleanup_dialog(dialog)
		return "Editor warnings were not shown for untyped socket"
	if "socket" not in dialog.editor_issues_label.text.to_lower():
		_cleanup_dialog(dialog)
		return "Editor warning text missing socket reference"
	_cleanup_dialog(dialog)
	return null

func _test_wizard_guidance_for_missing_socket() -> Variant:
	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tile := Tile.new()
	tile.name = "GuidedTile"

	dialog._current_library = library
	dialog._current_tile = tile
	dialog._suggestions = []
	dialog._current_analysis = {
		Vector3i.RIGHT: {
			"direction": Vector3i.RIGHT,
			"has_socket": false,
			"suggestion": {},
			"within_tolerance": false,
			"best_candidate": null,
			"issues": ["No socket defined on this face; connections will be skipped."]
		}
	}
	dialog._update_summary()
	if not dialog.wizard_guidance_label.visible:
		_cleanup_dialog(dialog)
		return "Guidance label was not shown for missing sockets"
	var text := dialog.wizard_guidance_label.text.to_lower()
	if "right" not in text:
		_cleanup_dialog(dialog)
		return "Guidance text did not mention the affected direction"
	if "add a socket" not in text:
		_cleanup_dialog(dialog)
		return "Guidance text did not offer corrective action"
	_cleanup_dialog(dialog)
	return null

func _test_editor_bulk_actions() -> Variant:
	var dialog := _create_dialog_for_test()
	if dialog == null:
		return "Failed to instantiate suggestion dialog"

	var library := ModuleLibrary.new()
	library.ensure_defaults()
	var tile := Tile.new()
	tile.name = "BulkTile"
	tile.ensure_all_sockets()
	var tiles: Array[Tile] = []
	tiles.append(tile)
	library.tiles = tiles

	dialog.show_for_tile(tile, library, [], SOCKET_EDITOR_MODE_EDITOR)
	if dialog._editor_socket_states.size() < 2:
		_cleanup_dialog(dialog)
		return "Socket editor did not build enough states for testing"
	dialog._editor_current_socket_index = 0
	var first_state: Dictionary = dialog._editor_socket_states[0]
	var working: Socket = first_state.get("working")
	if working == null:
		_cleanup_dialog(dialog)
		return "Active socket state missing working socket"
	working.socket_id = "bulk_type"
	dialog._on_editor_bulk_apply_type_pressed()
	for state in dialog._editor_socket_states:
		var state_socket: Socket = state.get("working")
		if state_socket == null or state_socket.socket_id != "bulk_type":
			_cleanup_dialog(dialog)
			return "Bulk apply did not synchronize socket types"
	if "bulk_type" not in library.socket_types:
		_cleanup_dialog(dialog)
		return "Bulk apply did not register the new socket type"
	dialog._on_editor_allow_self_toggled(true)
	dialog._on_editor_bulk_allow_self_pressed()
	for state in dialog._editor_socket_states:
		if not state.get("allow_self", false):
			_cleanup_dialog(dialog)
			return "Bulk self sync did not copy allow_self flag"
		var check_socket: Socket = state.get("working")
		if check_socket.socket_id != "" and "bulk_type" not in check_socket.compatible_sockets:
			_cleanup_dialog(dialog)
			return "Self compatibility missing after bulk sync"
	_cleanup_dialog(dialog)
	return null
