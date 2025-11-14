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


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	match mode:
		Mode.GROUND_WALLS:
			return _is_ground_or_wall_cell(position, grid_size)
		Mode.PERIMETER_ONLY:
			return _is_perimeter_cell(position, grid_size)
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
			return "Fill ground level and perimeter walls (good for single buildings)"
		Mode.PERIMETER_ONLY:
			return "Fill only outer edges (hollow interior, good for boundaries)"
	return ""


func _is_ground_or_wall_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if cell is on ground level or on a perimeter wall"""
	var is_ground = position.y == 0
	var is_wall = (position.x == 0 or position.x == grid_size.x - 1 or
				   position.z == 0 or position.z == grid_size.z - 1)
	return is_ground or is_wall


func _is_perimeter_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if cell is on any outer edge of the grid"""
	return (position.x == 0 or position.x == grid_size.x - 1 or
	        position.y == 0 or position.y == grid_size.y - 1 or
	        position.z == 0 or position.z == grid_size.z - 1)


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
	
	var desc_label = Label.new()
	desc_label.text = "Ground + Walls: Floor and side walls\nPerimeter Only: All outer edges (hollow box)"
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return vbox
