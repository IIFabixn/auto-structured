@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyPerimeter
## Strategy that fills only the outer edges of the grid.
##
## Creates a hollow structure with only the perimeter filled.
## Useful for creating walls or boundaries.


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	return _is_perimeter_cell(position, grid_size)


func get_name() -> String:
	return "Perimeter Only"


func get_description() -> String:
	return "Fill only outer edges (hollow interior)"


func _is_perimeter_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if cell is on the outer edge of the grid"""
	return (
		position.x == 0 or position.x == grid_size.x - 1 or
		position.y == 0 or position.y == grid_size.y - 1 or
		position.z == 0 or position.z == grid_size.z - 1
	)
