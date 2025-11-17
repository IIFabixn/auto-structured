@tool
class_name SelectionManager extends RefCounted
## Centralized selection state management for tiles and sockets.
##
## Provides a single source of truth for what tile/socket is currently selected
## across all UI components, with change notifications via signals.
##
## Usage:
##   var manager = SelectionManager.new()
##   manager.selection_changed.connect(_on_selection_changed)
##   manager.select_tile(my_tile)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

## Emitted when the selected tile changes
## Parameters: tile (Tile or null), previous_tile (Tile or null)
signal tile_selected(tile: Tile, previous_tile: Tile)

## Emitted when the selected socket changes
## Parameters: socket (Socket or null), tile (Tile or null), previous_socket (Socket or null)
signal socket_selected(socket: Socket, tile: Tile, previous_socket: Socket)

## Emitted when selection is cleared
signal selection_cleared

## Emitted when multi-selection changes (for batch operations)
## Parameters: tiles (Array[Tile])
signal multi_selection_changed(tiles: Array)

## Currently selected tile
var selected_tile: Tile = null

## Currently selected socket (if any)
var selected_socket: Socket = null

## Parent tile of the selected socket (cached for quick access)
var selected_socket_tile: Tile = null

## Multi-selection for batch operations
var selected_tiles: Array[Tile] = []

## Associated library (optional, for validation)
var library: ModuleLibrary = null


func _init(lib: ModuleLibrary = null) -> void:
	library = lib


## Select a tile (clears socket selection)
func select_tile(tile: Tile) -> void:
	if tile == selected_tile:
		return
	
	var previous = selected_tile
	selected_tile = tile
	
	# Clear socket selection when changing tiles
	if selected_socket != null:
		var prev_socket = selected_socket
		selected_socket = null
		selected_socket_tile = null
		socket_selected.emit(null, tile, prev_socket)
	
	tile_selected.emit(tile, previous)


## Select a socket (automatically selects its parent tile)
func select_socket(socket: Socket, parent_tile: Tile) -> void:
	if socket == selected_socket and parent_tile == selected_socket_tile:
		return
	
	var prev_socket = selected_socket
	var prev_tile = selected_tile
	
	selected_socket = socket
	selected_socket_tile = parent_tile
	
	# Update tile selection if needed
	if parent_tile != selected_tile:
		selected_tile = parent_tile
		tile_selected.emit(parent_tile, prev_tile)
	
	socket_selected.emit(socket, parent_tile, prev_socket)


## Clear all selections
func clear_selection() -> void:
	if selected_tile == null and selected_socket == null and selected_tiles.is_empty():
		return
	
	var had_tile = selected_tile != null
	var had_socket = selected_socket != null
	
	selected_tile = null
	selected_socket = null
	selected_socket_tile = null
	selected_tiles.clear()
	
	if had_socket:
		socket_selected.emit(null, null, null)
	if had_tile:
		tile_selected.emit(null, null)
	
	selection_cleared.emit()


## Check if a tile is currently selected
func is_tile_selected(tile: Tile) -> bool:
	return selected_tile == tile


## Check if a socket is currently selected
func is_socket_selected(socket: Socket) -> bool:
	return selected_socket == socket


## Get the currently selected tile
func get_selected_tile() -> Tile:
	return selected_tile


## Get the currently selected socket
func get_selected_socket() -> Socket:
	return selected_socket


## Get the tile containing the selected socket
func get_selected_socket_tile() -> Tile:
	return selected_socket_tile


## Add tile to multi-selection
func add_to_selection(tile: Tile) -> void:
	if tile in selected_tiles:
		return
	selected_tiles.append(tile)
	multi_selection_changed.emit(selected_tiles)


## Remove tile from multi-selection
func remove_from_selection(tile: Tile) -> void:
	if tile not in selected_tiles:
		return
	selected_tiles.erase(tile)
	multi_selection_changed.emit(selected_tiles)


## Toggle tile in multi-selection
func toggle_selection(tile: Tile) -> void:
	if tile in selected_tiles:
		remove_from_selection(tile)
	else:
		add_to_selection(tile)


## Set multi-selection to specific tiles
func set_multi_selection(tiles: Array[Tile]) -> void:
	selected_tiles.clear()
	selected_tiles.assign(tiles)
	multi_selection_changed.emit(selected_tiles)


## Get all selected tiles (including multi-selection)
func get_all_selected_tiles() -> Array[Tile]:
	var result: Array[Tile] = []
	if selected_tile != null and selected_tile not in selected_tiles:
		result.append(selected_tile)
	result.append_array(selected_tiles)
	return result


## Check if multi-selection is active
func has_multi_selection() -> bool:
	return not selected_tiles.is_empty()


## Get count of selected tiles
func get_selection_count() -> int:
	var count = 0
	if selected_tile != null:
		count += 1
	count += selected_tiles.size()
	return count


## Clear multi-selection only (keeps single selection)
func clear_multi_selection() -> void:
	if selected_tiles.is_empty():
		return
	selected_tiles.clear()
	multi_selection_changed.emit(selected_tiles)
