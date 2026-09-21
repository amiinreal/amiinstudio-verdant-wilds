@tool
extends Node3D
## Self-contained, deterministic island. All positions returned by the API are local.
signal world_generated(seed_value: int)
signal resonance_changed(site_id: int, active: bool)

const KIT := "res://styled Nature megaKit/glTF/"
const WATER_SHADER := preload("res://styled Nature megaKit/ProceduralWorld/water.gdshader")
const SITE_NAMES: Array[String] = ["Wind / Pinewatch", "Light / Sunmeadow", "Water / Stillwater", "Earth / Stoneheart", "Spirit / Whisperwood", "Nature / Elder Grove"]
const SITE_COLORS: Array[Color] = [Color("b6eadb"), Color("ffe09a"), Color("68dce7"), Color("f4af79"), Color("c3a3ef"), Color("a5e285")]

@export_category("Island")
@export var world_seed: int = 73129
@export_range(160.0, 360.0, 8.0) var world_size: float = 224.0
@export_range(64, 240, 8) var terrain_resolution: int = 160
@export_range(0.25, 2.0, 0.05) var vegetation_density: float = 1.2
@export var generate_on_ready: bool = true
@export var create_collisions: bool = true
@export_tool_button("Rebuild island", "Reload") var rebuild_button: Callable = generate

var sites: Array[Vector3] = []
var spawn_points: Array[Vector3] = []
var generation_stats: Dictionary = {}
var _noise: FastNoiseLite = FastNoiseLite.new()
var _detail: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _generated: Node3D
var _batches: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _site_materials: Array[StandardMaterial3D] = []
var _active_sites: Array[bool] = []
var _phase: float = 0.0
var _scale_factor: float = 1.0
var _building: bool = false

func _ready() -> void:
	if generate_on_ready:
		generate()

func generate() -> void:
	if _building or not is_inside_tree():
		return
	_building = true
	var started: int = Time.get_ticks_msec()
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "GeneratedIsland"
	add_child(_generated)
	_batches.clear()
	sites.clear()
	spawn_points.clear()
	_site_materials.clear()
	_active_sites.clear()
	generation_stats = {"trees": 0, "rocks": 0, "plants": 0, "instances": 0, "batches": 0}
	_rng.seed = world_seed
	_noise.seed = world_seed
	_noise.frequency = 0.018
	_noise.fractal_octaves = 3
	_detail.seed = world_seed + 917
	_detail.frequency = 0.09
	_detail.fractal_octaves = 2
	_phase = _rng.randf_range(-PI, PI)
	_scale_factor = world_size / 224.0
	for i in range(6):
		var angle: float = site_angle(i)
		var p: Vector2 = Vector2(cos(angle), sin(angle)) * ring_radius(angle)
		sites.append(Vector3(p.x, 3.8, p.y) * _scale_factor)
		var spawn: Vector2 = Vector2(cos(angle), sin(angle)) * 3.0 * _scale_factor
		spawn_points.append(Vector3(spawn.x, sample_height(spawn) + 1.2, spawn.y))
	_build_terrain()
	_build_water()
	_build_landmarks()
	_scatter()
	_flush_batches()
	generation_stats["milliseconds"] = Time.get_ticks_msec() - started
	_building = false
	world_generated.emit(world_seed)
	if not Engine.is_editor_hint():
		print("Resonant Wilds | seed ", world_seed, " | ", generation_stats)

func site_angle(index: int) -> float:
	return -PI / 2.0 + index * TAU / 6.0 + sin(_phase) * 0.08

func ring_radius(angle: float) -> float:
	return 58.0 + 3.0 * sin(angle * 3.0 + _phase)

func trail_distance(p: Vector2) -> float:
	# Six spokes and a continuous loop guarantee a connected route for every seed.
	var q: Vector2 = p / _scale_factor
	var distance: float = absf(q.length() - ring_radius(q.angle()))
	for i in range(6):
		var angle: float = site_angle(i)
		var endpoint: Vector2 = Vector2(cos(angle), sin(angle)) * ring_radius(angle)
		var nearest: Vector2 = endpoint * clampf(q.dot(endpoint) / endpoint.length_squared(), 0.0, 1.0)
		distance = minf(distance, q.distance_to(nearest))
	return distance * _scale_factor

