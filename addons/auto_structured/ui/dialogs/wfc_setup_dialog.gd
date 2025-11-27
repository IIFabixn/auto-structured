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

func _ready() -> void:
	ok_button_text = "Apply"
	cancel_button_text = "Cancel"
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)

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
	setup_confirmed.emit(_last_config)

func get_last_config() -> Dictionary:
	return _last_config.duplicate(true)
