extends Node3D
## Camera-crosshair raycast targeting for F (till/plant/water/harvest/fish/fill bucket),
## mirroring how builder.gd aims building placement: a ray from the center of the screen,
## not a fixed distance in the player's facing direction. Runs every frame so a ghost tile
## always shows exactly what F will act on, the same way the builder's ghost does.
const Habitat = preload("res://Adventure/animals/habitat.gd")
var session: Node3D
var ghost: MeshInstance3D
var _tint: StandardMaterial3D
var mode: String = "none"
var plot_id: String = ""
var target: Vector3 = Vector3.ZERO
var valid: bool = false
var hint: String = ""

func _ready() -> void:
	var mesh: BoxMesh = BoxMesh.new(); mesh.size = Vector3(0.94, 0.06, 0.94)
	ghost = MeshInstance3D.new(); ghost.mesh = mesh
	_tint = StandardMaterial3D.new(); _tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _tint.no_depth_test = false
	ghost.material_override = _tint
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost); ghost.hide()

func update(camera: Camera3D, blocked: bool) -> void:
	mode = "none"; plot_id = ""; valid = false; hint = ""
	if not is_instance_valid(session) or not session.running or blocked or camera == null:
		ghost.hide(); return
	var actor: CharacterBody3D = session.local_player()
	var world: Node3D = session.world
	if actor == null or not is_instance_valid(world):
		ghost.hide(); return
	var center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	var start: Vector3 = camera.project_ray_origin(center)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(center) * 6.0, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or actor.position.distance_to(hit.position) > 4.0:
		ghost.hide(); return
	var point: Vector3 = hit.position
	var equipped: String = str(session.local_profile.get("equipped", "hand"))
	var near_water: bool = world.near_water(point) or world.near_water(actor.position)
	if equipped == "fishing_rod" and near_water:
		mode = "fish"; hint = "F · Cast your line"; ghost.hide(); return
	if equipped == "bucket" and near_water:
		mode = "fill_bucket"; hint = "F · Fill bucket"; ghost.hide(); return
	var found_plot: String = world.farmland_view.nearest(point, 0.75) if is_instance_valid(world.farmland_view) else ""
	if not found_plot.is_empty():
		var record: Dictionary = world.farmland_view.plots.get(found_plot, {})
		var crop: String = str(record.get("crop", ""))
		target = Vector3(record.p[0], record.p[1], record.p[2])
		plot_id = found_plot
		if crop.is_empty():
			mode = "water" if equipped == "water_bucket" else "plant"
			hint = "F · Water soil" if mode == "water" else "F · Plant seeds"
		elif float(record.get("progress", 0.0)) >= 1.0:
			mode = "harvest"; hint = "F · Harvest " + crop
		elif equipped == "water_bucket":
			mode = "water"; hint = "F · Water soil"
		else:
			mode = "growing"; hint = "Still growing…"
		valid = mode != "growing"
		_show(target, valid)
		return
	# Nothing farmed here -- offer to till, snapped to the same 1 m grid tilling commits to.
	target = Vector3(roundf(point.x), 0, roundf(point.z))
	target.y = world.height_at(Vector2(target.x, target.z))
	mode = "till"
	valid = Habitat.clear_ground(world, Vector2(target.x, target.z), 0.6)
	hint = "F · Till soil" if valid else "This ground will not hold a farm plot"
	_show(target, valid)

func _show(p: Vector3, ok: bool) -> void:
	ghost.position = p + Vector3(0, 0.04, 0)
	_tint.albedo_color = Color(0.35, 1, 0.5, 0.45) if ok else Color(0.95, 0.55, 0.15, 0.4)
	ghost.show()

func confirm() -> void:
	if is_instance_valid(session): session.farm_confirm(mode, plot_id, target)
