@tool
class_name WfcRegionConfig extends Resource
## Unified configuration for WFC region/boundary tracking and constraints.
##
## This resource consolidates all region-related settings that were previously
## scattered across WfcSolver, WfcSolverConfig, and RegionBoundaryRequirement.
##
## Region tracking allows WFC to:
## - Limit the number of separate boundary structures
## - Enforce that boundaries form closed loops
## - Control how boundary tiles connect to each other

## ============================================================================
## Core Settings
## ============================================================================

## Enable region tracking and boundary enforcement during WFC solve.
## When disabled, boundary_role on tiles is ignored.
@export var enabled: bool = false

## Maximum number of separate boundary structures allowed.
## 0 = unlimited, 1 = single connected structure (typical for buildings)
@export_range(0, 10) var max_regions: int = 1

## Whether boundary regions must form closed loops (no gaps to world edge).
## When true, post-solve validation will flag structures with openings.
@export var require_closed_regions: bool = true

## ============================================================================
## Boundary Tile Connection Rules
## ============================================================================

## Minimum adjacent boundary tiles required for EDGE role tiles.
## EDGE tiles form straight segments of walls/fences.
@export_range(1, 4) var min_edge_neighbors: int = 2

## Minimum adjacent boundary tiles required for CORNER role tiles.
## CORNER tiles handle turns in the boundary.
@export_range(1, 4) var min_corner_neighbors: int = 1

## Reduce neighbor requirements for tiles placed along the world boundary (grid edge).
## Useful for structures that intentionally open to the grid perimeter.
@export var relax_at_world_boundary: bool = true

## Allow boundary chains to terminate (dead ends) instead of requiring closed loops.
## When true, only 1 neighbor is required regardless of tile role.
@export var allow_open_ends: bool = false

## ============================================================================
## Advanced Settings
## ============================================================================

## Include vertical (Y-axis) neighbors when determining region connectivity.
## Enable for multi-story structures where walls connect across floors.
@export var include_vertical_connectivity: bool = true

## Enforce max_regions constraint during WFC solve (strict) or only validate after (relaxed).
## Relaxed mode (false) is recommended - it allows WFC to place walls freely, then validates.
## Strict mode (true) blocks wall placement that would create new regions, which can cause
## gaps when WFC doesn't solve in spatial order.
@export var enforce_max_regions_during_solve: bool = false


## ============================================================================
## Factory Methods
## ============================================================================

static func default() -> WfcRegionConfig:
	"""Create a default configuration (region tracking disabled)."""
	return WfcRegionConfig.new()


static func single_closed_structure() -> WfcRegionConfig:
	"""Create config for a single closed building structure."""
	var config = WfcRegionConfig.new()
	config.enabled = true
	config.max_regions = 1
	config.require_closed_regions = true
	config.min_edge_neighbors = 2
	config.min_corner_neighbors = 1
	config.relax_at_world_boundary = false
	config.allow_open_ends = false
	config.enforce_max_regions_during_solve = false  # Relaxed for better WFC results
	return config


static func multi_structure() -> WfcRegionConfig:
	"""Create config allowing multiple separate structures."""
	var config = WfcRegionConfig.new()
	config.enabled = true
	config.max_regions = 0  # Unlimited
	config.require_closed_regions = true
	config.relax_at_world_boundary = true
	return config


static func open_layout() -> WfcRegionConfig:
	"""Create config for open/fence-like structures that can have dead ends."""
	var config = WfcRegionConfig.new()
	config.enabled = true
	config.max_regions = 0
	config.require_closed_regions = false
	config.allow_open_ends = true
	config.min_edge_neighbors = 1
	return config


## ============================================================================
## Serialization Helpers
## ============================================================================

func to_dict() -> Dictionary:
	"""Serialize config to dictionary for storage."""
	return {
		"enabled": enabled,
		"max_regions": max_regions,
		"require_closed_regions": require_closed_regions,
		"min_edge_neighbors": min_edge_neighbors,
		"min_corner_neighbors": min_corner_neighbors,
		"relax_at_world_boundary": relax_at_world_boundary,
		"allow_open_ends": allow_open_ends,
		"include_vertical_connectivity": include_vertical_connectivity,
		"enforce_max_regions_during_solve": enforce_max_regions_during_solve
	}


static func from_dict(data: Dictionary) -> WfcRegionConfig:
	"""Deserialize config from dictionary."""
	var config = WfcRegionConfig.new()
	if data.is_empty():
		return config
	
	config.enabled = data.get("enabled", config.enabled)
	config.max_regions = data.get("max_regions", config.max_regions)
	config.require_closed_regions = data.get("require_closed_regions", config.require_closed_regions)
	config.min_edge_neighbors = data.get("min_edge_neighbors", config.min_edge_neighbors)
	config.min_corner_neighbors = data.get("min_corner_neighbors", config.min_corner_neighbors)
	config.relax_at_world_boundary = data.get("relax_at_world_boundary", config.relax_at_world_boundary)
	config.allow_open_ends = data.get("allow_open_ends", config.allow_open_ends)
	config.include_vertical_connectivity = data.get("include_vertical_connectivity", config.include_vertical_connectivity)
	config.enforce_max_regions_during_solve = data.get("enforce_max_regions_during_solve", config.enforce_max_regions_during_solve)
	
	return config


func duplicate_config() -> WfcRegionConfig:
	"""Create a deep copy of this config."""
	return WfcRegionConfig.from_dict(to_dict())
