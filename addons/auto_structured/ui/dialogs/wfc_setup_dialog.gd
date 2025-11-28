@tool
class_name WfcSetupDialog extends ConfirmationDialog

signal setup_confirmed(config: Dictionary)

@onready var grid_x_spin: SpinBox = %GridXSpin
@onready var grid_y_spin: SpinBox = %GridYSpin
@onready var grid_z_spin: SpinBox = %GridZSpin
@onready var cell_x_spin: SpinBox = %CellXSpin
@onready var cell_y_spin: SpinBox = %CellYSpin
@onready var cell_z_spin: SpinBox = %CellZSpin

var _last_config: Dictionary = {
	"grid_size": Vector3i(5, 3, 5),
	"cell_size": Vector3(2, 2, 2)
}

const _EDITOR_SETTINGS_KEY := "auto_structured/wfc_setup/config"
const _EDITOR_SETTINGS_KEY_GRID_SIZE := "auto_structured/wfc_setup/config/grid_size"
const _EDITOR_SETTINGS_KEY_CELL_SIZE := "auto_structured/wfc_setup/config/cell_size"

func _ready() -> void:
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	_load_last_config_from_editor()

func open_with_defaults(grid_size: Vector3i = Vector3i(5, 3, 5), cell_size: Vector3 = Vector3(2, 2, 2)) -> void:
	grid_x_spin.value = max(1, grid_size.x)
	grid_y_spin.value = max(1, grid_size.y)
	grid_z_spin.value = max(1, grid_size.z)
	cell_x_spin.value = max(0.1, cell_size.x)
	cell_y_spin.value = max(0.1, cell_size.y)
	cell_z_spin.value = max(0.1, cell_size.z)
	popup_centered_ratio(0.2)
	grab_focus()

func open_with_last() -> void:
	var cfg := get_last_config()
	open_with_defaults(cfg["grid_size"], cfg["cell_size"])

func get_config() -> Dictionary:
	return {
		"grid_size": Vector3i(
			int(grid_x_spin.value),
			int(grid_y_spin.value),
			int(grid_z_spin.value)
		),
		"cell_size": Vector3(
			cell_x_spin.value,
			cell_y_spin.value,
			cell_z_spin.value
		)
	}

func _on_confirmed() -> void:
	_last_config = get_config()
	_save_last_config_to_editor()
	setup_confirmed.emit(_last_config)

func get_last_config() -> Dictionary:
	return _last_config.duplicate(true)

func apply_library_defaults(grid_size: Vector3i = Vector3i.ZERO, cell_size: Vector3 = Vector3.ZERO) -> void:
	"""Seed config with library-provided values when no editor overrides exist."""
	if grid_size != Vector3i.ZERO and not _has_editor_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE):
		_last_config["grid_size"] = grid_size
	if cell_size != Vector3.ZERO and not _has_editor_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE):
		_last_config["cell_size"] = cell_size

func _load_last_config_from_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	var default_grid: Vector3i = _last_config["grid_size"]
	var default_cell: Vector3 = _last_config["cell_size"]
	var grid_loaded := false
	var cell_loaded := false
	var grid_value := default_grid
	var cell_value := default_cell
	if editor_settings.has_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE):
		var stored_grid = editor_settings.get_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE)
		grid_value = _to_vector3i(stored_grid, default_grid)
		grid_loaded = true
	if editor_settings.has_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE):
		var stored_cell = editor_settings.get_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE)
		cell_value = _to_vector3(stored_cell, default_cell)
		cell_loaded = true
	if grid_loaded or cell_loaded:
		_last_config = {
			"grid_size": grid_value,
			"cell_size": cell_value
		}
		return
	if not editor_settings.has_setting(_EDITOR_SETTINGS_KEY):
		return
	var legacy = editor_settings.get_setting(_EDITOR_SETTINGS_KEY)
	if typeof(legacy) != TYPE_DICTIONARY:
		return
	var parsed := _sanitize_config(legacy)
	if parsed.is_empty():
		return
	_last_config = parsed

func _save_last_config_to_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY_GRID_SIZE, _last_config.get("grid_size", Vector3i(5, 3, 5)))
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY_CELL_SIZE, _last_config.get("cell_size", Vector3(2, 2, 2)))

func _sanitize_config(data: Dictionary) -> Dictionary:
	var default_grid := Vector3i(5, 3, 5)
	var default_cell := Vector3(2, 2, 2)
	var grid_size := _to_vector3i(data.get("grid_size", default_grid), default_grid)
	var cell_size := _to_vector3(data.get("cell_size", default_cell), default_cell)
	return {
		"grid_size": grid_size,
		"cell_size": cell_size
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
