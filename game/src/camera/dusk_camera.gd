class_name DuskCamera
extends Camera3D
## The dusk cold open: a scripted shot that starts low in the valley, looking
## up at the herd against the sunset, then rises back over the town and
## settles into the angled command view. Press R or click to replay.

signal shot_finished

const DURATION := 9.0

## Camera positions along the shot, start to end.
const POSITIONS: Array[Vector3] = [
	Vector3(10.0, 3.5, -10.0),
	Vector3(34.0, 26.0, 70.0),
	Vector3(0.0, 80.0, 175.0),
]
## The point the camera looks at for each position above.
const TARGETS: Array[Vector3] = [
	Vector3(0.0, 14.0, -120.0),
	Vector3(0.0, 4.0, -70.0),
	Vector3(0.0, 0.0, -30.0),
]

var _time := 0.0
var _finished := false


func _ready() -> void:
	replay()


func _process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	global_transform = pose_at(_time)
	if _time >= DURATION:
		_finished = true
		shot_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if (key and key.pressed and key.keycode == KEY_R) or (click and click.pressed):
		replay()


func replay() -> void:
	_time = 0.0
	_finished = false
	global_transform = pose_at(0.0)


## Seconds into the shot, from 0 to DURATION.
func elapsed() -> float:
	return minf(_time, DURATION)


## The camera's transform `time` seconds into the shot. Holds the first pose
## before the start and the last pose after the end.
static func pose_at(time: float) -> Transform3D:
	var progress := smoothstep(0.0, DURATION, time)
	var segments := POSITIONS.size() - 1
	var index := mini(int(progress * segments), segments - 1)
	var weight := progress * segments - index
	var spot := _along(POSITIONS, index, weight)
	var target := _along(TARGETS, index, weight)
	return Transform3D(Basis.IDENTITY, spot).looking_at(target, Vector3.UP)


static func _along(points: Array[Vector3], index: int, weight: float) -> Vector3:
	var before := points[maxi(index - 1, 0)]
	var after := points[mini(index + 2, points.size() - 1)]
	return points[index].cubic_interpolate(points[index + 1], before, after, weight)
