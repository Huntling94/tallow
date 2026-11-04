class_name SeasonRun
extends RefCounted
## A stub run of seasons, enough to prove the path from simulation to
## telemetry. Each season a herd of placeholder size arrives, then the season
## ends. Real herd rules replace this in M1.

const HERD_MIN := 8
const HERD_MAX := 24


## The events of a run of `seasons` seasons from `run_seed`, in order. Each
## event has `type`, `season`, `tick` and `seq` plus its own fields.
func run(run_seed: int, seasons: int) -> Array[Dictionary]:
	var herd := RandomStreams.new(run_seed).for_system("herd")
	var events: Array[Dictionary] = []
	for season: int in range(1, seasons + 1):
		var tick := 0
		(
			events
			. append(
				{
					"type": "herd_arrived",
					"season": season,
					"tick": tick,
					"seq": 0,
					"herd_size": herd.randi_range(HERD_MIN, HERD_MAX),
				}
			)
		)
		events.append({"type": "season_ended", "season": season, "tick": tick, "seq": 1})
	return events
