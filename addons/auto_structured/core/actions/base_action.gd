@tool
class_name BaseAction extends RefCounted

## Base class for undoable actions in Auto Structured plugin.
## Actions encapsulate both the forward operation and its inverse.

const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

var _undo_redo: AutoStructuredUndoRedo
var _action_name: String

func _init(undo_redo: AutoStructuredUndoRedo, action_name: String = "Action") -> void:
	_undo_redo = undo_redo
	_action_name = action_name

## Execute this action and register it with the undo/redo system
func execute() -> void:
	_undo_redo.begin_action(_action_name)
	_setup_do()
	_setup_undo()
	_undo_redo.commit_action()

## Override in subclasses to define the forward operation
func _setup_do() -> void:
	push_error("_setup_do() not implemented in %s" % get_script().resource_path)

## Override in subclasses to define the undo operation
func _setup_undo() -> void:
	push_error("_setup_undo() not implemented in %s" % get_script().resource_path)
