extends RefCounted

const WfcStrategyGroundWalls := preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_ground_walls.gd")
const WfcStrategyScatter := preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_scatter.gd")
const WfcStrategyOrganic := preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_organic.gd")
const WfcStrategyLayered := preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_layered.gd")
const WfcStrategyVillageLayout := preload("res://addons/auto_structured/core/wfc/strategies/wfc_strategy_village_layout.gd")

func run_all() -> Dictionary:
	var results := {
		"total": 0,
		"failures": []
	}

	_run_test(results, "Ground walls tag coverage", Callable(self, "test_ground_walls_tags"))
	_run_test(results, "Scatter strategy determinism", Callable(self, "test_scatter_determinism"))
	_run_test(results, "Organic strategy semantics", Callable(self, "test_organic_semantics"))
	_run_test(results, "Layered atrium layout", Callable(self, "test_layered_walkways"))
	_run_test(results, "Village layout seed reproducibility", Callable(self, "test_village_layout_reproducible"))

	return results

func _run_test(results: Dictionary, name: String, callable: Callable) -> void:
	results["total"] += 1
	var outcome = callable.call()
	if outcome == null:
		print("  ✔ ", name)
	else:
		print("  ✘ ", name, " -> ", outcome)
		results["failures"].append("%s: %s" % [name, outcome])

func test_ground_walls_tags() -> Variant:
	var strategy := WfcStrategyGroundWalls.new()
	strategy.include_roof = true
	strategy.mode = WfcStrategyGroundWalls.Mode.GROUND_WALLS
	var size := Vector3i(4, 3, 4)
	strategy.initialize(size)

	var ground_interior := Vector3i(1, 0, 1)
	if not strategy.should_collapse_cell(ground_interior, size):
		return "Ground interior should be filled"
	var floor_tags := strategy.get_cell_tags(ground_interior, size)
	if "floor" not in floor_tags or "interior" not in floor_tags:
		return "Ground interior missing expected tags: %s" % [floor_tags]

	var wall_cell := Vector3i(0, 1, 1)
	if not strategy.should_collapse_cell(wall_cell, size):
		return "Perimeter column should be filled"
	var wall_tags := strategy.get_cell_tags(wall_cell, size)
	if "wall" not in wall_tags or "exterior" not in wall_tags:
		return "Wall cell missing tags: %s" % [wall_tags]

	var roof_cell := Vector3i(1, size.y - 1, 1)
	if not strategy.should_collapse_cell(roof_cell, size):
		return "Roof cell should exist when roof included"
	var roof_tags := strategy.get_cell_tags(roof_cell, size)
	if "roof" not in roof_tags:
		return "Roof cell missing roof tag: %s" % [roof_tags]

	return null

func test_scatter_determinism() -> Variant:
	var strategy := WfcStrategyScatter.new()
	strategy.fill_probability = 0.5
	strategy.random_seed = 99
	strategy.noise_frequency = 0.35
	var size := Vector3i(4, 1, 4)
	strategy.initialize(size)

	var sample := Vector3i(2, 0, 1)
	var first := strategy.should_collapse_cell(sample, size)
	for i in range(5):
		if strategy.should_collapse_cell(sample, size) != first:
			return "Scatter produced inconsistent result on repeated checks"

	var tags := strategy.get_cell_tags(sample, size)
	if first and "decoration" not in tags:
		return "Scatter filled cell should be tagged as decoration"
	if not first and not tags.is_empty():
		return "Scatter empty cell should not have tags"

	return null

