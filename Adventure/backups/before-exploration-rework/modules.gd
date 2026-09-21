extends RefCounted
## Native Medieval Village MegaKit pieces: 2 m bays, 3 m storeys, 90-degree joins.
const KIT: String = "res://Medieval Village Megakit/glTF/"
const GRID: float = 2.0
const STOREY: float = 3.0
static var _catalog: Dictionary = {}
static var _scenes: Dictionary = {}

static func catalog() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	_add("foundation_stone", "Stone foundation", "Floor_Brick", "foundation", Vector2i(1, 1), {"stone": 6, "wood": 2})
	_add("foundation_wood", "Timber foundation", "Floor_WoodDark", "foundation", Vector2i(1, 1), {"wood": 6, "stone": 2})
	_add("floor_oak", "Oak floor", "Floor_WoodLight", "floor", Vector2i.ONE, {"planks": 3})
	_add("floor_dark", "Dark timber floor", "Floor_WoodDark", "floor", Vector2i.ONE, {"planks": 3})
	_add("floor_brick", "Brick floor", "Floor_RedBrick", "floor", Vector2i.ONE, {"stone": 4})
	_add("wall_plaster", "Plaster wall", "Wall_Plaster_Straight", "wall", Vector2i.ONE, {"wood": 3, "stone": 2, "fiber": 1})
	_add("wall_brick", "Stone wall", "Wall_UnevenBrick_Straight", "wall", Vector2i.ONE, {"stone": 5})
	_add("wall_timber", "Timber lattice wall", "Wall_Plaster_WoodGrid", "wall", Vector2i.ONE, {"wood": 5, "fiber": 2})
	_add("door_flat", "Flat doorway", "Wall_Plaster_Door_Flat", "door", Vector2i.ONE, {"wood": 4, "stone": 2})
	_add("door_round", "Round stone doorway", "Wall_UnevenBrick_Door_Round", "door", Vector2i.ONE, {"stone": 4, "wood": 2})
	_add("window_wide", "Wide window wall", "Wall_Plaster_Window_Wide_Flat", "window", Vector2i.ONE, {"wood": 4, "stone": 2})
	_add("window_round", "Round window wall", "Wall_UnevenBrick_Window_Thin_Round", "window", Vector2i.ONE, {"stone": 4, "wood": 2})
	_add("corner_wood", "Timber corner", "Corner_Exterior_Wood", "corner", Vector2i.ONE, {"wood": 2})
	_add("corner_stone", "Stone corner", "Corner_Exterior_Brick", "corner", Vector2i.ONE, {"stone": 3})
	_add("beam", "Support post", "Corner_Exterior_Wood", "support", Vector2i.ONE, {"wood": 3})
	_add("roof_small", "2 × 4 tiled roof", "Roof_2x4_RoundTile", "roof", Vector2i(1, 2), {"wood": 6, "stone": 5})
	_add("roof_square", "4 × 4 tiled roof", "Roof_RoundTiles_4x4", "roof", Vector2i(2, 2), {"wood": 10, "stone": 8})
	_add("roof_long", "4 × 6 tiled roof", "Roof_RoundTiles_4x6", "roof", Vector2i(2, 3), {"wood": 14, "stone": 10})
	_add("roof_corner", "Timber eave corner", "Roof_Wooden_2x1_Corner", "roof_trim", Vector2i.ONE, {"wood": 2})
	_add("roof_trim", "Timber eave section", "Roof_Wooden_2x1_Center", "roof_trim", Vector2i.ONE, {"wood": 2})
	_add("chimney", "Brick chimney", "Prop_Chimney", "chimney", Vector2i.ONE, {"stone": 7})
	_add("chimney_tall", "Tall chimney", "Prop_Chimney2", "chimney", Vector2i.ONE, {"stone": 9})
	_add("stairs", "Interior stairs", "Stair_Interior_Solid", "stairs", Vector2i(1, 3), {"planks": 7, "wood": 3})
	_catalog["stairs"]["offset"] = Vector3(0, 0.02, 2)
	_add("balcony", "Balcony rail", "Balcony_Simple_Straight", "balcony", Vector2i.ONE, {"planks": 3, "wood": 2})
	_add("balcony_corner", "Balcony corner", "Balcony_Cross_Corner", "balcony", Vector2i.ONE, {"wood": 4})
	_add("fence", "Timber fence", "Prop_WoodenFence_Single", "fence", Vector2i.ONE, {"wood": 3})
	_add("fence_ornate", "Metal fence", "Prop_MetalFence_Ornament", "fence", Vector2i.ONE, {"stone": 3, "wood": 2})
	_add("crate", "Storage decoration", "Prop_Crate", "decoration", Vector2i.ONE, {"planks": 2})
	_add("vine", "Exterior vine", "Prop_Vine4", "wall_decoration", Vector2i.ONE, {"fiber": 3})
	return _catalog

static func _add(id: String, label: String, asset: String, kind: String, footprint: Vector2i, cost: Dictionary) -> void:
	_catalog[id] = {"id": id, "label": label, "asset": asset, "kind": kind, "footprint": footprint, "cost": cost, "offset": Vector3.ZERO}

static func definition(id: String) -> Dictionary:
	return catalog().get(id, {})

static func native_asset(asset: String) -> Node3D:
	if not _scenes.has(asset):
		_scenes[asset] = load(KIT + asset + ".gltf") as PackedScene
	var scene: PackedScene = _scenes[asset]
	return scene.instantiate() as Node3D if scene != null else Node3D.new()

static func visual(module_id: String) -> Node3D:
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
	elif kind in ["wall", "door", "window", "roof", "fence"]:
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
