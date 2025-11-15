extends SceneTree

const WfcSolverTests := preload("res://addons/auto_structured/tests/test_wfc_solver.gd")
const WfcStrategyTests := preload("res://addons/auto_structured/tests/test_wfc_strategies.gd")

func _initialize() -> void:
	print("Running auto_structured test suite...\n")
	var solver_suite := WfcSolverTests.new()
	var solver_results := solver_suite.run_all()

	var strategy_suite := WfcStrategyTests.new()
	var strategy_results := strategy_suite.run_all()

	var total: int = int(solver_results["total"]) + int(strategy_results["total"])
	var failures: Array = []
	failures.append_array(solver_results["failures"])
	failures.append_array(strategy_results["failures"])

	if failures.is_empty():
		print("\nAll %d tests passed!" % total)
		quit(0)
	else:
		print("\n%d/%d tests failed:" % [failures.size(), total])
		for failure in failures:
			print("  - ", failure)
		quit(1)