func clearing_distance(p: Vector2) -> float:
	var distance: float = p.length() - 10.0 * _scale_factor
	for site in sites:
		distance = minf(distance, p.distance_to(Vector2(site.x, site.z)) - 6.5 * _scale_factor)
	return distance

func sample_height(p: Vector2) -> float:
	var q: Vector2 = p / _scale_factor
	var radius: float = q.length()
	var height: float = maxf(2.6, 4.2 + _noise.get_noise_2dv(q) * 5.0 + _detail.get_noise_2dv(q) * 0.4)
	height += smoothstep(66.0, 88.0, radius) * (5.0 + _noise.get_noise_2dv(q * 0.65) * 11.0)
	var lake_distance: float = (q - Vector2(29.0, 19.0)).length()
	height = lerpf(-2.4, height, smoothstep(11.0, 19.0, lake_distance))
	var flat_mask: float = 1.0 - smoothstep(2.4, 6.0, trail_distance(p) / _scale_factor)
	flat_mask = maxf(flat_mask, 1.0 - smoothstep(0.0, 5.0, clearing_distance(p) / _scale_factor))
	height = lerpf(height, 3.8, flat_mask)
	var coast: float = 93.0 + _noise.get_noise_2dv(q * 1.3) * 7.0
	height = lerpf(height, -6.5, smoothstep(coast - 8.0, coast + 9.0, radius))
	return height * _scale_factor

func sample_normal(p: Vector2) -> Vector3:
	var step: float = 0.6 * _scale_factor
	return Vector3(sample_height(p - Vector2(step, 0)) - sample_height(p + Vector2(step, 0)), 2.0 * step, sample_height(p - Vector2(0, step)) - sample_height(p + Vector2(0, step))).normalized()

func biome_at(p: Vector2) -> String:
	var q: Vector2 = p / _scale_factor
	if q.x < -24.0:
		return "Whisperwood"
	if q.y < -23.0:
		return "Pinewatch"
	if q.distance_to(Vector2(29, 19)) < 25.0:
		return "Stillwater"
	return "Sunmeadow"

func get_spawn_transform(index: int = 0) -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D.IDENTITY
	return Transform3D(Basis.IDENTITY, spawn_points[posmod(index, spawn_points.size())])

func set_resonance(site_id: int, active: bool) -> void:
	# Call from authoritative gameplay code; this module does not manage networking.
	if site_id < 0 or site_id >= _site_materials.size():
		return
	_active_sites[site_id] = active
	_site_materials[site_id].emission_energy_multiplier = 3.2 if active else 0.45
	resonance_changed.emit(site_id, active)

func _terrain_color(p: Vector2, height: float) -> Color:
	var q: Vector2 = p / _scale_factor
	var color: Color = Color("839752")
	var biome: String = biome_at(p)
	if biome == "Pinewatch":
		color = Color("617a50")
	elif biome == "Whisperwood":
		color = Color("64867a")
	color = color.lerp(Color("adba69"), clampf(_detail.get_noise_2dv(q) * 0.5 + 0.24, 0.0, 0.6))
	var path_mask: float = 1.0 - smoothstep(1.45, 2.5, trail_distance(p) / _scale_factor)
	path_mask = maxf(path_mask, (1.0 - smoothstep(-1.0, 0.5, clearing_distance(p) / _scale_factor)) * 0.82)
	color = color.lerp(Color("bbae7a"), path_mask)
	color = color.lerp(Color("c8c198"), 1.0 - smoothstep(0.3, 2.1, height / _scale_factor))
	return color

func _build_terrain() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride: int = terrain_resolution + 1
	for z in range(stride):
		for x in range(stride):
			var p: Vector2 = Vector2(float(x) / terrain_resolution - 0.5, float(z) / terrain_resolution - 0.5) * world_size
			var height: float = sample_height(p)
			surface.set_color(_terrain_color(p, height))
			surface.set_uv(p * 0.1)
			surface.add_vertex(Vector3(p.x, height, p.y))
	for z in range(terrain_resolution):
		for x in range(terrain_resolution):
			var a: int = z * stride + x
			for index: int in [a, a + 1, a + stride, a + 1, a + stride + 1, a + stride]:
				surface.add_index(index)
	surface.generate_normals()
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "WalkableTerrain"
	terrain.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	terrain.material_override = material
	_generated.add_child(terrain)
	if create_collisions:
		terrain.create_trimesh_collision()

