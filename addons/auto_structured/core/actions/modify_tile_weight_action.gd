@tool
extends "res://addons/auto_structured/core/actions/base_action.gd"
class_name ModifyTileWeightAction

## Action to modify a tile's weight with undo/redo support

var _tile: Tile
var _new_weight: float
var _old_weight: float

func _init(undo_redo: AutoStructuredUndoRedo, tile: Tile, new_weight: float) -> void:
	super(undo_redo, "Change Tile Weight")
	_tile = tile
	_new_weight = maxf(0.01, new_weight)
	_old_weight = tile.weight

func _setup_do() -> void:
	_undo_redo.add_do_property(_tile, "weight", _new_weight)

func _setup_undo() -> void:
	_undo_redo.add_undo_property(_tile, "weight", _old_weight)
