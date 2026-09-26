extends SceneTree
## Headless QA for the camera-crosshair raycast farm targeting controller. Physics raycasts
## work without a window, so this runs headless like the other *_check.gd scripts.
const Habitat = preload("res://Adventure/animals/habitat.gd")
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
	session.start_solo(73129, "Farm Targeting QA")
	session.set_physics_process(false)
	await physics_frame
	var world: Node3D = session.world
	var store: RefCounted = session.store
	var actor: CharacterBody3D = session.players[1]
	var t: float = session.clock_time

	var base: Vector2 = Vector2(actor.position.x, actor.position.z)
	var spot: Vector3 = Vector3.INF
	for radius in range(2, 24):
		for angle in range(0, 8):
			var candidate: Vector2 = base + Vector2.from_angle(angle * PI / 4) * radius
			if Habitat.clear_ground(world, candidate, 0.6):
				spot = Vector3(candidate.x, world.height_at(candidate), candidate.y); break
		if spot != Vector3.INF: break
	check(spot != Vector3.INF, "found clear ground to aim at")
	if spot == Vector3.INF: quit(1); return

	# Look straight down at the target spot from above -- a simple, unambiguous aim.
	game.camera.global_position = spot + Vector3(0, 5, 0)
	game.camera.look_at(spot, Vector3.FORWARD)
	game.camera.make_current()
	actor.position = spot + Vector3(0, 0, 0.5)

	game.farm_target.update(game.camera, false)
	check(game.farm_target.mode == "till", "aiming at clear, unfarmed ground resolves to till: got '%s'" % game.farm_target.mode)
	check(game.farm_target.valid, "till target is reported valid")
	check(Vector2(game.farm_target.target.x, game.farm_target.target.z).distance_to(spot_xz(spot)) < 1.0, "ghost lands on the exact tile under the crosshair")

	game.farm_target.confirm()
	check(store.data.farmland.size() == 1, "F (via confirm()) actually tilled the aimed-at tile")

	# Re-aim at the plot that now exists there and confirm it resolves to plant, not till.
	game.farm_target.update(game.camera, false)
	check(game.farm_target.mode == "plant", "re-aiming at the new plot resolves to plant, not till again: got '%s'" % game.farm_target.mode)
	var first_plot: String = store.data.farmland.keys()[0]
	check(game.farm_target.plot_id == first_plot, "the targeted plot id matches the one just tilled")

	# A second plot 1 m away must resolve independently -- the same crosshair-precision
	# regression covered in farming_check.gd, verified here through the real controller.
	t = maxf(t, session.clock_time) + 1.0
	var neighbor: Vector3 = Vector3.INF
	for offset: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var candidate: Vector2 = spot_xz(spot) + offset
		if Habitat.clear_ground(world, candidate, 0.6):
			neighbor = Vector3(candidate.x, world.height_at(candidate), candidate.y); break
	check(neighbor != Vector3.INF, "found a clear 1 m neighbor to the first plot")
	var till_neighbor: Dictionary = store.farm_action(1, "till", "", neighbor, actor.position, world, t); t += 1.0
	check(till_neighbor.ok, "tilled a neighbor plot directly: " + str(till_neighbor.reason))
	world.apply_delta(store.public_delta())
	game.camera.global_position = spot + Vector3(0, 5, 0)
	game.camera.look_at(spot, Vector3.FORWARD)
	game.farm_target.update(game.camera, false)
	check(game.farm_target.plot_id == first_plot, "aiming at the original plot still resolves to it, not its 1 m neighbor")

	# Blocked (menu open) or no camera must never leave a stale ghost/ready action behind.
	game.farm_target.update(game.camera, true)
	check(game.farm_target.mode == "none" and not game.farm_target.ghost.visible, "targeting clears itself while blocked (menu open)")

	session.stop(false)
	game.queue_free()
	await process_frame
	print("FARM_TARGETING_CHECK_COMPLETE failures=", failures)
	quit(failures)

func spot_xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)
