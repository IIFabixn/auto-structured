extends SceneTree

const WfcSolverTests := preload("res://addons/auto_structured/tests/test_wfc_solver.gd")

func _run() -> void:
	print("Running auto_structured test suite...\n")
	var suite := WfcSolverTests.new()
	var results := suite.run_all()

	var failures: Array = results["failures"]
	var total: int = results["total"]

	if failures.is_empty():
		print("\nAll %d tests passed!" % total)
		quit(0)
	else:
		print("\n%d/%d tests failed:" % [failures.size(), total])
		for failure in failures:
			print("  - ", failure)
		quit(1)
