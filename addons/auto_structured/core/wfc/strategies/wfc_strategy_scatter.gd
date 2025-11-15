@tool
class_name WfcStrategyScatter extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"

## Strategy that randomly scatters tiles based on a probability.
##
## Useful for placing decoration, clutter, trees, rocks, and debris.
## NOT suitable for structural layout - use this for a "decoration pass"
## after your main structure is generated.

## Probability of filling a cell (0.0 to 1.0)
@export_range(0.0, 1.0, 0.05) var fill_probability: float = 0.5
@export var random_seed: int = 1337
@export_range(0.05, 1.0, 0.05) var noise_frequency: float = 0.35

var _noise := FastNoiseLite.new()


func initialize(_grid_size: Vector3i) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_noise.frequency = noise_frequency
	_noise.seed = random_seed


func _normalized_noise(position: Vector3i) -> float:
	var value := _noise.get_noise_3d(float(position.x), float(position.y), float(position.z))
	return clamp((value + 1.0) * 0.5, 0.0, 1.0)


func _should_place(position: Vector3i) -> bool:
	if fill_probability <= 0.0:
		return false
	if fill_probability >= 1.0:
		return true
	return _normalized_noise(position) <= fill_probability


func should_collapse_cell(position: Vector3i, _grid_size: Vector3i) -> bool:
	return _should_place(position)


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

	var seed_label := Label.new()
	seed_label.text = "Random Seed:"
	vbox.add_child(seed_label)

	var seed_spinner := SpinBox.new()
	seed_spinner.min_value = -2147483648
	seed_spinner.max_value = 2147483647
	seed_spinner.step = 1
	seed_spinner.value = random_seed
	seed_spinner.value_changed.connect(func(value: float):
		random_seed = int(value)
		_noise.seed = random_seed
	)
	vbox.add_child(seed_spinner)

	var freq_label := Label.new()
	freq_label.text = "Noise Frequency:"
	vbox.add_child(freq_label)

	var freq_slider := HSlider.new()
	freq_slider.min_value = 0.05
	freq_slider.max_value = 1.0
	freq_slider.step = 0.05
	freq_slider.value = noise_frequency
	freq_slider.value_changed.connect(func(value: float):
		noise_frequency = value
		_noise.frequency = value
	)
	vbox.add_child(freq_slider)
	
	return vbox


func get_cell_tags(position: Vector3i, _grid_size: Vector3i) -> Array[String]:
	if not _should_place(position):
		return []
	return ["decoration"]
