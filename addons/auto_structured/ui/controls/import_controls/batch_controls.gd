@tool
class_name BatchControls extends VBoxContainer

const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")
const SocketTemplate = preload("res://addons/auto_structured/ui/utils/socket_template.gd")

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
        "template_id": _get_selected_template_id(),
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
    
    if config.has("template_id"):
        _select_template_by_id(config["template_id"])
    
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
    
    var templates = LibraryPresets.get_socket_templates()
    for i in range(templates.size()):
        var template = templates[i]
        templateOptionButton.add_item(template.template_name, i)
        templateOptionButton.set_item_tooltip(i + 1, template.description)

func _get_selected_template_id() -> int:
    """Get the selected template ID (-1 for None)."""
    var selected_idx = templateOptionButton.selected
    if selected_idx < 0:
        return -1
    return templateOptionButton.get_item_id(selected_idx)

func _select_template_by_id(template_id: int) -> void:
    """Select a template by its ID."""
    for i in range(templateOptionButton.item_count):
        if templateOptionButton.get_item_id(i) == template_id:
            templateOptionButton.selected = i
            return

## ============================================================================
## Tag Management
## ============================================================================

func setup(library) -> void:
    """Setup batch controls with library reference."""
    print("BatchControls: Setting up with library: %s" % library.library_name)
    _library = library
    
    # Repopulate template dropdown with library templates
    _populate_template_dropdown()
    
    # Register socket types from all templates so they appear in socket menus
    var templates = LibraryPresets.get_socket_templates()
    for template in templates:
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
    
    print("BatchControls: Populating tag menu")
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
    
    # Register all socket types from template entries
    for entry_data in template.entries:
        var entry = SocketTemplate.normalize_entry(entry_data)
        var socket_id: String = entry["socket_id"]
        var compatible: Array = entry["compatible"]
        
        # Register socket type in library
        var socket_type = _library.ensure_socket_type(socket_id)
        if socket_type:
            # Update compatibility
            for compat_id in compatible:
                if not socket_type.compatible_types.has(compat_id):
                    socket_type.compatible_types.append(compat_id)

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

