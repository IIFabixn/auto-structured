@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name BoundaryRequirement

## Restricts tile placement based on proximity to grid boundaries.
## Useful for edge tiles, corner pieces, or tiles that shouldn't touch edges.

enum BoundaryMode {
	MUST_TOUCH,      ## Tile must be on at least one boundary
	MUST_NOT_TOUCH,  ## Tile must not be on any boundary
	CORNER_ONLY,     ## Tile must be on a corner (2+ boundaries)
	INTERIOR_ONLY    ## Tile must not touch any boundary
}

@export var mode: BoundaryMode = BoundaryMode.MUST_TOUCH
@export var check_x_boundaries: bool = true
@export var check_z_boundaries: bool = true
@export var check_y_boundaries: bool = false  ## Usually false for floor-based generation

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	
	var grid_size = grid.size
	var boundaries_touched = 0
	
	if check_x_boundaries:
		if position.x == 0 or position.x == grid_size.x - 1:
			boundaries_touched += 1
	
	if check_z_boundaries:
		if position.z == 0 or position.z == grid_size.z - 1:
			boundaries_touched += 1
	
	if check_y_boundaries:
		if position.y == 0 or position.y == grid_size.y - 1:
			boundaries_touched += 1
	
	match mode:
		BoundaryMode.MUST_TOUCH:
			return boundaries_touched > 0
		BoundaryMode.MUST_NOT_TOUCH:
			return boundaries_touched == 0
		BoundaryMode.CORNER_ONLY:
			return boundaries_touched >= 2
		BoundaryMode.INTERIOR_ONLY:
			return boundaries_touched == 0
	
	return true

func get_failure_reason() -> String:
	match mode:
		BoundaryMode.MUST_TOUCH:
			return "Tile must be on a boundary edge"
		BoundaryMode.MUST_NOT_TOUCH:
			return "Tile cannot be on a boundary edge"
		BoundaryMode.CORNER_ONLY:
			return "Tile must be on a corner (touching 2+ boundaries)"
		BoundaryMode.INTERIOR_ONLY:
			return "Tile must be in the interior (not touching boundaries)"
	return super.get_failure_reason()

func get_description() -> String:
	var axes = []
	if check_x_boundaries:
		axes.append("X")
	if check_z_boundaries:
		axes.append("Z")
	if check_y_boundaries:
		axes.append("Y")
	var axis_str = "/".join(axes) if not axes.is_empty() else "none"
	
	match mode:
		BoundaryMode.MUST_TOUCH:
			return "Must touch boundary (%s)" % axis_str
		BoundaryMode.MUST_NOT_TOUCH:
			return "Must not touch boundary (%s)" % axis_str
		BoundaryMode.CORNER_ONLY:
			return "Corner only (%s)" % axis_str
		BoundaryMode.INTERIOR_ONLY:
			return "Interior only (%s)" % axis_str
	return super.get_description()
