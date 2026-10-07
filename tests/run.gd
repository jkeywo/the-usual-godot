extends SceneTree


func _initialize() -> void:
	var suite := SimulationTests.new()
	var result := suite.run()
	print(JSON.stringify(result, "  "))
	quit(0 if result.failures.is_empty() and result.missing_source_tests.is_empty() else 1)
