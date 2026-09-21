extends SceneTree
const Session := preload("res://Adventure/session.gd")
var game: Node3D
var role: String = "host"
var port: int = 29150
var failed: bool = false

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		port = int(args[1])
	call_deferred("_run")

func _run() -> void:
	game = Node3D.new()
	game.set_script(Session)
	game.save_enabled = false
	game.name = "Session"
	root.add_child(game)
	if role == "host":
		if game.host_game(424242, port, "Host") != OK:
			_fail("host bind")
			return
		var deadline: int = Time.get_ticks_msec() + 35000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if game.players.size() == 3 and game.state["solved"][0]:
				print("NETWORK_HOST_PASS players=3 seed=424242 shared_shrine=true")
				await create_timer(0.5).timeout
				# Fixture enables the final portal to exercise a synchronized expedition reset.
				game.state["solved"] = [true, true, true, true, true, true, true]
				game.next_expedition()
				while game._ready_peers.size() < 2 and Time.get_ticks_msec() < deadline:
					await process_frame
				if game._ready_peers.size() != 2:
					_fail("clients did not reload the next expedition")
					return
				game.world.reveal()
				game.world.ward()
				print("NETWORK_RESTART_PASS new_seed=", game.state["seed"])
				while game.players.size() > 1 and Time.get_ticks_msec() < deadline:
					await process_frame
				if game.players.size() != 1:
					_fail("disconnected players were not removed")
					return
				print("NETWORK_DISCONNECT_PASS remaining_players=1")
				game.stop(false)
				quit()
				return
		_fail("host did not see two clients and shared shrine completion")
		return
	await create_timer(1 if role == "lead" else 6).timeout
	if game.join_game("127.0.0.1", port, role) != OK:
		_fail("client start")
		return
	var deadline: int = Time.get_ticks_msec() + 25000
	while (not game.running or game.local_player() == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.local_player() == null:
		_fail("connection timeout")
		return
	if game.state["seed"] != 424242:
		_fail("seed mismatch")
		return
	if role == "lead":
		var start: Vector3 = game.local_player().position
		for i in range(30):
			game.submit_input(Vector2(0, -1), 0, false)
			await physics_frame
		game.submit_input(Vector2.ZERO, 0, false)
		await create_timer(0.25).timeout
		if game.local_player().position.distance_to(start) < 1:
			_fail("client input did not produce authoritative movement")
			return
		for note: int in [0, 1, 2]:
			game.play_note(note)
			await create_timer(0.25).timeout
	else:
		if not game.state["solved"][0]:
			_fail("late join did not restore unlocked shrine")
			return
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if game.players.size() == 3 and game.state["solved"][0] and game.world.bridges[0].visible:
			print("NETWORK_CLIENT_PASS role=", role, " seed=", game.state["seed"], " players=3 state_synced=true")
			while Time.get_ticks_msec() < deadline:
				await process_frame
				if game.state["seed"] == 432161 and game.players.size() == 3 and game.world.is_revealed() and game.world.is_stunned():
					break
			if game.state["seed"] != 432161 or not game.world.is_revealed() or not game.world.is_stunned():
				_fail("new expedition or temporary effects did not synchronize")
				return
			print("NETWORK_CLIENT_RESTART_PASS role=", role, " effects_synced=true")
			await create_timer(0.6).timeout
			game.stop(false)
			quit()
			return
	_fail("roster or shared bridge did not synchronize")

func _fail(reason: String) -> void:
	push_error("NETWORK_FAIL " + role + " " + reason)
	game.stop(false)
	quit(1)
