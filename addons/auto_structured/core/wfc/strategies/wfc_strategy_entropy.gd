@tool
class_name WfcEntropyStrategy extends WfcSolveStrategy
## Default entropy-based selection that defers to the grid's min-heap.

func get_id() -> String:
	return "entropy"

func get_display_name() -> String:
	return "Entropy (default)"
