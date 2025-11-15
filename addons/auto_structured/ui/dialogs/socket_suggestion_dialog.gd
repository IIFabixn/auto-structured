@tool
class_name SocketSuggestionDialog extends AcceptDialog

signal suggestions_accepted(tile: Tile, selections: Array)
signal modify_requested(tile: Tile, selections: Array)
signal suggestions_rejected(tile: Tile)

const Tile := preload("res://addons/auto_structured/core/tile.gd")

@onready var summary_label: Label = %SummaryLabel
@onready var suggestion_tree: Tree = %SuggestionTree

var _current_tile: Tile = null
var _suggestions: Array = []
var _modify_button: Button

func _ready() -> void:
	title = "Socket Suggestions"
	get_ok_button().text = "Accept"
	add_cancel_button("Reject")
	_modify_button = add_button("Modify…", true, "modify")
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	custom_action.connect(_on_custom_action)
	_setup_tree()

func show_for_tile(tile: Tile, suggestions: Array) -> void:
	_current_tile = tile
	_suggestions = suggestions.duplicate()
	_update_summary()
	_populate_tree()
	var has_suggestions := not _suggestions.is_empty()
	get_ok_button().disabled = not has_suggestions
	_modify_button.disabled = not has_suggestions
	if has_suggestions:
		popup_centered_ratio(0.5)
	else:
		hide()

func _setup_tree() -> void:
	suggestion_tree.columns = 5
	suggestion_tree.set_column_titles_visible(true)
	suggestion_tree.set_column_title(0, "Use")
	suggestion_tree.set_column_title(1, "Direction")
	suggestion_tree.set_column_title(2, "Socket Type")
	suggestion_tree.set_column_title(3, "Matched Tile")
	suggestion_tree.set_column_title(4, "Score")
	suggestion_tree.hide_root = true

func _populate_tree() -> void:
	suggestion_tree.clear()
	var root := suggestion_tree.create_item()
	for i in range(_suggestions.size()):
		var entry: Dictionary = _suggestions[i]
		var item := suggestion_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, true)
		item.set_metadata(0, i)
		var direction: Vector3i = entry.get("direction", Vector3i.ZERO)
		item.set_text(1, _direction_to_label(direction))
		item.set_text(2, entry.get("socket_id", ""))
		var partner_tile: Tile = entry.get("partner_tile", null)
		item.set_text(3, partner_tile.name if partner_tile else "-")
		var score := float(entry.get("score", 0.0))
		item.set_text(4, "%.3f" % score)

func _collect_selected_suggestions() -> Array:
	var selections: Array = []
	var root := suggestion_tree.get_root()
	if root == null:
		return selections
	var item := root.get_first_child()
	while item:
		if item.is_checked(0):
			var index := int(item.get_metadata(0))
			if index >= 0 and index < _suggestions.size():
				selections.append(_suggestions[index])
		item = item.get_next()
	return selections

func _on_confirmed() -> void:
	var selections := _collect_selected_suggestions()
	emit_signal("suggestions_accepted", _current_tile, selections)
	hide()

func _on_canceled() -> void:
	emit_signal("suggestions_rejected", _current_tile)

func _on_custom_action(action: StringName) -> void:
	if action == StringName("modify"):
		var selections := _collect_selected_suggestions()
		emit_signal("modify_requested", _current_tile, selections)
		hide()

func _update_summary() -> void:
	if summary_label == null:
		return
	if _current_tile == null:
		summary_label.text = ""
		return
	var count := _suggestions.size()
	if count == 0:
		summary_label.text = "No matching sockets were detected for '%s'." % _current_tile.name
	else:
		summary_label.text = "Found %d potential socket match%s for '%s'." % [count, "es" if count != 1 else "", _current_tile.name]

static func _direction_to_label(direction: Vector3i) -> String:
	match direction:
		Vector3i.RIGHT:
			return "Right"
		Vector3i.LEFT:
			return "Left"
		Vector3i.UP:
			return "Up"
		Vector3i.DOWN:
			return "Down"
		Vector3i.FORWARD:
			return "Forward"
		Vector3i.BACK:
			return "Back"
		_:
			return str(direction)
