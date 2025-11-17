@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyRequirementPropertyAction

## Action to modify a requirement property with undo/redo support

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

var _requirement: Requirement
var _property: String
var _new_value: Variant
var _old_value: Variant

func _init(undo_redo: AutoStructuredUndoRedo, requirement: Requirement, property: String, new_value: Variant) -> void:
	super(undo_redo, "Modify Requirement %s" % property.capitalize())
	_requirement = requirement
	_property = property
	_new_value = new_value
	_old_value = requirement.get(_property)

func _setup_do() -> void:
	_undo_redo.add_do_property(_requirement, _property, _new_value)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_requirement, _property, _old_value)
