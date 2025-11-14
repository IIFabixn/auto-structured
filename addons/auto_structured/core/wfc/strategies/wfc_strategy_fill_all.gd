@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyFillAll
## Strategy that fills every cell in the grid.
##
## This is the default behavior - all cells will be collapsed with a tile.


func should_collapse_cell(_position: Vector3i, _grid_size: Vector3i) -> bool:
	return true


func get_name() -> String:
	return "Fill All"


func get_description() -> String:
	return "Fill every cell in the grid"


func get_options() -> Control:
	"""Fill All has no configurable options"""
	var label = Label.new()
	label.text = "No configuration needed.\nThis strategy fills all cells."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
