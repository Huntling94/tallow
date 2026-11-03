extends GdUnitTestSuite
## ADR-0002: simulation code must not reach scenes, rendering, the wall clock,
## unseeded randomness, files or input.

const FIXTURES := "res://tests/fixtures/sim_boundary"


func test_the_simulation_folder_follows_the_boundary_rules() -> void:
	assert_array(Array(SimBoundary.scan_sim_folder())).is_empty()


func test_folder_scan_finds_bad_files_in_subfolders() -> void:
	var violations := SimBoundary.scan_sim_folder(FIXTURES)
	assert_array(Array(violations)).contains_exactly(
		["%s/nested/bad_clock.gd line 6: wall-clock time" % FIXTURES]
	)


func test_folder_scan_of_a_missing_folder_is_empty() -> void:
	assert_array(Array(SimBoundary.scan_sim_folder("res://tests/no_such_folder"))).is_empty()


func test_plain_simulation_code_has_no_violations() -> void:
	var source := """class_name Herd
extends RefCounted
var _rng: RandomNumberGenerator
func step(tick: int) -> int:
	_rng.seed = 7
	return _rng.randi_range(0, tick) + int(_rng.randf() * 2.0)
"""
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_each_forbidden_reference_is_reported() -> void:
	var cases := {
		"extends Node": "scene or node type",
		"var a: Node2D": "scene or node type",
		"var b: Node3D": "scene or node type",
		"var c: Control": "scene or node type",
		"var d: CanvasItem": "scene or node type",
		"var e: Viewport": "scene or node type",
		"var f: SceneTree": "scene or node type",
		"var root := get_tree().root": "scene tree access",
		"var g := MeshInstance3D.new()": "rendering",
		"var h: Camera3D": "rendering",
		"RenderingServer.force_draw()": "rendering",
		"var i: Sprite2D": "rendering",
		"var j: Sprite3D": "rendering",
		"var now := Time.get_ticks_msec()": "wall-clock time",
		"var ms := OS.get_ticks_msec()": "wall-clock time",
		"var frame := Engine.get_physics_frames()": "frame counter",
		"var tick := Engine.get_process_frames()": "frame counter",
		"var k := randi()": "unseeded randomness",
		"var l := randf()": "unseeded randomness",
		"var m := randfn(0.0, 1.0)": "unseeded randomness",
		"var n := randi_range(1, 6)": "unseeded randomness",
		"var o := randf_range(0.0, 1.0)": "unseeded randomness",
		"randomize()": "unseeded randomness",
		"seed(42)": "unseeded randomness",
		"var p := rand_from_seed(42)": "unseeded randomness",
		"_rng.randomize()": "unseeded randomness",
		"var q := RandomNumberGenerator.new()": "unseeded randomness",
		"herd.shuffle()": "unseeded randomness",
		"var r = herd.pick_random()": "unseeded randomness",
		'var s = load("res://data/herd.json")': "resource loading",
		'const T = preload("res://data/herd.json")': "resource loading",
		"var u := ResourceLoader.exists(path)": "file or resource access",
		"var v := FileAccess.open(path, FileAccess.READ)": "file or resource access",
		"var w := DirAccess.open(path)": "file or resource access",
		'if Input.is_action_pressed("fire"):': "input",
	}
	for line: String in cases:
		var reported := ", ".join(SimBoundary.find_violations(line))
		assert_str(reported).override_failure_message(line).contains(cases[line])


func test_comments_are_ignored() -> void:
	var source := "# Never call Time.get_ticks_msec() or randi() here.\nvar x := 1"
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_violations_name_the_line() -> void:
	var source := "var a := 1\nvar b := randf()"
	assert_str(SimBoundary.find_violations(source)[0]).starts_with("line 2:")
