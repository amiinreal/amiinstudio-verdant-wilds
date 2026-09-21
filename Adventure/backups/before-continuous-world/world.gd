extends Node3D
const Rules := preload("res://Adventure/rules.gd")
const KIT: String = "res://styled Nature megaKit/glTF/"
const WATER := preload("res://Adventure/water.gdshader")
var seed_value: int = 73129
var shrines: Array[Node3D] = []
var bridges: Array[Node3D] = []
var treasures: Array[Node3D] = []
var sentinels: Array[Node3D] = []
var terrain_meshes: Array[MeshInstance3D] = []
var placements: Dictionary = {}
var _cache: Dictionary = {}
var _noise: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _root: Node3D
var _materials: Array[StandardMaterial3D] = []
var _reveal_until: float = 0.0
var _stun_until: float = 0.0
var _time: float = 0.0
var _solved: Array = []

func build(new_seed: int) -> void:
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "GeneratedArchipelago"
	add_child(_root)
	seed_value = new_seed
	_noise.seed = seed_value
	_noise.frequency = 0.045
	_noise.fractal_octaves = 3
	_rng.seed = seed_value
	shrines.clear()
	bridges.clear()
	treasures.clear()
	sentinels.clear()
	terrain_meshes.clear()
	_materials.clear()
	placements.clear()
	_solved = [false, false, false, false, false, false, false]
	_reveal_until = 0
	_stun_until = 0
	for i in range(7):
		_build_island(i)
		_build_shrine(i)
		_scatter_island(i)
		for j in range(3):
			_build_treasure(i, j)
		if i == 4 or i == 5:
			_build_sentinel(i)
	for edge: Vector3i in Rules.EDGES:
		_build_bridge(edge)
	_flush_instances()
	var ocean: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	ocean.mesh = plane
	ocean.position.y = -1.2
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER
	ocean.material_override = water
	_root.add_child(ocean)
	print("ARCHIPELAGO seed=", seed_value, " islands=7 asset_batches=", placements.size())

func height_at(p: Vector2, island: int = -1) -> float:
	if island < 0:
		island = nearest_island(p)
	var q: Vector2 = p - Rules.CENTERS[island]
	var radius: float = q.length()
	var height: float = 3.8 + _noise.get_noise_2dv(p) * 3.5
	var route_distance: float = q.length()
	for edge: Vector3i in Rules.EDGES:
		if edge.x != island and edge.y != island:
			continue
		var other: int = edge.y if edge.x == island else edge.x
		var end: Vector2 = (Rules.CENTERS[other] - Rules.CENTERS[island]).normalized() * 40.0
		var closest: Vector2 = end * clampf(q.dot(end) / end.length_squared(), 0, 1)
		route_distance = minf(route_distance, q.distance_to(closest))
	height = lerpf(height, 3.8, 1.0 - smoothstep(2.8, 6.0, route_distance))
	height = lerpf(height, 3.8, 1.0 - smoothstep(8.0, 13.0, radius))
	var coast: float = 33.5 + _noise.get_noise_2dv(p * 1.7) * 3.5
	return lerpf(height, -7.0, smoothstep(coast - 3, coast + 6, radius))

func nearest_island(p: Vector2) -> int:
	var best: int = 0
	for i in range(1, 7):
		if p.distance_squared_to(Rules.CENTERS[i]) < p.distance_squared_to(Rules.CENTERS[best]):
			best = i
	return best

func shrine_position(index: int) -> Vector3:
	var p: Vector2 = Rules.CENTERS[index]
	return Vector3(p.x, 3.8, p.y)

func spawn_position(index: int, slot: int = 0) -> Vector3:
	return shrine_position(index) + Vector3((slot % 3 - 1) * 1.5, 0.5, 5.5 + (slot / 3) * 1.6)

func _path_distance(q: Vector2, island: int) -> float:
	var distance: float = q.length()
	for edge: Vector3i in Rules.EDGES:
		if edge.x == island or edge.y == island:
			var other: int = edge.y if edge.x == island else edge.x
			var end: Vector2 = (Rules.CENTERS[other] - Rules.CENTERS[island]).normalized() * 40.0
			distance = minf(distance, q.distance_to(end * clampf(q.dot(end) / end.length_squared(), 0, 1)))
	return distance

