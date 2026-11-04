extends SceneTree
## Command-line entry point for the headless runner.
##
## godot --headless --path game -s res://tools/headless_runner.gd -- \
##     --seed 42 --seasons 3 --out ../telemetry/run_42.jsonl
##
## A relative --out path is taken from the game/ folder.

const USAGE := "usage: -- --seed <int> --seasons <int> --out <file>"


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	if options.is_empty():
		printerr(USAGE)
		quit(2)
		return
	var out_path: String = options["out"]
	if out_path.is_relative_path():
		out_path = ProjectSettings.globalize_path("res://").path_join(out_path).simplify_path()
	var result := HeadlessRun.run(options["seed"], options["seasons"], out_path)
	if result != OK:
		printerr("Run failed: %s" % error_string(result))
		quit(1)
		return
	print("Wrote %s" % out_path)
	quit(0)


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {}
	for index: int in range(0, args.size() - 1, 2):
		var flag := args[index]
		var value := args[index + 1]
		if flag in ["--seed", "--seasons"] and value.is_valid_int():
			options[flag.trim_prefix("--")] = value.to_int()
		elif flag == "--out":
			options["out"] = value
	if options.size() != 3 or args.size() != 6 or options["seasons"] < 1:
		return {}
	return options
