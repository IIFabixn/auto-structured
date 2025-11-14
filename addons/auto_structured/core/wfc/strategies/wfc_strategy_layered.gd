@tool
class_name WfcStrategyLayered extends WfcStrategyBase
## EXAMPLE: Simple layered building demonstrating semantic tagging.
##
## This is a LEARNING EXAMPLE, not a production strategy.
## Use WfcStrategyBuilding for actual building generation.
##
## Creates a basic multi-story structure with:
## - Floor tiles on the ground level (y=0)
## - Wall tiles on the exterior perimeter
## - Interior/floor tiles inside
## - Roof tiles on the top level
##
## Demonstrates the minimal use of get_cell_tags() for semantic generation.

func get_name() -> String:
	return "Layered (Example Only)"

func get_description() -> String:
	return "EXAMPLE: Simple demo of semantic tagging. Use WfcStrategyBuilding for production."

func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
	# Fill the entire volume
	return true

func get_cell_tags(position: Vector3i, grid_size: Vector3i) -> Array[String]:
	"""Assign semantic tags based on position in the building"""
	var tags: Array[String] = []
	
	# Ground level (y=0)
	if position.y == 0:
		tags.append("floor")
		
		# Check if it's also an exterior wall
		if _is_perimeter(position, grid_size):
			tags.append("wall")
			tags.append("exterior")
		else:
			tags.append("interior")
	
	# Top level (roof)
	elif position.y == grid_size.y - 1:
		tags.append("roof")
	
	# Middle floors
	else:
		# Check if exterior perimeter
		if _is_perimeter(position, grid_size):
			tags.append("wall")
			tags.append("exterior")
		else:
			# Interior space
			tags.append("interior")
			tags.append("floor")
	
	return tags

func _is_perimeter(position: Vector3i, grid_size: Vector3i) -> bool:
	"""Check if position is on the outer perimeter (x or z edges)"""
	return (position.x == 0 or position.x == grid_size.x - 1 or
	        position.z == 0 or position.z == grid_size.z - 1)


func get_options() -> Control:
	"""Layered strategy has no configurable options - it's a simple example"""
	var label = Label.new()
	label.text = "This is an EXAMPLE strategy for learning.\n\nNo configuration needed.\nUse WfcStrategyBuilding for production use."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
