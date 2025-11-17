@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name AddTileTagAction

## Action to add a tag to a tile with undo/redo support

var _tile: Tile
var _tag: String

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, tag: String) -> void:
	super(undo_redo, "Add Tag")
	_tile = tile
	_tag = tag

func _setup_do() -> void:
	_undo_redo.add_do_method(_tile, "add_tag", [_tag])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(_tile, "remove_tag", [_tag])
