extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value: int in [73129, 12345, 2026]:
		var world: Node3D = Node3D.new()
		world.set_script(load("res://Adventure/open_world.gd"))
		root.add_child(world)
		world.build(seed_value, 2)
		var ok: bool = world.wildlife.get_child_count() >= 9 + 20 and world.cooking_stations.size() == 3
		var wild_count: int = 0; var rare_count: int = 0
		print("HABITAT seed=", seed_value, " animals=", world.wildlife.get_child_count(), " cooking_fires=", world.cooking_stations.size())
		for animal: Node3D in world.wildlife.get_children():
			for step: int in range(9):
				ok = ok and preload("res://Adventure/animals/habitat.gd").clear_ground(world, animal.start.lerp(animal.finish, float(step)/8.0), 0.8 if animal.species == "cow" else 0.45)
			if animal.animal_id.contains("_w"): wild_count += 1
			if animal.rare:
				rare_count += 1
				ok = ok and animal.health > (100 if animal.species == "cow" else 50)
		ok = ok and wild_count >= 20
		print("HABITAT seed=", seed_value, " wild=", wild_count, " rare=", rare_count)
		if not ok: failures += 1
		world.queue_free()
		await process_frame
	print("HABITAT_CHECK_COMPLETE failures=", failures)
	quit(failures)
