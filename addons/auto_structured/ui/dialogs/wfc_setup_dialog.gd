@tool
class_name WfcSetupDialog extends ConfirmationDialog

signal setup_confirmed(config: Dictionary)

const WfcSolverConfig = preload("res://addons/auto_structured/core/wfc/wfc_solver_config.gd")
const WfcRegionConfig = preload("res://addons/auto_structured/core/wfc/wfc_region_config.gd")

const PRESET_ORDER := ["small", "medium", "large", "very_large", "custom"]
const PRESET_LABELS := {
	"small": "Small",
	"medium": "Medium",
	"large": "Large",
	"very_large": "Very Large",
	"custom": "Custom"
}
const PRESET_BUILDERS := {
	"small": Callable(WfcSolverConfig, "small_grid"),
	"medium": Callable(WfcSolverConfig, "medium_grid"),
	"large": Callable(WfcSolverConfig, "large_grid"),
	"very_large": Callable(WfcSolverConfig, "very_large_grid")
}
const STRATEGY_ORDER := ["entropy", "center_out", "frontier", "growing", "blueprint"]
const STRATEGY_LABELS := {
	"entropy": "Entropy",
	"center_out": "Center-Out",
	"frontier": "Frontier",
	"growing": "Growing",
	"blueprint": "Blueprint"
}

@onready var preset_option: OptionButton = %PresetOption
@onready var strategy_option: OptionButton = %StrategyOption
@onready var grid_x_spin: SpinBox = %GridXSpin
@onready var grid_y_spin: SpinBox = %GridYSpin
@onready var grid_z_spin: SpinBox = %GridZSpin
@onready var cell_x_spin: SpinBox = %CellXSpin
@onready var cell_y_spin: SpinBox = %CellYSpin
@onready var cell_z_spin: SpinBox = %CellZSpin
@onready var advanced_label: Label = %AdvancedLabel
@onready var advanced_grid: GridContainer = %AdvancedGrid
@onready var yield_spin: SpinBox = %YieldSpin
@onready var propagation_spin: SpinBox = %PropagationSpin
@onready var max_iterations_spin: SpinBox = %MaxIterationsSpin
@onready var progress_spin: SpinBox = %ProgressSpin
@onready var backtrack_depth_spin: SpinBox = %BacktrackDepthSpin
@onready var checkpoint_spin: SpinBox = %CheckpointSpin
@onready var prewarm_check: CheckButton = %PrewarmCheck
@onready var backtracking_check: CheckButton = %BacktrackingCheck
@onready var region_boundary_check: CheckButton = %RegionBoundaryCheck
@onready var max_regions_spin: SpinBox = %MaxRegionsSpin
@onready var require_closed_regions_check: CheckButton = %RequireClosedRegionsCheck

var _last_config: Dictionary = {
	"grid_size": Vector3i(5, 3, 5),
	"cell_size": Vector3(2, 2, 2)
}
var _current_preset_id: String = "medium"
var _current_solver_config: WfcSolverConfig
var _syncing_custom_controls: bool = false

const _EDITOR_SETTINGS_KEY := "auto_structured/wfc_setup/config"
const _EDITOR_SETTINGS_KEY_GRID_SIZE := "auto_structured/wfc_setup/config/grid_size"
const _EDITOR_SETTINGS_KEY_CELL_SIZE := "auto_structured/wfc_setup/config/cell_size"
const _EDITOR_SETTINGS_KEY_SOLVER := "auto_structured/wfc_setup/config/solver"

func _ready() -> void:
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	_load_last_config_from_editor()
	_ensure_solver_defaults()
	_populate_preset_option()
	_populate_strategy_option()
	_setup_custom_control_signals()
	_sync_controls_from_config()

func open_with_defaults(grid_size: Vector3i = Vector3i(5, 3, 5), cell_size: Vector3 = Vector3(2, 2, 2)) -> void:
	grid_x_spin.value = max(1, grid_size.x)
	grid_y_spin.value = max(1, grid_size.y)
	grid_z_spin.value = max(1, grid_size.z)
	cell_x_spin.value = max(0.1, cell_size.x)
	cell_y_spin.value = max(0.1, cell_size.y)
	cell_z_spin.value = max(0.1, cell_size.z)
	_sync_options_ui()
	popup_centered_ratio(0.2)
	grab_focus()

func open_with_last() -> void:
	var cfg := get_last_config()
	open_with_defaults(cfg["grid_size"], cfg["cell_size"])

