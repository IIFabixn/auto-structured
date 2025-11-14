@tool
class_name Requirement extends Resource
## Base class for WFC generation requirements
##
## Override evaluate() in subclasses to implement custom requirement logic.
## The requirement system allows users to constrain module placement during
## Wave Function Collapse generation.

@export var enabled: bool = true

func evaluate(_cell_position: Vector3i, _context: Dictionary) -> bool:
	"""
	Check if this requirement is satisfied for the given cell position.

	Args:
		cell_position: The grid position being evaluated
		context: Dictionary containing:
			- "module": The module being considered (if any)
			- "tags": Array of tags from the module
			- "grid": Reference to the WFC grid
			- "neighbors": Dictionary of neighbor cells by direction

	Returns:
		true if the requirement is satisfied, false otherwise
	"""
	return enabled
