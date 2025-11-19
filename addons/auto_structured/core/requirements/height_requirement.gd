@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name HeightRequirement

## Restricts tile placement based on Y coordinate (height).
## Useful for tiles that should only appear at ground level, upper floors, etc.

enum HeightMode {
	EXACT,           ## Tile must be at exactly the specified height
	MIN,             ## Tile must be at or above the specified height
	MAX,             ## Tile must be at or below the specified height
	RANGE            ## Tile must be within the specified range (inclusive)
}

@export var mode: HeightMode = HeightMode.MIN
@export var height_value: int = 0  ## For EXACT, MIN, or MAX modes
@export var min_height: int = 0    ## For RANGE mode
@export var max_height: int = 10   ## For RANGE mode

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	var y = position.y
	
	match mode:
		HeightMode.EXACT:
			return y == height_value
		HeightMode.MIN:
			return y >= height_value
		HeightMode.MAX:
			return y <= height_value
		HeightMode.RANGE:
			return y >= min_height and y <= max_height
	
	return true

func get_failure_reason() -> String:
	match mode:
		HeightMode.EXACT:
			return "Tile must be at height Y=%d" % height_value
		HeightMode.MIN:
			return "Tile must be at or above Y=%d" % height_value
		HeightMode.MAX:
			return "Tile must be at or below Y=%d" % height_value
		HeightMode.RANGE:
			return "Tile must be between Y=%d and Y=%d" % [min_height, max_height]
	return super.get_failure_reason()

func get_description() -> String:
	match mode:
		HeightMode.EXACT:
			return "Only at Y=%d" % height_value
		HeightMode.MIN:
			return "Y >= %d" % height_value
		HeightMode.MAX:
			return "Y <= %d" % height_value
		HeightMode.RANGE:
			return "Y between %d and %d" % [min_height, max_height]
	return super.get_description()

func get_config_control() -> Control:
	var vbox = VBoxContainer.new()
	
	# Mode selector
	var mode_hbox = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Mode:"
	mode_label.custom_minimum_size.x = 80
	mode_hbox.add_child(mode_label)
	
	var mode_option = OptionButton.new()
	mode_option.add_item("Exact", HeightMode.EXACT)
	mode_option.add_item("Minimum", HeightMode.MIN)
	mode_option.add_item("Maximum", HeightMode.MAX)
	mode_option.add_item("Range", HeightMode.RANGE)
	mode_option.select(mode)
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.item_selected.connect(func(idx: int): mode = idx)
	mode_hbox.add_child(mode_option)
	vbox.add_child(mode_hbox)
	
	# Height value (for EXACT, MIN, MAX)
	var value_hbox = HBoxContainer.new()
	var value_label = Label.new()
	value_label.text = "Height:"
	value_label.custom_minimum_size.x = 80
	value_hbox.add_child(value_label)
	
	var value_spinbox = SpinBox.new()
	value_spinbox.min_value = -100
	value_spinbox.max_value = 100
	value_spinbox.value = height_value
	value_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_spinbox.value_changed.connect(func(val: float): height_value = int(val))
	value_hbox.add_child(value_spinbox)
	vbox.add_child(value_hbox)
	
	# Min height (for RANGE)
	var min_hbox = HBoxContainer.new()
	var min_label = Label.new()
	min_label.text = "Min Height:"
	min_label.custom_minimum_size.x = 80
	min_hbox.add_child(min_label)
	
	var min_spinbox = SpinBox.new()
	min_spinbox.min_value = -100
	min_spinbox.max_value = 100
	min_spinbox.value = min_height
	min_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_spinbox.value_changed.connect(func(val: float): min_height = int(val))
	min_hbox.add_child(min_spinbox)
	vbox.add_child(min_hbox)
	
	# Max height (for RANGE)
	var max_hbox = HBoxContainer.new()
	var max_label = Label.new()
	max_label.text = "Max Height:"
	max_label.custom_minimum_size.x = 80
	max_hbox.add_child(max_label)
	
	var max_spinbox = SpinBox.new()
	max_spinbox.min_value = -100
	max_spinbox.max_value = 100
	max_spinbox.value = max_height
	max_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_spinbox.value_changed.connect(func(val: float): max_height = int(val))
	max_hbox.add_child(max_spinbox)
	vbox.add_child(max_hbox)
	
	return vbox
