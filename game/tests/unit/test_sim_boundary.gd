extends GdUnitTestSuite
## ADR-0002: simulation code must not reach scenes, rendering, the wall clock,
## unseeded randomness or files.


func test_the_simulation_folder_follows_the_boundary_rules() -> void:
	assert_array(Array(SimBoundary.scan_sim_folder())).is_empty()


func test_plain_simulation_code_has_no_violations() -> void:
	var source := """class_name Herd
extends RefCounted
var _rng: RandomNumberGenerator
func step(tick: int) -> int:
	return _rng.randi_range(0, tick)
"""
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_each_forbidden_reference_is_reported() -> void:
	var cases := {
		"extends Node": "scene or node type",
		"var root := get_tree().root": "scene tree access",
		"var mesh := MeshInstance3D.new()": "rendering",
		"var now := Time.get_ticks_msec()": "wall-clock time",
		"var ms := OS.get_ticks_msec()": "wall-clock time",
		"var roll := randi()": "unseeded randomness",
		"randomize()": "unseeded randomness",
		'var data = load("res://data/herd.json")': "resource loading",
		"var file := FileAccess.open(path, FileAccess.READ)": "file or resource access",
		'if Input.is_action_pressed("fire"):': "input",
	}
	for line: String in cases:
		var violations := SimBoundary.find_violations(line)
		assert_int(violations.size()).override_failure_message(line).is_greater(0)
		assert_str(violations[0]).contains(cases[line])


func test_seeded_generator_methods_are_allowed() -> void:
	var source := "var roll := _rng.randf()\nvar pick := _rng.randi_range(1, 6)"
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_comments_are_ignored() -> void:
	var source := "# Never call Time.get_ticks_msec() or randi() here.\nvar x := 1"
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_violations_name_the_line() -> void:
	var source := "var a := 1\nvar b := randf()"
	assert_str(SimBoundary.find_violations(source)[0]).starts_with("line 2:")
