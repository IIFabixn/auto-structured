@tool
class_name StructureViewport extends Control

@onready var module_library_control: ModuleLibraryPanel = %ModuleLibraryPanel
@onready var details_panel: DetailsPanel = %DetailsPanel
@onready var viewport_panel: PreviewPanel = %PreviewPanel

func _ready() -> void:
	module_library_control.tile_selected.connect(_on_module_tile_selected)
	module_library_control.library_loaded.connect(_on_library_loaded)
	details_panel.closed.connect(_on_details_panel_closed)
	details_panel.tile_modified.connect(_on_tile_modified)
	details_panel.socket_preview_requested.connect(_on_socket_preview_requested)
	details_panel.socket_editor_requested.connect(_on_socket_editor_requested)
	
	# Ensure initial library is passed to preview panel if already loaded
	if module_library_control.current_library:
		viewport_panel.set_module_library(module_library_control.current_library)


func _on_module_tile_selected(tile: Tile) -> void:
	if tile == null:
		if details_panel.current_tile != null:
			details_panel.close_details()
		else:
			details_panel.hide()
		return

	details_panel.show_tile(tile, module_library_control.current_library)
	viewport_panel.preview_tile(tile)


func _on_details_panel_closed() -> void:
	viewport_panel.clear_structure()
	module_library_control.unselect_tile()


func _on_tile_modified(_tile: Tile) -> void:
	module_library_control.save_current_library()

func _on_library_loaded(library: ModuleLibrary) -> void:
	"""Update preview panel when library is loaded"""
	viewport_panel.set_module_library(library)


func _on_socket_preview_requested(socket: Socket) -> void:
	"""Handle socket preview request - show compatible tiles preview"""
	if not module_library_control.current_library:
		return

	var compatible_results = WfcHelper.find_compatible_tiles(
		socket,
		module_library_control.current_library.tiles,
		details_panel.current_tile
	)
	print("StructureViewport: Previewing compatible tiles for tile '%s', socket: %s" % [details_panel.current_tile.name, socket.socket_id])
	# Use the new preview_socket function with tile, socket, and compatible tiles
	viewport_panel.preview_socket(
		details_panel.current_tile,
		socket,
		compatible_results
	)

func _on_socket_editor_requested(tile: Tile, start_mode: int) -> void:
	if module_library_control == null:
		return
	module_library_control.open_socket_editor_for_tile(tile, start_mode)
