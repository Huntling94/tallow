class_name Valley
extends Node3D
## A grey-box valley at dusk, built in code: terrain, a walled town with its
## lamps and the Lamphouse, and a few beasts walking down from the far end.
## Purely visual. Nothing here reads or changes simulation state yet.
##
## The valley runs along the z axis: the herd enters at the far end (-z),
## the town sits near the other end (+z), and the sun sets behind the herd.

const SIZE_X := 720.0
const Z_FAR := -560.0
const Z_NEAR := 200.0
const GRID_STEP := 4.0
const TOWN_CENTRE := Vector3(0.0, 0.0, 70.0)
const TOWN_RADIUS := 26.0
const BEAST_SPEED := 1.6
const LAMP_ENERGY := 4.0
const LAMPHOUSE_ENERGY := 10.0

## When the lamps start and finish coming on, in seconds into the shot.
const LAMPS_ON_FROM := 2.5
const LAMPS_ON_UNTIL := 6.5
## Sun elevation in degrees at the start and end of the shot.
const SUN_START := 7.0
const SUN_END := 0.5
## Sun brightness at the start and end of the shot.
const SUN_ENERGY_START := 1.6
const SUN_ENERGY_END := 0.35

const GROUND_COLOR := Color(0.27, 0.25, 0.23)
const BUILDING_COLOR := Color(0.55, 0.52, 0.48)
const WALL_COLOR := Color(0.42, 0.38, 0.33)
const BEAST_COLOR := Color(0.07, 0.06, 0.06)
const LAMP_COLOR := Color(1.0, 0.72, 0.38)

@export var layout_seed := 11

var _lamps: Array[OmniLight3D] = []
var _beasts: Array[Node3D] = []
var _noise := FastNoiseLite.new()

@onready var _camera: DuskCamera = $DuskCamera
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_noise.seed = layout_seed
	_noise.frequency = 0.012
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	add_child(_build_terrain())
	_build_town(rng)
	_build_beasts(rng)


func _process(delta: float) -> void:
	var time := _camera.elapsed()
	var progress := time / DuskCamera.DURATION
	var elevation := lerpf(SUN_START, SUN_END, progress)
	_sun.light_energy = lerpf(SUN_ENERGY_START, SUN_ENERGY_END, progress)
	# Facing +z, so the sun sets behind the herd as seen from the town.
	_sun.basis = Basis.from_euler(Vector3(deg_to_rad(-elevation), PI, 0.0))
	for index: int in _lamps.size():
		var lamp := _lamps[index]
		var full := LAMPHOUSE_ENERGY if index == 0 else LAMP_ENERGY
		lamp.light_energy = full * lamp_level(time, index, _lamps.size())
	for beast: Node3D in _beasts:
		beast.position.z += BEAST_SPEED * delta
		beast.position.y = height_at(beast.position.x, beast.position.z)


## How far lamp `index` of `count` has come on, from 0 to 1, `time` seconds
## into the shot. The Lamphouse (index 0) lights first, then the rest in turn.
static func lamp_level(time: float, index: int, count: int) -> float:
	var span := LAMPS_ON_UNTIL - LAMPS_ON_FROM
	var start := LAMPS_ON_FROM + span * 0.7 * index / maxf(count - 1, 1)
	return smoothstep(start, start + span * 0.3, time)


## Ground height at (x, z): a flat valley floor rising to ridges either side.
func height_at(x: float, z: float) -> float:
	var slope := smoothstep(28.0, 140.0, absf(x)) + smoothstep(160.0, 360.0, absf(x))
	var far_rise := 18.0 * smoothstep(-130.0, -240.0, z) + 60.0 * smoothstep(-260.0, -520.0, z)
	var bumps := (1.0 + 7.0 * slope) * _noise.get_noise_2d(x, z)
	return 46.0 * slope + far_rise + bumps


func _ground(spot: Vector3) -> float:
	return height_at(spot.x, spot.z)


