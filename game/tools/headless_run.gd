class_name HeadlessRun
extends RefCounted
## One seeded run with no window: simulate, then write its telemetry file.

const SETTINGS := {
	"valley": "grey_box",
	"herd_personality": "steady",
	"modifier": null,
	"bot_strategy": "none",
}


## Runs `seasons` seasons from `run_seed` and writes the telemetry to
## `out_path`. Returns OK or the error that stopped it. `rule_folders` is
## only overridden by tests.
static func run(
	run_seed: int,
	seasons: int,
	out_path: String,
	rule_folders: PackedStringArray = RulesVersion.RULE_FOLDERS
) -> Error:
	var rules_version := RulesVersion.compute(rule_folders)
	if rules_version.is_empty():
		return ERR_FILE_NOT_FOUND
	var graph := GameData.load_valley(SETTINGS["valley"])
	var herd := GameData.load_herd(SETTINGS["herd_personality"])
	if graph == null or herd == null:
		return ERR_INVALID_DATA
	var settings := SETTINGS.duplicate()
	settings["seasons"] = seasons
	var events := SeasonRun.new().run(RandomStreams.new(run_seed), graph, herd, seasons)
	var file_lines := TelemetryWriter.lines(rules_version, run_seed, settings, events)
	return TelemetryWriter.write(out_path, file_lines)
