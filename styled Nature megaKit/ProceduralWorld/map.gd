extends Control
var world: Node3D
var explorer: CharacterBody3D

func _draw() -> void:
	if world == null or world.sites.is_empty():
		return
	var center: Vector2 = size * 0.5
	var ratio: float = size.x / world.world_size
	draw_circle(center, size.x * 0.45, Color("203f3d"))
	draw_arc(center, size.x * 0.45, 0, TAU, 96, Color("49685b"), 1.0, true)
	var loop: PackedVector2Array = PackedVector2Array()
	for i in range(97):
		var angle: float = TAU * i / 96.0
		loop.append(center + Vector2(cos(angle), sin(angle)) * world.ring_radius(angle) * world.world_size / 224.0 * ratio)
	draw_polyline(loop, Color("8a9773"), 1.5, true)
	for i in range(world.sites.size()):
		var p: Vector3 = world.sites[i]
		var point: Vector2 = center + Vector2(p.x, p.z) * ratio
		draw_line(center, point, Color("8a9773"), 1.5, true)
		draw_circle(point, 4.0, world.SITE_COLORS[i])
	draw_circle(center + Vector2(29, 19) * world.world_size / 224.0 * ratio, 12.0 * world.world_size / 224.0 * ratio, Color("548b94"))
	draw_circle(center, 4.0, Color("f5e4b5"))
	if explorer != null and explorer.enabled:
		var p: Vector3 = explorer.position
		var point: Vector2 = center + Vector2(p.x, p.z) * ratio
		draw_circle(point, 3.0, Color.WHITE)
		draw_line(point, point + Vector2(-sin(explorer.rotation.y), -cos(explorer.rotation.y)) * 10.0, Color.WHITE, 2.0, true)
