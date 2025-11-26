@tool
class_name ImportTileDetail
extends VBoxContainer

signal selection_changed(checked: bool)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")
const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")

const DIRECTION_KEYS := {
    "up": Vector3i.UP,
    "down": Vector3i.DOWN,
    "left": Vector3i.LEFT,
    "right": Vector3i.RIGHT,
    "forward": Vector3i.FORWARD,
    "back": Vector3i.BACK
}

const DIRECTION_ORDER := ["up", "down", "left", "right", "forward", "back"]

@onready var includeCheckBox: CheckBox = %IncludeCheckBox
@onready var fileLabel: Label = %FileLabel
@onready var nameLineEdit: LineEdit = %NameLineEdit
@onready var xSizeSpinBox: SpinBox = %XSizeSpinBox
@onready var ySizeSpinBox: SpinBox = %YSizeSpinBox
@onready var zSizeSpinBox: SpinBox = %ZSizeSpinBox
@onready var tagsMenuButton: MenuButton = %TagsMenuButton
@onready var addTagButton: TextureButton = %AddTagButton
@onready var rotationSymmetryOptionButton: OptionButton = %RotationSymmetryOptionButton
@onready var templateOptionButton: OptionButton = %TemplateOptionButton
@onready var resetSocketsButton: Button = %ResetSocketsButton
@onready var upSocketLineEdit: LineEdit = %UpSocketLineEdit
@onready var downSocketLineEdit: LineEdit = %DownSocketLineEdit
@onready var leftSocketLineEdit: LineEdit = %LeftSocketLineEdit
@onready var rightSocketLineEdit: LineEdit = %RightSocketLineEdit
@onready var frontSocketLineEdit: LineEdit = %FrontSocketLineEdit
@onready var backSocketLineEdit: LineEdit = %BackSocketLineEdit

var file_path: String = ""
var _library: ModuleLibrary = null
var _tags: Array[String] = []
var _socket_names: Dictionary = {}
var _templates: Array = []
var _selected_template_index: int = -1
var _selected_template_key: String = ""
var _updating_socket_fields := false
var _socket_fields_wired := false

func _template_key_for(template: SocketTemplate) -> String:
    if template == null:
        return ""
    return template.template_name.strip_edges().to_lower()

func _ready() -> void:
    _setup_rotation_symmetry_options()
    _setup_tag_menu()
    _setup_template_controls()
    _setup_socket_fields()
    _reset_socket_names()
    _update_socket_fields()
    if includeCheckBox:
        includeCheckBox.toggled.connect(func(checked: bool):
            selection_changed.emit(checked)
        )
    if addTagButton:
        addTagButton.pressed.connect(_on_add_tag_pressed)

func setup(path: String, library: ModuleLibrary) -> void:
    if not is_node_ready():
        await ready
    file_path = path
    _library = library
    _reload_template_options()
    if fileLabel:
        fileLabel.text = path.get_file()
        fileLabel.tooltip_text = path
    if nameLineEdit:
        nameLineEdit.text = path.get_file().get_basename()
    if includeCheckBox:
        includeCheckBox.button_pressed = true
    if xSizeSpinBox:
        xSizeSpinBox.value = 1
    if ySizeSpinBox:
        ySizeSpinBox.value = 1
    if zSizeSpinBox:
        zSizeSpinBox.value = 1
    _tags.clear()
    _update_tags_display()
    _select_rotation_symmetry(Tile.RotationSymmetry.AUTO)
    _selected_template_index = -1
    _selected_template_key = ""
    if templateOptionButton:
        templateOptionButton.selected = 0
    _reset_socket_names()
    _update_socket_fields()

func is_checked() -> bool:
    return includeCheckBox.button_pressed if includeCheckBox else false

func set_checked(checked: bool) -> void:
    if includeCheckBox:
        includeCheckBox.button_pressed = checked

func get_config() -> Dictionary:
    return {
        "file_path": file_path,
        "tile_name": nameLineEdit.text if nameLineEdit else file_path.get_file().get_basename(),
        "size": Vector3i(int(xSizeSpinBox.value), int(ySizeSpinBox.value), int(zSizeSpinBox.value)),
        "tags": _tags.duplicate(),
        "rotation_symmetry": _get_selected_rotation_symmetry(),
        "template_key": _selected_template_key,
        "template_id": _selected_template_index,
        "socket_names": _socket_names.duplicate(true)
    }

