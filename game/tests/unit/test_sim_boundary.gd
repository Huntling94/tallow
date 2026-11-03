extends GdUnitTestSuite
## ADR-0002: simulation code must not reach scenes, nodes, resources, engine
## servers, the wall clock, unseeded randomness, files or input.

const FIXTURES := "res://tests/fixtures/sim_boundary"


func test_the_simulation_folder_exists_and_follows_the_boundary_rules() -> void:
	assert_bool(DirAccess.dir_exists_absolute(SimBoundary.SIM_DIR)).is_true()
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
var _rng := RandomNumberGenerator.new()
var _pattern := RegEx.new()
var _sizes: Array[int] = []
func step(tick: int) -> String:
	_rng.seed = 7
	var roll := _rng.randi_range(0, tick) + int(_rng.randf() * 2.0)
	return "tick %d roll %d" % [tick, roll]
"""
	assert_array(Array(SimBoundary.find_violations(source))).is_empty()


func test_each_forbidden_reference_is_reported() -> void:
	var cases := {
		"extends Node": "node type",
		"extends Timer": "node type Timer",
		"extends Area3D": "node type Area3D",
		"var a: Label": "node type Label",
		"var b: AnimationPlayer": "node type AnimationPlayer",
		"var c := MeshInstance3D.new()": "node type MeshInstance3D",
		"var d: Camera3D": "node type Camera3D",
		"var e: PackedScene": "resource type PackedScene",
		"var f: Texture2D": "resource type Texture2D",
		"var root := get_tree().root": "scene tree access",
		'var g := get_node("Herd")': "scene access",
		"var h := $Herd": "scene access",
		"var i := %Lamphouse": "scene access",
		"@onready var j := 1": "scene access",
		"@export var k := 1": "scene access",
		"var l := scene.instantiate()": "scene access",
		"RenderingServer.force_draw()": "engine server",
		"var now := Time.get_ticks_msec()": "wall-clock time",
		"var ms := OS.get_ticks_msec()": "wall-clock time",
		"var frame := Engine.get_physics_frames()": "frame counter",
		"var tick := Engine.get_process_frames()": "frame counter",
		"var m := randi()": "unseeded randomness",
		"var n := randf()": "unseeded randomness",
		"var o := randfn(0.0, 1.0)": "unseeded randomness",
		"var p := randi_range(1, 6)": "unseeded randomness",
		"var q := randf_range(0.0, 1.0)": "unseeded randomness",
		"randomize()": "unseeded randomness",
		"seed(42)": "unseeded randomness",
		"var r := rand_from_seed(42)": "unseeded randomness",
		"_rng.randomize()": "unseeded randomness",
		"herd.shuffle()": "unseeded randomness",
		"var s = herd.pick_random()": "unseeded randomness",
		'var t = load("res://data/herd.json")': "resource loading",
		'const U = preload("res://data/herd.json")': "resource loading",
		"var v := ResourceLoader.exists(path)": "file or resource access",
		"var w := FileAccess.open(path, FileAccess.READ)": "file or resource access",
		"var x := DirAccess.open(path)": "file or resource access",
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
