extends SceneTree

const TestTileRotation = preload("res://addons/auto_structured/tests/test_tile_rotation.gd")

func _initialize() -> void:
	print("Running TileRotation tests only...")
	var test = TestTileRotation.new()
	test.run_all_tests()
	
	if test.tests_failed == 0:
		print("\n✓ ALL ROTATION TESTS PASSED")
		quit(0)
	else:
		print("\n✗ SOME ROTATION TESTS FAILED")
		quit(1)
