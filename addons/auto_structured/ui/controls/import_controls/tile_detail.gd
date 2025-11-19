@tool
class_name ImportTileDetail
extends VBoxContainer

const LibraryPresets = preload("res://addons/auto_structured/core/library_presets.gd")

@onready var checkedCheckBox : CheckBox = %CheckedCheckBox
@onready var nameLabel : Label = %NameLabel
@onready var overrideCheckButton : Button = %OverrideCheckButton

@onready var detailsContainer : VBoxContainer = %DetailsContainer

@onready var xSizeSpinBox : SpinBox = %XSizeSpinBox
@onready var ySizeSpinBox : SpinBox = %YSizeSpinBox
@onready var zSizeSpinBox : SpinBox = %ZSizeSpinBox

@onready var templateOptionButton : OptionButton = %TemplateOptionButton
@onready var addTemplateButton : TextureButton = %AddTemplateButton

@onready var tagsMenuButton : MenuButton = %TagsMenuButton
@onready var addTagButton : TextureButton = %AddTagButton

@onready var autoSymmetryDetectionCheckBox : CheckBox = %AutoSymmetryDetectionCheckBox
@onready var rotationalVarianceCheckBox : CheckBox = %RotationalVarianceCheckBox
@onready var selfMatchCheckBox : CheckBox = %SelfMatchCheckBox

@onready var addSocketTypeButton : TextureButton = %AddSocketTypeButton

@onready var upSocketMenuButton : MenuButton = %UpSocketMenuButton
@onready var downSocketMenuButton : MenuButton = %DownSocketMenuButton
@onready var leftSocketMenuButton : MenuButton = %LeftSocketMenuButton
@onready var rightSocketMenuButton : MenuButton = %RightSocketMenuButton
@onready var frontSocketMenuButton : MenuButton = %FrontSocketMenuButton
@onready var backSocketMenuButton : MenuButton = %BackSocketMenuButton

var file_path: String = ""
var _tags: Array[String] = []
var _has_override: bool = false
var _library = null  # Reference to module library
var _socket_config: Dictionary = {}
var _current_template_id: int = 0  # Track current template selection (0 = none, 1+ = template index)

func _ready() -> void:
    """Initialize the tile detail."""
    if overrideCheckButton:
        overrideCheckButton.pressed.connect(_on_override_pressed)
    
    if addTagButton:
        addTagButton.pressed.connect(_on_add_tag_pressed)
    
    if detailsContainer:
        detailsContainer.visible = false
    
    _populate_template_dropdown()
    _setup_tag_menu()
    _setup_socket_menus()

## ============================================================================
## Public API
## ============================================================================

func setup(path: String, library = null) -> void:
    """Setup the tile detail with a file path."""
    file_path = path
    _library = library
    var file_name = path.get_file().get_basename()
    
    # Clear any previous state
    _socket_config.clear()
    
    # Disconnect template signal temporarily to prevent unwanted triggers during setup
    if templateOptionButton and templateOptionButton.item_selected.is_connected(_on_template_selected):
        templateOptionButton.item_selected.disconnect(_on_template_selected)
    
    # Repopulate template dropdown with library templates
    _populate_template_dropdown()
    
    # Update socket menu texts to show initial state (all "none")
    _update_all_socket_menu_texts()
    
    if nameLabel:
        nameLabel.text = file_name
    
    # Set default size
    if xSizeSpinBox:
        xSizeSpinBox.value = 1
    if ySizeSpinBox:
        ySizeSpinBox.value = 1
    if zSizeSpinBox:
        zSizeSpinBox.value = 1

func is_checked() -> bool:
    """Check if this tile is selected."""
    return checkedCheckBox.button_pressed if checkedCheckBox else false

func set_checked(checked: bool) -> void:
    """Set the checked state."""
    if checkedCheckBox:
        checkedCheckBox.button_pressed = checked

func has_override() -> bool:
    """Check if this tile has custom override settings."""
    return _has_override

func get_config() -> Dictionary:
    """Get the tile configuration."""
    var config = {
        "file_path": file_path,
        "tile_name": nameLabel.text if nameLabel else file_path.get_file().get_basename(),
        "size": Vector3i(int(xSizeSpinBox.value), int(ySizeSpinBox.value), int(zSizeSpinBox.value)),
        "template_id": _get_selected_template_id(),
        "tags": _tags.duplicate(),
        "auto_detect_symmetry": autoSymmetryDetectionCheckBox.button_pressed if autoSymmetryDetectionCheckBox else true,
        "generate_variants": rotationalVarianceCheckBox.button_pressed if rotationalVarianceCheckBox else false,
        "include_self_match": selfMatchCheckBox.button_pressed if selfMatchCheckBox else false,
        "has_override": _has_override,
        "socket_config": _socket_config.duplicate()
    }
    return config

