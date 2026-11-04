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
## `out_path`. Returns OK or the error that stopped it.
static func run(run_seed: int, seasons: int, out_path: String) -> Error:
	var settings := SETTINGS.duplicate()
	settings["seasons"] = seasons
	var events := SeasonRun.new().run(run_seed, seasons)
	var file_lines := TelemetryWriter.lines(RulesVersion.compute(), run_seed, settings, events)
	return TelemetryWriter.write(out_path, file_lines)
