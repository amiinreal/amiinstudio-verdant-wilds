extends SceneTree
## Run with --headless --path <project> --script <this resource path>.
const WORLD_SCENE := preload("res://styled Nature megaKit/ProceduralWorld/world.tscn")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _fingerprint(world: Node3D) -> int:
	var data: Array = []
	for key: String in world._batches:
		data.append(key)
		data.append(world._batches[key]["transforms"])
	return hash(data)

func _run() -> void:
	var world: Node3D = WORLD_SCENE.instantiate()
	root.add_child(world)
	var original_hash: int = _fingerprint(world)
	world.generate()
	_check(original_hash == _fingerprint(world), "Same seed did not reproduce identical asset placements")
	await process_frame
	_check(world.get_child_count() == 1, "Regeneration left duplicate generated roots")
	for seed_value: int in [73129, 42, -713, 2026]:
		world.world_seed = seed_value
		world.generate()
		_check(world.sites.size() == 6 and world.spawn_points.size() == 6, "Missing sites or spawns")
		_check(world.generation_stats["trees"] > 100, "Insufficient kit trees generated")
		for i in range(6):
			_check(world.get_spawn_transform(i).origin.y > 4.0, "Spawn is below safe ground")
			var site: Vector3 = world.sites[i]
			for step in range(101):
				var p: Vector2 = Vector2(site.x, site.z) * float(step) / 100.0
				_check(absf(world.sample_height(p) - 3.8) < 0.05, "Spoke is not level and traversable")
		for step in range(360):
			var angle: float = TAU * step / 360.0
			var p: Vector2 = Vector2(cos(angle), sin(angle)) * world.ring_radius(angle)
			_check(absf(world.sample_height(p) - 3.8) < 0.05, "Loop is not level and traversable")
		world.set_resonance(2, true)
		_check(world._active_sites[2], "Resonance hook did not activate")
		world.set_resonance(2, false)
		_check(not world._active_sites[2], "Resonance hook did not deactivate")
		await physics_frame
		await physics_frame
		for spawn: Vector3 in world.spawn_points:
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * 4, spawn - Vector3.UP * 10)
			var result: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			_check(not result.is_empty(), "Terrain collision ray missed below a spawn")
		_check(world._mesh_cache.size() >= 20, "Kit asset variety was not loaded")
	# Exercise supported size extremes, checking scaled routes and spawn clearance.
	for size_value: float in [160.0, 360.0]:
		world.world_size = size_value
		world.generate()
		for site: Vector3 in world.sites:
			_check(absf(world.sample_height(Vector2(site.x, site.z)) - site.y) < 0.05, "Scaled site does not meet terrain")
	print("VALIDATION ", "PASSED" if failures == 0 else "FAILED", " | ", failures, " failures | deterministic placement, 4 seeds, 2 sizes, connected dry routes, spawn collisions, regeneration, resonance")
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
