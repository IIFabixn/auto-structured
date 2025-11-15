@tool
class_name PreviewSettingsDialog extends Control

const WfcStrategyBase = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd")
const WfcStrategyFillAll = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_fill_all.gd")
const WfcStrategyGroundWalls = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_ground_walls.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const StrategyPresetStore = preload("res://addons/auto_structured/ui/dialogs/strategy_preset_store.gd")

signal apply_requested(strategy: WfcStrategyBase)
signal cell_size_changed(new_size: Vector3)

@onready var x_spinbox: SpinBox = %XSpinBox
@onready var y_spinbox: SpinBox = %YSpinBox
@onready var z_spinbox: SpinBox = %ZSpinBox
@onready var strategy_option: OptionButton = %StrategyOption
@onready var strategy_description: RichTextLabel = %StrategyDescription
@onready var warning_panel: PanelContainer = %WarningPanel
@onready var warning_label: RichTextLabel = %WarningLabel
@onready var options_panel: PanelContainer = %OptionsPanel
@onready var strategy_options_container: VBoxContainer = %StrategyOptionsContainer
@onready var options_placeholder: Label = %OptionsPlaceholder
@onready var reset_button: Button = %ResetButton
@onready var save_preset_button: Button = %SavePresetButton
@onready var load_preset_button: MenuButton = %LoadPresetButton
@onready var apply_button: Button = %ApplyButton
@onready var save_preset_dialog: AcceptDialog = %SavePresetDialog
@onready var preset_name_edit: LineEdit = %PresetNameEdit
@onready var cell_x_spinbox: SpinBox = %CellXSpinBox
@onready var cell_y_spinbox: SpinBox = %CellYSpinBox
@onready var cell_z_spinbox: SpinBox = %CellZSpinBox

# Grid size
var grid_size: Vector3i = Vector3i(5, 5, 5)

# Cell size (world units)
var cell_world_size: Vector3 = Vector3(1, 1, 1)

# Strategy management
var available_strategies: Array[WfcStrategyBase] = []
var current_strategy_index: int = 0
var strategy_keys: Array[String] = []
var strategy_defaults: Dictionary = {}

# Preset storage
var preset_store := StrategyPresetStore.new()
var _current_presets: Array[String] = []

# Active module library (for tag coverage checks)
var module_library: ModuleLibrary = null


