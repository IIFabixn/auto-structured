@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name RemoveTileFromLibraryAction

## Action to remove a tile from a library with undo/redo support

var _library: ModuleLibrary
var _tile: Tile
var _index: int

func _init(undo_redo: AutoStructuredUndoRedo, library: ModuleLibrary, tile: Tile) -> void:
	super(undo_redo, "Remove Tile from Library")
	_library = library
	_tile = tile
	_index = library.tiles.find(tile)

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_remove_tile", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_restore_tile", [])

func _remove_tile() -> void:
	_library.tiles.erase(_tile)

func _restore_tile() -> void:
	if _index >= 0 and _index <= _library.tiles.size():
		_library.tiles.insert(_index, _tile)
	else:
		_library.tiles.append(_tile)
