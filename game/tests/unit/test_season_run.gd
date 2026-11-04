extends GdUnitTestSuite
## The stub season run: one herd arrival and one season end per season, in order.


func test_each_season_has_a_herd_arrival_then_a_season_end() -> void:
	var events := SeasonRun.new().run(42, 3)
	var types: Array[String] = []
	for event: Dictionary in events:
		types.append(event["type"])
	(
		assert_array(types)
		. is_equal(
			[
				"herd_arrived",
				"season_ended",
				"herd_arrived",
				"season_ended",
				"herd_arrived",
				"season_ended",
			]
		)
	)


func test_events_are_ordered_by_season_tick_and_seq() -> void:
	var events := SeasonRun.new().run(42, 4)
	for index: int in range(1, events.size()):
		var before: Dictionary = events[index - 1]
		var after: Dictionary = events[index]
		var key_before := [before["season"], before["tick"], before["seq"]]
		var key_after := [after["season"], after["tick"], after["seq"]]
		assert_bool(_less(key_before, key_after)).is_true()


func test_herd_sizes_are_in_range_and_follow_the_seed() -> void:
	var sizes_42 := _sizes(SeasonRun.new().run(42, 6))
	for size: int in sizes_42:
		assert_int(size).is_between(SeasonRun.HERD_MIN, SeasonRun.HERD_MAX)
	assert_array(_sizes(SeasonRun.new().run(42, 6))).is_equal(sizes_42)
	assert_array(_sizes(SeasonRun.new().run(7, 6))).is_not_equal(sizes_42)


func _sizes(events: Array[Dictionary]) -> Array[int]:
	var sizes: Array[int] = []
	for event: Dictionary in events:
		if event["type"] == "herd_arrived":
			sizes.append(event["herd_size"])
	return sizes


func _less(left: Array, right: Array) -> bool:
	for index: int in left.size():
		if left[index] != right[index]:
			return left[index] < right[index]
	return false
