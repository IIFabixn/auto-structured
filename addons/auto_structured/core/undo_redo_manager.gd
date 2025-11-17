@tool
class_name AutoStructuredUndoRedo extends RefCounted

## Centralized undo/redo manager for Auto Structured plugin operations.
## Wraps Godot's EditorUndoRedoManager with a clean API for tile/library operations.

var _editor_undo_redo: EditorUndoRedoManager
var _plugin: EditorPlugin

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_editor_undo_redo = plugin.get_undo_redo()

## ============================================================================
## TILE OPERATIONS
## ============================================================================

func modify_tile_property(tile: Tile, property: String, new_value: Variant, old_value: Variant, action_name: String = "") -> void:
	"""
	Record a tile property modification for undo/redo.
	
	Args:
		tile: The tile being modified
		property: The property name (e.g., "name", "size", "tags")
		new_value: The new value to set
		old_value: The previous value to restore on undo
		action_name: Optional custom action name (defaults to "Modify Tile Property")
	"""
	if action_name.is_empty():
		action_name = "Modify Tile %s" % property.capitalize()
	
	_editor_undo_redo.create_action(action_name)
	_editor_undo_redo.add_do_property(tile, property, new_value)
	_editor_undo_redo.add_undo_property(tile, property, old_value)
	_editor_undo_redo.commit_action()

func add_tile(library: ModuleLibrary, tile: Tile) -> void:
	"""
	Record adding a tile to a library for undo/redo.
	
	Args:
		library: The library to add the tile to
		tile: The tile to add
	"""
	_editor_undo_redo.create_action("Add Tile")
	_editor_undo_redo.add_do_method(self, "_do_add_tile", library, tile)
	_editor_undo_redo.add_undo_method(self, "_undo_add_tile", library, tile)
	_editor_undo_redo.commit_action()

func remove_tile(library: ModuleLibrary, tile: Tile, index: int) -> void:
	"""
	Record removing a tile from a library for undo/redo.
	
	Args:
		library: The library to remove the tile from
		tile: The tile to remove
		index: The index where the tile was located (for proper restoration)
	"""
	_editor_undo_redo.create_action("Remove Tile")
	_editor_undo_redo.add_do_method(self, "_do_remove_tile", library, tile)
	_editor_undo_redo.add_undo_method(self, "_undo_remove_tile", library, tile, index)
	_editor_undo_redo.commit_action()

## ============================================================================
## SOCKET OPERATIONS
## ============================================================================

func add_socket(tile: Tile, socket: Socket) -> void:
	"""
	Record adding a socket to a tile for undo/redo.
	
	Args:
		tile: The tile to add the socket to
		socket: The socket to add
	"""
	_editor_undo_redo.create_action("Add Socket")
	_editor_undo_redo.add_do_method(self, "_do_add_socket", tile, socket)
	_editor_undo_redo.add_undo_method(self, "_undo_add_socket", tile, socket)
	_editor_undo_redo.commit_action()

func remove_socket(tile: Tile, socket: Socket, index: int) -> void:
	"""
	Record removing a socket from a tile for undo/redo.
	
	Args:
		tile: The tile to remove the socket from
		socket: The socket to remove
		index: The index where the socket was located
	"""
	_editor_undo_redo.create_action("Remove Socket")
	_editor_undo_redo.add_do_method(self, "_do_remove_socket", tile, socket)
	_editor_undo_redo.add_undo_method(self, "_undo_remove_socket", tile, socket, index)
	_editor_undo_redo.commit_action()

func modify_socket_property(socket: Socket, property: String, new_value: Variant, old_value: Variant, action_name: String = "") -> void:
	"""
	Record a socket property modification for undo/redo.
	
	Args:
		socket: The socket being modified
		property: The property name
		new_value: The new value to set
		old_value: The previous value to restore on undo
		action_name: Optional custom action name
	"""
	if action_name.is_empty():
		action_name = "Modify Socket %s" % property.capitalize()
	
	_editor_undo_redo.create_action(action_name)
	_editor_undo_redo.add_do_property(socket, property, new_value)
	_editor_undo_redo.add_undo_property(socket, property, old_value)
	_editor_undo_redo.commit_action()

## ============================================================================
## LIBRARY OPERATIONS
## ============================================================================

func modify_library_property(library: ModuleLibrary, property: String, new_value: Variant, old_value: Variant, action_name: String = "") -> void:
	"""
	Record a library property modification for undo/redo.
	
	Args:
		library: The library being modified
		property: The property name
		new_value: The new value to set
		old_value: The previous value to restore on undo
		action_name: Optional custom action name
	"""
	if action_name.is_empty():
		action_name = "Modify Library %s" % property.capitalize()
	
	_editor_undo_redo.create_action(action_name)
	_editor_undo_redo.add_do_property(library, property, new_value)
	_editor_undo_redo.add_undo_property(library, property, old_value)
	_editor_undo_redo.commit_action()

func add_socket_type(library: ModuleLibrary, socket_type: SocketType) -> void:
	"""
	Record adding a socket type to a library for undo/redo.
	
	Args:
		library: The library to add the socket type to
		socket_type: The socket type to add
	"""
	_editor_undo_redo.create_action("Add Socket Type")
	_editor_undo_redo.add_do_method(self, "_do_add_socket_type", library, socket_type)
	_editor_undo_redo.add_undo_method(self, "_undo_add_socket_type", library, socket_type)
	_editor_undo_redo.commit_action()

