# Fixture for test_sim_boundary.gd: line 6 breaks the wall-clock rule.
extends RefCounted


func now() -> int:
	return Time.get_ticks_msec()
