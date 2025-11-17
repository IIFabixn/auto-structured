@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name RemoveSocketFromTileAction

## Action to remove a socket from a tile with undo/redo support

var _tile: Tile
var _socket: Socket
var _index: int

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, socket: Socket) -> void:
	super(undo_redo, "Remove Socket from Tile")
	_tile = tile
	_socket = socket
	_index = tile.sockets.find(socket)

func _setup_do() -> void:
	_undo_redo.add_do_method(self, "_remove_socket", [])

func _setup_undo() -> void:
	_undo_redo.add_undo_method(self, "_restore_socket", [])

func _remove_socket() -> void:
	_tile.sockets.erase(_socket)

func _restore_socket() -> void:
	if _index >= 0 and _index <= _tile.sockets.size():
		_tile.sockets.insert(_index, _socket)
	else:
		_tile.sockets.append(_socket)