func _build_water() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "LakeAndOcean"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE * world_size * 50.0
	water.mesh = plane
	water.position.y = 0.15 * _scale_factor
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(water)

func _build_landmarks() -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "MusicClearings"
	_generated.add_child(markers)
	for i in range(6):
		var site: Marker3D = Marker3D.new()
		site.name = "Site_%d_%s" % [i, SITE_NAMES[i].get_slice(" / ", 0)]
		site.position = sites[i]
		site.set_meta("site_id", i)
		site.set_meta("theme", SITE_NAMES[i])
		markers.add_child(site)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = SITE_COLORS[i]
		material.emission_enabled = true
		material.emission = SITE_COLORS[i]
		material.emission_energy_multiplier = 0.45
		_site_materials.append(material)
		_active_sites.append(false)
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 2.8 * _scale_factor
		torus.outer_radius = 2.88 * _scale_factor
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = material
		ring.position.y = 0.07
		site.add_child(ring)
		for j in range(8):
			var angle: float = j * TAU / 8.0
			var p: Vector2 = Vector2(sites[i].x, sites[i].z) + Vector2(cos(angle), sin(angle)) * 4.4 * _scale_factor
			_queue_asset("RockPath_Round_Small_%d" % (j % 3 + 1), p, 0.85 * _scale_factor, angle)
		# A distinctive kit tree just beyond each clearing, away from both trails.
		var landmark_angle: float = site_angle(i) + 0.17
		var tree_p: Vector2 = Vector2(cos(landmark_angle), sin(landmark_angle)) * 73.0 * _scale_factor
		var tree_name: String = "TwistedTree_3" if i >= 4 else "CommonTree_5"
		_queue_asset(tree_name, tree_p, (0.9 if i >= 4 else 1.65) * _scale_factor, -landmark_angle, true)
	var spawns: Node3D = Node3D.new()
	spawns.name = "PlayerSpawns"
	_generated.add_child(spawns)
	for i in range(spawn_points.size()):
		var marker: Marker3D = Marker3D.new()
		marker.name = "Player_%d" % (i + 1)
		marker.position = spawn_points[i]
		spawns.add_child(marker)
	# Central gathering place, paved with original kit stones.
	for i in range(14):
		var angle: float = TAU * i / 14.0
		_queue_asset("RockPath_Round_Wide", Vector2(cos(angle), sin(angle)) * 6.6 * _scale_factor, 0.8 * _scale_factor, angle)

func _scatter() -> void:
	var spacing: float = 5.8 / sqrt(vegetation_density) * _scale_factor
	var extent: int = ceili(world_size * 0.46 / spacing)
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var p: Vector2 = Vector2(x, z) * spacing + Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25)) * spacing
			if not _scatter_allowed(p, 5.0):
				continue
			var biome: String = biome_at(p)
			var chance: float = 0.70 if biome != "Sunmeadow" else 0.33
			if _rng.randf() > chance:
				continue
			var name_prefix: String = "CommonTree_"
			var size: float = _rng.randf_range(0.8, 1.45)
			if biome == "Pinewatch":
				name_prefix = "Pine_"
				size *= 1.18
			elif biome == "Whisperwood":
				name_prefix = "TwistedTree_"
				size *= 0.42
			_queue_asset(name_prefix + str(_rng.randi_range(1, 5)), p, size * _scale_factor, _rng.randf() * TAU, true)
			generation_stats["trees"] += 1
	for i in range(int(9000 * vegetation_density)):
		var p: Vector2 = Vector2(_rng.randf_range(-99, 99), _rng.randf_range(-99, 99)) * _scale_factor
		if not _scatter_allowed(p, 2.9):
			continue
		var biome: String = biome_at(p)
		var roll: float = _rng.randf()
		var asset: String = "Grass_Common_Short"
		var size: float = _rng.randf_range(0.45, 0.85)
		if roll < 0.045:
			asset = "Rock_Medium_%d" % _rng.randi_range(1, 3)
			size = _rng.randf_range(0.35, 0.9)
			generation_stats["rocks"] += 1
		elif roll < 0.09:
			asset = "Bush_Common_Flowers" if biome == "Sunmeadow" else "Bush_Common"
			size = _rng.randf_range(0.6, 1.05)
		elif roll < 0.18:
			asset = "Mushroom_Common" if biome == "Whisperwood" else "Fern_1"
			size = _rng.randf_range(0.45, 0.85)
		elif roll < 0.35:
			asset = "Flower_3_Group" if _detail.get_noise_2dv(p) > 0.0 else "Flower_4_Group"
		elif roll < 0.45:
			asset = "Clover_1"
		elif roll < 0.6:
			asset = "Grass_Wispy_Short"
		_queue_asset(asset, p, size * _scale_factor, _rng.randf() * TAU, roll < 0.045)
		generation_stats["plants"] += 1

