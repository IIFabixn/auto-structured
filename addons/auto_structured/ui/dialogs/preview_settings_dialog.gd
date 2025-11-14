@tool
class_name PreviewSettingsDialog extends Control

const WfcStrategyBase = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd")
const WfcStrategyFillAll = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_fill_all.gd")
const WfcStrategySparse = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_sparse.gd")
const WfcStrategyGroundWalls = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_ground_walls.gd")

@onready var x_spinbox: SpinBox = %XSpinBox
@onready var y_spinbox: SpinBox = %YSpinBox
@onready var z_spinbox: SpinBox = %ZSpinBox
@onready var strategy_option: OptionButton = %StrategyOption

@onready var strategy_options_container: VBoxContainer = %StrategyOptionsContainer

# Grid size
var grid_size: Vector3i = Vector3i(5, 5, 5)

# Strategy management
var available_strategies: Array[WfcStrategyBase] = []
var current_strategy_index: int = 0


func _ready() -> void:
	# Discover and initialize available strategies automatically
	_discover_strategies()
	current_strategy_index = 0
	
	# Initialize grid size spinboxes
	x_spinbox.value = grid_size.x
	y_spinbox.value = grid_size.y
	z_spinbox.value = grid_size.z
	x_spinbox.value_changed.connect(_on_grid_size_changed)
	y_spinbox.value_changed.connect(_on_grid_size_changed)
	z_spinbox.value_changed.connect(_on_grid_size_changed)
	
	# Initialize strategy dropdown (clear first to avoid duplicates)
	strategy_option.clear()
	for strategy in available_strategies:
		strategy_option.add_item(strategy.get_name())
	strategy_option.selected = current_strategy_index
	strategy_option.item_selected.connect(_on_strategy_selected)
	
	# Show options for initial strategy
	if available_strategies.size() > 0:
		_update_strategy_options(available_strategies[current_strategy_index])


func get_grid_size() -> Vector3i:
	"""Get the current grid size"""
	return grid_size


func set_grid_size(size: Vector3i) -> void:
	"""Set the grid size"""
	grid_size = size
	if x_spinbox:
		x_spinbox.value = grid_size.x
		y_spinbox.value = grid_size.y
		z_spinbox.value = grid_size.z


func get_current_strategy() -> WfcStrategyBase:
	"""Get the currently selected strategy"""
	if current_strategy_index >= 0 and current_strategy_index < available_strategies.size():
		return available_strategies[current_strategy_index]
	return null


func _on_grid_size_changed(_value: float) -> void:
	"""Handle grid size spinbox changes"""
	grid_size = Vector3i(
		int(x_spinbox.value),
		int(y_spinbox.value),
		int(z_spinbox.value)
	)
	print("Grid size changed to: ", grid_size)


func _on_strategy_selected(index: int) -> void:
	"""Handle strategy dropdown selection"""
	if index >= 0 and index < available_strategies.size():
		current_strategy_index = index
		var strategy = available_strategies[index]
		print("Strategy changed to: ", strategy.get_name())
		
		# Update strategy options container
		_update_strategy_options(strategy)


func _update_strategy_options(strategy: WfcStrategyBase) -> void:
	"""Update the strategy options container with the strategy's custom options"""
	# Clear existing options
	for child in strategy_options_container.get_children():
		child.queue_free()
	
	# Get options control from strategy
	var options_control = strategy.get_options()
	if options_control:
		strategy_options_container.add_child(options_control)


# =============================================================================
# Strategy Discovery
# =============================================================================

func _discover_strategies() -> void:
	"""Automatically discover all strategy classes in the strategies folder"""
	available_strategies.clear()
	
	var strategies_path = "res://addons/auto_structured/core/wfc/strategies/"
	var dir = DirAccess.open(strategies_path)
	
	if not dir:
		push_error("Could not open strategies directory: " + strategies_path)
		# Fallback to hardcoded strategies
		available_strategies = [
			WfcStrategyFillAll.new(),
			WfcStrategySparse.new(0.5),
			WfcStrategyGroundWalls.new()
		]
		return
	
	# Collect all .gd files (except base class)
	var strategy_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			# Skip the base class
			if file_name != "wfc_strategy_base.gd":
				strategy_files.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort alphabetically for consistent ordering
	strategy_files.sort()
	
	# Instantiate each strategy
	for strategy_file in strategy_files:
		var script_path = strategies_path + strategy_file
		var script = load(script_path)
		
		if script and script is GDScript:
			# Try to instantiate the strategy
			var strategy_instance = script.new()
			
			# Verify it's a valid strategy (has the required methods)
			if strategy_instance.has_method("should_collapse_cell") and \
			   strategy_instance.has_method("get_name") and \
			   strategy_instance.has_method("get_description"):
				
				# Special handling for Sparse strategy - set default probability
				if strategy_instance is WfcStrategySparse:
					strategy_instance.fill_probability = 0.5
				
				available_strategies.append(strategy_instance)
				print("Discovered strategy: ", strategy_instance.get_name())
			else:
				push_warning("Skipped invalid strategy: " + strategy_file)
	
	# Ensure we have at least one strategy
	if available_strategies.is_empty():
		push_error("No valid strategies found! Using fallback.")
		available_strategies = [WfcStrategyFillAll.new()]
