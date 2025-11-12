@tool
class_name StructureViewport extends Control

@onready var module_library_control: ModuleLibraryControl = %ModuleLibraryControl
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

func _ready() -> void:
	module_library_control.tile_selected.connect(_on_module_tile_selected)
	details_panel.closed.connect(_on_details_panel_closed)
	details_panel.tile_modified.connect(_on_tile_modified)
	details_panel.socket_preview_requested.connect(_on_socket_preview_requested)


func _on_module_tile_selected(tile: Tile) -> void:
	details_panel.display_tile_details(tile, module_library_control.current_library)
	viewport_panel.display_tile_preview(tile)


func _on_details_panel_closed() -> void:
	viewport_panel.clear_structure()
	module_library_control.unselect_tile()


func _on_tile_modified(_tile: Tile) -> void:
	module_library_control.save_current_library()

func _on_socket_preview_requested(socket_item: SocketItem) -> void:
	"""Handle socket preview request - show compatible tiles preview"""
	var compatible_tiles = socket_item.get_compatible_tiles()
	if compatible_tiles.size() > 0:
		# Pass the socket direction so compatible tiles can be positioned correctly
		viewport_panel.start_compatible_tiles_preview(compatible_tiles, socket_item.socket.direction)
	else:
		# Show a brief message if no compatible tiles found
		push_warning("No compatible tiles found for socket: %s" % socket_item.socket.socket_id)