func remove_socket_type(library: ModuleLibrary, socket_type: SocketType, index: int) -> void:
	"""
	Record removing a socket type from a library for undo/redo.
	
	Args:
		library: The library to remove the socket type from
		socket_type: The socket type to remove
		index: The index where the socket type was located
	"""
	_editor_undo_redo.create_action("Remove Socket Type")
	_editor_undo_redo.add_do_method(self, "_do_remove_socket_type", library, socket_type)
	_editor_undo_redo.add_undo_method(self, "_undo_remove_socket_type", library, socket_type, index)
	_editor_undo_redo.commit_action()

## ============================================================================
## TAG OPERATIONS
## ============================================================================

func add_tag(tile: Tile, tag: String) -> void:
	"""
	Record adding a tag to a tile for undo/redo.
	
	Args:
		tile: The tile to add the tag to
		tag: The tag string to add
	"""
	_editor_undo_redo.create_action("Add Tag")
	_editor_undo_redo.add_do_method(self, "_do_add_tag", tile, tag)
	_editor_undo_redo.add_undo_method(self, "_undo_add_tag", tile, tag)
	_editor_undo_redo.commit_action()

func remove_tag(tile: Tile, tag: String, index: int) -> void:
	"""
	Record removing a tag from a tile for undo/redo.
	
	Args:
		tile: The tile to remove the tag from
		tag: The tag to remove
		index: The index where the tag was located
	"""
	_editor_undo_redo.create_action("Remove Tag")
	_editor_undo_redo.add_do_method(self, "_do_remove_tag", tile, tag)
	_editor_undo_redo.add_undo_method(self, "_undo_remove_tag", tile, tag, index)
	_editor_undo_redo.commit_action()

## ============================================================================
## BATCH OPERATIONS
## ============================================================================

func begin_action(action_name: String) -> void:
	"""
	Begin a custom multi-step action. Useful for grouping multiple operations.
	Must be followed by commit_action().
	
	Args:
		action_name: The name of the action to display in the undo history
	"""
	_editor_undo_redo.create_action(action_name)

func add_do_method(object: Object, method: StringName, args: Array = []) -> void:
	"""
	Add a method to call on redo/do. Must be between begin_action() and commit_action().
	
	Args:
		object: The object to call the method on
		method: The method name to call
		args: Optional array of arguments to pass to the method
	"""
	_editor_undo_redo.add_do_method(object, method)
	for arg in args:
		_editor_undo_redo.add_do_method(object, method, arg)

func add_undo_method(object: Object, method: StringName, args: Array = []) -> void:
	"""
	Add a method to call on undo. Must be between begin_action() and commit_action().
	
	Args:
		object: The object to call the method on
		method: The method name to call
		args: Optional array of arguments to pass to the method
	"""
	_editor_undo_redo.add_undo_method(object, method)
	for arg in args:
		_editor_undo_redo.add_undo_method(object, method, arg)

func add_do_property(object: Object, property: String, value: Variant) -> void:
	"""
	Add a property change on redo/do. Must be between begin_action() and commit_action().
	"""
	_editor_undo_redo.add_do_property(object, property, value)

func add_undo_property(object: Object, property: String, value: Variant) -> void:
	"""
	Add a property change on undo. Must be between begin_action() and commit_action().
	"""
	_editor_undo_redo.add_undo_property(object, property, value)

func commit_action() -> void:
	"""
	Commit the current action started with begin_action().
	"""
	_editor_undo_redo.commit_action()

## ============================================================================
## INTERNAL IMPLEMENTATION METHODS
## ============================================================================

func _do_add_tile(library: ModuleLibrary, tile: Tile) -> void:
	library.tiles.append(tile)

func _undo_add_tile(library: ModuleLibrary, tile: Tile) -> void:
	library.tiles.erase(tile)

func _do_remove_tile(library: ModuleLibrary, tile: Tile) -> void:
	library.tiles.erase(tile)

func _undo_remove_tile(library: ModuleLibrary, tile: Tile, index: int) -> void:
	library.tiles.insert(index, tile)

func _do_add_socket(tile: Tile, socket: Socket) -> void:
	tile.sockets.append(socket)

func _undo_add_socket(tile: Tile, socket: Socket) -> void:
	tile.sockets.erase(socket)

func _do_remove_socket(tile: Tile, socket: Socket) -> void:
	tile.sockets.erase(socket)

func _undo_remove_socket(tile: Tile, socket: Socket, index: int) -> void:
	tile.sockets.insert(index, socket)

func _do_add_socket_type(library: ModuleLibrary, socket_type: SocketType) -> void:
	library.socket_types.append(socket_type)

func _undo_add_socket_type(library: ModuleLibrary, socket_type: SocketType) -> void:
	library.socket_types.erase(socket_type)

func _do_remove_socket_type(library: ModuleLibrary, socket_type: SocketType) -> void:
	library.socket_types.erase(socket_type)

func _undo_remove_socket_type(library: ModuleLibrary, socket_type: SocketType, index: int) -> void:
	library.socket_types.insert(index, socket_type)

func _do_add_tag(tile: Tile, tag: String) -> void:
	if not tile.tags.has(tag):
		tile.tags.append(tag)

func _undo_add_tag(tile: Tile, tag: String) -> void:
	tile.tags.erase(tag)

func _do_remove_tag(tile: Tile, tag: String) -> void:
	tile.tags.erase(tag)

func _undo_remove_tag(tile: Tile, tag: String, index: int) -> void:
	tile.tags.insert(index, tag)
