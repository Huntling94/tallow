extends GdUnitTestSuite
## The dusk cold open: the camera's path and the order the lamps come on.


func test_the_shot_starts_at_the_first_position() -> void:
	assert_vector(DuskCamera.pose_at(0.0).origin).is_equal_approx(
		DuskCamera.POSITIONS[0], Vector3.ONE * 0.001
	)


func test_the_shot_ends_in_the_command_view_looking_at_its_target() -> void:
	var pose := DuskCamera.pose_at(DuskCamera.DURATION)
	var looking := -pose.basis.z
	var wanted := (DuskCamera.TARGETS[-1] - DuskCamera.POSITIONS[-1]).normalized()
	assert_vector(pose.origin).is_equal_approx(DuskCamera.POSITIONS[-1], Vector3.ONE * 0.001)
	assert_vector(looking).is_equal_approx(wanted, Vector3.ONE * 0.001)


func test_the_shot_holds_its_end_pose_afterwards_and_its_start_pose_before() -> void:
	(
		assert_bool(
			DuskCamera.pose_at(DuskCamera.DURATION * 3.0).is_equal_approx(
				DuskCamera.pose_at(DuskCamera.DURATION)
			)
		)
		. is_true()
	)
	assert_bool(DuskCamera.pose_at(-1.0).is_equal_approx(DuskCamera.pose_at(0.0))).is_true()


func test_the_camera_never_jumps_between_frames() -> void:
	var step := 1.0 / 60.0
	var time := 0.0
	var previous := DuskCamera.pose_at(0.0).origin
	while time < DuskCamera.DURATION:
		time += step
		var current := DuskCamera.pose_at(time).origin
		assert_float(current.distance_to(previous)).is_less(1.5)
		previous = current


func test_lamps_are_dark_at_the_start_and_all_lit_by_the_end() -> void:
	for index: int in 8:
		assert_float(Valley.lamp_level(0.0, index, 8)).is_equal(0.0)
		assert_float(Valley.lamp_level(Valley.LAMPS_ON_UNTIL, index, 8)).is_equal(1.0)


func test_the_lamphouse_lights_before_the_other_lamps() -> void:
	var time := Valley.LAMPS_ON_FROM + 0.8
	assert_float(Valley.lamp_level(time, 0, 8)).is_greater(Valley.lamp_level(time, 1, 8))
	assert_float(Valley.lamp_level(time, 1, 8)).is_greater_equal(Valley.lamp_level(time, 7, 8))