func _setup_rotation_symmetry_options() -> void:
    if not rotationSymmetryOptionButton:
        return
    rotationSymmetryOptionButton.clear()
    rotationSymmetryOptionButton.add_item("Auto-detect", Tile.RotationSymmetry.AUTO)
    rotationSymmetryOptionButton.add_item("Full (4 rotations)", Tile.RotationSymmetry.FULL)
    rotationSymmetryOptionButton.add_item("Half (2 rotations)", Tile.RotationSymmetry.HALF)
    rotationSymmetryOptionButton.add_item("Quarter (1 rotation)", Tile.RotationSymmetry.QUARTER)
    rotationSymmetryOptionButton.add_item("Custom", Tile.RotationSymmetry.CUSTOM)

func _select_rotation_symmetry(value: int) -> void:
    if not rotationSymmetryOptionButton:
        return
    for i in range(rotationSymmetryOptionButton.item_count):
        if rotationSymmetryOptionButton.get_item_id(i) == value:
            rotationSymmetryOptionButton.selected = i
            return
    rotationSymmetryOptionButton.selected = 0

func _get_selected_rotation_symmetry() -> int:
    if not rotationSymmetryOptionButton:
        return Tile.RotationSymmetry.AUTO
    var idx := rotationSymmetryOptionButton.selected
    if idx < 0:
        return Tile.RotationSymmetry.AUTO
    return rotationSymmetryOptionButton.get_item_id(idx)

func _setup_tag_menu() -> void:
    if not tagsMenuButton:
        return
    var popup := tagsMenuButton.get_popup()
    if popup:
        if not popup.about_to_popup.is_connected(_populate_tag_menu):
            popup.about_to_popup.connect(_populate_tag_menu)
        if not popup.id_pressed.is_connected(_on_tag_menu_item_pressed):
            popup.id_pressed.connect(_on_tag_menu_item_pressed)

func _populate_tag_menu() -> void:
    if not tagsMenuButton:
        return
    var popup := tagsMenuButton.get_popup()
    if not popup:
        return
    popup.clear()
    if not _library:
        popup.add_item("(No library loaded)", -1)
        popup.set_item_disabled(0, true)
        return
    var available_tags := _library.get_available_tags()
    if available_tags.is_empty():
        popup.add_item("(No tags available)", -1)
        popup.set_item_disabled(0, true)
        return
    for i in range(available_tags.size()):
        var tag := available_tags[i]
        popup.add_check_item(tag, i)
        popup.set_item_checked(i, _tags.has(tag))

func _on_tag_menu_item_pressed(id: int) -> void:
    if not _library:
        return
    var available_tags := _library.get_available_tags()
    if id < 0 or id >= available_tags.size():
        return
    var tag := available_tags[id]
    if _tags.has(tag):
        _tags.erase(tag)
    else:
        _tags.append(tag)
    _update_tags_display()

func _update_tags_display() -> void:
    if not tagsMenuButton:
        return
    if _tags.is_empty():
        tagsMenuButton.text = "No tags"
    else:
        tagsMenuButton.text = ", ".join(_tags)

func _on_add_tag_pressed() -> void:
    var dialog := AcceptDialog.new()
    dialog.title = "Add Tag"
    dialog.dialog_text = "Enter tag name:"
    var tag_edit := LineEdit.new()
    tag_edit.placeholder_text = "tag_name"
    tag_edit.custom_minimum_size = Vector2(200, 0)
    dialog.add_child(tag_edit)
    dialog.confirmed.connect(func():
        var tag := tag_edit.text.strip_edges()
        if tag.is_empty():
            return
        if _library:
            _library.add_available_tag(tag)
        if not _tags.has(tag):
            _tags.append(tag)
        _update_tags_display()
    )
    dialog.canceled.connect(dialog.queue_free)
    dialog.confirmed.connect(dialog.queue_free)
    add_child(dialog)
    dialog.popup_centered()
    tag_edit.grab_focus()

