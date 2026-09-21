extends SceneTree
var session: Node3D
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func run() -> void:
	session = Node3D.new(); session.set_script(preload("res://Adventure/session.gd")); session.name = "Session"; root.add_child(session)
	session.save_enabled = false
	var deadline: int = Time.get_ticks_msec() + 30000
	while session.account_service.account.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not session.account_service.account.is_empty(), "one-time launch ticket authenticates game")
	if failures: quit(1); return
	if OS.get_environment("AMIIN_TEST_ROLE") == "host":
		await session.host_online(73129)
		check(session.running and session.relay_mode, "host opens authenticated relay world")
		var file := FileAccess.open(OS.get_environment("AMIIN_TEST_CODE_FILE"), FileAccess.WRITE)
		file.store_string(session.invite_code); file.close()
		deadline = Time.get_ticks_msec() + 45000
		while session.players.size() < 2 and Time.get_ticks_msec() < deadline: await process_frame
		check(session.players.size() == 2, "Godot RPC handshake over WebSocket relay")
		if session.players.size() == 2:
			var guest: int = session.players.keys()[1]
			check(str(session.store.bindings[guest]).begins_with("account_"), "persistent guest identity from relay")
			session.store.profile(guest).inventory.wood = 37
			session._publish_profile(guest)
			await create_timer(5).timeout
	else:
		await session.join_online(OS.get_environment("AMIIN_TEST_INVITE"))
		deadline = Time.get_ticks_msec() + 40000
		while int(session.local_profile.get("inventory", {}).get("wood", 0)) != 37 and Time.get_ticks_msec() < deadline: await process_frame
		check(session.players.size() == 2, "guest receives world and two-player roster")
		check(int(session.local_profile.get("inventory", {}).get("wood", 0)) == 37, "host-owned inventory replicated privately")
	session.stop(false)
	print("ONLINE_CHECK_COMPLETE failures=", failures)
	quit(1 if failures else 0)
