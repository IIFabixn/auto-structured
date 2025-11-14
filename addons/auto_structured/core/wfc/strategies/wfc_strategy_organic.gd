@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name WfcStrategyOrganic
## Noise-based strategy for organic, varied building structures.
##
## Uses Perlin noise to create more interesting, less boxy building shapes.
## Combines noise with edge bias to maintain structural integrity while
## adding variety to the overall shape.
##
## NOTE: For best results, ensure your tile library has tiles with "none" sockets
## or flexible socket compatibility to work with irregular shapes.


## Controls how much of the structure is filled (lower = more sparse, higher = more solid)
@export_range(0.0, 1.0) var density: float = 0.7

## Number of floors that should be completely solid at the base
@export_range(0, 5) var base_solid_height: int = 1

## Scale of the noise pattern (higher = more variation, lower = smoother)
@export_range(0.01, 0.5) var noise_frequency: float = 0.15

## Seed for noise generation (change for different variations)
@export var noise_seed: int = 0

## How much to favor filling cells near the edges (0.0 = no bias, 1.0 = strong edge preference)
@export_range(0.0, 1.0) var edge_bias_strength: float = 0.6

var noise: FastNoiseLite


func _init() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.seed = noise_seed


func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	# Always fill the base floors for structural stability
	if position.y < base_solid_height:
		return true
	
	# Always fill perimeter walls for first few floors to ensure socket compatibility
	var is_perimeter = (position.x == 0 or position.x == grid_size.x - 1 or
						position.z == 0 or position.z == grid_size.z - 1)
	if is_perimeter and position.y < 3:
		return true
	
	# Get noise value for this position
	var noise_val = noise.get_noise_3d(float(position.x), float(position.y), float(position.z))
	# Noise returns values from -1 to 1, normalize to 0 to 1
	noise_val = (noise_val + 1.0) / 2.0
	
	# Calculate distance to nearest edge (for edge bias)
	var dist_x = min(position.x, grid_size.x - 1 - position.x)
	var dist_z = min(position.z, grid_size.z - 1 - position.z)
	var dist_to_edge = min(dist_x, dist_z)
	
	# Normalize distance (0 at edge, 1 at center)
	var max_dist = min(grid_size.x, grid_size.z) / 2.0
	var normalized_dist = clamp(float(dist_to_edge) / max_dist, 0.0, 1.0)
	
	# Edge bias: cells near edges are more likely to be filled
	# (1.0 - normalized_dist) means edge = 1.0, center = 0.0
	var edge_bias = (1.0 - normalized_dist) * edge_bias_strength
	
	# Height falloff: higher floors are less likely to be filled (creates tapered effect)
	var height_ratio = float(position.y) / float(grid_size.y)
	var height_falloff = 1.0 - (height_ratio * 0.4)  # Reduce by up to 40% at top for taper
	
	# Combine noise with biases
	var final_value = noise_val + edge_bias
	final_value *= height_falloff
	
	# Threshold based on density setting
	var threshold = 1.0 - density
	
	return final_value > threshold


func get_name() -> String:
	return "Organic (Noise-Based)"


func get_description() -> String:
	return "Uses Perlin noise for varied, organic building shapes with controllable density"
