@tool
class_name RequirementItem extends VBoxContainer

signal changed(requirement: Requirement)
signal deleted(requirement: Requirement)

const Requirement = preload("res://addons/auto_structured/core/requirements/requirement.gd")
const GroundRequirement = preload("res://addons/auto_structured/core/requirements/ground_requirement.gd")
const HeightRequirement = preload("res://addons/auto_structured/core/requirements/height_requirement.gd")
const TagRequirement = preload("res://addons/auto_structured/core/requirements/tag_requirement.gd")
const PositionRequirement = preload("res://addons/auto_structured/core/requirements/position_requirement.gd")
const RotationRequirement = preload("res://addons/auto_structured/core/requirements/rotation_requirement.gd")

var requirement: Requirement:
	set(value):
		requirement = value
		_update_display()

var library = null # ModuleLibrary reference for tag suggestions

@onready var type_label: Label = $HBoxContainer/TypeLabel
@onready var enabled_check: CheckBox = $HBoxContainer/EnabledCheck
@onready var config_container: HBoxContainer = $ConfigContainer
@onready var delete_button: Button = $HBoxContainer/DeleteButton


func _ready() -> void:
	if enabled_check:
		enabled_check.toggled.connect(_on_enabled_toggled)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	_update_display()


func _update_display() -> void:
	"""Update UI to match requirement type and properties"""
	if not requirement or not is_inside_tree():
		return
	
	# Update enabled checkbox
	if enabled_check:
		enabled_check.button_pressed = requirement.enabled
	
	# Clear previous config controls
	if config_container:
		for child in config_container.get_children():
			child.queue_free()
	
	# Enable mouse filter for tooltip to work
	type_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Update type label and create appropriate config controls
	if requirement is GroundRequirement:
		type_label.text = "Ground Level"
		type_label.tooltip_text = "This tile/socket can only be placed at ground level (Y=0).\nUseful for: doors, ground floor walls, foundations."
		# No additional config needed
	
	elif requirement is HeightRequirement:
		type_label.text = "Height Range"
		type_label.tooltip_text = "Constrains placement to specific floor heights.\nUseful for: roof pieces (high only), balconies (2nd floor+), basement items."
		_create_height_controls(requirement)
	
	elif requirement is TagRequirement:
		type_label.text = "Tag"
		type_label.tooltip_text = "Requires/excludes tiles with specific tags.\nUseful for: 'stone door needs stone walls', 'windows exclude solid walls'."
		_create_tag_controls(requirement)
	
	elif requirement is PositionRequirement:
		type_label.text = "Force Position"
		type_label.tooltip_text = "Forces a specific tile at an exact grid position.\nUseful for: ensuring doors at entrances, chimneys at specific spots."
		_create_position_controls(requirement)
	
	elif requirement is RotationRequirement:
		type_label.text = "Rotation"
		type_label.tooltip_text = "Requires the connecting tile to be rotated by at least a minimum angle.\nUseful for: corner pieces that shouldn't connect without rotation."
		_create_rotation_controls(requirement)
	
	else:
		type_label.text = "Unknown"


func _create_height_controls(height_req: HeightRequirement) -> void:
	"""Create min/max height spinboxes"""
	var min_label = Label.new()
	min_label.text = "Min:"
	config_container.add_child(min_label)
	
	var min_spin = SpinBox.new()
	min_spin.min_value = 0
	min_spin.max_value = 999
	min_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_spin.value = height_req.min_height
	min_spin.value_changed.connect(func(value):
		height_req.min_height = int(value)
		changed.emit(requirement)
	)
	config_container.add_child(min_spin)

	var max_label = Label.new()
	max_label.text = "Max:"
	config_container.add_child(max_label)
	
	var max_spin = SpinBox.new()
	max_spin.min_value = 0
	max_spin.max_value = 999
	max_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_spin.value = height_req.max_height
	max_spin.value_changed.connect(func(value):
		height_req.max_height = int(value)
		changed.emit(requirement)
	)
	config_container.add_child(max_spin)


func _create_tag_controls(tag_req: TagRequirement) -> void:
	"""Create tag name input and exclude mode checkbox"""
	var tag_edit = LineEdit.new()
	tag_edit.text = tag_req.required_tag
	tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_edit.placeholder_text = "tag name"
	tag_edit.text_changed.connect(func(new_text):
		tag_req.required_tag = new_text
		changed.emit(requirement)
	)
	config_container.add_child(tag_edit)
	
	var mode_label = Label.new()
	mode_label.text = "Mode:"
	config_container.add_child(mode_label)
	
	var mode_option = OptionButton.new()
	mode_option.add_item("Require", 0)
	mode_option.add_item("Exclude", 1)
	mode_option.selected = 1 if tag_req.exclude_mode else 0
	mode_option.item_selected.connect(func(index):
		tag_req.exclude_mode = (index == 1)
		changed.emit(requirement)
	)
	config_container.add_child(mode_option)


func _create_position_controls(pos_req: PositionRequirement) -> void:
	"""Create X/Y/Z position spinboxes and module ID input"""
	for axis in ["X", "Y", "Z"]:
		var label = Label.new()
		label.text = axis + ":"
		config_container.add_child(label)
		
		var spin = SpinBox.new()
		spin.min_value = -999
		spin.max_value = 999
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		match axis:
			"X":
				spin.value = pos_req.target_position.x
				spin.value_changed.connect(func(value):
					pos_req.target_position.x = int(value)
					changed.emit(requirement)
				)
			"Y":
				spin.value = pos_req.target_position.y
				spin.value_changed.connect(func(value):
					pos_req.target_position.y = int(value)
					changed.emit(requirement)
				)
			"Z":
				spin.value = pos_req.target_position.z
				spin.value_changed.connect(func(value):
					pos_req.target_position.z = int(value)
					changed.emit(requirement)
				)
		
		config_container.add_child(spin)


func _create_rotation_controls(rotation_req: RotationRequirement) -> void:
	"""Create rotation angle option button"""
	var label = Label.new()
	label.text = "Min Angle:"
	config_container.add_child(label)
	
	var option = OptionButton.new()
	option.add_item("0° (Any)", 0)
	option.add_item("90°+", 90)
	option.add_item("180°", 180)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Set current value
	match rotation_req.minimum_rotation_degrees:
		0:
			option.selected = 0
		90:
			option.selected = 1
		180:
			option.selected = 2
	
	option.item_selected.connect(func(index):
		rotation_req.minimum_rotation_degrees = option.get_item_id(index)
		changed.emit(requirement)
	)
	
	config_container.add_child(option)


func _on_enabled_toggled(pressed: bool) -> void:
	if requirement:
		requirement.enabled = pressed
		changed.emit(requirement)


func _on_delete_pressed() -> void:
	deleted.emit(requirement)
