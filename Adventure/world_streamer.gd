extends RefCounted
## Visual detail follows this client; gameplay collision follows every server player.
var world: Node3D
var visual_chunks: Dictionary={}
var physics_chunks: Dictionary={}
var visual_root: Node3D
var physics_root: Node3D
var far_root: Node3D
var last_view: Vector2i=Vector2i(9999,9999)
var view_radius: int=3

static func cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/64),floori(p.z/64))

func setup(value: Node3D) -> void:
	world=value
	visual_root=Node3D.new(); visual_root.name="StreamedVegetation"; world._root.add_child(visual_root)
	physics_root=Node3D.new(); physics_root.name="ActiveGameplayChunks"; world._root.add_child(physics_root)
	far_root=Node3D.new(); far_root.name="DistantForestCanopies"; world._root.add_child(far_root)
	world.make_far_canopies(far_root)
	update(world.spawn_position(0),[world.spawn_position(0)])

func update(view: Vector3, players: Array) -> void:
	var center: Vector2i=cell(view)
	if center!=last_view:
		last_view=center
		var wanted: Dictionary={}
		for z in range(-view_radius,view_radius+1):
			for x in range(-view_radius,view_radius+1): wanted[center+Vector2i(x,z)]=true
		for key: Vector2i in visual_chunks.keys():
			if not wanted.has(key):
				var node: Node3D=visual_chunks[key]; visual_root.remove_child(node); node.queue_free(); visual_chunks.erase(key)
				for batch_key: String in world.batch_cells.get(key,[]):
					for id: String in world.placements[batch_key]["resources"]:
						if not id.is_empty(): world.resource_visuals.erase(id)
		for key: Vector2i in wanted:
			if visual_chunks.has(key) or not world.batch_cells.has(key): continue
			var node: Node3D=Node3D.new(); node.name="Visual_%d_%d" % [key.x,key.y]; visual_root.add_child(node); visual_chunks[key]=node
			for batch_key: String in world.batch_cells[key]: world.make_batch(world.placements[batch_key],node,false)
	var required: Dictionary={}
	for p: Vector3 in players:
		var origin: Vector2i=cell(p)
		for z in range(-1,2):
			for x in range(-1,2): required[origin+Vector2i(x,z)]=true
	for key: Vector2i in physics_chunks.keys():
		if not required.has(key):
			var node: Node3D=physics_chunks[key]; physics_root.remove_child(node); node.queue_free(); physics_chunks.erase(key)
			for def: Dictionary in world.solid_cells.get(key,[]): world.resource_colliders.erase(def["id"])
	for key: Vector2i in required:
		if physics_chunks.has(key): continue
		var node: Node3D=Node3D.new(); node.name="Physics_%d_%d" % [key.x,key.y]; physics_root.add_child(node); physics_chunks[key]=node
		if world.terrain_cells.has(key):
			var terrain: MeshInstance3D=world.terrain_cells[key]
			var body: StaticBody3D=StaticBody3D.new(); var shape: CollisionShape3D=CollisionShape3D.new()
			shape.shape=terrain.mesh.create_trimesh_shape(); body.add_child(shape); node.add_child(body)
		for def: Dictionary in world.solid_cells.get(key,[]):
			if int(world.changed_resources.get(def["id"],1))<=0: continue
			var body: StaticBody3D=StaticBody3D.new(); body.position=def["p"]; body.set_meta("resource_id",def["id"])
			var collision: CollisionShape3D=CollisionShape3D.new(); var shape: CylinderShape3D=CylinderShape3D.new()
			shape.radius=def["radius"]; shape.height=def["height"]; collision.shape=shape; body.add_child(collision); node.add_child(body)
			world.resource_colliders[def["id"]]=body
	world.stream_structures(view,players)

func reset() -> void:
	last_view=Vector2i(9999,9999)
	for node: Node3D in physics_chunks.values(): physics_root.remove_child(node); node.queue_free()
	physics_chunks.clear(); world.resource_colliders.clear()
