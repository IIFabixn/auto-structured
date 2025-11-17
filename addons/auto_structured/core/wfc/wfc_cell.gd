class_name WfcCell extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int)
var possible_tile_variants: Array[Dictionary] = []
var position: Vector3i
var collapsed_variant: Dictionary = {}  # {"tile": Tile, "rotation_degrees": int} - Single source of truth when collapsed

func _init(pos: Vector3i, all_tile_variants: Array[Dictionary]) -> void:
	position = pos
	possible_tile_variants = all_tile_variants.duplicate()

func is_collapsed() -> bool:
	"""Cell is collapsed when collapsed_variant is set."""
	return not collapsed_variant.is_empty()

func get_entropy() -> int:
	if is_collapsed():
		return -1
	return possible_tile_variants.size()

func collapse() -> bool:
	if possible_tile_variants.is_empty():
		return false

	if is_collapsed():
		return true

	# Randomly select one tile+rotation variant from possibilities
	var selected_index = randi() % possible_tile_variants.size()
	collapsed_variant = possible_tile_variants[selected_index]
	# Clear possible variants to save memory - collapsed_variant is now the single source of truth
	possible_tile_variants.clear()

	return true

func constrain(valid_variants: Array[Dictionary]) -> bool:
	if is_collapsed():
		return false

	var original_count = possible_tile_variants.size()
	var new_possible: Array[Dictionary] = []

	for variant in possible_tile_variants:
		if is_variant_in_list(variant, valid_variants):
			new_possible.append(variant)

	possible_tile_variants = new_possible

	return possible_tile_variants.size() < original_count

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
	"""A cell has a contradiction when no variants remain and it is not collapsed."""
	return possible_tile_variants.is_empty() and collapsed_variant.is_empty()

func get_tile() -> Tile:
	return collapsed_variant.get("tile", null)

func get_rotation() -> int:
	return collapsed_variant.get("rotation_degrees", 0)

func get_variant() -> Dictionary:
	return collapsed_variant

func reset(all_tile_variants: Array[Dictionary]) -> void:
	possible_tile_variants = all_tile_variants.duplicate()
	collapsed_variant = {}