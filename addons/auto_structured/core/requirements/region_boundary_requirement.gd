@tool
extends "res://addons/auto_structured/core/requirements/requirement.gd"
class_name RegionBoundaryRequirement

const Tile = preload("res://addons/auto_structured/core/tile.gd")

## Configuration class for customizing boundary connection behavior.

@export var enforce_closed_loops: bool = true
@export var allow_open_ends: bool = false
@export var min_edge_neighbors: int = 1
@export var min_corner_neighbors: int = 1
@export var relax_on_world_boundary: bool = false

func evaluate(tile: Tile, position: Vector3i, grid, context: Dictionary) -> bool:
	if not enabled:
		return true
	if tile == null:
		return true
	
	# Get boundary role from the tile itself (not from requirement)
	var role: Tile.BoundaryRole = tile.boundary_role
	if role == Tile.BoundaryRole.NONE:
		return true  # Not a boundary tile, no constraint
	
	var required_neighbors := _required_neighbors_for_role(role, position, grid.size)
	if allow_open_ends:
		required_neighbors = min(1, required_neighbors)
	var counts := _count_boundary_neighbors(position, grid)
	if counts["confirmed"] >= required_neighbors:
		return true
	if not enforce_closed_loops:
		return counts["confirmed"] > 0
	return counts["confirmed"] + counts["potential"] >= required_neighbors

func _required_neighbors_for_role(role: Tile.BoundaryRole, position: Vector3i, grid_size: Vector3i) -> int:
	var required := min_edge_neighbors
	match role:
		Tile.BoundaryRole.CORNER:
			required = min_corner_neighbors
		Tile.BoundaryRole.INFILL:
			required = max(1, min_edge_neighbors - 1)
	if relax_on_world_boundary and _touches_world_boundary(position, grid_size):
		required = max(1, required - 1)
	return max(1, required)

func _touches_world_boundary(position: Vector3i, grid_size: Vector3i) -> bool:
	return (
		position.x == 0 or position.x == grid_size.x - 1
		or position.z == 0 or position.z == grid_size.z - 1
	)

func _count_boundary_neighbors(position: Vector3i, grid) -> Dictionary:
	var counts := {
		"confirmed": 0,
		"potential": 0
	}
	for dir in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor_pos: Vector3i = position + dir
		if not grid.is_valid_position(neighbor_pos):
			continue
		var neighbor_cell = grid.get_cell(neighbor_pos)
		if neighbor_cell == null:
			continue
		var state := _neighbor_state(neighbor_cell)
		if state == 2:
			counts["confirmed"] += 1
		elif state == 1:
			counts["potential"] += 1
	return counts

func _neighbor_state(cell) -> int:
	if cell.is_collapsed():
		var tile: Tile = cell.get_tile()
		return 2 if _tile_is_boundary(tile) else 0
	for variant in cell.possible_tile_variants:
		var tile: Tile = variant.get("tile")
		if _tile_is_boundary(tile):
			return 1
	return 0

func _tile_is_boundary(tile: Tile) -> bool:
	return tile != null and tile.boundary_role != Tile.BoundaryRole.NONE

static func get_tile_boundary_role(tile: Tile) -> Tile.BoundaryRole:
	"""Get the boundary role directly from the tile (kept for backward compatibility)"""
	if tile == null:
		return Tile.BoundaryRole.NONE
	return tile.boundary_role

func get_config_control(_tile: Tile = null) -> Control:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)

	var description_label = Label.new()
	description_label.text = "Configure boundary connection rules."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(description_label)

	var enforce_check = CheckButton.new()
	enforce_check.text = "Enforce closed loops"
	enforce_check.button_pressed = enforce_closed_loops
	enforce_check.tooltip_text = "Ensures boundary tiles only succeed when they complete closed rings."
	enforce_check.toggled.connect(func(pressed: bool): enforce_closed_loops = pressed)
	root.add_child(enforce_check)

	var relax_check = CheckButton.new()
	relax_check.text = "Relax when touching world boundary"
	relax_check.button_pressed = relax_on_world_boundary
	relax_check.tooltip_text = "Reduce neighbor requirements for placements along the outer grid boundary."
	relax_check.toggled.connect(func(pressed: bool): relax_on_world_boundary = pressed)
	root.add_child(relax_check)

	var open_ends_check = CheckButton.new()
	open_ends_check.text = "Allow open ends (only one neighbor needed)"
	open_ends_check.button_pressed = allow_open_ends
	open_ends_check.tooltip_text = "Permit chains that terminate instead of forming perfect loops."
	open_ends_check.toggled.connect(func(pressed: bool): allow_open_ends = pressed)
	root.add_child(open_ends_check)

	root.add_child(_create_neighbor_spinbox("Min Edge Neighbors", min_edge_neighbors, func(value):
		min_edge_neighbors = int(value)
	, "Required adjacent tiles for edge pieces."))
	root.add_child(_create_neighbor_spinbox("Min Corner Neighbors", min_corner_neighbors, func(value):
		min_corner_neighbors = int(value)
	, "Required adjacent tiles when placing corners."))

	return root

func _create_neighbor_spinbox(label_text: String, current_value: int, on_change: Callable, tooltip_text: String = "") -> Control:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 140
	if not tooltip_text.is_empty():
		label.tooltip_text = tooltip_text
	row.add_child(label)

	var spin = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 6
	spin.step = 1
	spin.value = current_value
	spin.value_changed.connect(on_change)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not tooltip_text.is_empty():
		spin.tooltip_text = tooltip_text
	row.add_child(spin)
	return row

func get_failure_reason() -> String:
	return "Region boundary tiles must remain connected to similar tiles."

func get_description() -> String:
	return "Ensures tiles marked as boundary roles connect to form sealed regions."
