@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyCheckerboard
## Example custom strategy that fills cells in a checkerboard pattern.
##
## This demonstrates how to create your own custom strategies.
## Only cells where (x + z) is even will be filled.
##
## NOTE: This pattern may fail with limited tile sets. Works best with tiles
## that have compatible sockets or "none" sockets for flexible connections.


func should_collapse_cell(position: Vector3i, _grid_size: Vector3i) -> bool:
	# Fill cells in a checkerboard pattern on the XZ plane
	return (position.x + position.z) % 2 == 0


func get_name() -> String:
	return "Checkerboard"


func get_description() -> String:
	return "Fill cells in a checkerboard pattern (alternating filled and empty)"
