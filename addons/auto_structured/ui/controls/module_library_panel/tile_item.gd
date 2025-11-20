@tool
class_name TileItem extends VBoxContainer

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const TileThumbnailGenerator = preload("res://addons/auto_structured/utils/thumbnail_generator.gd")

signal tile_selected(tile: Tile)
signal tile_deleted(tile: Tile)

@onready var tileImage: TextureRect = %TileImage
@onready var tileNameLabel: Label = %TileNameLabel
@onready var popupMenu: PopupMenu = %PopupMenu

const DELETE = 0

var _tile: Tile
@export var tile: Tile:
	get: 
		return _tile
	set(value): 
		_tile = value
		_update_ui()

func _ready() -> void:
	popupMenu.add_item("Delete Tile", DELETE)
	popupMenu.id_pressed.connect(_on_popup_menu_id_pressed)

func _gui_input(event: InputEvent) -> void:
	if not _tile:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tile_selected.emit(_tile)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var global_pos = get_global_mouse_position()
			popupMenu.position = global_pos
			popupMenu.popup()

func _on_popup_menu_id_pressed(id: int) -> void:
	if id == DELETE and _tile:
		tile_deleted.emit(_tile)
		queue_free()

func _update_ui() -> void:
	if not is_node_ready():
		return
		
	if _tile:
		tileNameLabel.text = _tile.name
		_generate_thumbnail()
	else:
		tileNameLabel.text = "No Tile"
		if tileImage:
			tileImage.texture = null

func _generate_thumbnail() -> void:
	"""Generate a thumbnail image for the tile."""
	if not _tile or not tileImage:
		return
		
	var texture = await TileThumbnailGenerator.generate_thumbnail(_tile, self, Vector2i(64, 64))
	if texture:
		tileImage.texture = texture