func set_config(config: Dictionary) -> void:
    """Set the tile configuration (from batch settings)."""
    if config.has("size"):
        var size: Vector3i = config["size"]
        if xSizeSpinBox:
            xSizeSpinBox.value = size.x
        if ySizeSpinBox:
            ySizeSpinBox.value = size.y
        if zSizeSpinBox:
            zSizeSpinBox.value = size.z
    
    if config.has("template_id"):
        var template_id = config["template_id"]
        _select_template_by_id(template_id)
        _current_template_id = template_id
        # Clear socket config when applying batch template
        _socket_config.clear()
        # Update all socket menu texts to reflect new template
        _update_all_socket_menu_texts()
    
    if config.has("tags"):
        _tags = config["tags"].duplicate()
        _update_tags_display()
    
    if config.has("auto_detect_symmetry") and autoSymmetryDetectionCheckBox:
        autoSymmetryDetectionCheckBox.button_pressed = config["auto_detect_symmetry"]
    
    if config.has("generate_variants") and rotationalVarianceCheckBox:
        rotationalVarianceCheckBox.button_pressed = config["generate_variants"]
    
    if config.has("include_self_match") and selfMatchCheckBox:
        selfMatchCheckBox.button_pressed = config["include_self_match"]

func reset_override() -> void:
    """Reset the override flag."""
    _has_override = false
    if overrideCheckButton:
        overrideCheckButton.text = "Override"

## ============================================================================
## Override Management
## ============================================================================

func _on_override_pressed() -> void:
    """Handle override button press."""
    if detailsContainer:
        var is_visible = detailsContainer.visible
        detailsContainer.visible = not is_visible
        
        if not is_visible:
            _has_override = true
            overrideCheckButton.text = "📌 Override"
        else:
            overrideCheckButton.text = "Override"

## ============================================================================
## Template Management
## ============================================================================

func _populate_template_dropdown() -> void:
    """Populate the template dropdown with built-in templates."""
    if not templateOptionButton:
        return
    
    templateOptionButton.clear()
    templateOptionButton.add_item("None (No Template)", 0)  # Use 0 for None since negative IDs don't work
    
    var templates = LibraryPresets.get_socket_templates()
    for i in range(templates.size()):
        var template = templates[i]
        templateOptionButton.add_item(template.template_name, i + 1)  # Offset by 1
        templateOptionButton.set_item_tooltip(i + 1, template.description)
    
    # Explicitly select "None" (index 0, ID 0)
    templateOptionButton.selected = 0
    _current_template_id = 0  # 0 means no template selected
    
    # Connect to template selection change
    if not templateOptionButton.item_selected.is_connected(_on_template_selected):
        templateOptionButton.item_selected.connect(_on_template_selected)

func _on_template_selected(index: int) -> void:
    """Handle template selection change."""
    var new_template_id = templateOptionButton.get_item_id(index)
    
    # If override is not active, just track the selection and update display
    if not _has_override:
        _current_template_id = new_template_id
        _socket_config.clear()
        _update_all_socket_menu_texts()
        return
    
    # Check if template is actually changing
    if _current_template_id == new_template_id:
        return
    
    # Only show confirmation if we're changing AWAY from a template
    # (template -> none or template -> different template)
    var is_changing_away_from_template = _current_template_id > 0
    
    # Check if there's custom socket configuration
    var has_socket_config = not _socket_config.is_empty()
    
    # Show confirmation if:
    # 1. Changing away from a template (will lose template sockets), OR
    # 2. There's existing manual socket configuration
    if is_changing_away_from_template or has_socket_config:
        # Show confirmation dialog
        var dialog = ConfirmationDialog.new()
        dialog.dialog_text = "Changing the template will override your current socket configuration. Continue?"
        dialog.title = "Override Socket Configuration"
        
        # Find the index for the previous template
        var previous_template_id = _current_template_id
        var revert_index = 0
        for i in range(templateOptionButton.item_count):
            if templateOptionButton.get_item_id(i) == previous_template_id:
                revert_index = i
                break
        
        dialog.confirmed.connect(func():
            # User confirmed, clear socket config and update template
            _current_template_id = new_template_id
            _socket_config.clear()
            _update_all_socket_menu_texts()
            dialog.queue_free()
        )
        
        dialog.canceled.connect(func():
            # User canceled, revert template selection to previous
            templateOptionButton.selected = revert_index
            dialog.queue_free()
        )
        
        add_child(dialog)
        dialog.popup_centered()
    else:
        # No confirmation needed, just update
        _current_template_id = new_template_id
        _socket_config.clear()
        _update_all_socket_menu_texts()

