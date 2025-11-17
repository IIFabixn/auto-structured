@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyLibraryPropertyAction

## Action to modify a library property with undo/redo support

var _library: ModuleLibrary
var _property: String
var _new_value: Variant
var _old_value: Variant

func _init(undo_redo: AutoStructuredUndoRedo, library: ModuleLibrary, property: String, new_value: Variant) -> void:
	super(undo_redo, "Modify Library %s" % property.capitalize())
	_library = library
	_property = property
	_new_value = new_value
	_old_value = library.get(_property)

func _setup_do() -> void:
	_undo_redo.add_do_property(_library, _property, _new_value)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_library, _property, _old_value)
