extends GdUnitTestSuite
## Spec 0037, AC4: over many bands, each route is chosen about as often as the
## model says. Seeds are fixed, so the test gives the same answer every run.

const SEEDS := 100
const SEASONS_PER_SEED := 45
const TOLERANCE := 0.015


func test_route_shares_match_the_model_over_20000_bands() -> void:
	var setup := GameData.load_setup("grey_box", "steady")
	var graph := setup.graph
	var herd := setup.herd
	var expected := RouteChoice.probabilities_ppm(RouteChoice.utilities(graph, herd))
	var counts := {}
	var bands := 0
	for run_seed: int in range(1, SEEDS + 1):
		var events := SeasonRun.new(setup, RandomStreams.new(run_seed)).run(SEASONS_PER_SEED, {})
		for event: Dictionary in events:
			if event["type"] == "route_chosen":
				counts[event["route"]] = counts.get(event["route"], 0) + 1
				bands += 1
	assert_int(bands).is_greater_equal(20000)
	for index: int in graph.route_ids.size():
		var share := float(counts.get(graph.route_ids[index], 0)) / bands
		assert_float(share).is_equal_approx(expected[index] / 1e6, TOLERANCE)
