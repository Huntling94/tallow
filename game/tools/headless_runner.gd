extends SceneTree
## Command-line entry point for the headless runner.
##
## godot --headless --path game -s res://tools/headless_runner.gd -- \
##     --seed 42 --out ../telemetry/run_42.jsonl [--seasons 5] [--plan demo]
##     [--valley grey_box]
##
## A relative --out path is taken from the game/ folder. --seasons defaults to
## 5, the M1 mini-run. --plan names a scripted plan in game/data/plans.
## --valley names a valley in game/data/valleys; `chokepoints` needs grey_box,
## because braided closes the segments it builds on.

const USAGE := "usage: -- --seed <int> --out <file> [--seasons <int>] [--plan <id>] [--valley <id>]"


func _initialize() -> void:
	var options := HeadlessRun.parse_args(OS.get_cmdline_user_args())
	if options.is_empty():
		printerr(USAGE)
		quit(2)
		return
	var out_path: String = options["out"]
	if out_path.is_relative_path():
		out_path = ProjectSettings.globalize_path("res://").path_join(out_path).simplify_path()
	var result := HeadlessRun.run(
		options["seed"],
		options["seasons"],
		out_path,
		RulesVersion.RULE_FOLDERS,
		options["plan"],
		options["valley"]
	)
	if result != OK:
		printerr("Run failed: %s" % error_string(result))
		quit(1)
		return
	print("Wrote %s" % out_path)
	quit(0)
