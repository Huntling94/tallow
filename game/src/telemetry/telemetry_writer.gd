class_name TelemetryWriter
extends RefCounted
## Turns a run's settings and simulation events into a JSON Lines file in the
## ADR-0003 shape: a run header, one line per event, then a run summary. Keys
## are sorted and nothing comes from the wall clock, so the same run always
## gives the same bytes.

const SCHEMA_VERSION := 1


## First 16 hex characters of SHA-256 over the rules version, seed and
## settings, so the same run always gets the same id.
static func run_id(rules_version: String, run_seed: int, settings: Dictionary) -> String:
	var source := {"rules_version": rules_version, "seed": run_seed, "settings": settings}
	return JSON.stringify(source, "", true).sha256_text().substr(0, 16)


## The file's lines, without line endings. `summary` adds optional fields to
## the run_end record, such as the final money.
static func lines(
	rules_version: String,
	run_seed: int,
	settings: Dictionary,
	events: Array[Dictionary],
	summary: Dictionary = {}
) -> PackedStringArray:
	var id := run_id(rules_version, run_seed, settings)
	var records: Array[Dictionary] = [
		{
			"type": "run_start",
			"schema_version": SCHEMA_VERSION,
			"rules_version": rules_version,
			"run_id": id,
			"seed": run_seed,
			"settings": settings,
		}
	]
	var seasons := 0
	for event: Dictionary in events:
		var record := event.duplicate()
		record["schema_version"] = SCHEMA_VERSION
		record["run_id"] = id
		records.append(record)
		seasons = maxi(seasons, event["season"])
	var run_end := {
		"type": "run_end",
		"schema_version": SCHEMA_VERSION,
		"run_id": id,
		"outcome": "completed",
		"score": 0,
		"seasons": seasons,
	}
	run_end.merge(summary)
	records.append(run_end)
	var result: PackedStringArray = []
	for record: Dictionary in records:
		result.append(JSON.stringify(record, "", true))
	return result


## Writes `file_lines` to `path` with LF endings, creating its folder.
static func write(path: String, file_lines: PackedStringArray) -> Error:
	var made := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != OK:
		return made
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(file_lines) + "\n")
	file.close()
	return OK
