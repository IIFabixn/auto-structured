extends SceneTree

const TestWfcCell = preload("res://addons/auto_structured/tests/test_wfc_cell.gd")
const TestWfcGrid = preload("res://addons/auto_structured/tests/test_wfc_grid.gd")
const TestWfcSolver = preload("res://addons/auto_structured/tests/test_wfc_solver.gd")
const TestWfcHelper = preload("res://addons/auto_structured/tests/test_wfc_helper.gd")
const TestSocket = preload("res://addons/auto_structured/tests/test_socket.gd")
const TestSocketType = preload("res://addons/auto_structured/tests/test_socket_type.gd")
const TestTile = preload("res://addons/auto_structured/tests/test_tile.gd")
const TestModuleLibrary = preload("res://addons/auto_structured/tests/test_module_library.gd")
const TestMeshOutlineAnalyzer = preload("res://addons/auto_structured/tests/test_mesh_outline_analyzer.gd")
const TestSocketSuggestionBuilder = preload("res://addons/auto_structured/tests/test_socket_suggestion_builder.gd")

var total_tests_passed: int = 0
var total_tests_failed: int = 0
var test_suites_passed: int = 0
var test_suites_failed: int = 0

func _initialize() -> void:
	print("╔════════════════════════════════════════════════════╗")
	print("║    Auto-Structured WFC Test Suite                 ║")
	print("╚════════════════════════════════════════════════════╝")
	print("")
	var start_time = Time.get_ticks_msec()
	# Run all test suites
	run_test_suite("Socket", TestSocket)
	print("")
	run_test_suite("SocketType", TestSocketType)
	print("")
	run_test_suite("Tile", TestTile)
	print("")
	run_test_suite("ModuleLibrary", TestModuleLibrary)
	print("")
	run_test_suite("MeshOutlineAnalyzer", TestMeshOutlineAnalyzer)
	print("")
	run_test_suite("SocketSuggestionBuilder", TestSocketSuggestionBuilder)
	print("")
	run_test_suite("WfcCell", TestWfcCell)
	print("")
	run_test_suite("WfcGrid", TestWfcGrid)
	print("")
	run_test_suite("WfcSolver", TestWfcSolver)
	print("")
	run_test_suite("WfcHelper", TestWfcHelper)
	print("")
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	
	# Print final summary
	print("╔════════════════════════════════════════════════════╗")
	print("║              FINAL TEST SUMMARY                    ║")
	print("╚════════════════════════════════════════════════════╝")
	print("")
	print("  Test Suites:")
	print("    Passed: ", test_suites_passed)
	print("    Failed: ", test_suites_failed)
	print("    Total:  ", test_suites_passed + test_suites_failed)
	print("")
	print("  Individual Tests:")
	print("    Passed: ", total_tests_passed)
	print("    Failed: ", total_tests_failed)
	print("    Total:  ", total_tests_passed + total_tests_failed)
	print("")
	print("  Time Elapsed: ", elapsed_time, "ms")
	print("")
	
	if total_tests_failed == 0:
		print("  ✓ ✓ ✓  ALL TESTS PASSED  ✓ ✓ ✓")
		print("")
		quit(0)
	else:
		print("  ✗ ✗ ✗  SOME TESTS FAILED  ✗ ✗ ✗")
		print("")
		quit(1)

func run_test_suite(suite_name: String, test_class) -> void:
	print("┌────────────────────────────────────────────────────┐")
	print("│  Running: ", suite_name.rpad(39), "│")
	print("└────────────────────────────────────────────────────┘")
	print("")
	
	var test_instance = test_class.new()
	test_instance.run_all_tests()
	
	# Aggregate results
	total_tests_passed += test_instance.tests_passed
	total_tests_failed += test_instance.tests_failed
	
	if test_instance.tests_failed == 0:
		test_suites_passed += 1
	else:
		test_suites_failed += 1
