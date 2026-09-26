extends Node3D
const Geo = preload("res://Adventure/geography.gd")
const Habitat = preload("res://Adventure/animals/habitat.gd")
const FIRE = preload("res://Adventure/cooking/cooking_fire.glb")

func setup(world: Node3D) -> void:
	name = "VillageCookingFires"
	for town: Vector2 in Geo.SETTLEMENTS:
		for attempt: int in range(100):
			var p: Vector2 = town + Vector2(6, 4) + Vector2.from_angle(attempt * 2.4) * (float(attempt) / 12.0)
			if not Habitat.clear_ground(world, p, 1.0): continue
			var fire: Node3D = FIRE.instantiate()
			fire.position = Vector3(p.x, world.height_at(p), p.y)
			add_child(fire)
			preload("res://Adventure/modules.gd").collider(fire, "cooking_fire")
			world.cooking_stations.append(fire.position)
			var light: OmniLight3D = OmniLight3D.new()
			light.position.y = 0.5
			light.light_color = Color("ffc075")
			light.light_energy = 0.6
			light.omni_range = 3.0
			fire.add_child(light)
			break
