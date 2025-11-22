@tool
class_name RequirementItem
extends VBoxContainer

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")

signal requirement_deleted(requirement: Requirement)
signal requirement_modified(requirement: Requirement)

@onready var name_label : Label = %NameLabel
@onready var delete_button : TextureButton = %DeleteButton
@onready var config_container : VBoxContainer = %ConfigContainer

var _requirement: Requirement
@export var requirement: Requirement:
	get:
		return _requirement
	set(value):
		_requirement = value
		if is_node_ready():
			_update_ui()

func _ready() -> void:
	if requirement:
		requirement._init()
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	
	_update_ui()

func _update_ui() -> void:
	if not _requirement or not is_node_ready():
		return
	
	# Update name label
	if name_label:
		name_label.text = _requirement.display_name if _requirement.display_name else "Requirement"
	
	# Rebuild config UI
	_build_config_ui()

func _build_config_ui() -> void:
	if not _requirement or not config_container:
		return
	
	# Clear existing config UI
	for child in config_container.get_children():
		child.queue_free()
	
	# Get the custom config control from the requirement
	var config_control = _requirement.get_config_control()
	if config_control:
		config_container.add_child(config_control)
		
		# Connect to any value changes in the config control
		_connect_config_signals(config_control)

func _connect_config_signals(control: Control) -> void:
	"""Recursively connect to value_changed signals to emit requirement_modified."""
	# Connect common control signals
	if control.has_signal("value_changed"):
		if not control.value_changed.is_connected(_on_config_value_changed):
			control.value_changed.connect(_on_config_value_changed)
	
	if control.has_signal("item_selected"):
		if not control.item_selected.is_connected(_on_config_item_selected):
			control.item_selected.connect(_on_config_item_selected)
	
	if control.has_signal("toggled"):
		if not control.toggled.is_connected(_on_config_toggled):
			control.toggled.connect(_on_config_toggled)
	
	if control.has_signal("text_changed"):
		if not control.text_changed.is_connected(_on_config_text_changed):
			control.text_changed.connect(_on_config_text_changed)
	
	# Recurse through children
	for child in control.get_children():
		if child is Control:
			_connect_config_signals(child)

func _on_config_value_changed(_value) -> void:
	requirement_modified.emit(_requirement)

func _on_config_item_selected(_index: int) -> void:
	requirement_modified.emit(_requirement)

func _on_config_toggled(_toggled_on: bool) -> void:
	requirement_modified.emit(_requirement)

func _on_config_text_changed(_new_text: String) -> void:
	requirement_modified.emit(_requirement)

func _on_delete_pressed() -> void:
	requirement_deleted.emit(_requirement)