func get_config() -> Dictionary:
	var payload := {
		"grid_size": Vector3i(
			int(grid_x_spin.value),
			int(grid_y_spin.value),
			int(grid_z_spin.value)
		),
		"cell_size": Vector3(
			cell_x_spin.value,
			cell_y_spin.value,
			cell_z_spin.value
		),
		"solver_config": _clone_solver_config(_current_solver_config),
		"solver_settings": _serialize_solver_config(_current_solver_config, _current_preset_id)
	}
	return payload

func _on_confirmed() -> void:
	_last_config = get_config()
	_save_last_config_to_editor()
	setup_confirmed.emit(_duplicate_config(_last_config))

func get_last_config() -> Dictionary:
	return _duplicate_config(_last_config)

func apply_library_defaults(grid_size: Vector3i = Vector3i.ZERO, cell_size: Vector3 = Vector3.ZERO) -> void:
	"""Seed config with library-provided values when no editor overrides exist."""
	if grid_size != Vector3i.ZERO and not _has_editor_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE):
		_last_config["grid_size"] = grid_size
	if cell_size != Vector3.ZERO and not _has_editor_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE):
		_last_config["cell_size"] = cell_size

func _duplicate_config(config: Dictionary) -> Dictionary:
	var copy := config.duplicate(true)
	if copy.has("solver_config"):
		copy["solver_config"] = _clone_solver_config(copy["solver_config"])
	else:
		copy["solver_config"] = _clone_solver_config(_current_solver_config)
	return copy

func _populate_preset_option() -> void:
	if preset_option == null:
		return
	preset_option.clear()
	for preset_id in PRESET_ORDER:
		preset_option.add_item(PRESET_LABELS.get(preset_id, preset_id.capitalize()))
	if not preset_option.item_selected.is_connected(_on_preset_option_selected):
		preset_option.item_selected.connect(_on_preset_option_selected)
	_sync_preset_selection()

func _populate_strategy_option() -> void:
	if strategy_option == null:
		return
	strategy_option.clear()
	for strategy_id in STRATEGY_ORDER:
		strategy_option.add_item(STRATEGY_LABELS.get(strategy_id, strategy_id.capitalize()))
	if not strategy_option.item_selected.is_connected(_on_strategy_option_selected):
		strategy_option.item_selected.connect(_on_strategy_option_selected)
	_sync_strategy_selection()

func _sync_controls_from_config() -> void:
	var grid_size: Vector3i = _last_config.get("grid_size", Vector3i(5, 3, 5))
	var cell_size: Vector3 = _last_config.get("cell_size", Vector3(2, 2, 2))
	grid_x_spin.value = grid_size.x
	grid_y_spin.value = grid_size.y
	grid_z_spin.value = grid_size.z
	cell_x_spin.value = cell_size.x
	cell_y_spin.value = cell_size.y
	cell_z_spin.value = cell_size.z
	_sync_options_ui()
	_sync_custom_solver_controls()

func _sync_options_ui() -> void:
	_sync_preset_selection()
	_sync_strategy_selection()
	_sync_custom_solver_controls()

func _sync_preset_selection() -> void:
	if preset_option == null:
		return
	var index := PRESET_ORDER.find(_current_preset_id)
	if index == -1:
		index = PRESET_ORDER.find("custom")
	if index >= 0:
		preset_option.select(index)

func _sync_strategy_selection() -> void:
	if strategy_option == null or _current_solver_config == null:
		return
	var strategy_id := _current_solver_config.solve_strategy_id
	var index := STRATEGY_ORDER.find(strategy_id)
	if index == -1:
		index = 0
	strategy_option.select(index)

func _on_preset_option_selected(index: int) -> void:
	if index < 0 or index >= PRESET_ORDER.size():
		return
	var preset_id: String = PRESET_ORDER[index]
	if preset_id == _current_preset_id:
		return
	_current_preset_id = preset_id
	if preset_id == "custom":
		_update_solver_settings_cache()
		_sync_custom_solver_controls()
		return
	var builder: Callable = PRESET_BUILDERS.get(preset_id)
	if builder and builder.is_valid():
		var new_config: WfcSolverConfig = builder.call()
		new_config.solve_strategy_id = _current_solver_config.solve_strategy_id
		_current_solver_config = new_config
	_last_config["solver_config"] = _clone_solver_config(_current_solver_config)
	_update_solver_settings_cache()
	_sync_strategy_selection()
	_sync_custom_solver_controls()

