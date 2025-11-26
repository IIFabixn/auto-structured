@tool
class_name BatchControls extends VBoxContainer

const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")
const SocketTemplate = preload("res://addons/auto_structured/utils/socket_template.gd")

@onready var xSpinBox : SpinBox = %XSizeSpinBox
@onready var ySpinBox : SpinBox = %YSizeSpinBox
@onready var zSpinBox : SpinBox = %ZSizeSpinBox

@onready var templateOptionButton : OptionButton = %TemplateOptionButton
@onready var addTemplateButton : TextureButton = %AddTemplateButton

@onready var tagsMenuButton : MenuButton = %TagsMenuButton
@onready var addTagButton : TextureButton = %AddTagButton

@onready var autoSymmetryDetectCheckBox : CheckBox = %AutoSymmetryDetectCheckBox
@onready var rotationalVarianceCheckBox : CheckBox = %RotationalVarianceCheckBox
@onready var selfMatchCheckBox : CheckBox = %SelfMatchCheckBox

@onready var applyAllButton : Button = %ApplyAllButton
@onready var applySelectedButton : Button = %ApplySelectedButton

var _tags: Array[String] = []
var _library: ModuleLibrary = null  # Reference to module library
var _available_templates: Array = []
var _registered_template_keys: Dictionary = {}

func _ready() -> void:
    """Initialize the batch controls."""
    _populate_template_dropdown()
    _setup_tag_menu()
    _setup_tag_buttons()

## ============================================================================
## Public API
## ============================================================================

func get_config() -> Dictionary:
    """Get the current batch configuration."""
    return {
        "size": Vector3i(int(xSpinBox.value), int(ySpinBox.value), int(zSpinBox.value)),
        "template_key": _get_selected_template_key(),
        "tags": _tags.duplicate(),
        "auto_detect_symmetry": autoSymmetryDetectCheckBox.button_pressed,
        "generate_variants": rotationalVarianceCheckBox.button_pressed,
        "include_self_match": selfMatchCheckBox.button_pressed
    }

func set_config(config: Dictionary) -> void:
    """Set the batch configuration."""
    if config.has("size"):
        var size: Vector3i = config["size"]
        xSpinBox.value = size.x
        ySpinBox.value = size.y
        zSpinBox.value = size.z
    
    if config.has("template_key"):
        _select_template_by_key(config["template_key"])
    elif config.has("template_id"):
        _select_template_by_legacy_id(config["template_id"])
    
    if config.has("tags"):
        _tags = config["tags"].duplicate()
        _update_tags_display()
    
    if config.has("auto_detect_symmetry"):
        autoSymmetryDetectCheckBox.button_pressed = config["auto_detect_symmetry"]
    
    if config.has("generate_variants"):
        rotationalVarianceCheckBox.button_pressed = config["generate_variants"]
    
    if config.has("include_self_match"):
        selfMatchCheckBox.button_pressed = config["include_self_match"]

## ============================================================================
## Template Management
## ============================================================================

func _populate_template_dropdown() -> void:
    """Populate the template dropdown with built-in templates."""
    templateOptionButton.clear()
    templateOptionButton.add_item("None", -1)
    templateOptionButton.set_item_metadata(0, "")

    _available_templates = _get_available_templates()
    for template in _available_templates:
        var key := _normalize_template_key(template.template_name)
        templateOptionButton.add_item(template.template_name)
        var item_index := templateOptionButton.item_count - 1
        templateOptionButton.set_item_metadata(item_index, key)
        templateOptionButton.set_item_tooltip(item_index, template.description)

func _get_selected_template_key() -> String:
    """Get the selected template identifier."""
    var selected_idx = templateOptionButton.selected
    if selected_idx < 0:
        return ""
    return String(templateOptionButton.get_item_metadata(selected_idx))

func _select_template_by_key(template_key: String) -> void:
    var normalized := _normalize_template_key(String(template_key))
    if normalized.is_empty():
        templateOptionButton.selected = 0
        return
    for i in range(templateOptionButton.item_count):
        var meta := String(templateOptionButton.get_item_metadata(i))
        if meta == normalized:
            templateOptionButton.selected = i
            return
    templateOptionButton.selected = 0

