extends Node3D
## Cosmetic wildlife: no inventory, damage, or authoritative multiplayer state.
const MODELS: Dictionary = {
	"cat": preload("res://Adventure/animals/cat.glb"),
	"dog": preload("res://Adventure/animals/dog.glb"),
	"cow": preload("res://Adventure/animals/cow.glb")
}
var animator: AnimationPlayer
var species: String
var world: Node3D
var start: Vector2
var finish: Vector2
var clock: float = 0.0
var walk_duration: float
var heading: float
var stride_speed: float

func setup(kind: String, terrain: Node3D, a: Vector2, b: Vector2, offset: float) -> void:
	species = kind
	world = terrain
	start = a
	finish = b
	clock = offset
	var model: Node3D = MODELS[kind].instantiate()
	add_child(model)
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Walk stance is 75% of a cycle; speed matches the authored foot trajectory.
	stride_speed = {"cat": 0.22 / (1.1 * 0.75), "dog": 0.32 / (1.1 * 0.75), "cow": 0.43 / (1.6 * 0.75)}[kind]
	walk_duration = a.distance_to(b) / stride_speed
	heading = atan2(-(b.x-a.x), -(b.y-a.y))
	if animator:
		for clip: StringName in animator.get_animation_list():
			if clip != &"RESET": animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_process(0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	clock += delta
	var half_cycle: float = walk_duration + 6.0
	var phase: float = fposmod(clock, half_cycle * 2.0)
	var returning: bool = phase >= half_cycle
	var local_time: float = fposmod(phase, half_cycle)
	var moving: bool = local_time < walk_duration
	var from: Vector2 = finish if returning else start
	var to: Vector2 = start if returning else finish
	var p: Vector2 = from.lerp(to, minf(local_time / walk_duration, 1.0))
	position = Vector3(p.x, world.height_at(p), p.y)
	rotation.y = heading + (PI if returning else 0.0)
	if not moving:
		# Turn during the last second of the rest, never slide through a walking turn.
		rotation.y += PI * smoothstep(half_cycle - 1.0, half_cycle, local_time)
	var camera: Camera3D = get_viewport().get_camera_3d()
	visible = camera == null or global_position.distance_squared_to(camera.global_position) < 120.0 * 120.0
	if animator:
		animator.active = visible
		var clip: StringName = &"walk" if moving else (&"graze" if species == "cow" else &"sniff")
		if not moving and local_time > walk_duration + 4.0: clip = &"idle"
		if animator.current_animation != clip: animator.play(clip, 0.20)