func _build_island(index: int) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_colors: Array[Color] = [Color("829b50"), Color("678855"), Color("78a59a"), Color("909978"), Color("8f8161"), Color("747a9c"), Color("88af74")]
	for z in range(65):
		for x in range(65):
			var q: Vector2 = Vector2(x - 32, z - 32) * 1.35
			var p: Vector2 = q + Rules.CENTERS[index]
			var h: float = height_at(p, index)
			var color: Color = base_colors[index].lerp(Color("b4b777"), clampf(_noise.get_noise_2dv(p * 3) + 0.15, 0, 0.5))
			color = color.lerp(Color("bca77a"), 1.0 - smoothstep(1.6, 3.1, _path_distance(q, index)))
			color = color.lerp(Color("c5b991"), 1.0 - smoothstep(-0.5, 2, h))
			surface.set_color(color)
			surface.add_vertex(Vector3(p.x, h, p.y))
	for z in range(64):
		for x in range(64):
			var a: int = z * 65 + x
			for v: int in [a, a + 1, a + 65, a + 1, a + 66, a + 65]:
				surface.add_index(v)
	surface.generate_normals()
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "Island_%d" % index
	terrain.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	terrain.material_override = material
	_root.add_child(terrain)
	terrain.create_trimesh_collision()
	terrain_meshes.append(terrain)

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func mesh_node(mesh: Mesh, mat: Material, parent: Node3D, p: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = p
	parent.add_child(instance)
	return instance

func _build_shrine(index: int) -> void:
	var shrine: Node3D = Node3D.new()
	shrine.name = "Shrine_%d" % index
	shrine.position = shrine_position(index)
	_root.add_child(shrine)
	shrines.append(shrine)
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 2.3
	cylinder.bottom_radius = 2.6
	cylinder.height = 0.25
	mesh_node(cylinder, material(Color("61766c")), shrine, Vector3(0, 0.04, 0))
	var mat: StandardMaterial3D = material(Rules.COLORS[index % 5], 0.5)
	_materials.append(mat)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 2.2
	ring.outer_radius = 2.32
	mesh_node(ring, mat, shrine, Vector3(0, 0.2, 0))
	var crystal: PrismMesh = PrismMesh.new()
	crystal.size = Vector3(0.7, 1.4, 0.7)
	var rune: MeshInstance3D = mesh_node(crystal, mat, shrine, Vector3(0, 1.8, 0))
	rune.name = "HeartRune"
	var label: Label3D = Label3D.new()
	label.text = Rules.NAMES[index]
	label.font_size = 34
	label.outline_size = 7
	label.pixel_size = 0.008
	label.position = Vector3(0, 4.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("efe6bf")
	shrine.add_child(label)
	var phrase: Array = Rules.melodies(seed_value)[index]
	for j in range(phrase.size()):
		var rock: BoxMesh = BoxMesh.new()
		rock.size = Vector3(0.7, 0.8 + phrase[j] * 0.2, 0.7)
		var node: MeshInstance3D = mesh_node(rock, material(Rules.COLORS[phrase[j]], 0.18), shrine, Vector3((j - (phrase.size() - 1) / 2.0) * 1.1, rock.size.y / 2, -3.1))
		var glyph: Label3D = Label3D.new()
		glyph.text = str(phrase[j] + 1)
		glyph.font_size = 54
		glyph.pixel_size = 0.009
		glyph.position.y = rock.size.y / 2 + 0.45
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(glyph)
	_queue("RockPath_Round_Wide", Rules.CENTERS[index] + Vector2(0, 3), 1.0, 0)
	if index == 6:
		_queue("TwistedTree_5", Rules.CENTERS[index] + Vector2(0, -9), 1.2, PI)

func _build_bridge(edge: Vector3i) -> void:
	var start: Vector2 = Rules.CENTERS[edge.x]
	var end: Vector2 = Rules.CENTERS[edge.y]
	var direction: Vector2 = (end - start).normalized()
	var a: Vector2 = start + direction * 27
	var b: Vector2 = end - direction * 27
	var bridge: Node3D = Node3D.new()
	bridge.name = "SongBridge_%d_%d" % [edge.x, edge.y]
	bridge.position = Vector3((a.x + b.x) / 2, 3.6, (a.y + b.y) / 2)
	bridge.rotation.y = -direction.angle() + PI / 2
	var length: float = a.distance_to(b)
	var deck: BoxMesh = BoxMesh.new()
	deck.size = Vector3(4.5, 0.4, length + 2)
	mesh_node(deck, material(Color("6d8b64")), bridge, Vector3.ZERO)
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = deck.size
	shape.shape = box
	body.add_child(shape)
	bridge.add_child(body)
	for side: float in [-2.1, 2.1]:
		var rail: BoxMesh = BoxMesh.new()
		rail.size = Vector3(0.18, 0.18, length + 2)
		mesh_node(rail, material(Color("b9c08b")), bridge, Vector3(side, 0.75, 0))
		var rail_body: StaticBody3D = StaticBody3D.new()
		var rail_collision: CollisionShape3D = CollisionShape3D.new()
		var rail_box: BoxShape3D = BoxShape3D.new()
		rail_box.size = Vector3(0.2, 1.3, length + 2)
		rail_collision.shape = rail_box
		rail_collision.position = Vector3(side, 0.6, 0)
		rail_body.add_child(rail_collision)
		bridge.add_child(rail_body)
	for step in range(int(length / 2)):
		var plank: BoxMesh = BoxMesh.new()
		plank.size = Vector3(4.35, 0.09, 0.75)
		mesh_node(plank, material(Color("a6ab79")), bridge, Vector3(0, 0.23, -length / 2 + step * 2 + 1))
	_root.add_child(bridge)
	bridges.append(bridge)
	_set_bridge(bridge, false, false)
	for p: Vector2 in [a, b]:
		_queue("Rock_Medium_2", p + direction.orthogonal() * 3.1, 0.85, direction.angle())

func _set_bridge(bridge: Node3D, active: bool, animate: bool) -> void:
	bridge.visible = active
	for body: Node in bridge.get_children():
		if body is StaticBody3D:
			(body as StaticBody3D).collision_layer = 1 if active else 0
	if active and animate:
		bridge.position.y = -1.0
		create_tween().tween_property(bridge, "position:y", 3.6, 1.8).set_trans(Tween.TRANS_SINE)

func apply_state(state: Dictionary, animate: bool = true) -> void:
	var previous: Array = _solved.duplicate()
	_solved = state["solved"].duplicate()
	for i in range(7):
		_materials[i].emission_energy_multiplier = 2.2 if _solved[i] else 0.5
		if _solved[i] and not previous[i] and animate:
			pulse(shrine_position(i), Rules.COLORS[i % 5], 12)
	for i in range(bridges.size()):
		var gate: int = Rules.EDGES[i].z
		_set_bridge(bridges[i], _solved[gate], animate and _solved[gate] and not previous[gate])
	for treasure: Node3D in treasures:
		var collected: bool = int(treasure.get_meta("id")) in state["collected"]
		treasure.set_meta("collected", collected)
		treasure.visible = not collected and (not treasure.get_meta("hidden") or _time < _reveal_until)

func _build_treasure(island: int, index: int) -> void:
	var angle: float = float(index) * TAU / 3.0 + 0.5
	var p: Vector2 = Rules.CENTERS[island] + Vector2(cos(angle), sin(angle)) * 16
	var treasure: Node3D = Node3D.new()
	treasure.name = "Memory_%d" % (island * 3 + index)
	treasure.position = Vector3(p.x, height_at(p, island) + 1.0, p.y)
	treasure.set_meta("id", island * 3 + index)
	treasure.set_meta("hidden", index == 2)
	treasure.set_meta("collected", false)
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.6, 1.1, 0.6)
	mesh_node(prism, material(Color("ffe5a4"), 1.8), treasure, Vector3.ZERO)
	_root.add_child(treasure)
	treasures.append(treasure)
	treasure.visible = index != 2

func _build_sentinel(island: int) -> void:
	var sentinel: Node3D = Node3D.new()
	sentinel.name = "Discord_%d" % island
	sentinel.set_meta("island", island)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	mesh_node(sphere, material(Color("4c334e")), sentinel, Vector3.ZERO)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	mesh_node(ring, material(Color("ef819c"), 1.8), sentinel, Vector3.ZERO)
	_root.add_child(sentinel)
	sentinels.append(sentinel)

func _scatter_island(index: int) -> void:
	for z in range(-6, 7):
		for x in range(-6, 7):
			var q: Vector2 = Vector2(x * 5, z * 5) + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
			if q.length() > 29 or q.length() < 11 or _path_distance(q, index) < 4.8 or _rng.randf() > 0.72:
				continue
			var asset: String = "CommonTree_%d" % _rng.randi_range(1, 5)
			var size: float = _rng.randf_range(0.85, 1.3)
			if index == 1 or index == 3:
				asset = "Pine_%d" % _rng.randi_range(1, 5)
			elif index == 4 or index == 5:
				asset = "TwistedTree_%d" % _rng.randi_range(1, 5)
				size *= 0.45
			var p: Vector2 = Rules.CENTERS[index] + q
			_queue(asset, p, size, _rng.randf() * TAU)
			var body: StaticBody3D = StaticBody3D.new()
			body.position = Vector3(p.x, height_at(p, index) + 1.3, p.y)
			var collision: CollisionShape3D = CollisionShape3D.new()
			var cylinder: CylinderShape3D = CylinderShape3D.new()
			cylinder.radius = 0.4
			cylinder.height = 2.6
			collision.shape = cylinder
			body.add_child(collision)
			_root.add_child(body)
	for i in range(650):
		var q: Vector2 = Vector2(_rng.randf_range(-29, 29), _rng.randf_range(-29, 29))
		if q.length() > 29 or q.length() < 7 or _path_distance(q, index) < 2.8:
			continue
		var options: Array[String] = ["Grass_Common_Short", "Grass_Wispy_Short", "Flower_3_Group", "Flower_4_Group", "Fern_1", "Bush_Common_Flowers", "Mushroom_Common", "Rock_Medium_1"]
		var asset: String = options[_rng.randi_range(0, options.size() - 1)]
		_queue(asset, q + Rules.CENTERS[index], _rng.randf_range(0.35, 0.75), _rng.randf() * TAU)

func _queue(asset: String, p: Vector2, size: float, yaw: float) -> void:
	var key: String = "%s:%d" % [asset, nearest_island(p)]
	if not placements.has(key):
		placements[key] = {"asset": asset, "transforms": []}
	placements[key]["transforms"].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), Vector3(p.x, height_at(p) - 0.03, p.y)))

