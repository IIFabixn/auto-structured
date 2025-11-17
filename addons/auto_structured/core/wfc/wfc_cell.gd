class_name WfcCell extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int), "weight" (float)
var possible_tile_variants: Array[Dictionary] = []
var position: Vector3i

## Cache for Shannon entropy (invalidated when possibilities change)
var _cached_entropy: float = -1.0
var _entropy_valid: bool = false

func _init(pos: Vector3i, all_tile_variants: Array[Dictionary]) -> void:
	position = pos
	possible_tile_variants = all_tile_variants.duplicate()
	_entropy_valid = false

func is_collapsed() -> bool:
	"""Cell is collapsed when only one variant remains."""
	return possible_tile_variants.size() == 1

func get_entropy() -> float:
	"""Calculate Shannon entropy: -sum(p * log(p)) where p is normalized weight."""
	if is_collapsed():
		return -1.0
	
	if _entropy_valid:
		return _cached_entropy
	
	var count = possible_tile_variants.size()
	if count == 0:
		return 0.0
	
	# Calculate total weight
	var total_weight := 0.0
	for variant in possible_tile_variants:
		total_weight += variant.get("weight", 1.0)
	
	# Calculate Shannon entropy
	var entropy := 0.0
	for variant in possible_tile_variants:
		var weight = variant.get("weight", 1.0)
		var probability = weight / total_weight
		if probability > 0.0:
			entropy -= probability * log(probability)
	
	# Add small noise for tie-breaking
	entropy += randf() * 0.0001
	
	_cached_entropy = entropy
	_entropy_valid = true
	return entropy

func collapse() -> bool:
	"""Collapse to a single variant using weighted random selection."""
	if possible_tile_variants.is_empty():
		return false

	if is_collapsed():
		return true

	# Weighted random selection based on tile weights
	var total_weight := 0.0
	for variant in possible_tile_variants:
		total_weight += variant.get("weight", 1.0)
	
	var random_value = randf() * total_weight
	var cumulative_weight := 0.0
	var selected_variant: Dictionary
	
	for variant in possible_tile_variants:
		cumulative_weight += variant.get("weight", 1.0)
		if cumulative_weight >= random_value:
			selected_variant = variant
			break
	
	# Fallback to last variant if floating point errors
	if selected_variant.is_empty():
		selected_variant = possible_tile_variants[-1]
	
	# Keep only the selected variant
	possible_tile_variants.clear()
	possible_tile_variants.append(selected_variant)
	_entropy_valid = false

	return true

func constrain(valid_variants: Array[Dictionary]) -> bool:
	"""Constrain possibilities to only valid variants. Returns true if changed."""
	if is_collapsed():
		return false

	var original_count = possible_tile_variants.size()
	var new_possible: Array[Dictionary] = []

	for variant in possible_tile_variants:
		if is_variant_in_list(variant, valid_variants):
			new_possible.append(variant)

	possible_tile_variants = new_possible
	
	if possible_tile_variants.size() < original_count:
		_entropy_valid = false
		return true
	
	return false

func is_variant_in_list(variant: Dictionary, list: Array[Dictionary]) -> bool:
	"""Check if a tile+rotation variant exists in the list. Optimized for performance."""
	var target_tile = variant["tile"]
	var target_rotation = variant["rotation_degrees"]
	
	# Direct comparison is faster than dictionary access in tight loops
	for item in list:
		if item["tile"] == target_tile and item["rotation_degrees"] == target_rotation:
			return true
	return false

func has_contradiction() -> bool:
	"""A cell has a contradiction when no variants remain."""
	return possible_tile_variants.is_empty()

func get_tile() -> Tile:
	"""Get the collapsed tile, or null if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0].get("tile", null)
	return null

func get_rotation() -> int:
	"""Get the collapsed rotation, or 0 if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0].get("rotation_degrees", 0)
	return 0

func get_variant() -> Dictionary:
	"""Get the collapsed variant, or empty dict if not collapsed."""
	if is_collapsed():
		return possible_tile_variants[0]
	return {}

func reset(all_tile_variants: Array[Dictionary]) -> void:
	"""Reset cell to uncollapsed state with all possibilities."""
	possible_tile_variants = all_tile_variants.duplicate()
	_entropy_valid = false