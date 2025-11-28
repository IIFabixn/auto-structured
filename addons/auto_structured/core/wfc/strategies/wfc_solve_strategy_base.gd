@tool
class_name WfcSolveStrategy extends RefCounted
## Base class for selecting the next cell to collapse during WFC solving.
##
## Custom strategies can override the hooks below to bias how the solver
## progresses across the grid while still relying on the main WFC pipeline.

func get_id() -> String:
	"""Unique identifier used by configs/inspector dropdowns."""
	return "entropy"

func get_display_name() -> String:
	"""Human-readable name for UI/debugging."""
	return "Entropy (default)"

func configure(_solver, _config) -> void:
	"""Called once the solver has a grid and optional config available."""
	pass

func on_reset(_solver) -> void:
	"""Invoked when the solver resets the grid so strategy state can reset too."""
	pass

func on_cell_collapsed(_cell) -> void:
	"""Notifies the strategy that a cell finished collapsing."""
	pass

func pick_next_cell(solver) -> Variant:
	"""Return the next cell to collapse. Default is entropy-based selection."""
	if solver == null:
		return null
	return solver.grid.get_lowest_entropy_cell()
