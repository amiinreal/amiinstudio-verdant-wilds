extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	print("PASS " if ok else "FAIL ", detail)
	if not ok: failures += 1
func run() -> void:
	var session: Node3D = Node3D.new()
	session.set_script(load("res://Adventure/session.gd"))
	root.add_child(session)
	session.save_enabled = false
	session.start_solo(73129, "Cooking QA")
	session.set_physics_process(false)
	await physics_frame
	check(session.world.cooking_stations.size() == 3, "three accessible village cooking stations")
	check(session.world.wildlife.get_child_count() >= 9 + 20, "the nine settlement animals plus a wider scattered population are placed")
	for animal: Node3D in session.world.wildlife.get_children():
		check(session.world.wildlife._clear_corridor(session.world, animal.start, animal.finish, 0.0) == false, "occupied routes are reserved against overlapping new spawns")
		if not animal.animal_id.contains("_w"):
			var town: Vector2 = preload("res://Adventure/geography.gd").SETTLEMENTS[int(animal.animal_id.get_slice("_",1))]
			if animal.species == "cow": check(minf(animal.start.y,animal.finish.y) >= town.y+8.0 and maxf(animal.start.y,animal.finish.y) <= town.y+19.0, "cow stays on the meadow terrace inside the fence")
		for step: int in range(9):
			check(preload("res://Adventure/animals/habitat.gd").clear_ground(session.world, animal.start.lerp(animal.finish,float(step)/8.0),0.8 if animal.species=="cow" else 0.45), animal.animal_id + " clear, dry, gentle route")
	var actor: CharacterBody3D = session.players[1]
	var profile: Dictionary = session.store.profile(1)
	profile.inventory.meat = 2
	profile.inventory.wood = 2
	actor.position = session.world.cooking_stations[0] + Vector3(0,0,10)
	session._craft(1,"cooked_meat")
	check(not session._actions.has(1), "cannot cook away from a fire")
	actor.position = session.world.cooking_stations[0] + Vector3(0,0,1.8)
	session._craft(1,"cooked_meat")
	check(session._actions.has(1), "cooking begins within reach")
	actor.position += Vector3(4,0,0)
	session.clock_time += 4.1
	session._tick_actions()
	check(profile.inventory.meat == 2 and profile.inventory.wood == 2 and int(profile.inventory.get("cooked_meat",0))==0, "walking away cancels without consuming ingredients")
	actor.position = session.world.cooking_stations[0] + Vector3(0,0,1.8)
	session._craft(1,"cooked_meat")
	session.clock_time += 4.1
	session._tick_actions()
	check(profile.inventory.meat == 1 and profile.inventory.wood == 1 and profile.inventory.cooked_meat == 1, "completed cook produces exactly one cooked meat")
	session._tick_actions()
	check(profile.inventory.cooked_meat == 1, "completed job cannot award twice")
	session.clock_time += 1.0
	check(not session.store.inventory_action(1,"meat","eat",session.clock_time).ok, "raw meat must be cooked")
	profile.fullness = 20
	session._inventory_action(1,"cooked_meat","eat")
	check(profile.inventory.cooked_meat == 0 and profile.fullness == 60, "cooked food is consumed for 40 food")
	check(preload("res://Adventure/modules.gd").catalog().has("cooking_fire"), "cooking fire is buildable")
	for id: String in ["raw_meat", "cooked_meat", "cooking_fire"]:
		var model: PackedScene = load("res://Adventure/cooking/" + id + ".glb")
		check(model != null, id + " model imports")
		var instance: Node = model.instantiate()
		check(instance.find_children("*", "MeshInstance3D", true, false).size() > 0, id + " contains visible mesh")
		instance.free()
	session.stop(false)
	session.queue_free()
	await process_frame
	print("COOKING_CHECK_COMPLETE failures=", failures)
	quit(failures)
