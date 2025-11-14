@tool
class_name WfcStrategyVillageLayout extends WfcStrategyBase
## Macro layout strategy for village generation with roads and buildings.
##
## This is a LAYOUT strategy - it generates the high-level structure:
## 1. Road network (grid-based paths)
## 2. Building footprints (rectangular plots between roads)
## 3. Semantic regions (assigns tags: road, wall, floor, roof, interior, exterior)
##
## This strategy defines WHAT goes WHERE, not the actual tiles.
## Use semantic tags on your tiles to control which tiles appear in each region.
##
## Usage:
##   var strategy = WfcStrategyVillageLayout.new()
##   strategy.road_width = 2
##   strategy.building_min_size = Vector3i(4, 3, 4)
##   strategy.building_max_size = Vector3i(8, 6, 8)
##   var solver = WfcSolver.new(grid, strategy)

## Region type enum for internal classification
enum RegionType {
	EMPTY,       ## Empty space (air)
	ROAD,        ## Road/path
	BUILDING,    ## Building structure
}

## Configuration: Road generation
@export var road_width: int = 2
@export var road_spacing: int = 12  ## Average distance between roads
@export var road_noise_threshold: float = 0.3  ## Higher = fewer roads

## Configuration: Building generation
@export var building_min_size: Vector3i = Vector3i(4, 3, 4)
@export var building_max_size: Vector3i = Vector3i(10, 7, 10)
@export var building_density: float = 0.6  ## Probability of placing building in valid plot
@export var min_building_spacing: int = 1  ## Min distance between buildings

## Configuration: Building details
@export var ground_floor_height: int = 1  ## Cells for ground floor (y=0)
@export var wall_thickness: int = 1  ## Walls are typically 1 cell thick
@export var roof_height: int = 1  ## Cells for roof at top

## Internal: Stored region data (built during initialize)
var _regions: Dictionary = {}  ## Vector3i -> RegionType
var _building_footprints: Array[Dictionary] = []  ## [{min: Vector3i, max: Vector3i}]
var _grid_size: Vector3i

func get_name() -> String:
	return "Village Layout (Macro)"

func get_description() -> String:
	return "Macro layout: generates road network and building footprints with semantic tagging. Use with tagged tiles."

func initialize(grid_size: Vector3i) -> void:
	"""Generate the macro layout: roads and building footprints"""
	_grid_size = grid_size
	_regions.clear()
	_building_footprints.clear()
	
	print("[Village Strategy] Initializing village layout...")
	print("  Grid size: ", grid_size)
	
	# Step 1: Generate road network (2D on ground level)
	_generate_road_network()
	
	# Step 2: Find valid building plots between roads
	_generate_building_footprints()
	
	# Step 3: Mark 3D regions for each building (walls, interior, roof)
	_classify_building_regions()
	
	print("  Generated ", _building_footprints.size(), " buildings")
	var road_count = _count_regions_of_type(RegionType.ROAD)
	print("  Road cells: ", road_count)

