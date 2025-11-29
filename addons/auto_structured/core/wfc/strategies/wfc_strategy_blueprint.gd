@tool
class_name WfcBlueprintStrategy extends "res://addons/auto_structured/core/wfc/strategies/wfc_solve_strategy_base.gd"
## WFC solve strategy that uses Blueprints to prepare the grid.
##
## This strategy delegates zone generation and cell filtering to a Blueprint,
## allowing different generation patterns without duplicating WFC logic.
##
## Usage:
##   var strategy = WfcBlueprintStrategy.new()
##   strategy.set_blueprint(BuildingBlueprint.new())
##   strategy.blueprint.configure({"max_rooms": 5})
##   solver.set_solve_strategy(strategy)

const BlueprintBase = preload("res://addons/auto_structured/core/blueprints/blueprint_base.gd")
const BuildingBlueprint = preload("res://addons/auto_structured/core/blueprints/building_blueprint.gd")

## The blueprint to use for generation
var blueprint: BlueprintBase = null

## Reference to grid/solver during prepare phase
var _grid_ref = null
var _solver_ref = null

## Debug mode
var debug_enabled: bool = false


func get_id() -> String:
	if blueprint:
		return "blueprint_%s" % blueprint.get_id()
	return "blueprint"


func get_display_name() -> String:
	if blueprint:
		return "Blueprint: %s" % blueprint.get_display_name()
	return "Blueprint Strategy"


func set_blueprint(bp: BlueprintBase) -> void:
	blueprint = bp
	if blueprint:
		blueprint.debug_enabled = debug_enabled


func configure(_solver, _config) -> void:
	if _solver:
		_solver_ref = _solver
		_grid_ref = _solver.grid


func get_solver_overrides() -> Dictionary:
	## Blueprints handle structure deterministically, so disable some solver checks
	return {
		"enforce_region_boundaries": false,
		"require_closed_regions": false,
	}


func prepare_grid(grid, solver) -> void:
	## Apply blueprint zones to the grid.
	if grid == null:
		push_error("BlueprintStrategy: Cannot prepare null grid")
		return
	
	_grid_ref = grid
	_solver_ref = solver
	
	# Create default blueprint if none set
	if blueprint == null:
		blueprint = BuildingBlueprint.new()
		blueprint.debug_enabled = debug_enabled
		_log("No blueprint set, using default BuildingBlueprint")
	
	# Generate the blueprint
	blueprint.generate(grid.size)
	
	# Apply zone constraints to each cell
	var zone_counts: Dictionary = {}
	var cells_filtered = 0
	
	for cell in grid.get_all_cells():
		if cell == null or cell.is_collapsed():
			continue
		
		var zone = blueprint.get_zone(cell.position)
		zone_counts[zone] = zone_counts.get(zone, 0) + 1
		
		var before_count = cell.possible_tile_variants.size()
		
		# Handle EMPTY zone specially - mark cell as empty
		if zone == BlueprintBase.Zone.EMPTY:
			cell.possible_tile_variants.clear()
			cell._entropy_valid = false
			continue
		
		# Filter cell based on zone
		blueprint.filter_cell_by_zone(cell, zone)
		
		var after_count = cell.possible_tile_variants.size()
		if after_count < before_count:
			cells_filtered += 1
		
		# Debug output for cells with few variants
		if debug_enabled and after_count <= 2 and after_count < before_count:
			_log("Cell %s (%s): %d -> %d variants" % [
				cell.position, 
				blueprint.get_zone_name(zone), 
				before_count, 
				after_count
			])
	
	# Print summary
	_log("Blueprint applied:")
	for zone in zone_counts:
		_log("  %s: %d cells" % [blueprint.get_zone_name(zone), zone_counts[zone]])
	_log("  Cells with reduced variants: %d" % cells_filtered)


func on_reset(_solver) -> void:
	# Blueprint state is regenerated on each prepare_grid call
	pass


func pick_next_cell(solver) -> Variant:
	## Pick next cell, optionally using blueprint priorities.
	if solver == null or solver.grid == null:
		return null
	
	# For now, use default entropy-based selection
	# Could enhance to use blueprint.get_collapse_priority()
	return solver.grid.get_lowest_entropy_cell()


func adjust_weights_for_cell(cell, _solver) -> void:
	## Adjust variant weights based on blueprint context.
	if cell == null or blueprint == null:
		return
	
	var zone = blueprint.get_zone(cell.position)
	
	# For wall/door zones, prefer rotations that face the correct direction
	if zone == BlueprintBase.Zone.WALL or zone == BlueprintBase.Zone.DOOR:
		var facing = blueprint.get_wall_facing_direction(cell.position)
		if facing != Vector3i.ZERO:
			_adjust_wall_rotation_weights(cell, facing)


func _adjust_wall_rotation_weights(cell, facing_direction: Vector3i) -> void:
	## Boost weights for wall rotations that align with the expected facing.
	## This encourages walls to face outward without forcing them.
	
	# Map facing direction to preferred rotation
	# Assuming wall's "outside" face is at -Z in local space (rotation 0)
	var preferred_rotation = _direction_to_rotation(facing_direction)
	
	for variant in cell.possible_tile_variants:
		var rotation = variant.get("rotation_degrees", 0)
		var weight = variant.get("weight", 1.0)
		
		if rotation == preferred_rotation:
			# Boost weight for correct rotation
			variant["weight"] = weight * 3.0
		else:
			# Slightly reduce weight for wrong rotations
			variant["weight"] = weight * 0.5


func _direction_to_rotation(direction: Vector3i) -> int:
	## Convert facing direction to Y rotation in degrees.
	## Assumes wall's "outside" is -Z at rotation 0.
	if direction == Vector3i(0, 0, -1):  # -Z
		return 0
	elif direction == Vector3i(1, 0, 0):  # +X
		return 90
	elif direction == Vector3i(0, 0, 1):  # +Z
		return 180
	elif direction == Vector3i(-1, 0, 0):  # -X
		return 270
	return 0


func _log(message: String) -> void:
	if debug_enabled:
		print("[BlueprintStrategy] %s" % message)