func _update_all_socket_menu_texts() -> void:
    """Update all socket menu button texts."""
    var menus = [
        upSocketMenuButton,
        downSocketMenuButton,
        leftSocketMenuButton,
        rightSocketMenuButton,
        frontSocketMenuButton,
        backSocketMenuButton
    ]
    
    for menu in menus:
        if menu:
            _update_socket_menu_text(menu)

func _get_selected_template_id() -> int:
    """Get the selected template ID (0 for None, 1+ for templates)."""
    if not templateOptionButton:
        return 0
    
    var selected_idx = templateOptionButton.selected
    if selected_idx < 0:
        return 0
    
    return templateOptionButton.get_item_id(selected_idx)

func _select_template_by_id(template_id: int) -> void:
    """Select a template by its ID."""
    if not templateOptionButton:
        return
    
    # Temporarily disconnect signal to prevent triggering confirmation dialog
    if templateOptionButton.item_selected.is_connected(_on_template_selected):
        templateOptionButton.item_selected.disconnect(_on_template_selected)
    
    for i in range(templateOptionButton.item_count):
        if templateOptionButton.get_item_id(i) == template_id:
            templateOptionButton.selected = i
            break
    
    # Reconnect signal
    if not templateOptionButton.item_selected.is_connected(_on_template_selected):
        templateOptionButton.item_selected.connect(_on_template_selected)

## ============================================================================
## Tag Management
## ============================================================================

func _setup_tag_menu() -> void:
    """Setup tag menu button."""
    if tagsMenuButton:
        tagsMenuButton.about_to_popup.connect(_populate_tag_menu)
        var popup = tagsMenuButton.get_popup()
        if not popup.id_pressed.is_connected(_on_tag_menu_item_pressed):
            popup.id_pressed.connect(_on_tag_menu_item_pressed)

func _populate_tag_menu() -> void:
    """Populate tag menu with available tags from library."""
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
    _has_override = true

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
            _has_override = true
    )
    
    dialog.canceled.connect(dialog.queue_free)
    dialog.confirmed.connect(dialog.queue_free)
    
    add_child(dialog)
    dialog.popup_centered()
    tag_edit.grab_focus()

## ============================================================================
## Socket Management
## ============================================================================

func _setup_socket_menus() -> void:
    """Setup socket menu buttons."""
    var socket_menus = [
        upSocketMenuButton,
        downSocketMenuButton,
        leftSocketMenuButton,
        rightSocketMenuButton,
        frontSocketMenuButton,
        backSocketMenuButton
    ]
    
    for menu in socket_menus:
        if menu:
            menu.about_to_popup.connect(_populate_socket_menu.bind(menu))
            var popup = menu.get_popup()
            popup.id_pressed.connect(_on_socket_menu_item_pressed.bind(menu))
    
    if addSocketTypeButton:
        addSocketTypeButton.pressed.connect(_on_add_socket_type_pressed)

func _populate_socket_menu(menu: MenuButton) -> void:
    """Populate socket menu with available socket types from library."""
    if not menu or not _library:
        return
    
    var popup = menu.get_popup()
    popup.clear()
    
    # Determine direction from menu
    var direction = _get_direction_from_menu(menu)
    if direction == Vector3i.ZERO:
        return
    
    # Get socket types from library
    var socket_types = _library.get_socket_type_resources()
    if socket_types.is_empty():
        popup.add_item("(No socket types available)", -1)
        popup.set_item_disabled(0, true)
        return
    
    # Get current sockets for this direction
    var current_sockets: Array = []
    if _socket_config.has(direction):
        current_sockets = _socket_config[direction]
    elif _current_template_id > 0:
        # If no manual config but template is selected, show what the template will create
        current_sockets = _get_template_sockets_for_direction(direction)
    
    # Add socket types
    for i in range(socket_types.size()):
        var socket_type = socket_types[i]
        var socket_id = socket_type.type_id
        var is_selected = current_sockets.has(socket_id)
        popup.add_check_item(socket_id, i)
        popup.set_item_checked(i, is_selected)
    
    _update_socket_menu_text(menu)

func _get_direction_from_menu(menu: MenuButton) -> Vector3i:
    """Get socket direction from menu button."""
    if menu == upSocketMenuButton:
        return Vector3i.UP
    elif menu == downSocketMenuButton:
        return Vector3i.DOWN
    elif menu == leftSocketMenuButton:
        return Vector3i.LEFT
    elif menu == rightSocketMenuButton:
        return Vector3i.RIGHT
    elif menu == frontSocketMenuButton:
        return Vector3i.FORWARD
    elif menu == backSocketMenuButton:
        return Vector3i.BACK
    return Vector3i.ZERO

