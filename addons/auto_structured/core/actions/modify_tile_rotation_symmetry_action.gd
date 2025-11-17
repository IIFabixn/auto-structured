@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyTileRotationSymmetryAction

## Action to modify a tile's rotation symmetry mode with undo/redo support.

const Tile = preload("res://addons/auto_structured/core/tile.gd")

var tile: Tile
var old_symmetry: Tile.RotationSymmetry
var new_symmetry: Tile.RotationSymmetry
var old_custom_rotations: Array[int]
var new_custom_rotations: Array[int]

func _init(p_tile: Tile, p_new_symmetry: Tile.RotationSymmetry, p_new_custom_rotations: Array[int] = []) -> void:
	tile = p_tile
	old_symmetry = tile.rotation_symmetry
	new_symmetry = p_new_symmetry
	
	# Store custom rotations
	old_custom_rotations = []
	old_custom_rotations.assign(tile.custom_rotations)
	new_custom_rotations = []
	new_custom_rotations.assign(p_new_custom_rotations)

func do(undo_redo: EditorUndoRedoManager) -> void:
	undo_redo.add_do_property(tile, "rotation_symmetry", new_symmetry)
	if new_symmetry == Tile.RotationSymmetry.CUSTOM:
		undo_redo.add_do_method(self, "_set_custom_rotations", tile, new_custom_rotations)
	
	undo_redo.add_undo_property(tile, "rotation_symmetry", old_symmetry)
	if old_symmetry == Tile.RotationSymmetry.CUSTOM:
		undo_redo.add_undo_method(self, "_set_custom_rotations", tile, old_custom_rotations)

func _set_custom_rotations(target_tile: Tile, rotations: Array[int]) -> void:
	target_tile.custom_rotations.clear()
	target_tile.custom_rotations.assign(rotations)

func get_description() -> String:
	var symmetry_names = {
		Tile.RotationSymmetry.AUTO: "Auto",
		Tile.RotationSymmetry.FULL: "Full (4 rotations)",
		Tile.RotationSymmetry.HALF: "Half (2 rotations)",
		Tile.RotationSymmetry.QUARTER: "Quarter (1 rotation)",
		Tile.RotationSymmetry.CUSTOM: "Custom"
	}
	return "Change tile '%s' rotation symmetry to %s" % [tile.name, symmetry_names.get(new_symmetry, "Unknown")]
