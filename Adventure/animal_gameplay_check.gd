extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	print("PASS " if ok else "FAIL ", detail)
	if not ok: failures += 1
func press(game: Node, key: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._input(event)
func run() -> void:
	var game: Node3D = load("res://Adventure/main.tscn").instantiate()
	root.add_child(game)
	for child: Node in game.get_children():
		if child is CanvasLayer and child.get_script() == load("res://Adventure/intro.gd"): child.hide()
	game.set_process(false)
	var session: Node3D = game.session
	session.save_enabled = false
	session.start_solo(73129, "Wildlife QA")
	session.set_physics_process(false)
	await physics_frame
	var cow: Node3D = session.world.wildlife.find_animal("cow_0")
	check(cow != null, "cow exists in playable world")
	if cow == null:
		quit(1)
		return
	var actor: CharacterBody3D = session.players[1]
	var distant: Vector3 = actor.position
	actor.position = cow.position + Vector3(0, 0, 20)
	session._attack_animal(1, cow.animal_id)
	check(not session._actions.has(1), "out-of-range attack rejected")
	actor.position = cow.position + Vector3(0, 0, 1.8)
	actor.facing = PI
	check(session.nearest_animal(1) == null, "animals behind the player cannot be hit")
	actor.facing = 0
	await physics_frame
	check(session.nearest_animal(1) == cow, "cow can be targeted in reach")
	if DisplayServer.get_name() != "headless":
		var camera: Camera3D = game.get_node("Overview")
		camera.position = cow.position + Vector3(3.0, 2.0, 3.8)
		camera.look_at(cow.position + Vector3.UP * 0.5)
		camera.make_current()
		session.world.wildlife.tick(session.clock_time, 0.0)
		session.world.update_streaming(cow.position, [cow.position])
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/animals-in-game.png")
	session.gather()
	check(session._actions.has(1), "normal use-tool input schedules a hit")
	session.clock_time += 0.41
	session._tick_actions()
	check(cow.health == 70, "first axe impact damages cow (100 max health)")
	check(int(session.local_profile.inventory.get("meat", 0)) == 0, "no meat before defeat")
	session._attack_animal(1, cow.animal_id)
	check(not session._actions.has(1), "swing cooldown rejects spam")
	for expected_health: int in [40, 10]:
		session.clock_time += 1.0
		session.gather()
		session.clock_time += 0.41
		session._tick_actions()
		check(cow.health == expected_health, "axe impact damages cow toward defeat")
	session.clock_time += 1.0
	session.gather()
	session.clock_time += 0.41
	session._tick_actions()
	check(cow.health == 0 and not cow.visible and cow.hitbox.collision_layer == 0, "defeated cow disappears and is no longer hittable")
	check(int(session.local_profile.inventory.get("meat", 0)) == 3, "cow adds exactly three meat to inventory")
	check(int(session.local_profile.inventory.get("bone", 0)) == 1, "cow adds exactly one bone to inventory")
	session.clock_time += 1.0
	var duplicate: Dictionary = session.store.hit_animal(1, cow, session.clock_time)
	check(not duplicate.ok and session.store.profile(1).inventory.meat == 3, "duplicate kill cannot award more meat")
	session.store.profile(1).fullness = 50
	check(session.world.cooking_stations.size() == 3, "each village has a cooking fire")
	session.store.profile(1).inventory.wood = 1
	actor.position = session.world.cooking_stations[0] + Vector3(0,0,1.8)
	session.craft("cooked_meat")
	check(session._actions.has(1), "cooking starts beside the village fire")
	session.clock_time += 4.1
	session._tick_actions()
	check(session.local_profile.inventory.meat == 2 and session.local_profile.inventory.wood == 0 and session.local_profile.inventory.cooked_meat == 1, "cooking consumes one raw meat and one wood for one cooked meat")
	session.clock_time += 1.0
	session.inventory_action("cooked_meat", "eat")
	check(session.local_profile.inventory.cooked_meat == 0 and int(session.local_profile.fullness) == 90, "eating removes cooked meat and restores food")
	session.clock_time += 1.0
	session.inventory_action("meat", "discard")
	check(session.local_profile.inventory.meat == 1, "remove one discards exactly one item")
	session.clock_time += 1.0
	var denied: Dictionary = session.store.inventory_action(1, "wood", "eat", session.clock_time)
	check(not denied.ok, "non-food cannot be eaten")
	session.store.profile(1).fullness = 100
	session.store.profile(1).inventory.cooked_meat = 1
	denied = session.store.inventory_action(1, "cooked_meat", "eat", session.clock_time)
	check(not denied.ok and session.store.profile(1).inventory.meat == 1, "full player does not lose food")
	session.store.profile(1).fullness = 75
	session.store.profile(1).inventory.cooked_meat = 0
	var dog: Node3D = session.world.wildlife.find_animal("dog_0")
	actor.position = dog.position + Vector3(0, 0, 1.5)
	actor.facing = 0
	await physics_frame
	session._attack_animal(1, dog.animal_id)
	actor.position += Vector3.RIGHT * 4.0
	session.clock_time += 0.41
	session._tick_actions()
	check(dog.health == 50, "moving away cancels hit before impact (50 max health)")
	actor.position = dog.position + Vector3(0, 0, 1.5)
	await physics_frame
	session._attack_animal(1, dog.animal_id)
	session.clock_time += 0.41
	session._tick_actions()
	check(dog.health == 20, "dog is also hittable")
	session.clock_time += 1.0
	var cat: Node3D = session.world.wildlife.find_animal("cat_0")
	actor.position = cat.position + Vector3(0, 0, 1.5)
	actor.facing = 0
	await physics_frame
	session._attack_animal(1, cat.animal_id)
	session.clock_time += 0.41
	session._tick_actions()
	check(cat.health == 20 and session.local_profile.inventory.meat == 1, "cat can be hit without cow meat reward")
	session.clock_time += 1.0
	actor.position = dog.position + Vector3(0, 0, 1.5)
	actor.facing = 0
	await physics_frame
	session.store.profile(1).inventory.meat = 0
	session.store.profile(1).inventory.bone = 0
	var wild_result: Dictionary = session.store.interact_animal(1, dog)
	check(not wild_result.get("tamed", false) and not wild_result.get("affection", false), "an unfed wild animal is not tamed and gets no affection")
	check(str(wild_result.get("reason", "")).contains("wild"), "wild animal explains how to tame it instead of a silent pet")
	session.pet_animal()
	check(not session.store.data.get("tamed", {}).has("dog_0"), "petting alone does not tame")
	session.store.profile(1).inventory.bone = 1
	session.pet_animal()
	check(session.store.data.tamed.get("dog_0") == "host" and int(session.local_profile.inventory.get("bone", 0)) == 0, "feeding a bone tames the dog and consumes it")
	check(dog.tamed and dog.owner_id == "host", "tamed state replicates onto the live animal node")
	if DisplayServer.get_name() != "headless":
		var camera: Camera3D = game.get_node("Overview")
		camera.position = dog.position + Vector3(1.6, 1.4, 2.2)
		camera.look_at(dog.position + Vector3.UP * 1.0)
		camera.make_current()
		session.world.wildlife.tick(session.clock_time, 0.0)
		session.world.update_streaming(dog.position, [dog.position])
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/animal-affection.png")
	session.store.profile(1).inventory.meat = 1
	actor.position += Vector3.FORWARD * 6.0
	var far_distance: float = dog.position.distance_to(actor.position)
	for step: int in range(40):
		session._physics_process(0.1)
	check(dog.position.distance_to(actor.position) < far_distance, "tamed dog follows its owner")
	check(dog.position.distance_to(actor.position) < 4.0, "tamed dog closes most of the gap within 4 seconds")
	if DisplayServer.get_name() != "headless":
		var camera2: Camera3D = game.get_node("Overview")
		camera2.position = actor.position + Vector3(-2.5, 2.0, 2.5)
		camera2.look_at(actor.position + Vector3.UP * 0.8)
		camera2.make_current()
		session.world.update_streaming(actor.position, [actor.position])
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/animal-follow.png")
	var replica: Node3D = Node3D.new()
	replica.set_script(load("res://Adventure/animals/population.gd"))
	session.world.add_child(replica)
	replica.setup(session.world)
	replica.apply_state(session.store.public_delta().animals)
	check(replica.find_animal("cow_0").health == 0, "late-join state preserves defeated cows")
	replica.tick(37.0, 0.0)
	session.world.wildlife.tick(37.0, 0.0)
	check(replica.find_animal("dog_0").position.is_equal_approx(session.world.wildlife.find_animal("dog_0").position), "animal positions agree at the same server time")
	replica.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(session.store.data))
	check(preload("res://Adventure/world_store.gd").valid_save(saved, 73129), "animal and food state remain valid after JSON save roundtrip")
	check(saved.animals.cow_0 == 0 and saved.profiles.host.inventory.meat == 1, "save contains depletion and remaining meat")
	game.hud.close_menu()
	press(game, KEY_E)
	check(game.hud.menu_open and game.hud.page == "Inventory", "E opens inventory with logical key fallback")
	press(game, KEY_E)
	check(not game.hud.menu_open, "E closes inventory")
	game.hud.open_page("Crafting")
	press(game, KEY_I)
	check(game.hud.page == "Inventory", "I opens inventory from another menu")
	var preference: bool = game.hud.hotbar_enabled
	game.hud.set_hotbar_visible(false)
	game.hud.close_menu()
	check(not game.hud._hotbar.visible, "hotbar stays hidden after closing inventory")
	game.hud.set_hotbar_visible(true)
	check(game.hud._hotbar.visible, "hotbar can be shown again")
	game.hud.set_hotbar_visible(preference)
	game.hud.open_page("Inventory")
	game.hud.inventory_category = "Food"
	game.hud.inventory_item = "meat"
	game.hud.open_page("Inventory")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/animal-food-inventory.png")
	session.stop(false)
	game.queue_free()
	await process_frame
	print("ANIMAL_GAMEPLAY_CHECK_COMPLETE failures=", failures)
	quit(failures)
