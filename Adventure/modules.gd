extends RefCounted
## Native Medieval Village MegaKit pieces: 2 m bays, 3 m storeys, 90-degree joins.
const KIT: String = "res://Medieval Village Megakit/glTF/"
const GRID: float = 2.0
const STOREY: float = 3.0
static var _definitions: Dictionary={}
static var _catalog: Dictionary = {}
static var _scenes: Dictionary = {}

static func catalog() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	refresh_catalog()
	return _catalog

## Re-scans res://Adventure/data/buildings from disk. catalog() only does this once per
## process lifetime (cached after the first call), so a piece added after the game was
## already running would silently never show up in the Build menu until a full restart.
## build_catalog.gd calls this every time the Build panel opens instead.
static func refresh_catalog() -> void:
	_definitions.clear()
	_catalog.clear()
	for file: String in DirAccess.get_files_at("res://Adventure/data/buildings"):
		# An exported build's .pck stores a converted resource as "name.tres.remap" (the
		# actual binary data lives elsewhere; the .remap file is what a directory listing
		# sees), so matching only ".tres" always found nothing outside the editor and the
		# catalog silently came back empty ("No matching pieces.") in every shipped build.
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")): continue
		var data: Resource=load("res://Adventure/data/buildings/"+file.trim_suffix(".remap"))
		_definitions[data.id]={"id":data.id,"label":data.display_name,"asset":data.scene.resource_path,"kind":data.snap_type,"footprint":data.footprint,"cost":data.resource_cost,"offset":data.offset,"data":data}
	for id: String in _definitions:
		if id not in ["roof_small","roof_square","roof_long","roof_corner"]: _catalog[id]=_definitions[id]

static func definition(id: String) -> Dictionary:
	catalog()
	return _definitions.get(id, {})

static func native_asset(asset: String) -> Node3D:
	if not _scenes.has(asset):
		_scenes[asset] = load(asset if asset.begins_with("res://") else KIT + asset + ".gltf") as PackedScene
	var scene: PackedScene = _scenes[asset]
	return scene.instantiate() as Node3D if scene != null else Node3D.new()

static func visual(module_id: String) -> Node3D:
	if module_id.begins_with("roof_panel_"): return preload("res://Adventure/roof_panels.gd").visual(module_id)
	var spec: Dictionary = definition(module_id)
	var result: Node3D = Node3D.new()
	if spec.is_empty():
		return result
	var part: Node3D = native_asset(spec["asset"])
	part.position = spec["offset"]
	result.add_child(part)
	return result

static func cells(module_id: String, p: Vector3, quarter_turns: int) -> Array[Vector2i]:
	var size: Vector2i = definition(module_id).get("footprint", Vector2i.ONE)
	if posmod(quarter_turns, 2) == 1:
		size = Vector2i(size.y, size.x)
	var result: Array[Vector2i] = []
	var first: Vector2 = Vector2(p.x, p.z) - Vector2(size - Vector2i.ONE)
	for z in range(size.y):
		for x in range(size.x):
			result.append(Vector2i(roundi((first.x + x * 2) / 2), roundi((first.y + z * 2) / 2)))
	return result

static func collider(node: Node3D, module_id: String) -> void:
	var kind: String = definition(module_id)["kind"]
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	node.add_child(body)
	# Keep door/window holes and native stairs, rather than blocking them with a box.
	if kind=="stairs":
		# A smooth walking surface over the native treads, matching the 3 m rise.
		var faces: PackedVector3Array=PackedVector3Array([Vector3(-0.86,3,-2.35),Vector3(0.86,3,-2.35),Vector3(-0.86,0.04,2.35),Vector3(0.86,3,-2.35),Vector3(0.86,0.04,2.35),Vector3(-0.86,0.04,2.35)])
		var shape: CollisionShape3D=CollisionShape3D.new(); var concave: ConcavePolygonShape3D=ConcavePolygonShape3D.new()
		concave.set_faces(faces); shape.shape=concave; body.add_child(shape)
	elif kind in ["wall", "door", "window", "roof", "roof_panel", "fence", "decoration", "balcony", "chimney"]:
		_mesh_colliders(node, body, Transform3D.IDENTITY)
	else:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(2, 0.18, 2) if kind in ["foundation", "floor"] else Vector3(0.2, 3, 0.2)
		shape.shape = box
		shape.position.y = -0.09 if kind in ["foundation", "floor"] else 1.5
		if kind in ["corner", "support", "foundation", "floor"]:
			body.add_child(shape)
		else:
			shape.free()

static func _mesh_colliders(node: Node, body: StaticBody3D, inherited: Transform3D) -> void:
	for child: Node in node.get_children():
		if child == body:
			continue
		var t: Transform3D = inherited
		if child is Node3D:
			t *= (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.shape = (child as MeshInstance3D).mesh.create_trimesh_shape()
			shape.transform = t
			body.add_child(shape)
		_mesh_colliders(child, body, t)

static func update_foundation_supports(node: Node3D, world: Node3D) -> void:
	var feet: Node3D=node.get_node_or_null("FoundationFeet") as Node3D
	if feet==null:
		feet=Node3D.new(); feet.name="FoundationFeet"; node.add_child(feet)
		for x: float in [-0.85,0.85]:
			for z: float in [-0.85,0.85]:
				var support: Node3D=native_asset("Corner_Exterior_Brick"); support.position=Vector3(x,0,z); feet.add_child(support)
	for support: Node3D in feet.get_children():
		var offset: Vector3=node.basis*Vector3(support.position.x,0,support.position.z)
		var ground: float=world.height_at(Vector2(node.position.x+offset.x,node.position.z+offset.z))
		support.position.y=ground-node.position.y
		support.scale.y=maxf(0.04,(node.position.y-ground)/3)
