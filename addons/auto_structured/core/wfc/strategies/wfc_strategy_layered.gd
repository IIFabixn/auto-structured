@tool
class_name WfcStrategyLayered extends WfcStrategyBase
## Atrium-style multi-level strategy with configurable walkways.
##
## Generates stacked levels with a hollow core. Ground level is fully solid,
## intermediate levels place walkways along the perimeter, and optional roof
## caps the structure. Useful for previewing multi-storey interiors or
## creating atrium hubs.

@export_range(1, 4) var walkway_width: int = 1
@export_range(1, 6) var level_interval: int = 2
@export var include_roof: bool = true
@export var carve_central_atrium: bool = true


func get_name() -> String:
	return "Atrium (Layered)"


func get_description() -> String:
	return "Generates a multi-level atrium with perimeter walkways on configurable floors."


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	if grid_size.x <= 0 or grid_size.z <= 0:
		return false

	var effective_width := max(1, min(walkway_width, int(ceil(float(min(grid_size.x, grid_size.z)) / 2.0))))
	var distance := _distance_to_perimeter(position, grid_size)
	var walkway_band: bool = (distance < effective_width) if carve_central_atrium else true
	var column_band := distance == 0
	var is_ground := position.y == 0
	var is_roof := include_roof and position.y == grid_size.y - 1
	var is_walkway_level := level_interval > 0 and position.y % level_interval == 0

	if is_ground:
		return true
	if is_roof:
		return walkway_band
	if is_walkway_level:
		return walkway_band

	# Keep structural columns on the perimeter to support the walkways
	return column_band


func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
	var tags: Array[String] = ["structure"]
	var effective_width := max(1, min(walkway_width, int(ceil(float(min(grid_size.x, grid_size.z)) / 2.0))))
	var distance := _distance_to_perimeter(position, grid_size)
	var walkway_band: bool = (distance < effective_width) if carve_central_atrium else true
	var column_band := distance == 0
	var is_ground := position.y == 0
	var is_roof := include_roof and position.y == grid_size.y - 1
	var is_walkway_level := level_interval > 0 and position.y % level_interval == 0

	if is_ground:
		tags.append_array(["floor", "interior"])
		return tags

	if is_roof:
		if walkway_band:
			tags.append_array(["roof", "exterior"])
			if column_band:
				tags.append("edge")
		else:
			tags.append("void")
		return tags

	if is_walkway_level and walkway_band:
		tags.append("floor")
		if column_band:
			tags.append_array(["wall", "exterior", "edge"])
		else:
			tags.append_array(["walkway", "interior"])
		return tags

	if column_band:
		tags.append_array(["wall", "exterior"])
	else:
		tags.append("void")

	return tags


func _distance_to_perimeter(position: Vector3i, grid_size: Vector3i) -> int:
	var dist_x = min(position.x, grid_size.x - 1 - position.x)
	var dist_z = min(position.z, grid_size.z - 1 - position.z)
	return max(0, min(dist_x, dist_z))


func get_options() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var walkway_label = Label.new()
	walkway_label.text = "Walkway Width (cells):"
	vbox.add_child(walkway_label)

	var walkway_spinner = SpinBox.new()
	walkway_spinner.min_value = 1
	walkway_spinner.max_value = 4
	walkway_spinner.value = walkway_width
	walkway_spinner.value_changed.connect(func(value: float):
		walkway_width = int(value)
	)
	vbox.add_child(walkway_spinner)

	var interval_label = Label.new()
	interval_label.text = "Level Interval (cells):"
	vbox.add_child(interval_label)

	var interval_spinner = SpinBox.new()
	interval_spinner.min_value = 1
	interval_spinner.max_value = 6
	interval_spinner.value = level_interval
	interval_spinner.value_changed.connect(func(value: float):
		level_interval = int(value)
	)
	vbox.add_child(interval_spinner)

	var roof_check = CheckBox.new()
	roof_check.text = "Include Roof"
	roof_check.button_pressed = include_roof
	roof_check.toggled.connect(func(pressed: bool):
		include_roof = pressed
	)
	vbox.add_child(roof_check)

	var atrium_check = CheckBox.new()
	atrium_check.text = "Carve Central Atrium"
	atrium_check.button_pressed = carve_central_atrium
	atrium_check.toggled.connect(func(pressed: bool):
		carve_central_atrium = pressed
	)
	vbox.add_child(atrium_check)

	return vbox
