@tool
class_name WfcStrategyBuilding extends WfcStrategyBase
## Single-building volume strategy with proper semantic tagging.
##
## This is the tagged, production-ready version of GroundWalls.
## Use this when running a solver for a specific building region/AABB.
##
## Automatically assigns semantic tags based on position:
## - Bottom layer: "floor"
## - Outer perimeter: "wall", "exterior"
## - Interior space: "interior", "floor" (for multi-story interiors)
## - Top layer: "roof"
##
## Perfect for:
## - Single houses within a larger village grid
## - Towers, rooms, individual structures
## - Any rectangular building volume
##
## Usage:
##   var strategy = WfcStrategyBuilding.new()
##   strategy.wall_thickness = 1
##   strategy.roof_height = 1
##   var solver = WfcSolver.new(grid, strategy)

## Height of the roof layer (cells from top)
@export_range(1, 5) var roof_height: int = 1

## Thickness of walls (currently only 1 is supported)
@export_range(1, 3) var wall_thickness: int = 1

## Whether to include interior floor tags for multi-story buildings
@export var tag_interior_floors: bool = true

## Whether to add material variation tags based on height
@export var add_height_tags: bool = false

var _grid_size: Vector3i = Vector3i.ZERO


func initialize(grid_size: Vector3i) -> void:
	_grid_size = grid_size
	if grid_size.y <= 0:
		return
	roof_height = clamp(roof_height, 1, max(1, grid_size.y))
	var max_wall_thickness = max(1, min(grid_size.x, grid_size.z) / 2)
	wall_thickness = clamp(wall_thickness, 1, max_wall_thickness)


func get_name() -> String:
	return "Building (Single Volume)"


func get_description() -> String:
	return "Tagged building strategy: floor, walls, interior, roof. Use for single building regions."


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	# Fill the entire building volume
	return true


func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
	"""Assign semantic tags based on position within the building"""
	var tags: Array[String] = []
	tags.append("structure")
	
	# Determine vertical layer
	var is_ground = position.y == 0
	var is_roof = position.y >= grid_size.y - roof_height
	var is_mid_floor = not is_ground and not is_roof
	
	# Determine if on perimeter (wall position)
	var is_perimeter = _is_on_perimeter(position, grid_size)
	
	# Ground level
	if is_ground:
		tags.append("floor")
		if is_perimeter:
			tags.append("wall")
			tags.append("exterior")
		else:
			tags.append("interior")
	
	# Roof level
	elif is_roof:
		tags.append("roof")
		# Optionally differentiate roof edges
		if is_perimeter:
			tags.append_array(["edge", "exterior"])
		else:
			tags.append("exterior")
	
	# Middle floors (between ground and roof)
	elif is_mid_floor:
		if is_perimeter:
			tags.append("wall")
			tags.append("exterior")
		else:
			tags.append("interior")
			if tag_interior_floors:
				tags.append("floor")  # Interior floor tiles
	
	# Optional: Add height-based tags for material variation
	if add_height_tags:
		var height_ratio = float(position.y) / float(grid_size.y)
		if height_ratio < 0.33:
			tags.append("lower")
		elif height_ratio < 0.66:
			tags.append("middle")
		else:
			tags.append("upper")
	
	return tags


func _is_on_perimeter(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if position is on the outer perimeter (x or z edges)"""
	if wall_thickness == 1:
		return (position.x == 0 or position.x == grid_size.x - 1 or
		        position.z == 0 or position.z == grid_size.z - 1)
	else:
		# For thicker walls (future support)
		return (position.x < wall_thickness or position.x >= grid_size.x - wall_thickness or
		        position.z < wall_thickness or position.z >= grid_size.z - wall_thickness)


func get_cell_weight(position: Vector3i, grid_size: Vector3i) -> float:
	# Collapse from ground upwards for stability and predictable layering
	return float(grid_size.y - position.y)


func get_options() -> Control:
	"""Return UI controls for configuring building parameters"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	# Roof height
	var roof_label = Label.new()
	roof_label.text = "Roof Height (cells):"
	vbox.add_child(roof_label)
	
	var roof_spinner = SpinBox.new()
	roof_spinner.min_value = 1
	roof_spinner.max_value = 5
	roof_spinner.value = roof_height
	roof_spinner.value_changed.connect(func(value: float):
		roof_height = int(value)
	)
	vbox.add_child(roof_spinner)
	
	# Wall thickness
	var wall_label = Label.new()
	wall_label.text = "Wall Thickness (cells):"
	vbox.add_child(wall_label)
	
	var wall_spinner = SpinBox.new()
	wall_spinner.min_value = 1
	wall_spinner.max_value = 3
	wall_spinner.value = wall_thickness
	wall_spinner.value_changed.connect(func(value: float):
		wall_thickness = int(value)
	)
	vbox.add_child(wall_spinner)
	
	# Tag interior floors checkbox
	var interior_check = CheckBox.new()
	interior_check.text = "Tag Interior Floors"
	interior_check.button_pressed = tag_interior_floors
	interior_check.toggled.connect(func(pressed: bool):
		tag_interior_floors = pressed
	)
	vbox.add_child(interior_check)
	
	# Add height tags checkbox
	var height_check = CheckBox.new()
	height_check.text = "Add Height-Based Tags (lower/middle/upper)"
	height_check.button_pressed = add_height_tags
	height_check.toggled.connect(func(pressed: bool):
		add_height_tags = pressed
	)
	vbox.add_child(height_check)
	
	return vbox