func _select_template_by_legacy_id(template_id: int) -> void:
    for i in range(templateOptionButton.item_count):
        if templateOptionButton.get_item_id(i) == template_id:
            templateOptionButton.selected = i
            return
    templateOptionButton.selected = 0

## ============================================================================
## Tag Management
## ============================================================================

func setup(library) -> void:
    """Setup batch controls with library reference."""
    if library == null:
        return
    _library = library
    _registered_template_keys.clear()
    
    # Repopulate template dropdown with library templates
    _populate_template_dropdown()
    
    # Register socket types from all templates so they appear in socket menus
    for template in _available_templates:
        _register_template_socket_types(template)
    
    # If _ready has already been called, reconnect the tag menu
    # This ensures the library reference is available when menu opens
    if is_node_ready() and tagsMenuButton:
        # Disconnect old signal if exists
        if tagsMenuButton.about_to_popup.is_connected(_populate_tag_menu):
            tagsMenuButton.about_to_popup.disconnect(_populate_tag_menu)
        # Reconnect to ensure library is available
        tagsMenuButton.about_to_popup.connect(_populate_tag_menu)

func _setup_tag_buttons() -> void:
    """Setup tag button handlers."""
    if addTagButton:
        addTagButton.pressed.connect(_on_add_tag_pressed)
    _update_tags_display()

func _setup_tag_menu() -> void:
    """Setup tag menu button."""
    if tagsMenuButton:
        tagsMenuButton.about_to_popup.connect(_populate_tag_menu)
        var popup = tagsMenuButton.get_popup()
        if not popup.id_pressed.is_connected(_on_tag_menu_item_pressed):
            popup.id_pressed.connect(_on_tag_menu_item_pressed)

func _populate_tag_menu() -> void:
    """Populate tag menu with available tags."""
    if not tagsMenuButton or not _library:
        return
    var popup = tagsMenuButton.get_popup()
    popup.clear()
    
    var available_tags = _library.get_available_tags()
    if available_tags.is_empty():
        popup.add_item("(No tags available)", -1)
        popup.set_item_disabled(0, true)
    else:
        for i in range(available_tags.size()):
            var tag = available_tags[i]
            var is_selected = _tags.has(tag)
            popup.add_check_item(tag, i)
            popup.set_item_checked(i, is_selected)

func _on_tag_menu_item_pressed(id: int) -> void:
    """Handle tag menu item selection."""
    if not _library:
        return
    
    var available_tags = _library.get_available_tags()
    if id < 0 or id >= available_tags.size():
        return
    
    var tag = available_tags[id]
    if _tags.has(tag):
        _tags.erase(tag)
    else:
        _tags.append(tag)
    _update_tags_display()

func _register_template_socket_types(template: SocketTemplate) -> void:
    """Register socket types from template in library."""
    if not template or not _library:
        return
    var key := _normalize_template_key(template.template_name)
    if key != "" and _registered_template_keys.has(key):
        return
    
    # Register all socket types from template entries
    for entry_data in template.entries:
        var entry = SocketTemplate.normalize_entry(entry_data)
        var socket_id: String = entry["socket_id"]
        var compatible: Array = entry["compatible"]
        
        # Register socket type in library
        _library.ensure_socket_type(socket_id)
        
        # Register compatible types
        for compat_id in compatible:
            _library.ensure_socket_type(compat_id)
    if key != "":
        _registered_template_keys[key] = true

func _get_available_templates() -> Array:
    if _library:
        return _library.get_socket_templates()
    return LibraryPresets.get_socket_templates()

func _normalize_template_key(name: String) -> String:
    return String(name).strip_edges().to_lower()

func _update_tags_display() -> void:
    """Update the tags menu button text."""
    if tagsMenuButton:
        if _tags.is_empty():
            tagsMenuButton.text = "None"
        else:
            tagsMenuButton.text = ", ".join(_tags)

func _on_add_tag_pressed() -> void:
    """Handle add tag button press."""
    var dialog = AcceptDialog.new()
    dialog.title = "Add Tag"
    dialog.dialog_text = "Enter tag name:"
    
    var tag_edit = LineEdit.new()
    tag_edit.placeholder_text = "tag_name"
    tag_edit.custom_minimum_size = Vector2(200, 0)
    dialog.add_child(tag_edit)
    
    dialog.confirmed.connect(func():
        var tag = tag_edit.text.strip_edges()
        if not tag.is_empty():
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

