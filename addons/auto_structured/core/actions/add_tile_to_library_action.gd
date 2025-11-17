@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name AddTileToLibraryAction

## Action to add a tile to a library with undo/redo support

var _library: ModuleLibrary
var _tile: Tile

func _init(undo_redo: AutoStructuredUndoRedo, library: ModuleLibrary, tile: Tile) -> void:
	super(undo_redo, "Add Tile to Library")
	_library = library
	_tile = tile

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_add_tile", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_remove_tile", [])

func _add_tile() -> void:
	if not _library.tiles.has(_tile):
		_library.tiles.append(_tile)

func _remove_tile() -> void:
	_library.tiles.erase(_tile)
