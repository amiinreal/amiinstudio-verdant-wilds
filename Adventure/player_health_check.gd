extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	print("PASS " if ok else "FAIL ", detail)
	if not ok: failures += 1
func run() -> void:
	var game: Node3D = load("res://Adventure/main.tscn").instantiate()
	root.add_child(game)
	for child: Node in game.get_children():
		if child is CanvasLayer and child.get_script() == load("res://Adventure/intro.gd"): child.hide()
	game.set_process(false)
	var session: Node3D = game.session
	session.save_enabled = false
	session.start_solo(73129, "Attacker")
	session.set_physics_process(false)
	await physics_frame

	# A second, fake peer standing in for a real multiplayer opponent -- enough to exercise
	# the authority-side PvP path without standing up an actual second ENet connection.
	session.store.enter(2, "", false)
	session._spawn(2, "Target", session.players[1].position + Vector3(0, 0, -1.5))
	var attacker: CharacterBody3D = session.players[1]
	var target: CharacterBody3D = session.players[2]
	attacker.facing = 0
	session.store.profile(1).equipped = "axe"
	check(int(session.store.profile(2).get("health", 100)) == 100, "new player starts at full health")

	session._attack_player(1, 2)
	check(session._actions.has(1), "swinging at a nearby, faced player schedules a hit")
	session.clock_time += 0.41
	session._tick_actions()
	check(int(session.store.profile(2).health) == 70, "axe hit deals 30 damage to another player")

	session._attack_player(1, 2)
	check(not session._actions.has(1), "swing cooldown rejects spam against players too")
	session.clock_time += 1.0
	target.position = attacker.position + Vector3(20, 0, 0)
	session._attack_player(1, 2)
	check(not session._actions.has(1), "an out-of-reach player cannot be targeted")
	target.position = attacker.position + Vector3(0, 0, -1.5)

	# Two more hits (30 each) bring 70 down to 10, then to defeat.
	for expected: int in [40, 10]:
		session.clock_time += 1.0
		session._attack_player(1, 2)
		session.clock_time += 0.41
		session._tick_actions()
		check(int(session.store.profile(2).health) == expected, "axe hit damages the target toward defeat")
	session.clock_time += 1.0
	session._attack_player(1, 2)
	session.clock_time += 0.41
	session._tick_actions()
	check(int(session.store.profile(2).health) == 100, "defeat resets the target back to full health")
	check(float(session.store.profile(2).fullness) >= 30.0, "defeat leaves the target with at least some food")

	# Starvation: zero food should slowly drain health, and hitting zero health should
	# respawn the player (not just sit at zero) with a forgiving food cushion.
	session.store.profile(1).fullness = 0
	session.store.profile(1).health = 1
	var spawn_pos: Vector3 = attacker.position
	attacker.position += Vector3(15, 0, 0)
	for step: int in range(5):
		session._physics_process(0.2)
	check(int(session.store.profile(1).health) == 100, "starving to zero health respawns the player")
	check(attacker.position.distance_to(spawn_pos) < 5.0, "starvation respawn returns to the checkpoint, not the wandered-off death spot")
	check(float(session.store.profile(1).fullness) >= 30.0, "starvation respawn leaves a food cushion so it is not an instant repeat death")

	# Eating restores both food and health, matching the HUD's advertised +40 / +20.
	session.store.profile(1).health = 50
	session.store.profile(1).fullness = 50
	session.store.profile(1).inventory.cooked_meat = 1
	session.inventory_action("cooked_meat", "eat")
	check(int(session.store.profile(1).health) == 70 and int(session.store.profile(1).fullness) == 90, "eating restores food and health together")
	session.store.profile(1).health = 62
	session._publish_profile(1)
	if DisplayServer.get_name() != "headless":
		game.hud.menu_open = false
		var camera: Camera3D = game.get_node("Overview")
		camera.position = attacker.position + Vector3(0, 3, 6)
		camera.look_at(attacker.position)
		camera.make_current()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/player-health-hud.png")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(session.store.data))
	check(preload("res://Adventure/world_store.gd").valid_save(saved, 73129), "health field survives a JSON save roundtrip")

	session.stop(false)
	game.queue_free()
	await process_frame
	print("PLAYER_HEALTH_CHECK_COMPLETE failures=", failures)
	quit(failures)
