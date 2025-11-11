@tool
class_name TileItem extends Control

signal delete_requested
signal selected

const Tile = preload("res://addons/auto_structured/core/tile.gd")

@export var module_name: String = "Module":
	set(value):
		module_name = value
		if name_label:
			name_label.text = module_name
	get:
		return module_name

@export var tile: Tile

@onready var popup_menu: PopupMenu = $PopupMenu
@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel

func _ready() -> void:
	name_label.text = module_name
	popup_menu.id_pressed.connect(_on_delete_selected)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse_pos = get_viewport().get_mouse_position()
			popup_menu.popup(Rect2(mouse_pos, Vector2.ZERO))

func _on_delete_selected(id: int) -> void:
	if id == 0:
		delete_requested.emit()