func _build_terrain() -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := int(SIZE_X / GRID_STEP)
	var rows := int((Z_NEAR - Z_FAR) / GRID_STEP)
	for row: int in rows + 1:
		for column: int in columns + 1:
			var x := -SIZE_X / 2.0 + column * GRID_STEP
			var z := Z_FAR + row * GRID_STEP
			surface.add_vertex(Vector3(x, height_at(x, z), z))
	for row: int in rows:
		for column: int in columns:
			var corner := row * (columns + 1) + column
			var below := corner + columns + 1
			for vertex: int in [corner, corner + 1, below, corner + 1, below + 1, below]:
				surface.add_index(vertex)
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = surface.commit()
	terrain.material_override = _material(GROUND_COLOR)
	return terrain


func _build_town(rng: RandomNumberGenerator) -> void:
	var town := Node3D.new()
	town.name = "Town"
	add_child(town)

	var lamphouse := _box(Vector3(7.0, 16.0, 7.0), BUILDING_COLOR)
	lamphouse.name = "Lamphouse"
	lamphouse.position = TOWN_CENTRE + Vector3(0.0, _ground(TOWN_CENTRE) + 8.0, 0.0)
	town.add_child(lamphouse)
	_add_lamp(town, lamphouse.position + Vector3(0.0, 10.0, 0.0), 40.0)

	for index: int in 14:
		var angle := TAU * index / 14.0 + rng.randf_range(-0.15, 0.15)
		var distance := rng.randf_range(9.0, TOWN_RADIUS - 6.0)
		var size := Vector3(
			rng.randf_range(4.0, 7.0), rng.randf_range(3.0, 7.0), rng.randf_range(4.0, 8.0)
		)
		var building := _box(size, BUILDING_COLOR)
		building.position = TOWN_CENTRE + Vector3(cos(angle), 0.0, sin(angle)) * distance
		building.position.y = _ground(building.position) + size.y / 2.0
		building.rotation.y = -angle
		town.add_child(building)

	for index: int in 7:
		var angle := TAU * (index + 0.5) / 7.0
		var spot := TOWN_CENTRE + Vector3(cos(angle), 0.0, sin(angle)) * (TOWN_RADIUS - 3.0)
		_add_lamp(town, spot + Vector3(0.0, _ground(spot) + 4.0, 0.0), 16.0)

	var segments := 36
	for index: int in segments:
		var angle := TAU * index / segments
		var wall := _box(Vector3(TAU * TOWN_RADIUS / segments + 0.4, 5.0, 1.2), WALL_COLOR)
		wall.position = TOWN_CENTRE + Vector3(cos(angle), 0.0, sin(angle)) * TOWN_RADIUS
		wall.position.y = _ground(wall.position) + 2.5
		wall.rotation.y = PI / 2.0 - angle
		town.add_child(wall)


func _build_beasts(rng: RandomNumberGenerator) -> void:
	var herd := Node3D.new()
	herd.name = "Herd"
	add_child(herd)
	for index: int in 6:
		var beast := Node3D.new()
		var body := _box(Vector3(6.0, 7.0, 14.0), BEAST_COLOR)
		body.position.y = 8.0
		var head := _box(Vector3(3.5, 4.0, 5.0), BEAST_COLOR)
		head.position = Vector3(0.0, 10.0, 9.0)
		beast.add_child(body)
		beast.add_child(head)
		for leg_x: float in [-2.2, 2.2]:
			for leg_z: float in [-5.0, 5.0]:
				var leg := _box(Vector3(1.6, 6.0, 1.6), BEAST_COLOR)
				leg.position = Vector3(leg_x, 3.0, leg_z)
				beast.add_child(leg)
		beast.position.x = rng.randf_range(-24.0, 24.0)
		beast.position.z = -125.0 + index * 12.0 + rng.randf_range(-4.0, 4.0)
		beast.scale = Vector3.ONE * rng.randf_range(1.6, 2.4)
		herd.add_child(beast)
		_beasts.append(beast)


func _add_lamp(parent: Node3D, spot: Vector3, reach: float) -> void:
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	bulb.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOR
	glow.emission_energy_multiplier = 6.0
	bulb.material_override = glow
	bulb.position = spot
	parent.add_child(bulb)

	var lamp := OmniLight3D.new()
	lamp.light_color = LAMP_COLOR
	lamp.light_energy = 0.0
	lamp.omni_range = reach
	lamp.position = spot
	parent.add_child(lamp)
	_lamps.append(lamp)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = _material(color)
	return box


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