func _setup_template_controls() -> void:
    if templateOptionButton:
        _reload_template_options()
        if not templateOptionButton.item_selected.is_connected(_on_template_selected):
            templateOptionButton.item_selected.connect(_on_template_selected)
    if resetSocketsButton:
        resetSocketsButton.pressed.connect(func():
            _selected_template_index = -1
            _selected_template_key = ""
            if templateOptionButton:
                templateOptionButton.selected = 0
            _reset_socket_names()
            _update_socket_fields()
        )

func _reload_template_options() -> void:
    if not templateOptionButton:
        return
    var previous_key := _selected_template_key
    if _library:
        _templates = _library.get_socket_templates()
    else:
        _templates = LibraryPresets.get_socket_templates()
    templateOptionButton.clear()
    templateOptionButton.add_item("No template", -1)
    templateOptionButton.set_item_metadata(0, "")
    var selection_index := 0
    _selected_template_index = -1
    _selected_template_key = ""
    for i in range(_templates.size()):
        var template: SocketTemplate = _templates[i]
        var key: String = _template_key_for(template)
        templateOptionButton.add_item(template.template_name, i)
        var option_index := templateOptionButton.item_count - 1
        templateOptionButton.set_item_metadata(option_index, key)
        templateOptionButton.set_item_tooltip(option_index, template.description)
        if not previous_key.is_empty() and key == previous_key:
            selection_index = option_index
            _selected_template_index = i
            _selected_template_key = key
    templateOptionButton.selected = selection_index

func _setup_socket_fields() -> void:
    if _socket_fields_wired:
        return
    var field_map := {
        "up": upSocketLineEdit,
        "down": downSocketLineEdit,
        "left": leftSocketLineEdit,
        "right": rightSocketLineEdit,
        "forward": frontSocketLineEdit,
        "back": backSocketLineEdit
    }
    for key in DIRECTION_ORDER:
        var captured_key: String = key
        var field: LineEdit = field_map.get(captured_key)
        if field:
            field.text_changed.connect(func(text: String):
                _on_socket_text_changed(captured_key, text)
            )
    _socket_fields_wired = true

func _on_socket_text_changed(key: String, text: String) -> void:
    if _updating_socket_fields:
        return
    var clean := text.strip_edges()
    if clean.is_empty():
        clean = "none"
    _socket_names[key] = clean

func _reset_socket_names() -> void:
    _socket_names.clear()
    for key in DIRECTION_ORDER:
        _socket_names[key] = "none"

func _update_socket_fields() -> void:
    _updating_socket_fields = true
    for key in DIRECTION_ORDER:
        var field: LineEdit = _get_socket_field(key)
        if field:
            field.text = _socket_names.get(key, "none")
    _updating_socket_fields = false

func _get_socket_field(key: String) -> LineEdit:
    match key:
        "up":
            return upSocketLineEdit
        "down":
            return downSocketLineEdit
        "left":
            return leftSocketLineEdit
        "right":
            return rightSocketLineEdit
        "forward":
            return frontSocketLineEdit
        "back":
            return backSocketLineEdit
    return null

func _on_template_selected(index: int) -> void:
    if not templateOptionButton:
        return
    _selected_template_index = templateOptionButton.get_item_id(index)
    var metadata := templateOptionButton.get_item_metadata(index)
    _selected_template_key = metadata if typeof(metadata) == TYPE_STRING else ""
    if _selected_template_index < 0:
        return
    _apply_template(_selected_template_index)

func _apply_template(template_id: int) -> void:
    if template_id < 0 or template_id >= _templates.size():
        return
    var template: SocketTemplate = _templates[template_id]
    _selected_template_index = template_id
    _selected_template_key = _template_key_for(template)
    _reset_socket_names()
    for entry_data in template.entries:
        var entry = entry_data if entry_data is Dictionary else {}
        var dir: Vector3i = entry.get("direction", Vector3i.UP)
        var socket_id: String = str(entry.get("socket_id", "none"))
        var key := _direction_to_key(dir)
        if key == "":
            continue
        _socket_names[key] = socket_id
    _update_socket_fields()

func _direction_to_key(direction: Vector3i) -> String:
    for key in DIRECTION_KEYS.keys():
        if DIRECTION_KEYS[key] == direction:
            return key
    return ""