@tool
class_name ManageSocketsDialog extends Window

signal sockets_changed(socket_ids: Array[String])
signal new_type_requested(type_name: String)
signal socket_renamed(old_name: String, new_name: String)
signal socket_deleted(socket_name: String)

var sockets_list: VBoxContainer
var search_field: LineEdit
var header_label: Label
var add_type_btn: Button
var all_socket_ids: Array[String] = []
var selected_socket_ids: Array[String] = []
var is_editable: bool = false:  # When true, show rename/delete buttons instead of checkboxes
	set(value):
		is_editable = value
		_update_ui_for_mode()

func _ready() -> void:
	title = "Manage Compatible Sockets"
	size = Vector2i(400, 400)
	min_size = Vector2i(350, 300)
	close_requested.connect(_on_close_requested)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	
	# Header with add button
	var header = HBoxContainer.new()
	header_label = Label.new()
	header_label.text = "Select Compatible Socket Types:"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_label)
	
	add_type_btn = Button.new()
	add_type_btn.text = "+ Add New Type..."
	add_type_btn.pressed.connect(_on_add_new_type_pressed)
	header.add_child(add_type_btn)
	
	vbox.add_child(header)
	
	# Search field
	search_field = LineEdit.new()
	search_field.placeholder_text = "Search socket types..."
	search_field.text_changed.connect(_on_search_changed)
	search_field.clear_button_enabled = true
	vbox.add_child(search_field)
	
	# Scrollable list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	sockets_list = VBoxContainer.new()
	sockets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sockets_list)
	
	vbox.add_child(scroll)
	
	add_child(vbox)

func set_available_sockets(available: Array[String], selected: Array[String]) -> void:
	"""Set the available socket types and which ones are currently selected"""
	all_socket_ids = available.duplicate()
	selected_socket_ids = selected.duplicate()
	_refresh_list()

func _refresh_list(filter: String = "") -> void:
	"""Refresh the checkbox list with optional filter"""
	if not sockets_list:
		return
	
	# Clear existing items
	for child in sockets_list.get_children():
		child.queue_free()
	
	# Build list: selected first (checked), then unselected (unchecked), both alphabetically
	var checked_items: Array[String] = []
	var unchecked_items: Array[String] = []
	
	var filter_lower = filter.to_lower()
	
	for socket_id in all_socket_ids:
		# Apply search filter
		if filter_lower and socket_id.to_lower().find(filter_lower) == -1:
			continue
		
		if socket_id in selected_socket_ids:
			checked_items.append(socket_id)
		else:
			unchecked_items.append(socket_id)
	
	checked_items.sort()
	unchecked_items.sort()
	
	# Add checked items first
	for socket_id in checked_items:
		_add_checkbox_item(socket_id, true)
	
	# Then unchecked items
	for socket_id in unchecked_items:
		_add_checkbox_item(socket_id, false)
	
	# Show message if no results
	if checked_items.is_empty() and unchecked_items.is_empty():
		var empty_label = Label.new()
		if filter:
			empty_label.text = "(No socket types match search)"
		else:
			empty_label.text = "(No socket types available)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sockets_list.add_child(empty_label)

func _add_checkbox_item(socket_id: String, is_checked: bool) -> void:
	"""Add a checkbox item or editable item to the list"""
	if is_editable:
		# Editable mode: show label with rename/delete buttons
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = socket_id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		var is_builtin = socket_id == "none" or socket_id == "any"
		
		var rename_btn = Button.new()
		rename_btn.text = "Rename"
		rename_btn.pressed.connect(_on_rename_socket_pressed.bind(socket_id))
		rename_btn.disabled = is_builtin
		if is_builtin:
			rename_btn.tooltip_text = "Cannot rename built-in socket type"
		hbox.add_child(rename_btn)
		
		var delete_btn = Button.new()
		delete_btn.text = "Delete"
		delete_btn.pressed.connect(_on_delete_socket_pressed.bind(socket_id))
		delete_btn.disabled = is_builtin
		if is_builtin:
			delete_btn.tooltip_text = "Cannot delete built-in socket type"
		hbox.add_child(delete_btn)
		
		sockets_list.add_child(hbox)
	else:
		# Checkbox mode: show checkboxes for selection
		var checkbox = CheckBox.new()
		checkbox.text = socket_id
		checkbox.button_pressed = is_checked
		checkbox.toggled.connect(_on_checkbox_toggled.bind(socket_id))
		sockets_list.add_child(checkbox)

func _on_checkbox_toggled(is_pressed: bool, socket_id: String) -> void:
	"""Handle checkbox toggle"""
	if is_pressed:
		if socket_id not in selected_socket_ids:
			selected_socket_ids.append(socket_id)
	else:
		selected_socket_ids.erase(socket_id)
	
	# Emit change signal
	sockets_changed.emit(selected_socket_ids)
	
	# Refresh list to reorder (checked items first)
	var current_filter = search_field.text if search_field else ""
	_refresh_list(current_filter)

func _on_search_changed(new_text: String) -> void:
	"""Handle search field text change"""
	_refresh_list(new_text)

func _on_add_new_type_pressed() -> void:
	"""Show dialog to add a new socket type"""
	var dialog = AcceptDialog.new()
	dialog.title = "Add New Socket Type"
	dialog.dialog_text = "Enter new socket type ID:"
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "e.g. wall_plain"
	dialog.add_child(line_edit)
	
	dialog.confirmed.connect(func():
		var new_type = line_edit.text.strip_edges()
		if new_type:
			new_type_requested.emit(new_type)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func _update_ui_for_mode() -> void:
	"""Update UI elements based on is_editable mode"""
	if not header_label:
		return  # Not ready yet
	
	if is_editable:
		title = "Manage Socket Types"
		header_label.text = "Socket Types:"
		if add_type_btn:
			add_type_btn.visible = true
	else:
		title = "Manage Compatible Sockets"
		header_label.text = "Select Compatible Socket Types:"
		if add_type_btn:
			add_type_btn.visible = true
	
	# Refresh the list to update the UI for the current mode
	if not all_socket_ids.is_empty():
		_refresh_list()

func _on_close_requested() -> void:
	"""Handle close button click"""
	hide()

func _on_rename_socket_pressed(socket_id: String) -> void:
	"""Show dialog to rename a socket type"""
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Socket Type"
	dialog.dialog_text = "Enter new name for '%s':" % socket_id
	
	var line_edit = LineEdit.new()
	line_edit.text = socket_id
	line_edit.placeholder_text = "e.g. wall_plain"
	dialog.add_child(line_edit)
	
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if new_name and new_name != socket_id:
			# Check if new name already exists
			if new_name in all_socket_ids:
				push_warning("Socket type '%s' already exists" % new_name)
			else:
				socket_renamed.emit(socket_id, new_name)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	line_edit.select_all()

func _on_delete_socket_pressed(socket_id: String) -> void:
	"""Show confirmation dialog to delete a socket type"""
	var dialog = ConfirmationDialog.new()
	dialog.title = "Delete Socket Type"
	dialog.dialog_text = "Are you sure you want to delete '%s'?\n\nThis will affect all tiles using this socket type." % socket_id
	
	dialog.confirmed.connect(func():
		socket_deleted.emit(socket_id)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
