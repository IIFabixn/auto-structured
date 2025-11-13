@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategySparse
## Strategy that randomly fills cells based on a probability.
##
## Useful for creating sparse or scattered structures.

## Probability of filling a cell (0.0 to 1.0)
@export_range(0.0, 1.0, 0.05) var fill_probability: float = 0.5


func _init(probability: float = 0.5) -> void:
	fill_probability = clamp(probability, 0.0, 1.0)


func should_collapse_cell(_position: Vector3i, _grid_size: Vector3i) -> bool:
	return randf() < fill_probability


func get_name() -> String:
	return "Sparse (%d%%)" % int(fill_probability * 100)


func get_description() -> String:
	return "Randomly fill cells with %d%% probability" % int(fill_probability * 100)
