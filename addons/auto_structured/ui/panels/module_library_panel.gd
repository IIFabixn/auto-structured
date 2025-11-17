@tool
class_name ModuleLibraryPanel extends Control

signal library_loaded(library: ModuleLibrary)
signal library_created(library: ModuleLibrary)
signal library_selected(library_name: String)
signal library_deleted(library_name: String)
signal library_renamed(old_name: String, new_name: String)
signal library_saved(library: ModuleLibrary)
signal tile_selected(tile: Tile)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const AutoStructuredUndoRedo = preload("res://addons/auto_structured/core/undo_redo_manager.gd")

const CREATE = 0
const RENAME = 1
const SAVE = 2
const DELETE = 3

@onready var library_option_button: OptionButton = %LibraryOptionButton
@onready var library_menu_button: MenuButton = %LibraryMenuButton
@onready var search_tile_edit: LineEdit = %SearchTileEdit
@onready var add_tile_button: TextureButton = %AddTileButton
@onready var tile_list: ItemList = %TileList

var undo_redo_manager: AutoStructuredUndoRedo

func setup_undo_redo(undo_redo: AutoStructuredUndoRedo) -> void:
	"""
	Initialize the undo/redo system for this panel.
	Should be called by the parent viewport after instantiation.
	"""
	undo_redo_manager = undo_redo