func _on_strategy_option_selected(index: int) -> void:
	if index < 0 or index >= STRATEGY_ORDER.size():
		return
	var strategy_id: String = STRATEGY_ORDER[index]
	if _current_solver_config == null:
		return
	_current_solver_config.solve_strategy_id = strategy_id
	_update_solver_settings_cache()
	_sync_custom_solver_controls()

func _setup_custom_control_signals() -> void:
	if yield_spin and not yield_spin.value_changed.is_connected(_on_custom_yield_changed):
		yield_spin.value_changed.connect(_on_custom_yield_changed)
	if propagation_spin and not propagation_spin.value_changed.is_connected(_on_custom_propagation_changed):
		propagation_spin.value_changed.connect(_on_custom_propagation_changed)
	if max_iterations_spin and not max_iterations_spin.value_changed.is_connected(_on_custom_max_iterations_changed):
		max_iterations_spin.value_changed.connect(_on_custom_max_iterations_changed)
	if progress_spin and not progress_spin.value_changed.is_connected(_on_custom_progress_changed):
		progress_spin.value_changed.connect(_on_custom_progress_changed)
	if backtrack_depth_spin and not backtrack_depth_spin.value_changed.is_connected(_on_custom_backtrack_depth_changed):
		backtrack_depth_spin.value_changed.connect(_on_custom_backtrack_depth_changed)
	if checkpoint_spin and not checkpoint_spin.value_changed.is_connected(_on_custom_checkpoint_changed):
		checkpoint_spin.value_changed.connect(_on_custom_checkpoint_changed)
	if prewarm_check and not prewarm_check.toggled.is_connected(_on_custom_prewarm_toggled):
		prewarm_check.toggled.connect(_on_custom_prewarm_toggled)
	if backtracking_check and not backtracking_check.toggled.is_connected(_on_custom_backtracking_toggled):
		backtracking_check.toggled.connect(_on_custom_backtracking_toggled)
	if region_boundary_check and not region_boundary_check.toggled.is_connected(_on_custom_region_boundary_toggled):
		region_boundary_check.toggled.connect(_on_custom_region_boundary_toggled)
	if max_regions_spin and not max_regions_spin.value_changed.is_connected(_on_custom_max_regions_changed):
		max_regions_spin.value_changed.connect(_on_custom_max_regions_changed)
	if require_closed_regions_check and not require_closed_regions_check.toggled.is_connected(_on_custom_require_closed_regions_toggled):
		require_closed_regions_check.toggled.connect(_on_custom_require_closed_regions_toggled)

func _sync_custom_solver_controls() -> void:
	var show_custom := _current_preset_id == "custom"
	_set_custom_section_visible(show_custom)
	if _current_solver_config == null:
		return
	_syncing_custom_controls = true
	# Region settings are always visible (not preset-specific)
	var region_cfg = _current_solver_config.region_config
	if region_boundary_check:
		region_boundary_check.button_pressed = region_cfg.enabled if region_cfg else false
	if max_regions_spin:
		max_regions_spin.value = region_cfg.max_regions if region_cfg else 1
	if require_closed_regions_check:
		require_closed_regions_check.button_pressed = region_cfg.require_closed_regions if region_cfg else true
	if show_custom:
		if yield_spin:
			yield_spin.value = _current_solver_config.yield_interval_ms
		if propagation_spin:
			propagation_spin.value = _current_solver_config.propagation_batch_size
		if max_iterations_spin:
			max_iterations_spin.value = _current_solver_config.max_iterations
		if progress_spin:
			progress_spin.value = _current_solver_config.progress_report_interval_ms
		if backtrack_depth_spin:
			backtrack_depth_spin.value = _current_solver_config.max_backtrack_depth
		if checkpoint_spin:
			checkpoint_spin.value = _current_solver_config.backtrack_checkpoint_frequency
		if prewarm_check:
			prewarm_check.button_pressed = _current_solver_config.prewarm_cache
		if backtracking_check:
			backtracking_check.button_pressed = _current_solver_config.enable_backtracking
	_syncing_custom_controls = false

func _set_custom_section_visible(visible: bool) -> void:
	if advanced_label:
		advanced_label.visible = visible
	if advanced_grid:
		advanced_grid.visible = visible

func _ensure_custom_mode_selection() -> void:
	if _current_preset_id != "custom":
		_current_preset_id = "custom"
		_sync_preset_selection()
		_update_solver_settings_cache()
		_sync_custom_solver_controls()

