extends GdUnitTestSuite
## The valley scene loads, builds its town and herd, and plays the shot.

const SCENE := "res://scenes/valley.tscn"


func test_the_valley_scene_builds_and_plays_the_shot() -> void:
	var valley: Valley = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(valley)
	for frame: int in 5:
		await get_tree().process_frame

	assert_int(valley.find_children("*", "OmniLight3D", true, false).size()).is_equal(8)
	assert_int(valley.get_node("Herd").get_child_count()).is_equal(6)
	var camera := valley.get_node("DuskCamera") as DuskCamera
	assert_float(camera.elapsed()).is_greater(0.0)