func test_organic_semantics() -> Variant:
	var strategy := WfcStrategyOrganic.new()
	strategy.base_solid_height = 1
	strategy.density = 0.65
	strategy.edge_bias_strength = 0.8
	strategy.noise_seed = 42
	strategy.add_height_tags = true
	var size := Vector3i(6, 4, 6)
	strategy.initialize(size)

	var ground_cell := Vector3i(2, 0, 2)
	if not strategy.should_collapse_cell(ground_cell, size):
		return "Organic strategy should always fill ground cell"
	var ground_tags := strategy.get_cell_tags(ground_cell, size)
	if "floor" not in ground_tags or "interior" not in ground_tags:
		return "Ground cell missing expected tags: %s" % [ground_tags]

	var wall_cell := Vector3i(0, 1, 2)
	if not strategy.should_collapse_cell(wall_cell, size):
		return "Perimeter support should exist"
	var wall_tags := strategy.get_cell_tags(wall_cell, size)
	if "wall" not in wall_tags or "exterior" not in wall_tags:
		return "Organic perimeter cell missing wall/exterior tags: %s" % [wall_tags]

	var roof_found := false
	for x in range(size.x):
		for z in range(size.z):
			var pos := Vector3i(x, size.y - 1, z)
			if strategy.should_collapse_cell(pos, size):
				var roof_tags := strategy.get_cell_tags(pos, size)
				if "roof" in roof_tags:
					roof_found = true
					break
		if roof_found:
			break
	if not roof_found:
		return "Failed to locate any roof-tagged cells"

	var interior_void := Vector3i(2, 3, 2)
	if strategy.should_collapse_cell(interior_void, size) and strategy.get_cell_tags(interior_void, size).is_empty():
		return "Filled cell should expose tags"

	return null

func test_layered_walkways() -> Variant:
	var strategy := WfcStrategyLayered.new()
	strategy.walkway_width = 1
	strategy.level_interval = 2
	strategy.include_roof = true
	strategy.carve_central_atrium = true
	var size := Vector3i(6, 5, 6)

	var ground_center := Vector3i(2, 0, 2)
	if not strategy.should_collapse_cell(ground_center, size):
		return "Ground level should be solid"
	var ground_tags := strategy.get_cell_tags(ground_center, size)
	if "floor" not in ground_tags:
		return "Ground tags missing floor designation: %s" % [ground_tags]

	var walkway_cell := Vector3i(0, 2, 3)
	if not strategy.should_collapse_cell(walkway_cell, size):
		return "Walkway level perimeter should be filled"
	var walkway_tags := strategy.get_cell_tags(walkway_cell, size)
	if "walkway" not in walkway_tags and "edge" not in walkway_tags:
		return "Walkway cell missing walkway/edge tags: %s" % [walkway_tags]

	var atrium_cell := Vector3i(2, 2, 2)
	if strategy.should_collapse_cell(atrium_cell, size):
		return "Atrium center should remain open"

	var roof_cell := Vector3i(0, size.y - 1, 2)
	if not strategy.should_collapse_cell(roof_cell, size):
		return "Roof perimeter should be present"
	var roof_tags := strategy.get_cell_tags(roof_cell, size)
	if "roof" not in roof_tags:
		return "Roof walkway missing roof tag: %s" % [roof_tags]

	return null

func test_village_layout_reproducible() -> Variant:
	var size := Vector3i(20, 4, 20)
	var strategy_a := WfcStrategyVillageLayout.new()
	strategy_a.random_seed = 2025
	strategy_a.initialize(size)

	var strategy_b := WfcStrategyVillageLayout.new()
	strategy_b.random_seed = 2025
	strategy_b.initialize(size)

	var sample_positions := [
		Vector3i(0, 0, 0),
		Vector3i(5, 0, 5),
		Vector3i(10, 0, 10),
		Vector3i(5, 1, 12),
		Vector3i(12, 2, 5),
		Vector3i(15, 0, 18)
	]
	for pos in sample_positions:
		var a := strategy_a.should_collapse_cell(pos, size)
		var b := strategy_b.should_collapse_cell(pos, size)
		if a != b:
			return "Seed reproducibility mismatch at %s" % [pos]

	var road_found := false
	for x in range(size.x):
		for z in range(size.z):
			var pos := Vector3i(x, 0, z)
			var tags := strategy_a.get_cell_tags(pos, size)
			if "road" in tags:
				road_found = true
				break
		if road_found:
			break
	if not road_found:
		return "No road cells detected in layout"

	var building_found := false
	for x in range(size.x):
		for y in range(1, size.y):
			for z in range(size.z):
				var pos := Vector3i(x, y, z)
				var tags := strategy_a.get_cell_tags(pos, size)
				if "interior" in tags or "wall" in tags:
					building_found = true
					break
			if building_found:
				break
		if building_found:
			break
	if not building_found:
		return "No building regions detected in layout"

	return null
