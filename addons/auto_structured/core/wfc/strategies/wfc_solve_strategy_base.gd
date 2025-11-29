@tool
class_name WfcSolveStrategy extends RefCounted
## Base class for WFC solve strategies.
##
## Strategies control two aspects of WFC solving:
## 1. Grid preparation - modify the grid before solving (remove candidates, pre-collapse cells)
## 2. Cell selection - pick which cell to collapse next during solving
##
## The key method is prepare_grid() which receives the fully populated grid
## and can modify it before WFC begins. This allows strategies to:
## - Generate room layouts and mark zones
## - Remove invalid tile candidates from cells
## - Pre-collapse certain cells to specific tiles
## - Apply any structural constraints

func get_id() -> String:
	"""Unique identifier used by configs/inspector dropdowns."""
	return "entropy"

func get_display_name() -> String:
	"""Human-readable name for UI/debugging."""
	return "Entropy (default)"

func configure(_solver, _config) -> void:
	"""Called once the solver has a grid and optional config available."""
	pass


func get_solver_overrides() -> Dictionary:
	"""Return solver configuration overrides for this strategy.
	
	Strategies can override solver settings by returning a dictionary
	with keys matching solver properties. For example:
	
	return {
		"enforce_region_boundaries": false,  # Disable boundary requirement checks
		"max_boundary_regions": 0,           # Disable region counting
	}
	
	Returns:
		Dictionary of solver property names to values
	"""
	return {}


func prepare_grid(_grid, _solver) -> void:
	"""Called before solving begins. Override to modify the grid.
	
	This is the main hook for strategies to set up structural constraints.
	The grid is fully populated with all tile variants at this point.
	
	Examples:
	- Generate a room layout and restrict cells to appropriate tile types
	- Remove boundary tiles from interior cells
	- Pre-collapse corner cells to corner tiles
	
	Args:
		grid: The WfcGrid with all cells populated
		solver: The WfcSolver instance (for access to config, etc.)
	"""
	pass

func on_reset(_solver) -> void:
	"""Invoked when the solver resets the grid so strategy state can reset too."""
	pass

func on_cell_collapsed(_cell) -> void:
	"""Notifies the strategy that a cell finished collapsing."""
	pass

func inject_constraints(_grid, _solver) -> void:
	"""Opportunity to add or update constraints before each selection step."""
	pass

func before_collapse(cell, solver) -> void:
	"""Hook before a cell collapses. Default implementation adjusts weights."""
	adjust_weights_for_cell(cell, solver)

func after_propagation(_cell, _solver, _changed_cells: Array = []) -> void:
	"""Called after propagation completes. Override for post-processing."""
	pass

func pick_next_cell(solver) -> Variant:
	"""Return the next cell to collapse. Default is entropy-based selection."""
	if solver == null:
		return null
	return solver.grid.get_lowest_entropy_cell()

func adjust_weights_for_cell(_cell, _solver) -> void:
	"""Called before collapsing a cell. Override to modify variant weights."""
	pass
