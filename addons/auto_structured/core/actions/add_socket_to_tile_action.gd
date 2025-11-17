@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name AddSocketToTileAction

## Action to add a socket to a tile with undo/redo support

var _tile: Tile
var _socket: Socket

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, socket: Socket) -> void:
	super(undo_redo, "Add Socket to Tile")
	_tile = tile
	_socket = socket

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_add_socket", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_remove_socket", [])

func _add_socket() -> void:
	if not _tile.sockets.has(_socket):
		_tile.sockets.append(_socket)

func _remove_socket() -> void:
	_tile.sockets.erase(_socket)
