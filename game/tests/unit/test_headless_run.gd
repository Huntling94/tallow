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
	assert_str(records[0]["type"]).is_equal("run_start")
	assert_int(int(records[0]["seed"])).is_equal(42)
	assert_str(records[0]["settings"]["valley"]).is_equal("braided")
	assert_str(records[0]["settings"]["herd_personality"]).is_equal("steady")
	assert_str(records[-1]["type"]).is_equal("run_end")
	assert_int(int(records[-1]["seasons"])).is_equal(3)
	var types := {}
	for record: Dictionary in records.slice(1, -1):
		types[record["type"]] = types.get(record["type"], 0) + 1
	for type: String in ["season_started", "herd_arrived", "route_options", "season_ended"]:
		assert_int(types[type]).is_equal(3)
	assert_int(types["route_chosen"]).is_greater_equal(3)
	# With no defences, nothing is killed and every band breaches.
	assert_bool(types.has("beast_killed")).is_false()
	assert_int(types["breach"]).is_equal(types["route_chosen"])


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


func test_a_missing_rules_folder_gives_no_rules_version() -> void:
	var folder := OUT.path_join("rules")
	_write(folder.path_join("herd.gd"), "var size := 8\n")
	assert_str(RulesVersion.compute([folder, OUT.path_join("missing")])).is_empty()
	(
		assert_error(func() -> void: RulesVersion.compute([OUT.path_join("missing")]))
		. is_push_error("RulesVersion: cannot open %s" % OUT.path_join("missing"))
	)


func test_a_run_with_a_missing_rules_folder_writes_nothing() -> void:
	var path := OUT.path_join("a.jsonl")
	var result := HeadlessRun.run(42, 3, path, [OUT.path_join("missing")])
	assert_int(result).is_equal(ERR_FILE_NOT_FOUND)
	assert_bool(FileAccess.file_exists(path)).is_false()


func test_the_default_rules_folders_are_found() -> void:
	var version := RulesVersion.compute()
	assert_int(version.length()).is_equal(16)
	assert_bool(version.is_valid_hex_number()).is_true()


func test_markdown_files_do_not_change_the_rules_version() -> void:
	var folder := OUT.path_join("rules")
	_write(folder.path_join("herd.gd"), "var size := 8\n")
	_write(folder.path_join("README.md"), "Notes.\n")
	var before := RulesVersion.compute([folder])
	_write(folder.path_join("README.md"), "Different notes.\n")
	assert_str(RulesVersion.compute([folder])).is_equal(before)


func test_moving_a_file_between_folders_changes_the_rules_version() -> void:
	var first := OUT.path_join("rules_a")
	var second := OUT.path_join("rules_b")
	_write(first.path_join("herd.gd"), "var size := 8\n")
	_write(second.path_join("route.gd"), "var width := 2\n")
	var before := RulesVersion.compute([first, second])
	DirAccess.remove_absolute(first.path_join("herd.gd"))
	_write(second.path_join("herd.gd"), "var size := 8\n")
	assert_str(RulesVersion.compute([first, second])).is_not_equal(before)


func test_the_loader_counts_towards_the_rules_version() -> void:
	assert_array(Array(RulesVersion.RULE_FOLDERS)).contains(["res://src/loading"])


func test_a_run_with_the_demo_plan_builds_defences() -> void:
	var path := OUT.path_join("demo.jsonl")
	assert_int(HeadlessRun.run(42, 5, path, RulesVersion.RULE_FOLDERS, "demo")).is_equal(OK)
	var records: Array = []
	for line: String in FileAccess.get_file_as_string(path).strip_edges().split("\n"):
		records.append(JSON.parse_string(line))
	assert_str(records[0]["settings"]["bot_strategy"]).is_equal("demo")
	var applied := records.filter(
		func(r: Dictionary) -> bool: return r["type"] == "command_applied"
	)
	assert_int(applied.size()).is_equal(3)
	var summary: Dictionary = records[-1]
	assert_bool(summary.has("money")).is_true()


func test_a_run_with_the_chokepoints_plan_writes_harvests_at_schema_1() -> void:
	var path := OUT.path_join("chokepoints.jsonl")
	var folders := RulesVersion.RULE_FOLDERS
	assert_int(HeadlessRun.run(42, 5, path, folders, "chokepoints", "grey_box")).is_equal(OK)
	var harvests := 0
	var beasts := 0
	var rejected := 0
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	for line: String in lines:
		var record: Dictionary = JSON.parse_string(line)
		assert_int(int(record["schema_version"])).is_equal(1)
		if record["type"] == "run_start":
			assert_str(record["settings"]["valley"]).is_equal("grey_box")
		elif record["type"] == "harvest":
			harvests += 1
			beasts += int(record["beasts"])
		elif record["type"] == "command_rejected":
			rejected += 1
	assert_int(harvests).is_equal(5)
	assert_int(rejected).is_equal(0)
	assert_int(beasts).is_greater(0)


func test_an_unknown_valley_stops_the_run() -> void:
	var path := OUT.path_join("no_valley.jsonl")
	var folders := RulesVersion.RULE_FOLDERS
	assert_int(HeadlessRun.run(42, 1, path, folders, "", "no_such_valley")).is_equal(
		ERR_INVALID_DATA
	)


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