func _on_custom_yield_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.yield_interval_ms = int(value)
	_update_solver_settings_cache()

func _on_custom_propagation_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.propagation_batch_size = int(value)
	_update_solver_settings_cache()

func _on_custom_max_iterations_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.max_iterations = int(value)
	_update_solver_settings_cache()

func _on_custom_progress_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.progress_report_interval_ms = int(value)
	_update_solver_settings_cache()

func _on_custom_backtrack_depth_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.max_backtrack_depth = int(value)
	_update_solver_settings_cache()

func _on_custom_checkpoint_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.backtrack_checkpoint_frequency = int(value)
	_update_solver_settings_cache()

func _on_custom_prewarm_toggled(pressed: bool) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.prewarm_cache = pressed
	_update_solver_settings_cache()

func _on_custom_backtracking_toggled(pressed: bool) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	_ensure_custom_mode_selection()
	_current_solver_config.enable_backtracking = pressed
	_update_solver_settings_cache()

func _on_custom_region_boundary_toggled(pressed: bool) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	if _current_solver_config.region_config:
		_current_solver_config.region_config.enabled = pressed
	_update_solver_settings_cache()

func _on_custom_max_regions_changed(value: float) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	if _current_solver_config.region_config:
		_current_solver_config.region_config.max_regions = int(value)
	_update_solver_settings_cache()

func _on_custom_require_closed_regions_toggled(pressed: bool) -> void:
	if _syncing_custom_controls or _current_solver_config == null:
		return
	if _current_solver_config.region_config:
		_current_solver_config.region_config.require_closed_regions = pressed
	_update_solver_settings_cache()

func _update_solver_settings_cache() -> void:
	_last_config["solver_settings"] = _serialize_solver_config(_current_solver_config, _current_preset_id)
	_last_config["solver_config"] = _clone_solver_config(_current_solver_config)

func _load_last_config_from_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	var default_grid: Vector3i = _last_config.get("grid_size", Vector3i(5, 3, 5))
	var default_cell: Vector3 = _last_config.get("cell_size", Vector3(2, 2, 2))
	var grid_value := default_grid
	var cell_value := default_cell
	if editor_settings.has_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE):
		var stored_grid = editor_settings.get_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE)
		grid_value = _to_vector3i(stored_grid, default_grid)
	if editor_settings.has_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE):
		var stored_cell = editor_settings.get_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE)
		cell_value = _to_vector3(stored_cell, default_cell)
	var solver_settings := _default_solver_settings()
	if editor_settings.has_setting(_EDITOR_SETTINGS_KEY_SOLVER):
		solver_settings = _sanitize_solver_settings(editor_settings.get_setting(_EDITOR_SETTINGS_KEY_SOLVER))
	elif editor_settings.has_setting(_EDITOR_SETTINGS_KEY):
		var legacy = editor_settings.get_setting(_EDITOR_SETTINGS_KEY)
		if typeof(legacy) == TYPE_DICTIONARY:
			solver_settings = _sanitize_solver_settings(legacy.get("solver_settings", {}))
	_last_config = {
		"grid_size": grid_value,
		"cell_size": cell_value,
		"solver_settings": solver_settings
	}

func _save_last_config_to_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	var storage := _config_for_storage(_last_config)
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE, storage.get("grid_size", Vector3i(5, 3, 5)))
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE, storage.get("cell_size", Vector3(2, 2, 2)))
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY_SOLVER, storage.get("solver_settings", _default_solver_settings()))

func _config_for_storage(config: Dictionary) -> Dictionary:
	return {
		"grid_size": config.get("grid_size", Vector3i(5, 3, 5)),
		"cell_size": config.get("cell_size", Vector3(2, 2, 2)),
		"solver_settings": config.get("solver_settings", _default_solver_settings())
	}

func _ensure_solver_defaults() -> void:
	if not _last_config.has("solver_settings"):
		_last_config["solver_settings"] = _default_solver_settings()
	_current_solver_config = _deserialize_solver_config(_last_config["solver_settings"])
	_current_preset_id = _last_config["solver_settings"].get("preset_id", "medium")
	_last_config["solver_config"] = _clone_solver_config(_current_solver_config)

func _default_solver_settings() -> Dictionary:
	var config := WfcSolverConfig.medium_grid()
	config.solve_strategy_id = "entropy"
	return _serialize_solver_config(config, "medium")

