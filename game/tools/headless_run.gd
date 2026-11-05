class_name HeadlessRun
extends RefCounted
## One seeded run with no window: simulate, then write its telemetry file.

const SETTINGS := {
	"valley": "braided",
	"herd_personality": "steady",
	"modifier": null,
	"bot_strategy": "none",
}
const DEFAULT_SEASONS := 5


## The options in the runner's command-line arguments, or {} if they are not
## usable.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var options := {"seasons": DEFAULT_SEASONS, "plan": "", "valley": SETTINGS["valley"]}
	if args.size() % 2 != 0:
		return {}
	for index: int in range(0, args.size(), 2):
		var flag := args[index]
		var value := args[index + 1]
		if flag in ["--seed", "--seasons"] and value.is_valid_int():
			options[flag.trim_prefix("--")] = value.to_int()
		elif flag in ["--out", "--plan", "--valley"]:
			options[flag.trim_prefix("--")] = value
		else:
			return {}
	if not (options.has("seed") and options.has("out")) or options["seasons"] < 1:
		return {}
	return options


## Runs `seasons` seasons from `run_seed` and writes the telemetry to
## `out_path`. `plan_id` names a scripted plan in game/data/plans, or "" for
## no commands. `valley_id` names a valley in game/data/valleys. Returns OK or
## the error that stopped it. `rule_folders` is only overridden by tests.
static func run(
	run_seed: int,
	seasons: int,
	out_path: String,
	rule_folders: PackedStringArray = RulesVersion.RULE_FOLDERS,
	plan_id: String = "",
	valley_id: String = SETTINGS["valley"]
) -> Error:
	var rules_version := RulesVersion.compute(rule_folders)
	if rules_version.is_empty():
		return ERR_FILE_NOT_FOUND
	var setup := GameData.load_setup(valley_id, SETTINGS["herd_personality"])
	if setup == null:
		return ERR_INVALID_DATA
	var plan := {}
	if plan_id != "":
		plan = GameData.load_plan(plan_id)
		if plan.is_empty():
			return ERR_INVALID_DATA
	var settings := SETTINGS.duplicate()
	settings["valley"] = valley_id
	settings["seasons"] = seasons
	settings["bot_strategy"] = plan_id if plan_id != "" else "none"
	var season_run := SeasonRun.new(setup, RandomStreams.new(run_seed))
	var events := season_run.run(seasons, plan)
	var file_lines := TelemetryWriter.lines(
		rules_version, run_seed, settings, events, {"money": season_run.state.money}
	)
	return TelemetryWriter.write(out_path, file_lines)
