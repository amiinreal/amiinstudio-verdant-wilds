extends Node3D
## Small bounded population, generated without consuming the world/resource RNG.
const Animal = preload("res://Adventure/animals/animal.gd")
const Geo = preload("res://Adventure/geography.gd")

func setup(world: Node3D) -> void:
	name = "WoodlandAnimals"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world.seed_value + 83021
	for town: Vector2 in Geo.SETTLEMENTS:
		for kind: String in ["cat", "dog", "cow"]:
			for attempt: int in range(60):
				var a: Vector2 = town + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(19.0, 29.0)
				var b: Vector2 = a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 4.0)
				if not _clear_corridor(world, a, b): continue
				var animal: Node3D = Node3D.new()
				animal.set_script(Animal)
				animal.name = kind.capitalize() + str(get_child_count())
				add_child(animal)
				animal.setup(kind, world, a, b, rng.randf() * 20.0)
				break

func _clear_corridor(world: Node3D, a: Vector2, b: Vector2) -> bool:
	for i: int in range(9):
		var p: Vector2 = a.lerp(b, float(i) / 8.0)
		if world.geography.slope_at(p) > 0.10: return false
		if world.height_at(p) < world.geography.water_height(p) + 0.8: return false
		if world.geography.road_distance(p) < 2.0: return false
		if world._crossing_clearance(p): return false
		for record: Dictionary in world.resources.values():
			var rp: Vector3 = record.p
			if p.distance_squared_to(Vector2(rp.x, rp.z)) < 2.25: return false
	return true
