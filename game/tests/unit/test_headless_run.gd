extends GdUnitTestSuite
## Spec 0027: the headless runner writes a telemetry file in the ADR-0003
## shape, the same seed gives the same bytes, and the rules version follows
## the simulation code and data.

const OUT := "user://test_headless_run"


func before_test() -> void:
	_remove(OUT)


func after_test() -> void:
	_remove(OUT)


func test_a_run_writes_header_events_and_summary() -> void:
	var records := _run(42, 3, "a.jsonl")
	assert_int(records.size()).is_equal(8)
	assert_str(records[0]["type"]).is_equal("run_start")
	assert_int(int(records[0]["seed"])).is_equal(42)
	assert_str(records[-1]["type"]).is_equal("run_end")
	assert_int(int(records[-1]["seasons"])).is_equal(3)
	for record: Dictionary in records.slice(1, -1):
		assert_array(["herd_arrived", "season_ended"]).contains([record["type"]])


func test_the_same_seed_gives_byte_identical_files() -> void:
	_run(42, 3, "a.jsonl")
	_run(42, 3, "b.jsonl")
	var first := FileAccess.get_file_as_bytes(OUT.path_join("a.jsonl"))
	assert_int(first.size()).is_greater(0)
	assert_bool(first == FileAccess.get_file_as_bytes(OUT.path_join("b.jsonl"))).is_true()


func test_a_different_seed_gives_different_herds() -> void:
	assert_array(_sizes(_run(42, 6, "a.jsonl"))).is_not_equal(_sizes(_run(43, 6, "b.jsonl")))


func test_every_record_carries_the_schema_version_and_run_id_in_order() -> void:
	var records := _run(42, 4, "a.jsonl")
	var run_id: String = records[0]["run_id"]
	var previous := [-1, -1, -1]
	for record: Dictionary in records:
		assert_int(int(record["schema_version"])).is_equal(1)
		assert_str(record["run_id"]).is_equal(run_id)
	for record: Dictionary in records.slice(1, -1):
		var key := [record["season"], record["tick"], record["seq"]]
		assert_bool(key > previous).is_true()
		previous = key


func test_the_rules_version_changes_with_any_rules_file() -> void:
	var folder := OUT.path_join("rules")
	_write(folder.path_join("herd.gd"), "var size := 8\n")
	_write(folder.path_join("nested/route.gd"), "var width := 2\n")
	var before := RulesVersion.compute([folder])
	assert_str(RulesVersion.compute([folder])).is_equal(before)
	_write(folder.path_join("nested/route.gd"), "var width := 3\n")
	assert_str(RulesVersion.compute([folder])).is_not_equal(before)


func test_line_endings_do_not_change_the_rules_version() -> void:
	var folder := OUT.path_join("rules")
	_write(folder.path_join("herd.gd"), "var size := 8\nvar speed := 2\n")
	var unix := RulesVersion.compute([folder])
	_write(folder.path_join("herd.gd"), "var size := 8\r\nvar speed := 2\r\n")
	assert_str(RulesVersion.compute([folder])).is_equal(unix)


func test_the_run_id_follows_rules_version_seed_and_settings() -> void:
	var settings := {"valley": "grey_box"}
	var id := TelemetryWriter.run_id("abc", 42, settings)
	assert_str(TelemetryWriter.run_id("abc", 42, settings)).is_equal(id)
	assert_str(TelemetryWriter.run_id("abd", 42, settings)).is_not_equal(id)
	assert_str(TelemetryWriter.run_id("abc", 43, settings)).is_not_equal(id)
	assert_str(TelemetryWriter.run_id("abc", 42, {"valley": "other"})).is_not_equal(id)


func _run(run_seed: int, seasons: int, name: String) -> Array[Dictionary]:
	var path := OUT.path_join(name)
	assert_int(HeadlessRun.run(run_seed, seasons, path)).is_equal(OK)
	# JSON numbers parse back as floats in Godot, so the tests compare with int().
	var records: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	assert_bool(text.ends_with("\n")).is_true()
	for line: String in text.strip_edges(false, true).split("\n"):
		records.append(JSON.parse_string(line))
	return records


func _sizes(records: Array[Dictionary]) -> Array:
	return (
		records
		. filter(func(r: Dictionary) -> bool: return r["type"] == "herd_arrived")
		. map(func(r: Dictionary) -> int: return int(r["herd_size"]))
	)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(folder: String) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	for name: String in directory.get_files():
		directory.remove(name)
	for name: String in directory.get_directories():
		_remove(folder.path_join(name))
	DirAccess.remove_absolute(folder)