func _serialize_solver_config(config: WfcSolverConfig, preset_id: String) -> Dictionary:
	if config == null:
		config = WfcSolverConfig.medium_grid()
	return {
		"preset_id": preset_id,
		"yield_interval_ms": config.yield_interval_ms,
		"propagation_batch_size": config.propagation_batch_size,
		"prewarm_cache": config.prewarm_cache,
		"max_iterations": config.max_iterations,
		"progress_report_interval_ms": config.progress_report_interval_ms,
		"enable_backtracking": config.enable_backtracking,
		"max_backtrack_depth": config.max_backtrack_depth,
		"backtrack_checkpoint_frequency": config.backtrack_checkpoint_frequency,
		"solve_strategy_id": config.solve_strategy_id,
		# Region settings (using unified config)
		"region_config": config.region_config.to_dict() if config.region_config else {}
	}

func _sanitize_solver_settings(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return _default_solver_settings()
	var config := _default_solver_settings()
	for key in config.keys():
		if data.has(key):
			config[key] = data[key]
	return config

func _deserialize_solver_config(data: Dictionary) -> WfcSolverConfig:
	var config := WfcSolverConfig.medium_grid()
	if data.is_empty():
		return config
	config.yield_interval_ms = data.get("yield_interval_ms", config.yield_interval_ms)
	config.propagation_batch_size = data.get("propagation_batch_size", config.propagation_batch_size)
	config.prewarm_cache = data.get("prewarm_cache", config.prewarm_cache)
	config.max_iterations = data.get("max_iterations", config.max_iterations)
	config.progress_report_interval_ms = data.get("progress_report_interval_ms", config.progress_report_interval_ms)
	config.enable_backtracking = data.get("enable_backtracking", config.enable_backtracking)
	config.max_backtrack_depth = data.get("max_backtrack_depth", config.max_backtrack_depth)
	config.backtrack_checkpoint_frequency = data.get("backtrack_checkpoint_frequency", config.backtrack_checkpoint_frequency)
	config.solve_strategy_id = data.get("solve_strategy_id", config.solve_strategy_id)
	# Restore region settings from unified config or legacy fields
	if data.has("region_config"):
		config.region_config = WfcRegionConfig.from_dict(data["region_config"])
	else:
		# Legacy field migration
		config.region_config.enabled = data.get("enforce_region_boundaries", false)
		config.region_config.max_regions = data.get("max_boundary_regions", 1)
		config.region_config.require_closed_regions = data.get("require_closed_regions", true)
	return config

func _clone_solver_config(source: WfcSolverConfig) -> WfcSolverConfig:
	var clone := WfcSolverConfig.new()
	if source == null:
		return clone
	clone.yield_interval_ms = source.yield_interval_ms
	clone.propagation_batch_size = source.propagation_batch_size
	clone.prewarm_cache = source.prewarm_cache
	clone.max_iterations = source.max_iterations
	clone.progress_report_interval_ms = source.progress_report_interval_ms
	clone.enable_backtracking = source.enable_backtracking
	clone.max_backtrack_depth = source.max_backtrack_depth
	clone.backtrack_checkpoint_frequency = source.backtrack_checkpoint_frequency
	clone.solve_strategy_id = source.solve_strategy_id
	# Clone region config
	if source.region_config:
		clone.region_config = source.region_config.duplicate_config()
	return clone

func _sanitize_config(data: Dictionary) -> Dictionary:
	var default_grid := Vector3i(5, 3, 5)
	var default_cell := Vector3(2, 2, 2)
	var grid_size := _to_vector3i(data.get("grid_size", default_grid), default_grid)
	var cell_size := _to_vector3(data.get("cell_size", default_cell), default_cell)
	var solver_settings := _sanitize_solver_settings(data.get("solver_settings", {}))
	return {
		"grid_size": grid_size,
		"cell_size": cell_size,
		"solver_settings": solver_settings
	}

func _to_vector3i(value, fallback: Vector3i) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return Vector3i(int(value["x"]), int(value["y"]), int(value["z"]))
	return fallback

func _to_vector3(value, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(float(value.x), float(value.y), float(value.z))
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return Vector3(float(value["x"]), float(value["y"]), float(value["z"]))
	return fallback

func _get_editor_settings() -> EditorSettings:
	if not Engine.is_editor_hint():
		return null
	var editor_interface := Engine.get_singleton("EditorInterface")
	if editor_interface == null:
		return null
	return editor_interface.get_editor_settings()

func _has_editor_setting(key: String) -> bool:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return false
	return editor_settings.has_setting(key)
