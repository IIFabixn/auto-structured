@tool
class_name WfcSolverConfig extends RefCounted
const WfcEntropyStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_entropy.gd")
const WfcCenterOutStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_center_out.gd")
const WfcFrontierStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_frontier.gd")
const WfcGrowingStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_growing.gd")
const WfcBlueprintStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_blueprint.gd")
const WfcLayoutFirstStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_layout_first.gd")
const WfcGuidedEntropyStrategy = preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_guided_entropy.gd")
const BuildingBlueprint = preload("res://addons/auto_structured/core/blueprints/building_blueprint.gd")
const WfcRegionConfig = preload("res://addons/auto_structured/core/wfc/wfc_region_config.gd")
## Configuration settings for WFC solver performance tuning.
##
## Use this to adjust performance vs. smoothness trade-offs for different grid sizes.

## How often to yield during solve (ms). Lower = smoother but slower.
var yield_interval_ms: int = 16

## How many cells to process in propagation before yielding.
var propagation_batch_size: int = 50

## Whether to pre-warm the compatibility cache at initialization.
var prewarm_cache: bool = true

## Maximum iterations before giving up.
var max_iterations: int = 10000

## Interval for progress reporting (ms). 0 = disabled.
var progress_report_interval_ms: int = 2000

## Enable backtracking on contradictions.
var enable_backtracking: bool = true

## Maximum depth of backtrack stack.
var max_backtrack_depth: int = 10

## Save checkpoint every N collapses.
var backtrack_checkpoint_frequency: int = 5

@export_enum("entropy", "center_out", "frontier", "growing", "layout_first", "guided_entropy", "blueprint")
var solve_strategy_id: String = "entropy"

## Blueprint configuration (used when solve_strategy_id = "blueprint")
var blueprint_config: Dictionary = {
	"min_room_size": 4,
	"max_room_size": 8,
	"max_rooms": 6,
	"margin": 1,
	"floor_height": 1,
	"num_floors": 1,
	"add_roof": false,
	"doors_per_room": 1,  # -1 = one door total, 0 = none, 1+ = per room
}

## Region configuration (consolidated from scattered settings)
var region_config: WfcRegionConfig = WfcRegionConfig.new()

## Legacy properties for backward compatibility (deprecated - use region_config instead)
var enforce_region_boundaries: bool:
	get: return region_config.enabled
	set(value): region_config.enabled = value

var max_boundary_regions: int:
	get: return region_config.max_regions
	set(value): region_config.max_regions = value

var require_closed_regions: bool:
	get: return region_config.require_closed_regions
	set(value): region_config.require_closed_regions = value


## Preset for small grids (< 10K cells)
static func small_grid() -> WfcSolverConfig:
	var config = WfcSolverConfig.new()
	config.yield_interval_ms = 50  # Less frequent yielding
	config.propagation_batch_size = 100
	config.prewarm_cache = true
	config.max_iterations = 20000
	config.progress_report_interval_ms = 5000
	return config


## Preset for medium grids (10K - 50K cells)
static func medium_grid() -> WfcSolverConfig:
	var config = WfcSolverConfig.new()
	config.yield_interval_ms = 16  # 60 fps
	config.propagation_batch_size = 50
	config.prewarm_cache = true
	config.max_iterations = 100000
	config.progress_report_interval_ms = 2000
	return config


## Preset for large grids (50K - 200K cells)
static func large_grid() -> WfcSolverConfig:
	var config = WfcSolverConfig.new()
	config.yield_interval_ms = 8  # More responsive
	config.propagation_batch_size = 25  # Smaller batches
	config.prewarm_cache = true
	config.max_iterations = 500000
	config.progress_report_interval_ms = 1000  # More frequent updates
	return config


## Preset for very large grids (> 200K cells)
static func very_large_grid() -> WfcSolverConfig:
	var config = WfcSolverConfig.new()
	config.yield_interval_ms = 4  # Maximum responsiveness
	config.propagation_batch_size = 10  # Very small batches
	config.prewarm_cache = true
	config.max_iterations = 1000000
	config.progress_report_interval_ms = 500
	return config