func _meshes(asset: String) -> Array:
	if _cache.has(asset):
		return _cache[asset]
	var scene: PackedScene = load(KIT + asset + ".gltf") as PackedScene
	if scene == null:
		push_error("Missing kit asset " + asset)
		return []
	var root: Node = scene.instantiate()
	var parts: Array = []
	_collect(root, Transform3D.IDENTITY, parts)
	root.free()
	_cache[asset] = parts
	return parts

func _collect(node: Node, transform_so_far: Transform3D, parts: Array) -> void:
	var t: Transform3D = transform_so_far
	if node is Node3D:
		t *= (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		parts.append({"mesh": instance.mesh, "transform": t})
	for child: Node in node.get_children():
		_collect(child, t, parts)

func _flush_instances() -> void:
	for key: String in placements:
		var batch: Dictionary = placements[key]
		for part: Dictionary in _meshes(batch["asset"]):
			var multi: MultiMesh = MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = part["mesh"]
			multi.instance_count = batch["transforms"].size()
			for i in range(multi.instance_count):
				multi.set_instance_transform(i, batch["transforms"][i] * part["transform"])
			var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
			node.multimesh = multi
			if not ("Tree" in batch["asset"] or "Pine" in batch["asset"]):
				node.visibility_range_end = 100
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(node)

func pulse(p: Vector3, color: Color, radius: float = 5.0) -> void:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	var node: MeshInstance3D = mesh_node(ring, material(color, 1.7), _root, p + Vector3.UP * 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector3(radius, 0.2, radius), 0.8)
	tween.tween_callback(node.queue_free)

func reveal() -> void:
	_reveal_until = _time + 15

func ward() -> void:
	_stun_until = _time + 8

func is_revealed() -> bool:
	return _time < _reveal_until

func is_stunned() -> bool:
	return _time < _stun_until

func tick(delta: float, server_time: float) -> void:
	_time = server_time
	for i in range(shrines.size()):
		var rune: Node3D = shrines[i].get_node("HeartRune")
		rune.rotation.y += delta * 0.6
		rune.position.y = 1.8 + sin(_time * 1.8 + i) * 0.16
	for treasure: Node3D in treasures:
		treasure.rotation.y += delta
		treasure.visible = not treasure.get_meta("collected") and (not treasure.get_meta("hidden") or is_revealed())
	for sentinel: Node3D in sentinels:
		var island: int = sentinel.get_meta("island")
		var angle: float = _time * 0.32 + island
		var p: Vector2 = Rules.CENTERS[island] + Vector2(cos(angle), sin(angle)) * 15.0
		sentinel.position = Vector3(p.x, height_at(p, island) + 1.6, p.y)
		sentinel.visible = not _solved[island]
		sentinel.rotation.z = 0.8 if is_stunned() else 0
