extends RefCounted

const SocketSuggestionDialogScene := preload("res://addons/auto_structured/ui/dialogs/socket_suggestion_dialog.tscn")
const ModuleLibrary := preload("res://addons/auto_structured/core/module_library.gd")
const Tile := preload("res://addons/auto_structured/core/tile.gd")
const SocketTemplateLibrary := preload("res://addons/auto_structured/ui/utils/socket_template_library.gd")

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

func _test_apply_template_sets_sockets() -> Variant:
	var builtin_templates := SocketTemplateLibrary.get_builtin_templates()
	if builtin_templates.is_empty():
		return "No built-in templates available"

	var dialog_instance := SocketSuggestionDialogScene.instantiate()
	if dialog_instance == null:
		return "Failed to instantiate suggestion dialog"
	var dialog := dialog_instance as SocketSuggestionDialog
	dialog.summary_label = dialog_instance.get_node("Margin/VBox/SummaryLabel")
	dialog.suggestion_tree = dialog_instance.get_node("Margin/VBox/SuggestionTree")
	dialog.template_panel = dialog_instance.get_node("Margin/VBox/TemplatePanel")
	dialog.template_option = dialog_instance.get_node("Margin/VBox/TemplatePanel/TemplateOption")
	dialog.apply_template_button = dialog_instance.get_node("Margin/VBox/TemplatePanel/ApplyTemplateButton")
	dialog.socket_type_option = dialog_instance.get_node("Margin/VBox/TypeEditor/SocketTypeOption")
	dialog.socket_type_hint = dialog_instance.get_node("Margin/VBox/TypeEditor/SocketTypeHint")
	dialog._setup_tree()
	dialog._setup_template_controls()
	dialog._setup_socket_type_option()

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

	dialog.queue_free()
	dialog.free()
	return null
