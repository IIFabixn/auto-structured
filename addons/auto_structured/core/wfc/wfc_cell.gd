class_name WfcCell extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Array of dictionaries with keys: "tile" (Tile), "rotation_degrees" (int)
var possible_tile_variants: Array[Dictionary] = []
var position: Vector3i
var collapsed_variant: Dictionary = {}  # {"tile": Tile, "rotation_degrees": int}

func _init(pos: Vector3i, all_tile_variants: Array[Dictionary]) -> void:
	position = pos
	possible_tile_variants = all_tile_variants.duplicate()

func is_collapsed() -> bool:
	return possible_tile_variants.size() == 1

func get_entropy() -> int:
	if is_collapsed():
		return -1
	return possible_tile_variants.size()

func collapse() -> bool:
	if possible_tile_variants.is_empty():
		return false

	if is_collapsed():
		collapsed_variant = possible_tile_variants[0]
		return true

	# Randomly select one tile+rotation variant from possibilities
	var selected_index = randi() % possible_tile_variants.size()
	collapsed_variant = possible_tile_variants[selected_index]
	possible_tile_variants = [collapsed_variant]

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
	"""Check if a tile+rotation variant exists in the list."""
	for item in list:
		if item["tile"] == variant["tile"] and item["rotation_degrees"] == variant["rotation_degrees"]:
			return true
	return false

func has_contradiction() -> bool:
	return possible_tile_variants.is_empty()

func get_tile() -> Tile:
	return collapsed_variant.get("tile", null)

func get_rotation() -> int:
	return collapsed_variant.get("rotation_degrees", 0)

func get_variant() -> Dictionary:
	return collapsed_variant

func reset(all_tile_variants: Array[Dictionary]) -> void:
	possible_tile_variants = all_tile_variants.duplicate()
	collapsed_variant = {}