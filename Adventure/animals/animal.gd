extends Node3D
## Animation follows session time; health and rewards are owned by the host.
const MODELS: Dictionary = {
	"cat": preload("res://Adventure/animals/cat.glb"),
	"dog": preload("res://Adventure/animals/dog.glb"),
	"cow": preload("res://Adventure/animals/cow.glb")
}
## Real-world m/s for a tamed pet chasing its owner. stride_speed (below) is NOT this --
## it is back-solved from an authored short trip's fixed animation duration, so reusing it
## for following made pets crawl at a fraction of the player's 3.8-7.5 m/s walk/run speed.
## These are a little faster than the player's sprint (7.5) so a lagging pet can catch up.
const FOLLOW_SPEED: Dictionary = {"cat": 7.5, "dog": 8.5}
var animator: AnimationPlayer
var species: String
var world: Node3D
var start: Vector2
var finish: Vector2
var clock: float = 0.0
var walk_duration: float
var heading: float
var stride_speed: float
var animal_id: String
var phase_offset: float = 0.0
var health: int = 100
var hitbox: Area3D
var visual: Node3D
var hurt_time: float = 0.0
var tamed: bool = false
var owner_id: String = ""
var affection_time: float = 0.0
var affection_label: Label3D
## Rolled by population.gd for the wider, procedurally scattered population -- more health
## and a bit larger, rather than a whole new species.
var rare: bool = false

func setup(kind: String, terrain: Node3D, a: Vector2, b: Vector2, offset: float, is_rare: bool = false) -> void:
	species = kind
	world = terrain
	start = a
	finish = b
	clock = offset
	phase_offset = offset
	rare = is_rare
	health = int((100 if kind == "cow" else 50) * (1.8 if rare else 1.0))
	var model: Node3D = MODELS[kind].instantiate()
	visual = model
	if rare: visual.scale = Vector3.ONE * 1.18
	add_child(model)
	hitbox = Area3D.new()
	hitbox.collision_layer = 8
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.90, 1.18, 1.9) if kind == "cow" else (Vector3(0.6, 0.85, 1.3) if kind == "dog" else Vector3(0.44, 0.65, 0.95))
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	hitbox.add_child(shape)
	add_child(hitbox)
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Walk stance is 75% of a cycle; speed matches the authored foot trajectory.
	stride_speed = {"cat": 0.16 / (1.1 * 0.75), "dog": 0.32 / (1.1 * 0.75), "cow": 0.43 / (1.6 * 0.75)}[kind]
	walk_duration = a.distance_to(b) / stride_speed
	heading = atan2(-(b.x-a.x), -(b.y-a.y))
	if animator:
		for clip: StringName in animator.get_animation_list():
			if clip != &"RESET": animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_process(0.0)

func _tick_affection(delta: float) -> void:
	if affection_time <= 0.0: return
	affection_time = maxf(0.0, affection_time - delta)
	if affection_label == null: return
	affection_label.visible = affection_time > 0.0
	affection_label.position.y = (1.75 if species == "cow" else 1.05) + 0.12 * sin(affection_time * 6.0)

## Hearts-and-smile popup, shown above the animal for a couple seconds after petting or taming.
func show_affection() -> void:
	affection_time = 2.4
	if affection_label == null:
		affection_label = Label3D.new()
		affection_label.text = "<3  ^_^  <3"
		affection_label.font_size = 56
		affection_label.outline_size = 10
		affection_label.modulate = Color(1.0, 0.45, 0.55)
		affection_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		affection_label.no_depth_test = true
		add_child(affection_label)
	affection_label.visible = true

## Tamed pets ignore their authored route and walk toward their owner instead.
func follow(target: Vector3, delta: float) -> void:
	if not is_instance_valid(world) or health <= 0: return
	hurt_time = maxf(0.0, hurt_time - delta)
	visual.rotation.z = sin(hurt_time * 35.0) * hurt_time * 0.35
	_tick_affection(delta)
	var to_target: Vector3 = target - position
	to_target.y = 0.0
	var distance: float = to_target.length()
	var stop_radius: float = 1.6
	var moving: bool = distance > stop_radius
	var trotting: bool = distance > 6.0
	if moving:
		var direction: Vector3 = to_target / distance
		var speed: float = FOLLOW_SPEED.get(species, 7.5) * (1.4 if trotting else 1.0)
		var step: float = minf(speed * delta, distance - stop_radius)
		var next_xz: Vector2 = Vector2(position.x, position.z) + Vector2(direction.x, direction.z) * step
		position = Vector3(next_xz.x, world.height_at(next_xz), next_xz.y)
		rotation.y = atan2(-direction.x, -direction.z)
	elif distance > 0.3:
		# Standing near its owner: turn to face them instead of freezing at the last heading.
		var facing: Vector3 = to_target / distance
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-delta * 6.0))
	var camera: Camera3D = get_viewport().get_camera_3d()
	visible = camera == null or global_position.distance_squared_to(camera.global_position) < 120.0 * 120.0
	if animator:
		animator.active = visible
		var clip: StringName = (&"trot" if trotting else &"walk") if moving else &"idle"
		if animator.current_animation != clip: animator.play(clip, 0.20)

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	if health <= 0:
		hide()
		animator.active = false
		return
	hurt_time = maxf(0.0, hurt_time - delta)
	visual.rotation.z = sin(hurt_time * 35.0) * hurt_time * 0.35
	_tick_affection(delta)
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

func apply_health(value: int) -> void:
	if value < health and value > 0: hurt_time = 0.35
	health = value
	hitbox.collision_layer = 8 if health > 0 else 0
	if health <= 0: hide()
