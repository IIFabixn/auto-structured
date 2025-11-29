@tool
class_name WfcInternalFallbackFactory

const Tile = preload("res://addons/auto_structured/core/tile.gd")

static func create_fallback_tile() -> Tile:
	"""Create the lightweight internal fallback tile used by the solver.

	This tile acts as a breathable "air" voxel that can connect to anything. It keeps
	contradictions recoverable without forcing authors to add their own empty tile to
	every library. The builder/grid both rely on the same helper so the fallback stays
	consistent regardless of which pipeline is active.
	"""
	var tile := Tile.new()
	tile.name = "Internal Air Tile"
	tile.size = Vector3i.ONE
	tile.weight = 0.01
	tile.tags = ["__auto_structured_internal__"]
	tile.rotation_symmetry = Tile.RotationSymmetry.QUARTER
	tile.requirements = []
	tile.ensure_all_sockets()
	tile.set_meta("auto_structured_internal_fallback", true)
	return tile
