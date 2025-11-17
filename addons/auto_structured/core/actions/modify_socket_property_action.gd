@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifySocketPropertyAction

## Action to modify a socket property with undo/redo support

var _socket: Socket
var _property: String
var _new_value: Variant
var _old_value: Variant

func _init(undo_redo: AutoStructuredUndoRedo, socket: Socket, property: String, new_value: Variant) -> void:
	super(undo_redo, "Modify Socket %s" % property.capitalize())
	_socket = socket
	_property = property
	_new_value = new_value
	_old_value = socket.get(_property)

func _setup_do() -> void:
	_undo_redo.add_do_property(_socket, _property, _new_value)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_socket, _property, _old_value)
