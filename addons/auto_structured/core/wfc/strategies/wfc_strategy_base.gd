@tool
class_name WfcStrategyBase extends RefCounted
## Base class for WFC generation strategies.
##
## Extend this class to create custom generation strategies that determine
## which cells should be collapsed during WFC generation.
##
## Example:
##   class_name MyCustomStrategy extends WfcStrategyBase
##   
##   func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
##       # Your custom logic here
##       return position.y == 0  # Only fill ground level
##   
##   func get_name() -> String:
##       return "My Custom Strategy"
##   
##   func get_description() -> String:
##       return "Only fills the ground level"


## Determine if a cell at the given position should be collapsed.
## Override this method in derived classes.
##
## Args:
##   position: Grid position of the cell (Vector3i)
##   grid_size: Total size of the grid (Vector3i)
##
## Returns:
##   true if the cell should be collapsed with a tile, false to leave it empty
func should_collapse_cell(_position: Vector3i, _grid_size: Vector3i) -> bool:
	push_error("should_collapse_cell() must be implemented in derived strategy class")
	return true


## Get a human-readable name for this strategy.
## Override this method in derived classes.
##
## Returns:
##   String name of the strategy
func get_name() -> String:
	push_error("get_name() must be implemented in derived strategy class")
	return "Unknown Strategy"


## Get a description of what this strategy does.
## Override this method in derived classes.
##
## Returns:
##   String description of the strategy behavior
func get_description() -> String:
	push_error("get_description() must be implemented in derived strategy class")
	return "No description available"


## Optional: Called before generation starts.
## Override to perform any initialization needed.
##
## Args:
##   grid_size: The size of the grid that will be generated
func initialize(_grid_size: Vector3i) -> void:
	pass


## Optional: Called after generation completes.
## Override to perform any cleanup needed.
func finalize() -> void:
	pass

func get_options() -> Control:
	return null


func serialize_state() -> Dictionary:
	var state: Dictionary = {}
	for prop in get_property_list():
		var usage: int = int(prop.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name: String = prop.get("name", "")
		if name == "script" or name.begins_with("_"):
			continue
		var type := int(prop.get("type", TYPE_NIL))
		if type == TYPE_OBJECT:
			continue
		state[name] = get(name)
	return state.duplicate(true)


func deserialize_state(state: Dictionary) -> void:
	if not state:
		return
	for key in state.keys():
		if _has_storage_property(key):
			set(key, state[key])
	if has_method("_on_after_deserialize_state"):
		call("_on_after_deserialize_state")


func _has_storage_property(property_name: String) -> bool:
	for prop in get_property_list():
		if prop.get("name", "") == property_name and int(prop.get("usage", 0)) & PROPERTY_USAGE_STORAGE:
			return true
	return false


func get_ui_warnings(_grid_size: Vector3i) -> Array[String]:
	return []


func get_required_tags(_grid_size: Vector3i) -> Array[String]:
	"""
	Return the list of semantic tile tags that this strategy expects to find.

	The UI uses this to explain strategy requirements and to highlight
	missing coverage in the active Module Library.
	"""
	return []


## Get semantic tags for a cell to filter which tile types can be placed.
## Override to assign semantic meaning (e.g., "road", "wall", "roof", "floor").
##
## Args:
##   position: Grid position of the cell (Vector3i)
##   grid_size: Total size of the grid (Vector3i)
##
## Returns:
##   Array of tag strings that the cell should have. Empty array means no filtering.
##
## Example:
##   func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
##       if position.y == 0:
##           return ["floor"]
##       elif position.y == grid_size.y - 1:
##           return ["roof"]
##       return []
func get_cell_tags(_position: Vector3i, _grid_size: Vector3i) -> Array[String]:
	return []


## Get weight/priority for collapsing this cell.
## Higher weights = higher priority. Can be used for custom collapse ordering.
##
## Args:
##   position: Grid position of the cell (Vector3i)
##   grid_size: Total size of the grid (Vector3i)
##
## Returns:
##   Weight value (default 1.0). Higher = more likely to be collapsed first.
##
## Example:
##   func get_cell_weight(position: Vector3i, grid_size: Vector3i) -> float:
##       # Prioritize collapsing from bottom up
##       return float(position.y)
func get_cell_weight(_position: Vector3i, _grid_size: Vector3i) -> float:
	return 1.0
