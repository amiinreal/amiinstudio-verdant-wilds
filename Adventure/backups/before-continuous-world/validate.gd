extends SceneTree
const Session := preload("res://Adventure/session.gd")
const Rules := preload("res://Adventure/rules.gd")
var failures: int = 0
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, text_value: String) -> void:
	if not value:
		failures += 1
		push_error("CHECK FAILED: " + text_value)

func play(phrase: Array, id: int = 1) -> void:
	for note: int in phrase:
		game.clock_time += 0.2
		game._handle_note(id, note, false)

func _run() -> void:
	game = Node3D.new()
	game.set_script(Session)
	game.name = "Session"
	game.save_enabled = false
	root.add_child(game)
	game.start_solo(73129, "Tester")
	check(game.world.shrines.size() == 7 and game.world.bridges.size() == 8, "Seven destinations and eight crossings")
	check(game.players.size() == 1 and game.running, "Solo starts")
	var fingerprint: int = hash(game.world.placements)
	game.world.build(73129)
	check(hash(game.world.placements) == fingerprint, "Seed reproduces identical vegetation")
	check(not game.world.bridges[0].visible, "Unsolved song keeps bridge closed")
	var player: CharacterBody3D = game.players[1]
	player.teleport(game.world.spawn_position(6))
	play(Rules.required_phrase(73129, 6))
	check(not game.state["solved"][6], "Finale rejects missing voices")
	player.teleport(game.world.spawn_position(0))
	play([4, 4, 4])
	check(not game.state["solved"][0], "Wrong notes do not unlock shrine")
	play([0, 1, 2])
	check(game.state["solved"][0] and game.world.bridges[0].visible and game.world.bridges[1].visible, "Bloom unlocks both first crossings")
	check(player.checkpoint == 0 and game.state["shards"] == 3, "Shrine grants reward and checkpoint")
	player.health = 40
	game.clock_time += 2.1
	play([0, 1, 2])
	check(player.health == 60, "Bloom heals player")
	for site in range(1, 6):
		player.teleport(game.world.spawn_position(site))
		play(Rules.required_phrase(73129, site))
		if site == 5:
			check(not game.state["solved"][5], "Observatory requires a second voice")
			game.request_echo()
			await create_timer(2.0).timeout
		check(game.state["solved"][site], "Shrine %d can be completed" % site)
	player.teleport(game.world.spawn_position(2))
	play([4, 2, 0])
	check(player.velocity.y >= 11, "Gust launches player")
	play([1, 3, 1])
	check(game.world.is_revealed(), "Reveal exposes hidden collectibles")
	play([0, 2, 4])
	check(game.world.is_stunned(), "Ward disables sentinels")
	var treasure: Node3D = game.world.treasures[8]
	player.teleport(treasure.position - Vector3.UP * 0.7)
	var before: int = game.state["shards"]
	game._check_treasures(1)
	game._check_treasures(1)
	check(game.state["shards"] == before + 1, "Treasure rewards exactly once")
	player.teleport(game.world.spawn_position(6))
	play(Rules.required_phrase(73129, 6))
	check(game.state["solved"].count(true) == 7, "Complete adventure reaches finale")
	await create_timer(2.0).timeout
	await physics_frame
	for i in range(game.world.bridges.size()):
		var bridge: Node3D = game.world.bridges[i]
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(bridge.position + Vector3.UP * 5, bridge.position - Vector3.UP * 5, 1)
		check(not game.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Open bridge %d has physical deck" % i)
	var old_seed: int = game.state["seed"]
	game.next_expedition()
	check(game.state["seed"] != old_seed and game.state["solved"].count(true) == 0, "New expedition resets progression with a new seed")
	check(player.checkpoint == 0 and player.health == 100, "New expedition resets player state")
	# Physical movement is server-authoritative and rejects non-finite inputs.
	var start: Vector3 = player.position
	for i in range(80):
		game.submit_input(Vector2(0, -1), 0, false)
		await physics_frame
	check(player.position.distance_to(start) > 3, "Server moves player across real terrain")
	game._accept_input(1, Vector2(INF, 0), 0, false)
	check(player.move_input.is_finite(), "Malformed movement rejected")
	check(Rules.required_phrase(42, 1) != Rules.required_phrase(73129, 1), "New seeds change melodies")
	check(not Rules.validate_state({"version": 1, "seed": 4, "solved": []}), "Malformed saved/network state rejected")
	print("ADVENTURE_VALIDATION_", "PASS" if failures == 0 else "FAIL", " failures=", failures, " | progression, spells, echo, treasure, bridge collisions, deterministic world, movement, replay")
	game.stop(false)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
