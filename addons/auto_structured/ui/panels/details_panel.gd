@tool
class_name DetailsPanel extends Control

signal closed
signal tile_modified(tile: Tile)

const SocketItem = preload("res://addons/auto_structured/ui/controls/socket_item.tscn")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const TagControl = preload("res://addons/auto_structured/ui/controls/tag_control.tscn")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

@export var current_tile: Tile
var current_library: ModuleLibrary = null

@onready var sockets_container = %SocketsContainer
@onready var name_label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/NameLabel

@onready var add_tag_edit: LineEdit = %AddTagEdit
@onready var add_tag_button: TextureButton = %AddTagButton
@onready var tags_container: VBoxContainer = %TagsContainer


func _ready() -> void:
	add_tag_button.pressed.connect(_on_add_tag)
	add_tag_edit.text_submitted.connect(func(new_tag: String) -> void: _on_add_tag())

func add_socket_item(socket: Socket) -> void:
	if not socket or not current_tile:
		return
	var socket_item: SocketItem = SocketItem.instantiate()
	socket_item.socket = socket
	socket_item.library = current_library
	socket_item.changed.connect(_on_socket_changed)
	sockets_container.add_child(socket_item)


func clear_sockets() -> void:
	for child in sockets_container.get_children():
		if child is SocketItem:
			child.queue_free()


func _on_socket_changed(_socket: Socket) -> void:
	# Socket properties were modified, save changes
	save_tile_changes()
func add_tag(tag: String) -> void:
	var tag_item: TagControl = TagControl.instantiate()
	tag_item.tag_name = tag
	tag_item.name_changed.connect(_on_tag_name_changed)
	tag_item.deleted.connect(_on_tag_delete_requested)
	tags_container.add_child(tag_item)


func _on_tag_name_changed(new_name: String) -> void:
	if not current_tile:
		return

	var tags_copy: Array[String] = []
	tags_copy.assign(current_tile.tags)
	var index = tags_copy.find(new_name)
	if index != -1:
		tags_copy[index] = new_name
		current_tile.tags = tags_copy


func _on_tag_delete_requested(tag_name: String) -> void:
	if not current_tile:
		return

	current_tile.remove_tag(tag_name)
	save_tile_changes()


func _on_add_tag() -> void:
	print("Adding tag")
	if not current_tile:
		return

	var tag = add_tag_edit.text.strip_edges()
	if tag == "":
		return

	current_tile.add_tag(tag)
	add_tag(tag)
	add_tag_edit.text = ""
	save_tile_changes()


func save_tile_changes() -> void:
	if current_tile:
		tile_modified.emit(current_tile)


func close_details() -> void:
	hide()
	name_label.text = "Tile: "
	clear_sockets()
	clear_tags()
	current_tile = null
	closed.emit()


func clear_tags() -> void:
	for child in tags_container.get_children():
		if child is TagControl:
			child.queue_free()


func display_tile_details(tile: Tile, library: ModuleLibrary = null) -> void:
	# Clear previous tile data
	name_label.text = "Tile: "
	clear_sockets()
	clear_tags()

	# Set new tile and library
	current_tile = tile
	current_library = library
	name_label.text = "Tile: %s" % tile.name

	# Ensure tile has all 6 sockets
	tile.ensure_all_sockets()

	# Populate UI with tile data
	for tag in tile.tags:
		add_tag(tag)
	
	# Display sockets in fixed order
	_display_all_sockets_in_order()

	show()

func _display_all_sockets_in_order() -> void:
	"""Display all 6 sockets in a fixed order: Up, Down, Right, Left, Forward, Back"""
	var directions = [
		Vector3i.UP,      # (0, 1, 0)
		Vector3i.DOWN,    # (0, -1, 0)
		Vector3i.RIGHT,   # (1, 0, 0)
		Vector3i.LEFT,    # (-1, 0, 0)
		Vector3i.FORWARD, # (0, 0, -1)
		Vector3i.BACK     # (0, 0, 1)
	]
	
	for direction in directions:
		var socket = current_tile.get_socket_by_direction(direction)
		if socket:
			add_socket_item(socket)
