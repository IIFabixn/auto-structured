@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyGroundWalls
## Strategy that fills ground level and perimeter walls.
##
## Perfect for house/building generation - creates a floor and outer walls,
## leaving the interior empty for rooms.


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	return _is_ground_or_wall_cell(position, grid_size)


func get_name() -> String:
	return "Ground + Walls"


func get_description() -> String:
	return "Fill ground level and perimeter walls (good for houses)"


func _is_ground_or_wall_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if cell is on ground level or on a perimeter wall"""
	var is_ground = position.y == 0
	var is_wall = (position.x == 0 or position.x == grid_size.x - 1 or
				   position.z == 0 or position.z == grid_size.z - 1)
	return is_ground or is_wall
