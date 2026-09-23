extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func run() -> void:
	var session: Node3D = Node3D.new()
	session.set_script(load("res://Adventure/session.gd"))
	root.add_child(session)
	session.save_enabled = false
	session.start_solo(73129, "Animal validation")
	await physics_frame
	var population: Node3D = session.world.find_child("WoodlandAnimals", true, false)
	check(population != null, "world creates wildlife population")
	if population:
		check(population.get_child_count() == 9, "three animals per settlement")
		for animal: Node3D in population.get_children():
			for fraction: float in [0.0, 0.25, 0.5, 0.9, 1.1, 1.8, 2.1]:
				animal.clock = animal.walk_duration * fraction
				animal._process(0.0)
				var p: Vector2 = Vector2(animal.position.x, animal.position.z)
				check(absf(animal.position.y - session.world.height_at(p)) < 0.001, animal.name + " remains grounded")
			check(animal.animator != null and animal.animator.is_playing(), animal.name + " animates")
		print("ANIMAL_POPULATION ", population.get_child_count())
	session.stop(false)
	session.queue_free()
	await process_frame
	check(not is_instance_valid(population), "wildlife is removed with the world")
	print("ANIMAL_WORLD_CHECK_COMPLETE failures=", failures)
	quit(failures)