func _scatter_allowed(p: Vector2, clearance: float) -> bool:
	if p.length() > world_size * 0.45 or sample_height(p) < 1.8 * _scale_factor:
		return false
	return trail_distance(p) > clearance * _scale_factor and clearing_distance(p) > 2.5 * _scale_factor and sample_normal(p).y > 0.86

func _queue_asset(asset: String, p: Vector2, size: float, yaw: float, solid: bool = false) -> void:
	# Spatial batches allow Godot to cull separate parts of the island.
	var cell: Vector2i = Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
	var key: String = "%s:%d:%d" % [asset, cell.x, cell.y]
	if not _batches.has(key):
		_batches[key] = {"asset": asset, "transforms": []}
	var position_local: Vector3 = Vector3(p.x, sample_height(p) - 0.035 * size, p.y)
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
	_batches[key]["transforms"].append(Transform3D(basis, position_local))
	generation_stats["instances"] += 1
	if solid and create_collisions:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = asset + "_Collision"
		body.position = position_local
		var collision: CollisionShape3D = CollisionShape3D.new()
		if asset.begins_with("Rock"):
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 1.05 * size
			collision.shape = sphere
			collision.position.y = 0.65 * size
		else:
			var cylinder: CylinderShape3D = CylinderShape3D.new()
			cylinder.radius = (0.95 if asset.begins_with("Twisted") else 0.32) * size
			cylinder.height = 3.0 * size
			collision.shape = cylinder
			collision.position.y = cylinder.height / 2.0
		body.add_child(collision)
		_generated.add_child(body)

func _asset_meshes(asset: String) -> Array:
	if _mesh_cache.has(asset):
		return _mesh_cache[asset]
	var path: String = KIT + asset + ".gltf"
	if not ResourceLoader.exists(path):
		push_error("Missing Nature MegaKit asset: " + path)
		return []
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return []
	var root: Node = scene.instantiate()
	var meshes: Array = []
	_collect_meshes(root, Transform3D.IDENTITY, meshes)
	root.free()
	_mesh_cache[asset] = meshes
	return meshes

func _collect_meshes(node: Node, parent_transform: Transform3D, meshes: Array) -> void:
	var local_transform: Transform3D = parent_transform
	if node is Node3D:
		local_transform *= (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			var mesh: Mesh = instance.mesh.duplicate() as Mesh
			for i in range(mesh.get_surface_count()):
				var material: Material = instance.get_active_material(i)
				if material != null:
					mesh.surface_set_material(i, material)
			meshes.append({"mesh": mesh, "transform": local_transform})
	for child in node.get_children():
		_collect_meshes(child, local_transform, meshes)

func _flush_batches() -> void:
	var foliage: Node3D = Node3D.new()
	foliage.name = "KitVegetation"
	_generated.add_child(foliage)
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var transforms: Array = batch["transforms"]
		for part: Dictionary in _asset_meshes(batch["asset"]):
			var multimesh: MultiMesh = MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part["mesh"]
			multimesh.instance_count = transforms.size()
			for i in range(transforms.size()):
				multimesh.set_instance_transform(i, transforms[i] * part["transform"])
			var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
			instance.name = key.replace(":", "_")
			instance.multimesh = multimesh
			var asset: String = batch["asset"]
			if not ("Tree" in asset or asset.begins_with("Pine") or asset.begins_with("Rock")):
				instance.visibility_range_end = 85.0 * _scale_factor
				instance.visibility_range_end_margin = 12.0
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			foliage.add_child(instance)
			generation_stats["batches"] += 1