## Custom configuration for specific needs
static func custom(yield_ms: int, batch_size: int, prewarm: bool = true) -> WfcSolverConfig:
	var config = WfcSolverConfig.new()
	config.yield_interval_ms = yield_ms
	config.propagation_batch_size = batch_size
	config.prewarm_cache = prewarm
	return config

func create_strategy_instance() -> WfcSolveStrategy:
	"""Instantiate the selected solve strategy."""
	match solve_strategy_id:
		"center_out":
			return WfcCenterOutStrategy.new()
		"frontier":
			return WfcFrontierStrategy.new()
		"growing":
			return WfcGrowingStrategy.new()
		"layout_first":
			return WfcLayoutFirstStrategy.new()
		"guided_entropy":
			return WfcGuidedEntropyStrategy.new()
		"blueprint":
			var strategy = WfcBlueprintStrategy.new()
			var blueprint = BuildingBlueprint.new()
			blueprint.configure(blueprint_config)
			strategy.set_blueprint(blueprint)
			return strategy
		_:
			return WfcEntropyStrategy.new()


func apply_to_solver(solver: WfcSolver, structural_config: Dictionary = {}) -> void:
	"""Apply this configuration to a solver instance."""
	solver.max_iterations = max_iterations
	solver.yield_interval_ms = yield_interval_ms
	solver.propagation_batch_size = propagation_batch_size
	solver.progress_report_interval_ms = progress_report_interval_ms
	solver.enable_backtracking = enable_backtracking
	solver.max_backtrack_depth = max_backtrack_depth
	solver.backtrack_checkpoint_frequency = backtrack_checkpoint_frequency
	
	# Apply region configuration
	if solver.has_method("set_region_config"):
		solver.set_region_config(region_config)
	else:
		# Fallback for backward compatibility
		solver.max_boundary_regions = region_config.max_regions
		solver.require_closed_regions = region_config.require_closed_regions
		if solver.has_method("set_region_boundary_enforcement"):
			solver.set_region_boundary_enforcement(region_config.enabled)
	
	# Apply structural constraints
	if not structural_config.is_empty():
		_apply_structural_constraints(solver, structural_config)
	
	if solver.has_method("set_solve_strategy"):
		solver.set_solve_strategy(create_strategy_instance(), self)

func _apply_structural_constraints(solver: WfcSolver, config: Dictionary) -> void:
	"""Configure structural constraints on the solver."""
	const WallContinuityConstraint = preload("res://addons/auto_structured/core/constraints/wall_continuity_constraint.gd")
	const DoorPlacementConstraint = preload("res://addons/auto_structured/core/constraints/door_placement_constraint.gd")
	const FloorSupportConstraint = preload("res://addons/auto_structured/core/constraints/floor_support_constraint.gd")
	
	solver.enforce_structural_constraints = config.get("enabled", true)
	solver.clear_structural_constraints()
	
	if not solver.enforce_structural_constraints:
		return
	
	# Wall Continuity Constraint
	var wall_cfg = config.get("wall_continuity", {})
	if wall_cfg.get("enabled", true):
		var wall_constraint = WallContinuityConstraint.new()
		wall_constraint.min_connections = wall_cfg.get("min_connections", 2)
		wall_constraint.corners_count_as_walls = true
		wall_constraint.doors_break_continuity = false
		solver.add_structural_constraint(wall_constraint)
	
	# Door Placement Constraint
	var door_cfg = config.get("door_placement", {})
	if door_cfg.get("enabled", true):
		var door_constraint = DoorPlacementConstraint.new()
		door_constraint.min_adjacent_walls = door_cfg.get("min_adjacent_walls", 2)
		door_constraint.require_floor_below = door_cfg.get("require_floor_below", true)
		door_constraint.allow_corner_doors = false
		solver.add_structural_constraint(door_constraint)
	
	# Floor Support Constraint
	var floor_cfg = config.get("floor_support", {})
	if floor_cfg.get("enabled", true):
		var floor_constraint = FloorSupportConstraint.new()
		floor_constraint.require_vertical_support = floor_cfg.get("require_vertical_support", true)
		floor_constraint.require_ground_support = false
		solver.add_structural_constraint(floor_constraint)
