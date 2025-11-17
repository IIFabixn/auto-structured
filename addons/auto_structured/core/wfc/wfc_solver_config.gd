class_name WfcSolverConfig extends RefCounted
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


func apply_to_solver(solver: WfcSolver) -> void:
	"""Apply this configuration to a solver instance."""
	solver.max_iterations = max_iterations
	solver.yield_interval_ms = yield_interval_ms
	solver.propagation_batch_size = propagation_batch_size
	solver.progress_report_interval_ms = progress_report_interval_ms
	solver.enable_backtracking = enable_backtracking
	solver.max_backtrack_depth = max_backtrack_depth
	solver.backtrack_checkpoint_frequency = backtrack_checkpoint_frequency
