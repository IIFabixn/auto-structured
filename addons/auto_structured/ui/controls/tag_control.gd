@tool
class_name TagControl extends Control

signal deleted(tag_name: String)
signal name_changed(old_name: String, new_name: String)

var tag_name: String = "Tag"

@onready var tag_edit: LineEdit = $TagEdit

func _ready() -> void:
	apply_tag_name(tag_name)
	if tag_edit:
		tag_edit.text_submitted.connect(_on_tag_edit_committed)
		tag_edit.focus_exited.connect(_on_tag_edit_focus_exited)

func delete_pressed() -> void:
	deleted.emit(tag_name)

func _on_tag_edit_committed(text: String) -> void:
	_commit_name_change(text)

func _on_tag_edit_focus_exited() -> void:
	_commit_name_change(tag_edit.text)

func _commit_name_change(raw_text: String) -> void:
	var sanitized := raw_text.strip_edges()
	if sanitized == tag_name:
		tag_edit.text = tag_name
		return
	var previous := tag_name
	apply_tag_name(sanitized)
	name_changed.emit(previous, tag_name)

func apply_tag_name(value: String) -> void:
	tag_name = value
	if tag_edit:
		tag_edit.text = tag_name

func focus_edit() -> void:
	if tag_edit:
		tag_edit.grab_focus()
		tag_edit.select_all()
