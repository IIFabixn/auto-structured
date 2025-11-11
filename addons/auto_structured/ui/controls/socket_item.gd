@tool
class_name SocketItem extends FoldableContainer

signal deleted
signal changed
signal selected

const Socket = preload("res://addons/auto_structured/core/socket.gd")

@export var socket: Socket = null:
	set(value):
		socket = value
		if name_edit and socket:
			name_edit.text = socket.socket_id
		selected.emit()

var name_edit: LineEdit
var direction_option: OptionButton

@onready var add_socket_button: TextureButton = $VBoxContainer/HBoxContainer/AddSocketButton
@onready var compatible_sockets_popup: PopupPanel = $PopupPanel
@onready var compatible_sockets_list: VBoxContainer = $PopupPanel/VBoxContainer/AvailableSocketList

func _ready() -> void:
	name_edit = get_node_or_null("VBoxContainer/NameEdit")
	direction_option = get_node_or_null("VBoxContainer/DirectionContainer/DirectionOption")
	add_socket_button.pressed.connect(_on_add_socket_pressed)
	update_title()
	if socket and name_edit:
		name_edit.text = socket.socket_id

func _on_add_socket_pressed() -> void:
	for child in compatible_sockets_list.get_children():
		child.queue_free()
	# TODO: Load available compatible sockets from current library
	compatible_sockets_popup.popup_centered()

func update_title() -> void:
	if not socket:
		return

	title = "Socket: %s" % get_direction_name(socket.direction)
	if name_edit:
		name_edit.text = socket.socket_id

func get_direction_name(direction: Vector3i) -> String:
	var direction_names = {
		Vector3i(1, 0, 0): "Right",
		Vector3i(-1, 0, 0): "Left",
		Vector3i(0, 1, 0): "Up",
		Vector3i(0, -1, 0): "Down",
		Vector3i(0, 0, 1): "Forward",
		Vector3i(0, 0, -1): "Back"
	}

	return direction_names.get(direction, "Unknown")

func set_direction(value: int) -> void:
	if not socket:
		return

	match value:
		0:
			pass
		1:
			socket.direction = Vector3i(1, 0, 0) # Right
		2:
			socket.direction = Vector3i(-1, 0, 0) # Left
		3:
			socket.direction = Vector3i(0, 1, 0) # Up
		4:
			socket.direction = Vector3i(0, -1, 0) # Down
		5:
			socket.direction = Vector3i(0, 0, 1) # Forward
		6:
			socket.direction = Vector3i(0, 0, -1) # Back
	update_title()

func _on_delete_selected(id: int) -> void:
	if id == 0:
		deleted.emit(socket)
		queue_free()
