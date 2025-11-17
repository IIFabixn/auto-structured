@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyTileSizeAction

## Action to modify a tile's size with undo/redo support

var _tile: Tile
var _new_size: Vector3i
var _old_size: Vector3i

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, new_size: Vector3i) -> void:
	super(undo_redo, "Change Tile Size")
	_tile = tile
	_new_size = new_size
	_old_size = tile.size

func _setup_do() -> void:
	_undo_redo.add_do_property(_tile, "size", _new_size)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_tile, "size", _old_size)
