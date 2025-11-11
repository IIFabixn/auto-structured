@tool
class_name TagControl extends Control

signal delete_requested
signal name_changed(new_name: String)

@export var tag_name: String = "Tag":
	set(value):
		tag_name = value
		name_changed.emit(tag_name)
		if tag_edit:
			tag_edit.text = tag_name
	get:
		return tag_name

@onready var tag_edit: LineEdit = $TagEdit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tag_edit.text = tag_name

func delete_pressed() -> void:
	delete_requested.emit()
