class_name WfcCell extends RefCounted

const Tile = preload("res://addons/auto_structured/core/tile.gd")

var possible_tiles: Array[Tile] = []
var position: Vector3i
var collapsed_tile: Tile = null

func _init(pos: Vector3i, all_tiles: Array[Tile]) -> void:
	position = pos
	possible_tiles = all_tiles.duplicate()

func is_collapsed() -> bool:
	return possible_tiles.size() == 1

func get_entropy() -> int:
	if is_collapsed():
		return -1
	return possible_tiles.size()

func collapse() -> bool:
	if possible_tiles.is_empty():
		return false

	if is_collapsed():
		collapsed_tile = possible_tiles[0]
		return true

	# Randomly select one tile from possibilities
	var selected_index = randi() % possible_tiles.size()
	collapsed_tile = possible_tiles[selected_index]
	possible_tiles = [collapsed_tile]

	return true

func constrain(valid_tiles: Array[Tile]) -> bool:
	if is_collapsed():
		return false

	var original_count = possible_tiles.size()
	var new_possible: Array[Tile] = []

	for tile in possible_tiles:
		if tile in valid_tiles:
			new_possible.append(tile)

	possible_tiles = new_possible

	return possible_tiles.size() < original_count

func has_contradiction() -> bool:
	return possible_tiles.is_empty()

func get_tile() -> Tile:
	return collapsed_tile

func reset(all_tiles: Array[Tile]) -> void:
	possible_tiles = all_tiles.duplicate()
	collapsed_tile = null