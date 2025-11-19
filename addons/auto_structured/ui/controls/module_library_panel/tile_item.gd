@tool
class_name TileItem extends VBoxContainer

const Tile = preload("res://addons/auto_structured/core/tile.gd")

signal tile_selected(tile: Tile)

@onready var tileImage: TextureRect = %TileImage
@onready var tileNameLabel: Label = %TileNameLabel

var _tile: Tile

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _tile:
			print("TileItem: Tile %s selected" % _tile.name)
			tile_selected.emit(_tile)

@export var tile: Tile:
	get: 
		return _tile
	set(value): 
		_tile = value
		_update_ui()

func _update_ui() -> void:
	if not is_node_ready():
		return
		
	if _tile:
		tileNameLabel.text = _tile.name
		# TODO Update tile image (placeholder logic)
	else:
		tileNameLabel.text = "No Tile"
		if tileImage:
			tileImage.texture = null