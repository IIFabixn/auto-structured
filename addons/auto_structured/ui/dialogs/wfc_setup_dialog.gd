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

func _load_last_config_from_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	if not editor_settings.has_setting(_EDITOR_SETTINGS_KEY):
		return
	var stored = editor_settings.get_setting(_EDITOR_SETTINGS_KEY)
	if typeof(stored) != TYPE_DICTIONARY:
		return
	var parsed := _sanitize_config(stored)
	if parsed.is_empty():
		return
	_last_config = parsed

func _save_last_config_to_editor() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return
	editor_settings.set_setting(_EDITOR_SETTINGS_KEY, _last_config.duplicate(true))

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