func _get_direction_name(direction: Vector3i) -> String:
    """Get display name for direction."""
    if direction == Vector3i.UP:
        return "Up"
    elif direction == Vector3i.DOWN:
        return "Down"
    elif direction == Vector3i.LEFT:
        return "Left"
    elif direction == Vector3i.RIGHT:
        return "Right"
    elif direction == Vector3i.FORWARD:
        return "Front"
    elif direction == Vector3i.BACK:
        return "Back"
    return "Unknown"

func _on_socket_menu_item_pressed(id: int, menu: MenuButton) -> void:
    """Handle socket menu item selection."""
    if not _library:
        return
    
    var direction = _get_direction_from_menu(menu)
    if direction == Vector3i.ZERO:
        return
    
    var socket_types = _library.get_socket_type_resources()
    if id < 0 or id >= socket_types.size():
        return
    
    var socket_type = socket_types[id]
    var socket_id = socket_type.type_id
    
    # Initialize direction array if needed
    if not _socket_config.has(direction):
        _socket_config[direction] = []
    
    var current_sockets: Array = _socket_config[direction]
    
    # Toggle socket
    if current_sockets.has(socket_id):
        current_sockets.erase(socket_id)
    else:
        current_sockets.append(socket_id)
    
    _update_socket_menu_text(menu)
    _has_override = true

func _get_template_sockets_for_direction(direction: Vector3i) -> Array:
    """Get socket type IDs that the current template defines for a direction."""
    if _current_template_id == 0:
        return []
    
    var template_index = _current_template_id - 1  # Adjust from ID to array index
    var templates = LibraryPresets.get_socket_templates()
    if template_index < 0 or template_index >= templates.size():
        return []
    
    var template = templates[template_index]
    var socket_ids: Array = []
    
    for entry_data in template.entries:
        var entry = entry_data if entry_data is Dictionary else {}
        if entry.get("direction", Vector3i.ZERO) == direction:
            var socket_id = entry.get("socket_id", "")
            if not socket_id.is_empty():
                socket_ids.append(socket_id)
    
    return socket_ids

func _update_socket_menu_text(menu: MenuButton) -> void:
    """Update socket menu button text to show selected sockets."""
    var direction = _get_direction_from_menu(menu)
    if direction == Vector3i.ZERO:
        return
    
    var direction_name = _get_direction_name(direction)
    
    # Determine which sockets to display
    var socket_ids: Array = []
    if _socket_config.has(direction) and not _socket_config[direction].is_empty():
        socket_ids = _socket_config[direction]
    elif _current_template_id > 0:
        socket_ids = _get_template_sockets_for_direction(direction)
    
    # Update menu text
    if socket_ids.is_empty():
        menu.text = "None"
    elif socket_ids.size() == 1:
        menu.text = "%s" % [socket_ids[0]]
    else:
        menu.text = "%d types" % [socket_ids.size()]

func _on_add_socket_type_pressed() -> void:
    """Handle add socket type button press."""
    if not _library:
        push_warning("No library reference available for adding socket types")
        return
    
    var dialog = AcceptDialog.new()
    dialog.title = "Add Socket Type"
    dialog.dialog_text = "Enter socket type ID:"
    
    var container = VBoxContainer.new()
    
    var id_label = Label.new()
    id_label.text = "Socket ID:"
    container.add_child(id_label)
    
    var id_edit = LineEdit.new()
    id_edit.placeholder_text = "socket_id"
    id_edit.custom_minimum_size = Vector2(200, 0)
    container.add_child(id_edit)
    
    var symmetry_check = CheckBox.new()
    symmetry_check.text = "Symmetric (can connect to itself)"
    symmetry_check.button_pressed = false
    container.add_child(symmetry_check)
    
    dialog.add_child(container)
    
    dialog.confirmed.connect(func():
        var socket_id = id_edit.text.strip_edges()
        if not socket_id.is_empty():
            var is_symmetric = symmetry_check.button_pressed
            var compatible_with = [socket_id] if is_symmetric else []
            
            # Register in library
            var socket_type = _library.register_socket_type(socket_id, compatible_with)
            if socket_type:
                print("Added socket type: ", socket_id)
            else:
                push_warning("Socket type already exists: ", socket_id)
    )
    
    dialog.canceled.connect(dialog.queue_free)
    dialog.confirmed.connect(dialog.queue_free)
    
    add_child(dialog)
    dialog.popup_centered()
    id_edit.grab_focus()