@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyTileNameAction

## Action to modify a tile's name with undo/redo support

var _tile: Tile
var _new_name: String
var _old_name: String

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, new_name: String) -> void:
	super(undo_redo, "Rename Tile")
	_tile = tile
	_new_name = new_name
	_old_name = tile.name

func _setup_do() -> void:
	_undo_redo.add_do_property(_tile, "name", _new_name)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_tile, "name", _old_name)
