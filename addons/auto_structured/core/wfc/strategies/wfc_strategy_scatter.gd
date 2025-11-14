@tool
class_name WfcStrategyScatter extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"

## Strategy that randomly scatters tiles based on a probability.
##
## Useful for placing decoration, clutter, trees, rocks, and debris.
## NOT suitable for structural layout - use this for a "decoration pass"
## after your main structure is generated.

## Probability of filling a cell (0.0 to 1.0)
@export_range(0.0, 1.0, 0.05) var fill_probability: float = 0.5


func _init(probability: float = 0.5) -> void:
	fill_probability = clamp(probability, 0.0, 1.0)


func should_collapse_cell(_position: Vector3i, _grid_size: Vector3i) -> bool:
	return randf() < fill_probability


func get_name() -> String:
	return "Scatter (Decoration)"


func get_description() -> String:
	return "Randomly scatter tiles for decoration, clutter, trees, rocks. Not for structural layout."


func get_options() -> Control:
	"""Return a control with strategy-specific options"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var label = Label.new()
	label.text = "Fill Probability:"
	vbox.add_child(label)
	
	var hbox = HBoxContainer.new()
	
	var slider = HSlider.new()
	slider.name = "ProbabilitySlider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = fill_probability * 100.0
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d%%" % int(fill_probability * 100)
	value_label.custom_minimum_size = Vector2(50, 0)
	hbox.add_child(value_label)
	
	vbox.add_child(hbox)
	
	# Connect slider to update probability and label
	slider.value_changed.connect(func(value: float):
		fill_probability = value / 100.0
		value_label.text = "%d%%" % int(value)
	)
	
	return vbox