func _ready() -> void:
	# Discover and initialize available strategies automatically
	_discover_strategies()
	current_strategy_index = 0
	
	# Initialize grid size spinboxes
	x_spinbox.value = grid_size.x
	y_spinbox.value = grid_size.y
	z_spinbox.value = grid_size.z
	x_spinbox.value_changed.connect(_on_grid_size_changed)
	y_spinbox.value_changed.connect(_on_grid_size_changed)
	z_spinbox.value_changed.connect(_on_grid_size_changed)
	cell_x_spinbox.value = cell_world_size.x
	cell_y_spinbox.value = cell_world_size.y
	cell_z_spinbox.value = cell_world_size.z
	cell_x_spinbox.value_changed.connect(_on_cell_size_changed)
	cell_y_spinbox.value_changed.connect(_on_cell_size_changed)
	cell_z_spinbox.value_changed.connect(_on_cell_size_changed)
	reset_button.pressed.connect(_on_reset_pressed)
	save_preset_button.pressed.connect(_on_save_preset_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	save_preset_dialog.confirmed.connect(_commit_save_preset)
	preset_name_edit.text_submitted.connect(func(_text):
		save_preset_dialog.accept()
	)
	var preset_popup := load_preset_button.get_popup()
	preset_popup.id_pressed.connect(_on_preset_menu_id_pressed)
	
	# Initialize strategy dropdown (clear first to avoid duplicates)
	strategy_option.clear()
	for strategy in available_strategies:
		strategy_option.add_item(strategy.get_name())
	strategy_option.selected = current_strategy_index
	strategy_option.item_selected.connect(_on_strategy_selected)
	_load_preset_button_state()
	
	# Show options for initial strategy
	if available_strategies.size() > 0:
		_update_strategy_panel()


func get_grid_size() -> Vector3i:
	"""Get the current grid size"""
	return grid_size


func set_grid_size(size: Vector3i) -> void:
	"""Set the grid size"""
	grid_size = size
	if x_spinbox:
		x_spinbox.value = grid_size.x
		y_spinbox.value = grid_size.y
		z_spinbox.value = grid_size.z
		_refresh_warnings()


func get_cell_size() -> Vector3:
	return cell_world_size


func set_cell_size(size: Vector3, emit_signal: bool = false) -> void:
	cell_world_size = size
	if cell_x_spinbox:
		cell_x_spinbox.set_value_no_signal(cell_world_size.x)
		cell_y_spinbox.set_value_no_signal(cell_world_size.y)
		cell_z_spinbox.set_value_no_signal(cell_world_size.z)
		if emit_signal:
			_emit_cell_size_changed()


func _on_cell_size_changed(_value: float) -> void:
	var new_size = Vector3(
		float(cell_x_spinbox.value),
		float(cell_y_spinbox.value),
		float(cell_z_spinbox.value)
	)
	# Clamp to minimum positive size
	new_size.x = max(new_size.x, 0.1)
	new_size.y = max(new_size.y, 0.1)
	new_size.z = max(new_size.z, 0.1)

	if new_size == cell_world_size:
		return

	cell_world_size = new_size
	_emit_cell_size_changed()


func _emit_cell_size_changed() -> void:
	if module_library and module_library.cell_world_size != cell_world_size:
		module_library.cell_world_size = cell_world_size
		if module_library.resource_path != "":
			var err = ResourceSaver.save(module_library, module_library.resource_path)
			if err != OK:
				push_warning("Failed to save module library: %s" % err)
	cell_size_changed.emit(cell_world_size)


func set_module_library(library: ModuleLibrary) -> void:
	"""Provide the active module library so requirements can be validated."""
	module_library = library
	if module_library:
		set_cell_size(module_library.cell_world_size, false)
	if is_inside_tree():
		call_deferred("_refresh_warnings")


func get_current_strategy() -> WfcStrategyBase:
	"""Get the currently selected strategy"""
	if current_strategy_index >= 0 and current_strategy_index < available_strategies.size():
		return available_strategies[current_strategy_index]
	return null


func _on_grid_size_changed(_value: float) -> void:
	"""Handle grid size spinbox changes"""
	grid_size = Vector3i(
		int(x_spinbox.value),
		int(y_spinbox.value),
		int(z_spinbox.value)
	)
	print("Grid size changed to: ", grid_size)
	_refresh_warnings()


func _on_strategy_selected(index: int) -> void:
	"""Handle strategy dropdown selection"""
	if index >= 0 and index < available_strategies.size():
		current_strategy_index = index
		var strategy = available_strategies[index]
		print("Strategy changed to: ", strategy.get_name())
		_update_strategy_panel()


func _update_strategy_options(strategy: WfcStrategyBase) -> void:
	"""Update the strategy options container with the strategy's custom options"""
	for child in strategy_options_container.get_children():
		if child == options_placeholder:
			continue
		child.queue_free()

	var options_control = strategy.get_options()
	if options_control:
		options_placeholder.hide()
		strategy_options_container.add_child(options_control)
	else:
		options_placeholder.show()


# =============================================================================
# Strategy Discovery
# =============================================================================

func _discover_strategies() -> void:
	"""Automatically discover all strategy classes in the strategies folder"""
	available_strategies.clear()
	strategy_keys.clear()
	
	var strategies_path = "res://addons/auto_structured/core/wfc/strategies/"
	var dir = DirAccess.open(strategies_path)
	
	if not dir:
		push_error("Could not open strategies directory: " + strategies_path)
		# Fallback to hardcoded strategies
		available_strategies = [
			WfcStrategyFillAll.new(),
			WfcStrategyGroundWalls.new()
		]
		return
	
	# Collect all .gd files (except base class)
	var strategy_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			# Skip the base class
			if file_name != "wfc_strategy_base.gd":
				strategy_files.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort alphabetically for consistent ordering
	strategy_files.sort()
	
	# Instantiate each strategy
	for strategy_file in strategy_files:
		var script_path = strategies_path + strategy_file
		var script := load(script_path) as Script
		if script == null:
			push_warning("Skipped '%s' (not a script resource)" % strategy_file)
			continue

		var strategy_instance := _instantiate_strategy_script(script, script_path)
		if strategy_instance == null:
			continue

		# Verify it's a valid strategy (has the required methods)
		if strategy_instance.has_method("should_collapse_cell") and \
			strategy_instance.has_method("get_name") and \
			strategy_instance.has_method("get_description"):
			
			available_strategies.append(strategy_instance)
			strategy_keys.append(_get_strategy_key(strategy_instance))
			_remember_strategy_defaults(strategy_instance)
			print("Discovered strategy: ", strategy_instance.get_name())
		else:
			push_warning("Skipped invalid strategy: " + strategy_file)
	
	# Ensure we have at least one strategy
	if available_strategies.is_empty():
		push_error("No valid strategies found! Using fallback.")
		var fallback = WfcStrategyFillAll.new()
		available_strategies = [fallback]
		strategy_keys = [_get_strategy_key(fallback)]
		_remember_strategy_defaults(fallback)


func _instantiate_strategy_script(script: Script, script_path: String) -> WfcStrategyBase:
	if script == null:
		return null

	if not script.can_instantiate():
		push_warning("Strategy script '%s' cannot be instantiated." % script_path)
		return null

	var base_type := script.get_instance_base_type()
	var instance: Variant = null

	if ClassDB.is_parent_class(base_type, "RefCounted"):
		if script.has_method("new"):
			instance = script.call("new")
		else:
			push_warning("Strategy script '%s' lacks new() despite RefCounted base." % script_path)
	elif ClassDB.is_parent_class(base_type, "Node"):
		if script.has_method("instantiate"):
			instance = script.call("instantiate")
		else:
			instance = script.instantiate()
	else:
		# Attempt generic instantiation fallback
		if script.has_method("new"):
			instance = script.call("new")
		elif script.has_method("instantiate"):
			instance = script.call("instantiate")

	if instance is WfcStrategyBase:
		return instance

	if instance is Object and instance is Node:
		(instance as Node).queue_free()

	if instance == null:
		push_warning("Strategy script '%s' could not be instantiated." % script_path)
	else:
		push_warning("Strategy script '%s' did not produce a WfcStrategyBase instance." % script_path)
	return null


func _update_strategy_panel() -> void:
	var strategy := get_current_strategy()
	if not strategy:
		strategy_description.clear()
		strategy_description.append_text("No strategy available.")
		for child in strategy_options_container.get_children():
			if child == options_placeholder:
				continue
			child.queue_free()
		options_placeholder.show()
		_current_presets.clear()
		load_preset_button.get_popup().clear()
		warning_panel.hide()
		_load_preset_button_state()
		return

	_refresh_description(strategy)
	_update_strategy_options(strategy)
	_refresh_presets_menu()
	_refresh_warnings()


func _refresh_description(strategy: WfcStrategyBase) -> void:
	strategy_description.clear()
	strategy_description.push_bold()
	strategy_description.append_text(strategy.get_name())
	strategy_description.pop()
	var desc := strategy.get_description()
	if not desc.strip_edges().is_empty():
		strategy_description.append_text("\n")
		strategy_description.append_text(desc)


func _refresh_presets_menu() -> void:
	var popup := load_preset_button.get_popup()
	popup.clear()
	_current_presets.clear()
	var strategy := get_current_strategy()
	if not strategy:
		_load_preset_button_state()
		return
	var names := preset_store.list_presets(_get_strategy_key(strategy))
	var idx := 0
	for name in names:
		popup.add_item(name, idx)
		_current_presets.append(name)
		idx += 1
	_load_preset_button_state()


func _collect_tag_requirements(strategy: WfcStrategyBase) -> Dictionary:
	var required: Array[String] = []
	required.assign(strategy.get_required_tags(grid_size))
	var seen: Dictionary = {}
	var unique: Array[String] = []
	for tag in required:
		var normalized := str(tag).strip_edges()
		if normalized.is_empty():
			continue
		if not seen.has(normalized):
			seen[normalized] = true
			unique.append(normalized)
	unique.sort()
	var missing: Array[String] = []
	if module_library:
		for tag in unique:
			if module_library.get_tiles_with_tag(tag).is_empty():
				missing.append(tag)
	return {
		"tags": unique,
		"missing": missing,
		"can_check": module_library != null
	}


func _refresh_warnings() -> void:
	var strategy := get_current_strategy()
	if not strategy:
		warning_panel.hide()
		return
	var warnings: Array[String] = []
	warnings.assign(strategy.get_ui_warnings(grid_size))
	var tag_info := _collect_tag_requirements(strategy)
	var required_tags: Array[String] = tag_info.get("tags", [])
	var missing_tags: Array[String] = tag_info.get("missing", [])
	var can_check: bool = bool(tag_info.get("can_check", false))
	if warnings.is_empty() and required_tags.is_empty():
		warning_panel.hide()
		return
	warning_panel.show()
	warning_label.clear()
	var needs_section_spacing := false
	if not warnings.is_empty():
		warning_label.push_bold()
		warning_label.append_text("Warnings")
		warning_label.pop()
		for warning in warnings:
			warning_label.append_text("\n• " + warning)
		needs_section_spacing = true
	if not required_tags.is_empty():
		if needs_section_spacing:
			warning_label.append_text("\n\n")
		warning_label.push_bold()
		warning_label.append_text("Tag Requirements")
		warning_label.pop()
		var missing_lookup: Dictionary = {}
		for tag in missing_tags:
			missing_lookup[tag] = true
		for tag in required_tags:
			var bullet := "\n• " + tag
			if missing_lookup.has(tag):
				warning_label.push_color(Color(1.0, 0.45, 0.4))
				warning_label.append_text(bullet + " (missing in current library)")
				warning_label.pop()
			else:
				warning_label.append_text(bullet)
		if not can_check:
			warning_label.append_text("\n  Load a module library to validate required tags.")
		elif not missing_tags.is_empty():
			warning_label.append_text("\n  Add the highlighted tags to your tiles via the Module Library panel.")


func _get_strategy_key(strategy: WfcStrategyBase) -> String:
	if not strategy:
		return ""
	var script: Script = strategy.get_script()
	if script and script.resource_path != "":
		return script.resource_path
	return strategy.get_class()


func _remember_strategy_defaults(strategy: WfcStrategyBase) -> void:
	var key := _get_strategy_key(strategy)
	if key.is_empty():
		return
	if not strategy_defaults.has(key):
		strategy_defaults[key] = strategy.serialize_state().duplicate(true)


func _current_strategy_key() -> String:
	if current_strategy_index >= 0 and current_strategy_index < strategy_keys.size():
		return strategy_keys[current_strategy_index]
	return _get_strategy_key(get_current_strategy())


func _reset_current_strategy() -> void:
	var strategy := get_current_strategy()
	if not strategy:
		return
	var key := _get_strategy_key(strategy)
	if strategy_defaults.has(key):
		var state: Dictionary = strategy_defaults[key]
		strategy.deserialize_state(state.duplicate(true))
	_update_strategy_options(strategy)
	_refresh_warnings()


func _on_reset_pressed() -> void:
	_reset_current_strategy()


func _on_save_preset_pressed() -> void:
	var strategy := get_current_strategy()
	if not strategy:
		return
	preset_name_edit.text = strategy.get_name()
	preset_name_edit.select_all()
	save_preset_dialog.popup_centered()


func _commit_save_preset() -> void:
	var strategy := get_current_strategy()
	if not strategy:
		return
	var name := preset_name_edit.text.strip_edges()
	if name.is_empty():
		return
	var data := strategy.serialize_state()
	preset_store.save_preset(_get_strategy_key(strategy), name, data)
	_refresh_presets_menu()


func _on_preset_menu_id_pressed(id: int) -> void:
	if id >= 0 and id < _current_presets.size():
		_apply_preset(_current_presets[id])


func _apply_preset(name: String) -> void:
	var strategy := get_current_strategy()
	if not strategy:
		return
	var data := preset_store.load_preset(_get_strategy_key(strategy), name)
	if data.is_empty():
		push_warning("Preset '%s' is empty or missing" % name)
		return
	strategy.deserialize_state(data)
	_update_strategy_options(strategy)
	_refresh_warnings()


func _on_apply_pressed() -> void:
	var strategy := get_current_strategy()
	if strategy:
		emit_signal("apply_requested", strategy)


func _load_preset_button_state() -> void:
	var has_strategy := get_current_strategy() != null
	reset_button.disabled = not has_strategy
	save_preset_button.disabled = not has_strategy
	apply_button.disabled = not has_strategy
	load_preset_button.disabled = not has_strategy or _current_presets.is_empty()
