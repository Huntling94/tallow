class_name RandomStreams
extends RefCounted
## One random stream per system, each seeded from the run seed and a fixed
## hash of the system's name (ADR-0002, rule 3). Adding a system never
## changes the numbers another system draws.

const FNV_OFFSET := -3750763034362895579  # 0xcbf29ce484222325 as a signed 64-bit integer
const FNV_PRIME := 1099511628211  # 0x100000001b3

var _run_seed: int


func _init(run_seed: int) -> void:
	_run_seed = run_seed


## A new generator for the named system. Same seed and name, same numbers.
func for_system(system: String) -> RandomNumberGenerator:
	var stream := RandomNumberGenerator.new()
	stream.seed = _run_seed ^ fnv1a_64(system)
	return stream


## FNV-1a 64-bit hash of the UTF-8 bytes of `text`, as a signed integer.
## Written here rather than using String.hash(), which may change between
## Godot versions. Multiplication wraps at 64 bits, as the algorithm expects.
static func fnv1a_64(text: String) -> int:
	var hash_value := FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		hash_value = (hash_value ^ byte) * FNV_PRIME
	return hash_value
