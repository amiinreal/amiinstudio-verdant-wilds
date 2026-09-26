extends SceneTree
## Headless QA for dropping items on the ground and another player auto-collecting them.
const Store = preload("res://Adventure/world_store.gd")
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
	session.start_solo(73129, "Drop QA")
	session.set_physics_process(false)
	await physics_frame
	var store: RefCounted = session.store
	var actor: CharacterBody3D = session.players[1]
	var profile: Dictionary = store.profile(1)
	profile.inventory.wood = 12
	var t: float = session.clock_time

	var no_item: Dictionary = store.drop_item(1, "stone", actor.position, actor.facing, t); t += 1.0
	check(not no_item.ok, "cannot drop an item you do not have")

	var dropped: Dictionary = store.drop_item(1, "wood", actor.position, actor.facing, t); t += 1.0
	check(dropped.ok, "dropped wood: " + str(dropped.reason))
	check(int(profile.inventory.get("wood", 0)) == 0, "dropping removes the whole stack from inventory")
	check(store.data.dropped.size() == 1, "one dropped-item record exists")

	# A second, distant player should not collect it...
	store.enter(2, "", false)
	session._spawn(2, "Other", actor.position + Vector3(50, 0, 0))
	var far_result: Array = store.tick_drops({1: actor.position + Vector3(50, 0, 0), 2: actor.position + Vector3(50, 0, 0)})
	check(far_result.is_empty(), "nobody standing far from the drop collects it")
	check(store.data.dropped.size() == 1, "far drop is untouched")

	# ...but walking a second player right up to it does, and it goes to THAT player, not
	# whoever dropped it -- this is a shared pickup, not a private one.
	var drop_id: String = store.data.dropped.keys()[0]
	var drop_p: Vector3 = Vector3(store.data.dropped[drop_id].p[0], store.data.dropped[drop_id].p[1], store.data.dropped[drop_id].p[2])
	var pickup: Array = store.tick_drops({1: actor.position + Vector3(50, 0, 0), 2: drop_p})
	check(pickup.size() == 1 and int(pickup[0].peer) == 2 and int(pickup[0].amount) == 12, "the nearby player collects it, not the original owner")
	check(int(store.profile(2).inventory.get("wood", 0)) == 12, "collected wood lands in the picker-upper's inventory")
	check(store.data.dropped.is_empty(), "the ground record is gone after pickup")

	check(Store.valid_save(store.data, int(store.data.seed)), "dropped-item data passes save validation")

	session.stop(false)
	session.queue_free()
	await process_frame
	print("DROP_CHECK_COMPLETE failures=", failures)
	quit(failures)
