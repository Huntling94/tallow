extends GdUnitTestSuite
## ADR-0002, rule 3: one stream per system, seeded from the run seed and a
## fixed hash of the system's name.


func test_the_name_hash_is_fnv_1a_64() -> void:
	# Reference values from the published FNV-1a 64-bit algorithm, as signed integers.
	assert_int(RandomStreams.fnv1a_64("")).is_equal(-3750763034362895579)
	assert_int(RandomStreams.fnv1a_64("a")).is_equal(-5808556873153909620)
	assert_int(RandomStreams.fnv1a_64("herd")).is_equal(742531866336319096)


func test_the_same_seed_and_system_give_the_same_numbers() -> void:
	var first := RandomStreams.new(42).for_system("herd")
	var second := RandomStreams.new(42).for_system("herd")
	for draw: int in 20:
		assert_int(first.randi()).is_equal(second.randi())


func test_different_systems_and_seeds_give_different_streams() -> void:
	var herd := RandomStreams.new(42).for_system("herd").randi()
	assert_int(RandomStreams.new(42).for_system("routes").randi()).is_not_equal(herd)
	assert_int(RandomStreams.new(43).for_system("herd").randi()).is_not_equal(herd)
