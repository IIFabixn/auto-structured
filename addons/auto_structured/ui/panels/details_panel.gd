@tool
class_name DetailsPanel extends Control

signal closed
signal tile_modified(tile: Tile)

const SocketItemScene = preload("res://addons/auto_structured/ui/controls/socket_item.tscn")
const Socket = preload("res://addons/auto_structured/core/socket.gd")
const Tile = preload("res://addons/auto_structured/core/tile.gd")
const TagControl = preload("res://addons/auto_structured/ui/controls/tag_control.tscn")

@export var current_tile: Tile

@onready var sockets_container = %SocketsContainer
@onready var new_socket_id_edit = %NewSocketIDEdit
@onready var add_socket_button = %AddSocketButton
@onready var name_label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/NameLabel
@onready var add_tag_edit: LineEdit = %AddTagEdit
@onready var add_tag_button: TextureButton = %AddTagButton
@onready var tags_container: VBoxContainer = %TagsContainer


func _ready() -> void:
	add_socket_button.pressed.connect(_on_add_socket_button_pressed)
	add_tag_button.pressed.connect(_on_add_tag)
	add_tag_edit.text_submitted.connect(func(new_tag: String) -> void: _on_add_tag())


func _on_add_socket_button_pressed() -> void:
	if not current_tile:
		return

	var socket_id = new_socket_id_edit.text.strip_edges()
	if socket_id == "":
		return

	# Create socket and add to tile
	var socket = Socket.new()
	socket.socket_id = socket_id

	var sockets_copy: Array[Socket] = []
	sockets_copy.assign(current_tile.sockets)
	sockets_copy.append(socket)
	current_tile.sockets = sockets_copy

	# Add socket to UI
	add_socket_item(socket)
	new_socket_id_edit.text = ""
	save_tile_changes()


func add_socket_item(socket: Socket) -> void:
	if not socket or not current_tile:
		return
	var socket_item = SocketItemScene.instantiate()
	socket_item.socket = socket
	sockets_container.add_child(socket_item)


func clear_sockets() -> void:
	for child in sockets_container.get_children():
		child.queue_free()


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


func display_tile_details(tile: Tile) -> void:
	# Clear previous tile data
	name_label.text = "Tile: "
	clear_sockets()
	clear_tags()

	# Set new tile
	current_tile = tile
	name_label.text = "Tile: %s" % tile.name

	# Populate UI with tile data
	for tag in tile.tags:
		add_tag(tag)
	for socket in tile.sockets:
		add_socket_item(socket)

	show()
