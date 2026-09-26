extends RefCounted
const Geo = preload("res://Adventure/geography.gd")

static func clear_ground(world: Node3D, p: Vector2, radius: float = 0.7) -> bool:
	if world.geography.slope_at(p) > 0.12: return false
	if world.height_at(p) < world.geography.water_height(p) + 0.9: return false
	if world.geography.road_distance(p) < 1.5 + radius: return false
	if world._crossing_clearance(p): return false
	# Authored houses and fences are not all part of resource collision cells.
	for i: int in range(Geo.SETTLEMENTS.size()):
		var town: Vector2 = Geo.SETTLEMENTS[i]
		for j: int in range(3 if i == 0 else 2):
			var house: Vector2 = town + Vector2(-13 if j % 2 == 0 else 13, -13 if j < 2 else 13)
			var d: Vector2 = (p - house).abs()
			if d.x < 3.2 + radius and d.y < 4.5 + radius: return false
		var local: Vector2 = p - town
		if local.x > -25.0-radius and local.x < 18.0+radius and absf(local.y-22.0) < 1.0+radius: return false
	var h: float = world.height_at(p)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if absf(world.height_at(p + direction * radius) - h) > 0.12: return false
	for record: Dictionary in world.resources.values():
		var rp: Vector3 = record.p
		if p.distance_squared_to(Vector2(rp.x, rp.z)) < pow(1.4 + radius, 2): return false
	return true
