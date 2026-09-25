extends Node3D
## Small bounded population, generated without consuming the world/resource RNG.
const Animal = preload("res://Adventure/animals/animal.gd")
const Geo = preload("res://Adventure/geography.gd")
const Habitat = preload("res://Adventure/animals/habitat.gd")

func setup(world: Node3D) -> void:
	name = "WoodlandAnimals"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world.seed_value + 83021
	for town_index: int in range(Geo.SETTLEMENTS.size()):
		var town: Vector2 = Geo.SETTLEMENTS[town_index]
		for kind: String in ["cat", "dog", "cow"]:
			var anchor: Vector2 = town + {"cat":Vector2(-13,-6), "dog":Vector2(-4,5), "cow":Vector2(7,14)}[kind]
			for attempt: int in range(640):
				var a: Vector2 = anchor + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 9.0 if attempt < 160 else 14.0)
				var b: Vector2 = a + Vector2.from_angle(rng.randf() * TAU) * (1.8 if kind == "cat" or attempt >= 160 else 3.0)
				if kind == "cow" and (minf(a.y, b.y) < town.y + 8.0 or maxf(a.y, b.y) > town.y + 19.0): continue
				if not _clear_corridor(world, a, b, 0.8 if kind == "cow" else 0.45): continue
				var animal: Node3D = Node3D.new()
				animal.set_script(Animal)
				animal.name = kind.capitalize() + str(get_child_count())
				animal.animal_id = "%s_%d" % [kind, town_index]
				add_child(animal)
				animal.setup(kind, world, a, b, rng.randf() * 20.0)
				animal.set_process(false)
				break

func _clear_corridor(world: Node3D, a: Vector2, b: Vector2, radius: float = 0.8) -> bool:
	for i: int in range(9):
		var p: Vector2 = a.lerp(b, float(i) / 8.0)
		if not Habitat.clear_ground(world, p, radius): return false
		for station: Vector3 in world.cooking_stations:
			if p.distance_to(Vector2(station.x, station.z)) < 2.5: return false
		for animal: Node3D in get_children():
			if p.distance_to(animal.start.lerp(animal.finish, 0.5)) < 2.5: return false
	return true

func tick(server_time: float, delta: float, owners: Dictionary = {}) -> void:
	for animal: Node3D in get_children():
		if animal.tamed and owners.has(animal.owner_id):
			animal.follow(owners[animal.owner_id], delta)
		else:
			animal.clock = server_time + animal.phase_offset - delta
			animal._process(delta)

func apply_state(records: Dictionary) -> void:
	for animal: Node3D in get_children():
		animal.apply_health(int(records.get(animal.animal_id, 100 if animal.species == "cow" else 50)))

func apply_tamed(records: Dictionary) -> void:
	for animal: Node3D in get_children():
		animal.tamed = records.has(animal.animal_id)
		animal.owner_id = str(records.get(animal.animal_id, ""))

func find_animal(id: String) -> Node3D:
	for animal: Node3D in get_children():
		if animal.animal_id == id: return animal
	return null
