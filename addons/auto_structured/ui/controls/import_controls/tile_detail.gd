@tool
class_name ImportTileDetail
extends VBoxContainer

signal selection_changed(checked: bool)

const Tile = preload("res://addons/auto_structured/core/tile.gd")
const ModuleLibrary = preload("res://addons/auto_structured/core/module_library.gd")

@onready var includeCheckBox: CheckBox = %IncludeCheckBox
@onready var fileLabel: Label = %FileLabel
@onready var nameLineEdit: LineEdit = %NameLineEdit
@onready var xSizeSpinBox: SpinBox = %XSizeSpinBox
@onready var ySizeSpinBox: SpinBox = %YSizeSpinBox
@onready var zSizeSpinBox: SpinBox = %ZSizeSpinBox
@onready var tagsMenuButton: MenuButton = %TagsMenuButton
@onready var addTagButton: TextureButton = %AddTagButton
@onready var rotationSymmetryOptionButton: OptionButton = %RotationSymmetryOptionButton

var file_path: String = ""
var _library: ModuleLibrary = null
var _tags: Array[String] = []

func _ready() -> void:
    _setup_rotation_symmetry_options()
    _setup_tag_menu()
    if includeCheckBox:
        includeCheckBox.toggled.connect(func(checked: bool):
            selection_changed.emit(checked)
        )
    if addTagButton:
        addTagButton.pressed.connect(_on_add_tag_pressed)

func setup(path: String, library: ModuleLibrary) -> void:
    file_path = path
    _library = library
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
        "rotation_symmetry": _get_selected_rotation_symmetry()
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