func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Only collapse cells that are part of roads or buildings"""
	var region = _regions.get(position, RegionType.EMPTY)
	return region != RegionType.EMPTY

func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
	"""Assign semantic tags based on region type and position within buildings"""
	var region = _regions.get(position, RegionType.EMPTY)
	
	match region:
		RegionType.ROAD:
			return ["road"]
		
		RegionType.BUILDING:
			# Determine if this is floor, wall, interior, or roof
			return _get_building_cell_tags(position)
	
	return []

func _generate_road_network() -> void:
	"""Generate a simple grid-based road network on y=0"""
	# Simple approach: horizontal and vertical roads at regular intervals
	# You can replace this with more sophisticated algorithms (Voronoi, graphs, etc.)
	
	for x in range(_grid_size.x):
		for z in range(_grid_size.z):
			var is_road = false
			
			# Vertical roads every road_spacing cells
			if x % road_spacing < road_width:
				is_road = true
			
			# Horizontal roads every road_spacing cells
			if z % road_spacing < road_width:
				is_road = true
			
			if is_road:
				# Mark road cells on ground level
				for y in range(ground_floor_height):
					_regions[Vector3i(x, y, z)] = RegionType.ROAD

func _generate_building_footprints() -> void:
	"""Find valid plots between roads and place buildings"""
	# Scan the ground plane for rectangular regions not occupied by roads
	# This is a simplified algorithm - production code would use more sophisticated placement
	
	var attempted_positions: Array[Vector3i] = []
	
	# Try placing buildings in a grid pattern
	var step = (building_min_size.x + building_max_size.x) / 2
	for x in range(road_width + 1, _grid_size.x - building_max_size.x, step):
		for z in range(road_width + 1, _grid_size.z - building_max_size.z, step):
			if randf() > building_density:
				continue
			
			# Random building size within bounds
			var size = Vector3i(
				randi_range(building_min_size.x, building_max_size.x),
				randi_range(building_min_size.y, building_max_size.y),
				randi_range(building_min_size.z, building_max_size.z)
			)
			
			var min_pos = Vector3i(x, 0, z)
			var max_pos = min_pos + size
			
			# Check if this footprint overlaps with roads or other buildings
			if _is_valid_building_plot(min_pos, max_pos):
				_building_footprints.append({
					"min": min_pos,
					"max": max_pos,
					"size": size
				})

func _is_valid_building_plot(min_pos: Vector3i, max_pos: Vector3i) -> bool:
	"""Check if a building can be placed here (no roads, other buildings, or out of bounds)"""
	# Check bounds
	if max_pos.x >= _grid_size.x or max_pos.z >= _grid_size.z:
		return false
	if max_pos.y >= _grid_size.y:
		return false
	
	# Check for overlap with roads or other buildings on ground level
	for x in range(min_pos.x - min_building_spacing, max_pos.x + min_building_spacing):
		for z in range(min_pos.z - min_building_spacing, max_pos.z + min_building_spacing):
			if x < 0 or x >= _grid_size.x or z < 0 or z >= _grid_size.z:
				continue
			
			var check_pos = Vector3i(x, 0, z)
			var existing = _regions.get(check_pos, RegionType.EMPTY)
			if existing != RegionType.EMPTY:
				return false
	
	return true

func _classify_building_regions() -> void:
	"""Mark all cells within building footprints as BUILDING type"""
	for building in _building_footprints:
		var min_pos: Vector3i = building["min"]
		var max_pos: Vector3i = building["max"]
		
		# Fill all cells in this building volume
		for x in range(min_pos.x, max_pos.x):
			for y in range(min_pos.y, max_pos.y):
				for z in range(min_pos.z, max_pos.z):
					var pos = Vector3i(x, y, z)
					_regions[pos] = RegionType.BUILDING

func _get_building_cell_tags(position: Vector3i) -> Array[String]:
	"""Determine specific tags for a building cell (floor, wall, interior, roof, etc.)"""
	# Find which building this position belongs to
	var building = _find_building_containing(position)
	if building.is_empty():
		return ["building"]  # Fallback
	
	var min_pos: Vector3i = building["min"]
	var max_pos: Vector3i = building["max"]
	var size: Vector3i = building["size"]
	
	var local_pos = position - min_pos
	var tags: Array[String] = []
	
	# Determine vertical layer
	if local_pos.y == 0:
		# Ground floor
		tags.append("floor")
		
		# Check if it's also a wall (perimeter of ground floor)
		if _is_perimeter(local_pos, size):
			tags.append("wall")
			tags.append("exterior")
		else:
			tags.append("interior")
	
	elif local_pos.y >= size.y - roof_height:
		# Roof level
		tags.append("roof")
	
	else:
		# Middle floors - walls or interior
		if _is_perimeter(local_pos, size):
			tags.append("wall")
			tags.append("exterior")
		else:
			tags.append("interior")
			tags.append("floor")  # Interior floors
	
	return tags

func _is_perimeter(local_pos: Vector3i, size: Vector3i) -> bool:
	"""Check if a local position is on the perimeter (outer edge) of a volume"""
	return (local_pos.x == 0 or local_pos.x == size.x - 1 or
	        local_pos.z == 0 or local_pos.z == size.z - 1)

func _find_building_containing(position: Vector3i) -> Dictionary:
	"""Find the building footprint that contains this position"""
	for building in _building_footprints:
		var min_pos: Vector3i = building["min"]
		var max_pos: Vector3i = building["max"]
		
		if (position.x >= min_pos.x and position.x < max_pos.x and
		    position.y >= min_pos.y and position.y < max_pos.y and
		    position.z >= min_pos.z and position.z < max_pos.z):
			return building
	
	return {}

func _count_regions_of_type(type: RegionType) -> int:
	"""Count how many cells are marked as a specific region type"""
	var count = 0
	for region_type in _regions.values():
		if region_type == type:
			count += 1
	return count


func get_options() -> Control:
	"""Return UI controls for configuring village layout parameters"""
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 400)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Road settings header
	var road_header = Label.new()
	road_header.text = "Road Settings"
	road_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(road_header)
	
	# Road width
	var road_width_label = Label.new()
	road_width_label.text = "Road Width (cells):"
	vbox.add_child(road_width_label)
	
	var road_width_spinner = SpinBox.new()
	road_width_spinner.min_value = 1
	road_width_spinner.max_value = 5
	road_width_spinner.value = road_width
	road_width_spinner.value_changed.connect(func(value: float):
		road_width = int(value)
	)
	vbox.add_child(road_width_spinner)
	
	# Road spacing
	var road_spacing_label = Label.new()
	road_spacing_label.text = "Road Spacing (cells):"
	vbox.add_child(road_spacing_label)
	
	var road_spacing_spinner = SpinBox.new()
	road_spacing_spinner.min_value = 8
	road_spacing_spinner.max_value = 30
	road_spacing_spinner.value = road_spacing
	road_spacing_spinner.value_changed.connect(func(value: float):
		road_spacing = int(value)
	)
	vbox.add_child(road_spacing_spinner)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Building settings header
	var building_header = Label.new()
	building_header.text = "Building Settings"
	building_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(building_header)
	
	# Building min size
	var min_size_label = Label.new()
	min_size_label.text = "Minimum Building Size (X, Y, Z):"
	vbox.add_child(min_size_label)
	
	var min_size_hbox = HBoxContainer.new()
	for i in range(3):
		var spinner = SpinBox.new()
		spinner.min_value = 3
		spinner.max_value = 20
		spinner.value = building_min_size[i]
		var axis = i
		spinner.value_changed.connect(func(value: float):
			match axis:
				0: building_min_size.x = int(value)
				1: building_min_size.y = int(value)
				2: building_min_size.z = int(value)
		)
		min_size_hbox.add_child(spinner)
	vbox.add_child(min_size_hbox)
	
	# Building max size
	var max_size_label = Label.new()
	max_size_label.text = "Maximum Building Size (X, Y, Z):"
	vbox.add_child(max_size_label)
	
	var max_size_hbox = HBoxContainer.new()
	for i in range(3):
		var spinner = SpinBox.new()
		spinner.min_value = 5
		spinner.max_value = 30
		spinner.value = building_max_size[i]
		var axis = i
		spinner.value_changed.connect(func(value: float):
			match axis:
				0: building_max_size.x = int(value)
				1: building_max_size.y = int(value)
				2: building_max_size.z = int(value)
		)
		max_size_hbox.add_child(spinner)
	vbox.add_child(max_size_hbox)
	
	# Building density
	var density_label = Label.new()
	density_label.text = "Building Density:"
	vbox.add_child(density_label)
	
	var density_hbox = HBoxContainer.new()
	var density_slider = HSlider.new()
	density_slider.min_value = 0.0
	density_slider.max_value = 1.0
	density_slider.step = 0.05
	density_slider.value = building_density
	density_slider.custom_minimum_size = Vector2(150, 0)
	density_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	density_hbox.add_child(density_slider)
	
	var density_value = Label.new()
	density_value.text = "%.2f" % building_density
	density_value.custom_minimum_size = Vector2(50, 0)
	density_hbox.add_child(density_value)
	vbox.add_child(density_hbox)
	
	density_slider.value_changed.connect(func(value: float):
		building_density = value
		density_value.text = "%.2f" % value
	)
	
	# Building spacing
	var spacing_label = Label.new()
	spacing_label.text = "Minimum Building Spacing (cells):"
	vbox.add_child(spacing_label)
	
	var spacing_spinner = SpinBox.new()
	spacing_spinner.min_value = 0
	spacing_spinner.max_value = 5
	spacing_spinner.value = min_building_spacing
	spacing_spinner.value_changed.connect(func(value: float):
		min_building_spacing = int(value)
	)
	vbox.add_child(spacing_spinner)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Details header
	var details_header = Label.new()
	details_header.text = "Building Details"
	details_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(details_header)
	
	# Ground floor height
	var ground_label = Label.new()
	ground_label.text = "Ground Floor Height (cells):"
	vbox.add_child(ground_label)
	
	var ground_spinner = SpinBox.new()
	ground_spinner.min_value = 1
	ground_spinner.max_value = 3
	ground_spinner.value = ground_floor_height
	ground_spinner.value_changed.connect(func(value: float):
		ground_floor_height = int(value)
	)
	vbox.add_child(ground_spinner)
	
	# Roof height
	var roof_label = Label.new()
	roof_label.text = "Roof Height (cells):"
	vbox.add_child(roof_label)
	
	var roof_spinner = SpinBox.new()
	roof_spinner.min_value = 1
	roof_spinner.max_value = 3
	roof_spinner.value = roof_height
	roof_spinner.value_changed.connect(func(value: float):
		roof_height = int(value)
	)
	vbox.add_child(roof_spinner)
	
	scroll.add_child(vbox)
	return scroll
