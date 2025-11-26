@tool
class_name AddTileDialog
extends ConfirmationDialog

signal tiles_selected(tiles: Array)

const Tile := preload("res://addons/auto_structured/core/tile.gd")

@onready var tile_list: ItemList = %TileList
@onready var info_label: Label = %InfoLabel

var _tiles: Array[Tile] = []

func _ready() -> void:
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	if tile_list:
		tile_list.select_mode = ItemList.SELECT_MULTI
		if not tile_list.item_selected.is_connected(_on_list_selection_changed):
			tile_list.item_selected.connect(_on_list_selection_changed)
		if not tile_list.multi_selected.is_connected(_on_list_multi_selection_changed):
			tile_list.multi_selected.connect(_on_list_multi_selection_changed)
	_update_dialog_state()

func set_available_tiles(tiles: Array) -> void:
	_tiles.clear()
	if tiles:
		for entry in tiles:
			var tile: Tile = entry
			if tile:
				_tiles.append(tile)
	if tile_list:
		tile_list.clear()
		for tile in _tiles:
			tile_list.add_item(_format_tile_label(tile))
	_update_dialog_state()

func _format_tile_label(tile: Tile) -> String:
	if tile == null:
		return "(Unnamed Tile)"
	var name := tile.name.strip_edges()
	return name if name != "" else "(Unnamed Tile)"

func _on_list_selection_changed(_index: int) -> void:
	_update_dialog_state()

func _on_list_multi_selection_changed(_index: int, _selected: bool) -> void:
	_update_dialog_state()

func _update_dialog_state() -> void:
	var selection_count := 0
	if tile_list:
		selection_count = tile_list.get_selected_items().size()
	var has_tiles := not _tiles.is_empty()
	if info_label:
		if not has_tiles:
			info_label.text = "All tiles are already visible."
		elif selection_count == 0:
			info_label.text = "Select tiles to add to the compatibility list."
		else:
			info_label.text = "Adding %d tile%s." % [selection_count, "s" if selection_count != 1 else ""]
	var ok_button := get_ok_button()
	if ok_button:
		ok_button.disabled = selection_count == 0 or not has_tiles

func _on_confirmed() -> void:
	if tile_list == null:
		return
	var selected_tiles: Array = []
	var indices := tile_list.get_selected_items()
	for idx in indices:
		if idx >= 0 and idx < _tiles.size():
			selected_tiles.append(_tiles[idx])
	if selected_tiles.is_empty():
		return
	emit_signal("tiles_selected", selected_tiles)
	hide()
