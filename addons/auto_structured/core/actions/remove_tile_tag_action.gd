@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name RemoveTileTagAction

## Action to remove a tag from a tile with undo/redo support

var _tile: Tile
var _tag: String
var _index: int

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, tag: String) -> void:
	super(undo_redo, "Remove Tag")
	_tile = tile
	_tag = tag
	_index = tile.tags.find(tag)

func _setup_do() -> void:
	_undo_redo.add_do_method(_tile, "remove_tag", [_tag])

func _setup_undo() -> void:
	# Need to restore at the correct index
	_undo_redo.add_undo_method(self, "_restore_tag", [])

func _restore_tag() -> void:
	if _index >= 0 and _index <= _tile.tags.size():
		_tile.tags.insert(_index, _tag)
	else:
		_tile.tags.append(_tag)
