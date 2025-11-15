@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyGroundWalls
## Strategy for creating single building volumes with floor and walls.
##
## Creates a floor and outer walls, leaving the interior empty.
## Use this when running a solver inside a specific building region.
##
## Modes:
## - GROUND_WALLS: Ground floor + perimeter walls (default, good for buildings)
## - PERIMETER_ONLY: All outer edges (creates hollow box, good for boundaries)

enum Mode {
	GROUND_WALLS,   ## Ground level + perimeter walls only
	PERIMETER_ONLY  ## All perimeter faces (hollow box)
}

@export var mode: Mode = Mode.GROUND_WALLS
@export var include_roof: bool = true


func initialize(grid_size: Vector3i) -> void:
	# Clamp roof toggle for very short grids (single layer behaves like ground)
	if grid_size.y <= 1:
		include_roof = false


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	var is_ground := position.y == 0
	var is_horizontal_perimeter := _is_horizontal_perimeter(position, grid_size)
	var is_shell := _is_shell_cell(position, grid_size)
	var is_roof := include_roof and position.y == grid_size.y - 1

	match mode:
		Mode.GROUND_WALLS:
			return is_ground or is_horizontal_perimeter or is_roof
		Mode.PERIMETER_ONLY:
			if not include_roof and position.y == grid_size.y - 1:
				return false
			return is_shell
	return false


func get_name() -> String:
	match mode:
		Mode.GROUND_WALLS:
			return "Ground + Walls"
		Mode.PERIMETER_ONLY:
			return "Perimeter Only"
	return "Ground + Walls"


func get_description() -> String:
	match mode:
		Mode.GROUND_WALLS:
			return "Fill ground slab, perimeter walls, and optional roof for single-structure shells"
		Mode.PERIMETER_ONLY:
			return "Create a hollow perimeter shell around the volume (optionally capped on top)"
	return ""


func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
	var tags: Array[String] = []
	var is_ground := position.y == 0
	var is_roof := include_roof and position.y == grid_size.y - 1
	var is_horizontal_perimeter := _is_horizontal_perimeter(position, grid_size)

	if is_ground:
		tags.append_array(["structure", "floor"])
		if is_horizontal_perimeter:
			tags.append_array(["wall", "exterior"])
		else:
			tags.append("interior")
	elif is_roof:
		tags.append_array(["structure", "roof", "exterior"])
		if is_horizontal_perimeter:
			tags.append("edge")
	else:
		if is_horizontal_perimeter:
			tags.append_array(["structure", "wall", "exterior"])
		else:
			tags.append_array(["structure", "interior"])

	return tags


func _is_ground_or_wall_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if cell is on ground level or on a perimeter wall"""
	var is_ground = position.y == 0
	var is_wall = (position.x == 0 or position.x == grid_size.x - 1 or
				   position.z == 0 or position.z == grid_size.z - 1)
	return is_ground or is_wall


func _is_horizontal_perimeter(position: Vector3i, grid_size: Vector3i) -> bool:
	return (
		position.x == 0 or position.x == grid_size.x - 1 or
		position.z == 0 or position.z == grid_size.z - 1
	)


func _is_shell_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	return _is_horizontal_perimeter(position, grid_size) or position.y == 0 or position.y == grid_size.y - 1


func get_cell_weight(position: Vector3i, grid_size: Vector3i) -> float:
	# Prefer collapsing lower cells first for stability
	return float(grid_size.y - position.y)


func get_options() -> Control:
	"""Return UI controls for configuring the strategy"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var label = Label.new()
	label.text = "Mode:"
	vbox.add_child(label)
	
	var option_button = OptionButton.new()
	option_button.add_item("Ground + Walls", Mode.GROUND_WALLS)
	option_button.add_item("Perimeter Only", Mode.PERIMETER_ONLY)
	option_button.selected = mode
	option_button.item_selected.connect(func(index: int):
		mode = index as Mode
	)
	vbox.add_child(option_button)

	var roof_check := CheckBox.new()
	roof_check.text = "Include Roof"
	roof_check.button_pressed = include_roof
	roof_check.toggled.connect(func(pressed: bool):
		include_roof = pressed
	)
	vbox.add_child(roof_check)
	
	var desc_label = Label.new()
	desc_label.text = "Ground + Walls: Solid ground slab, exterior walls, optional roof\nPerimeter Only: Hollow perimeter shell (toggle roof for a capped box)"
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return vbox
