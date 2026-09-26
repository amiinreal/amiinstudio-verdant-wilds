extends SceneTree
## Headless QA for tilling, planting, watering, harvesting, fishing and cooking/eating the
## new farm goods. Bypasses RPCs (is_authority() is true in solo) exactly like the other
## *_check.gd scripts in this folder.
const Habitat = preload("res://Adventure/animals/habitat.gd")
const Store = preload("res://Adventure/world_store.gd")
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
	session.start_solo(73129, "Farming QA")
	session.set_physics_process(false)
	await physics_frame
	var world: Node3D = session.world
	var store: RefCounted = session.store
	var actor: CharacterBody3D = session.players[1]
	var t: float = session.clock_time

	# Find two clear, tillable cells near spawn (real terrain, not a hardcoded guess).
	var base: Vector2 = Vector2(actor.position.x, actor.position.z)
	var spots: Array[Vector3] = []
	for radius in range(2, 24):
		for angle in range(0, 8):
			var candidate: Vector2 = base + Vector2.from_angle(angle * PI / 4) * radius
			if Habitat.clear_ground(world, candidate, 0.6):
				var already_near: bool = false
				for s: Vector3 in spots:
					if Vector2(s.x, s.z).distance_to(candidate) < 2.0: already_near = true
				if not already_near: spots.append(Vector3(candidate.x, world.height_at(candidate), candidate.y))
			if spots.size() >= 2: break
		if spots.size() >= 2: break
	check(spots.size() == 2, "found two tillable plots near spawn")
	if spots.size() < 2: quit(1); return

	# Till (advancing the clock past each cooldown, exactly as real play would).
	actor.position = spots[0]
	var till_a: Dictionary = store.farm_action(1, "till", "", spots[0], actor.position, world, t); t += 1.0
	check(till_a.ok, "till plot A: " + str(till_a.reason))
	actor.position = spots[1]
	var till_b: Dictionary = store.farm_action(1, "till", "", spots[1], actor.position, world, t); t += 1.0
	check(till_b.ok, "till plot B: " + str(till_b.reason))
	check(store.data.farmland.size() == 2, "two farmland plots recorded")
	var again: Dictionary = store.farm_action(1, "till", "", spots[0], spots[0], world, t); t += 1.0
	check(not again.ok, "cannot till the same soil twice")

	var plot_a: String = ""; var plot_b: String = ""
	for id: String in store.data.farmland:
		var pos: Vector3 = Vector3(store.data.farmland[id].p[0], store.data.farmland[id].p[1], store.data.farmland[id].p[2])
		if pos.distance_to(spots[0]) < 0.5: plot_a = id
		if pos.distance_to(spots[1]) < 0.5: plot_b = id
	check(not plot_a.is_empty() and not plot_b.is_empty() and plot_a != plot_b, "plot ids resolved")

	# Grass must not be left covering a tilled plot's soil model (regression: the grass
	# mask used to ignore farmland entirely, so the model rendered but was hidden).
	world.apply_delta(store.public_delta())
	var pixel_a: Vector2i = Vector2i(floori(spots[0].x + 512), floori(spots[0].z + 512))
	check(world.grass_mask_image.get_pixelv(pixel_a).r > 0.5, "grass is cleared around a tilled plot")

	# Plant.
	var profile: Dictionary = store.profile(1)
	profile.inventory["carrot_seeds"] = 3
	profile.inventory["wheat_seeds"] = 3
	store.equip(1, "carrot_seeds")
	actor.position = spots[0]
	var plant_a: Dictionary = store.farm_action(1, "plant", plot_a, spots[0], actor.position, world, t); t += 1.0
	check(plant_a.ok and store.data.farmland[plot_a].crop == "carrot", "planted carrot in plot A: " + str(plant_a.reason))
	store.equip(1, "wheat_seeds")
	actor.position = spots[1]
	var plant_b: Dictionary = store.farm_action(1, "plant", plot_b, spots[1], actor.position, world, t); t += 1.0
	check(plant_b.ok and store.data.farmland[plot_b].crop == "wheat", "planted wheat in plot B: " + str(plant_b.reason))

	# Growth: dry grows slowly, watered grows faster.
	store.tick_farms(10.0, t)
	var dry_progress: float = float(store.data.farmland[plot_a].progress)
	check(dry_progress > 0.0 and dry_progress < 0.1, "dry soil still grows, slowly: " + str(dry_progress))
	profile.inventory["water_bucket"] = 1
	var water_result: Dictionary = store.farm_action(1, "water", plot_a, spots[0], actor.position, world, t); t += 1.0
	check(water_result.ok and int(profile.inventory.get("water_bucket", 0)) == 0 and int(profile.inventory.get("bucket", 0)) == 1, "watering consumes the full bucket and returns an empty one: " + str(water_result.reason))
	store.tick_farms(10.0, t + 10.0)
	var watered_progress: float = float(store.data.farmland[plot_a].progress)
	check(watered_progress - dry_progress > 0.05, "watered soil grows noticeably faster")

	# Harvest (force ripeness rather than waiting minutes of simulated growth).
	store.data.farmland[plot_a].progress = 1.0
	var harvest: Dictionary = store.farm_action(1, "harvest", plot_a, spots[0], actor.position, world, t); t += 1.0
	check(harvest.ok and int(profile.inventory.get("carrot", 0)) >= 2, "harvested carrots: " + str(harvest.reason))
	check(store.data.farmland[plot_a].crop == "", "plot A cleared for replanting")

	# Eat a raw carrot.
	var before_food: float = float(profile.get("fullness", 50))
	var eat: Dictionary = store.inventory_action(1, "carrot", "eat", t); t += 1.0
	check(eat.ok and float(profile.fullness) > before_food, "eating a raw carrot restores food: " + str(eat.reason))

	# Bread from wheat.
	profile.inventory["wheat"] = 3
	var bread: Dictionary = store.craft(1, "bread", t); t += 1.0
	check(bread.ok and int(profile.inventory.get("bread", 0)) == 1, "baked bread from wheat: " + str(bread.reason))

	# Fill a bucket at the water's edge, then fish.
	var shore: Vector3 = Vector3.INF
	for x in range(0, 90, 2):
		var candidate: Vector2 = Vector2(25 + x, 120)
		var p3: Vector3 = Vector3(candidate.x, world.height_at(candidate), candidate.y)
		if world.near_water(p3) and world.geography.water_height(candidate) <= world.height_at(candidate):
			shore = p3; break
	check(shore != Vector3.INF, "found a shoreline near the lake")
	profile.inventory["bucket"] = 1
	actor.position = shore
	var fill: Dictionary = store.farm_action(1, "fill_bucket", "", shore, actor.position, world, t); t += 1.0
	check(fill.ok and int(profile.inventory.get("water_bucket", 0)) == 1, "filled a bucket at the water's edge: " + str(fill.reason))

	profile.inventory["fishing_rod"] = 1
	store.equip(1, "fishing_rod")
	var fish: Dictionary = store.catch_fish(1, t); t += 1.0
	check(fish.ok and (int(profile.inventory.get("river_fish", 0)) + int(profile.inventory.get("salmon", 0))) >= 1, "caught a fish")

	# Cook and eat it.
	profile.inventory["river_fish"] = 2
	profile.inventory["wood"] = 2
	var cook: Dictionary = store.craft(1, "cook_river_fish", t); t += 1.0
	check(cook.ok and int(profile.inventory.get("cooked_fish", 0)) >= 1, "cooked a river fish: " + str(cook.reason))
	var eat_fish: Dictionary = store.inventory_action(1, "cooked_fish", "eat", t); t += 1.0
	check(eat_fish.ok, "ate cooked fish: " + str(eat_fish.reason))

	# The save/load validator must accept this real, in-play farmland data.
	check(Store.valid_save(store.data, int(store.data.seed)), "farmland data passes save validation")

	print("FARMING_CHECK_COMPLETE failures=", failures)
	quit(failures)
