extends "res://Adventure/environment_base.gd"
const Geo := preload("res://Adventure/geography.gd")
const Modules := preload("res://Adventure/modules.gd")
const Effects := preload("res://Adventure/effects.gd")
const Nature := preload("res://Adventure/nature_library.gd")
const Ecology := preload("res://Adventure/ecology.gd")
const Streamer := preload("res://Adventure/world_streamer.gd")
const WIND := preload("res://Adventure/wind.gdshader")
var meadow: Node3D
var wildlife: Node3D
var farmland_view: Node3D
var cooking_stations: Array[Vector3] = []
var terrain_edits: Dictionary={}
var extra_resource_nodes: Dictionary={}
var wind_materials: Array[ShaderMaterial]=[]
var grass_clearings: Dictionary={}
var grass_mask_image: Image
var grass_base: Image
var grass_mask: ImageTexture
var _structure_signature: String=""
var splash_times: Dictionary={}
var water_states: Dictionary={}
var practical_lights: Array[OmniLight3D]=[]
var rotors: Array[Node3D]=[]
var lantern_time: float=0
var streamer: RefCounted
var batch_cells: Dictionary={}
var solid_cells: Dictionary={}
var terrain_cells: Dictionary={}
var changed_resources: Dictionary={}
var far_visuals: Dictionary={}
var structure_records: Array=[]
var _far_cache: Dictionary={}
var _view_position: Vector3=Vector3.ZERO
var _simulation_positions: Array=[]
var geography: RefCounted = Geo.new()
var resources: Dictionary = {}
var resource_visuals: Dictionary = {}
var resource_colliders: Dictionary = {}
var placed_root: Node3D
var placed_nodes: Dictionary = {}
var map_texture: ImageTexture
var generation_seconds: float = 0

func build(new_seed: int,landscape_version: int=2) -> void:
	var began: int = Time.get_ticks_msec()
	hide()
	preload("res://Adventure/loading_screen.gd").show_progress(5,"Preparing the landscape…")
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "ContinuousMainland"
	add_child(_root)
	seed_value = new_seed
	_rng.seed = seed_value
	geography.landscape_version=landscape_version
	geography.generate(seed_value)
	terrain_edits.clear(); extra_resource_nodes.clear()
	shrines.clear(); bridges.clear(); treasures.clear(); sentinels.clear()
	terrain_meshes.clear(); _materials.clear(); placements.clear()
	resources.clear(); resource_visuals.clear(); resource_colliders.clear(); placed_nodes.clear()
	practical_lights.clear(); rotors.clear(); wind_materials.clear(); _cache.clear(); _far_cache.clear(); splash_times.clear(); water_states.clear()
	batch_cells.clear(); solid_cells.clear(); terrain_cells.clear(); changed_resources.clear(); far_visuals.clear(); structure_records.clear(); grass_clearings.clear()
	_solved = [false,false,false,false,false,false,false]
	_reveal_until = 0
	_stun_until = 0
	preload("res://Adventure/loading_screen.gd").show_progress(36,"Building terrain surfaces…")
	_build_mainland()
	preload("res://Adventure/loading_screen.gd").show_progress(44,"Placing rivers, villages and bridges…")
	_build_watershed()
	for bridge: Dictionary in geography.bridge_defs: _normal_bridge(bridge)
	_settlements()
	_discoveries()
	_dress_locations()
	preload("res://Adventure/loading_screen.gd").show_progress(50,"Growing woodland and gathering resources…")
	var cached: Variant=preload("res://Adventure/generation_cache.gd").read_data("ecology",seed_value,landscape_version)
	if cached is Dictionary and cached.has_all(["placements","resources","solid_cells","batch_cells"]):
		placements=cached.placements; resources=cached.resources; solid_cells=cached.solid_cells; batch_cells=cached.batch_cells
	else:
		_vegetation()
		preload("res://Adventure/generation_cache.gd").write_data("ecology",seed_value,landscape_version,{"placements":placements,"resources":resources,"solid_cells":solid_cells,"batch_cells":batch_cells})
	preload("res://Adventure/loading_screen.gd").show_progress(76,"Preparing grass and building sites…")
	_create_grass_mask()
	meadow=Node3D.new(); meadow.set_script(preload("res://Adventure/meadow.gd")); _root.add_child(meadow); meadow.setup(self)
	placed_root = Node3D.new()
	placed_root.name = "PlayerConstruction"
	_root.add_child(placed_root)
	preload("res://Adventure/loading_screen.gd").show_progress(82,"Loading nearby models and collision…")
	_flush_instances()
	cooking_stations.clear()
	var cooking: Node3D = Node3D.new()
	cooking.set_script(preload("res://Adventure/cooking/village_cooking.gd"))
	_root.add_child(cooking)
	cooking.setup(self)
	_update_grass_mask()
	var animals: Node3D = Node3D.new()
	animals.set_script(preload("res://Adventure/animals/population.gd"))
	_root.add_child(animals)
	animals.setup(self)
	wildlife = animals
	var farmland: Node3D = Node3D.new()
	farmland.set_script(preload("res://Adventure/farming/farmland_view.gd"))
	_root.add_child(farmland)
	farmland_view = farmland
	preload("res://Adventure/loading_screen.gd").show_progress(95,"Drawing the map…")
	_map_image()
	show()
	preload("res://Adventure/loading_screen.gd").show_progress(98,"Preparing lighting and finishing the world…")
	generation_seconds = (Time.get_ticks_msec()-began)/1000.0
	print("OPEN_WORLD seed=",seed_value," resources=",resources.size()," chunks=256 batches=",placements.size()," seconds=",generation_seconds)

func height_at(p: Vector2, _island: int = -1) -> float:
	return geography.height_at(p)

func apply_terrain_edits(edits: Dictionary) -> void:
	if terrain_edits==edits: return
	var dirty: Dictionary={}
	var keys: Dictionary=terrain_edits.duplicate()
	keys.merge(edits,true)
	for key: String in keys:
		var index: int=int(key)
		var level: float=float(edits.get(key,geography.base_heights[index]))
		if is_equal_approx(geography.heights[index],level): continue
		geography.heights[index]=level
		var grid: Vector2i=Vector2i(index%257,index/257)
		# Shared boundary vertices belong to both adjacent chunks.
		for dz in [-1,0]:
			for dx in [-1,0]: dirty[Vector2i(floori(float(grid.x+dx)/16)-8,floori(float(grid.y+dz)/16)-8)]=true
	terrain_edits=edits.duplicate()
	for cell: Vector2i in dirty:
		if terrain_cells.has(cell): terrain_cells[cell].mesh=_terrain_mesh(cell.x+8,cell.y+8)
		for key: String in batch_cells.get(cell,[]):
			var batch: Dictionary=placements[key]
			for i in range(batch.transforms.size()):
				var t: Transform3D=batch.transforms[i]
				var id: String=batch.resources[i]
				var old: float=t.origin.y
				t.origin.y=height_at(Vector2(t.origin.x,t.origin.z))-(.18*t.basis.get_scale().x if "Rock_Medium" in batch.asset else .02)
				batch.transforms[i]=t
				for visual: Dictionary in far_visuals.get(id,[]):
					visual.transform.origin.y+=t.origin.y-old
					var shown: Transform3D=visual.transform
					if int(changed_resources.get(id,1))<=0: shown.basis=Basis.IDENTITY.scaled(Vector3.ONE*.00001)
					visual.multi.set_instance_transform(visual.index,shown)
		for def: Dictionary in solid_cells.get(cell,[]):
			var p: Vector3=def.p
			var resource_record: Dictionary=resources.get(def.id,{})
			if not resource_record.is_empty():
				var level: float=height_at(Vector2(p.x,p.z))
				def.p.y+=level-resource_record.p.y; resource_record.p.y=level
		if streamer!=null:
			if streamer.visual_chunks.has(cell):
				var node: Node3D=streamer.visual_chunks[cell]; node.get_parent().remove_child(node); node.queue_free(); streamer.visual_chunks.erase(cell)
				for key: String in batch_cells.get(cell,[]):
					for id: String in placements[key].resources: resource_visuals.erase(id)
			if streamer.physics_chunks.has(cell):
				var node: Node3D=streamer.physics_chunks[cell]; node.get_parent().remove_child(node); node.queue_free(); streamer.physics_chunks.erase(cell)
				for def: Dictionary in solid_cells.get(cell,[]): resource_colliders.erase(def.id)
	# Fiber resources have no solid collider; they still follow the new surface.
	for record: Dictionary in resources.values(): record.p.y=height_at(Vector2(record.p.x,record.p.z))
	if streamer!=null:
		streamer.last_view=Vector2i(9999,9999); streamer.update(_view_position,_simulation_positions)
	if is_instance_valid(meadow): meadow.invalidate()

func nearest_island(p: Vector2) -> int:
	return geography.region(p)

func shrine_position(index: int) -> Vector3:
	var p: Vector2 = Geo.CENTERS[index]
	if index == 2: p += Vector2(-78,0)
	return Vector3(p.x,height_at(p),p.y)

func spawn_position(index: int, slot: int=0) -> Vector3:
	var center: Vector3 = shrine_position(index)
	var p: Vector2 = Vector2(center.x+(slot%3-1)*1.5,center.z+6+(slot/3)*1.5)
	return Vector3(p.x,height_at(p)+0.5,p.y)

func ground_color(p: Vector2,h: float) -> Color:
	var color: Color = Color("526b2c").lerp(Color("2d4827"),geography.forest_density(p))
	color = color.lerp(Color("757e76"),smoothstep(46,100,h))
	color = color.lerp(Color("d5dcd1"),smoothstep(112,145,h))
	color = color.lerp(Color("bba77c"),1-smoothstep(0,4,h))
	var road: float = geography.road_distance(p,false)
	color = color.lerp(Color("8f704d"),1-smoothstep(2.4,4.8,road))
	color = color.lerp(Color("8b7150"),(1-smoothstep(0.6,1.8,geography.road_distance(p)))*0.6)
	for town: Vector2 in Geo.SETTLEMENTS:
		if p.distance_to(town)<31 and road<4: color=color.lerp(Color("929184"),0.8)
	return color

func _build_mainland() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.roughness=1
	for cz in range(16):
		for cx in range(16):
			var terrain: MeshInstance3D=mesh_node(_terrain_mesh(cx,cz),mat,_root,Vector3.ZERO)
			terrain.name="Terrain_%d_%d" % [cx,cz]
			terrain_cells[Vector2i(cx-8,cz-8)]=terrain
			terrain_meshes.append(terrain)

func _terrain_mesh(cx: int,cz: int) -> ArrayMesh:
	var surface: SurfaceTool=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(17):
		for x in range(17):
			var p: Vector2=Vector2(cx*64+x*4-512,cz*64+z*4-512)
			var h: float=height_at(p)
			surface.set_color(ground_color(p,h))
			surface.add_vertex(Vector3(p.x,h,p.y))
	for z in range(16):
		for x in range(16):
			var a: int=z*17+x
			for v: int in [a,a+1,a+17,a+1,a+18,a+17]: surface.add_index(v)
	surface.generate_normals()
	return surface.commit()

func _build_watershed() -> void:
	var water: ShaderMaterial=ShaderMaterial.new()
	water.shader=WATER
	var ocean: PlaneMesh=PlaneMesh.new()
	ocean.size=Vector2(6000,6000)
	mesh_node(ocean,water,_root,Vector3(0,-0.4,0))
	var river: ShaderMaterial=water.duplicate(); river.set_shader_parameter("river",true)
	_ribbon(Geo.RIVER,7.5,river)
	_ribbon(Geo.BROOK,3.5,river)
	_ribbon(Geo.STREAM,2.5,river)
	for lake: Vector4 in [Vector4(25,120,58,48),Vector4(190,160,12,12)]:
		var disk: CylinderMesh=CylinderMesh.new()
		disk.top_radius=lake.z; disk.bottom_radius=lake.z; disk.height=0.04; disk.radial_segments=64
		mesh_node(disk,water,_root,Vector3(lake.x,12 if lake.x==25 else 15,lake.y)).scale.z=lake.w/lake.z
	var curtain: SurfaceTool=SurfaceTool.new(); curtain.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(17):
		for x in range(33):
			var uv: Vector2=Vector2(x/32.0,y/16.0)
			curtain.set_uv(uv)
			curtain.add_vertex(Vector3(45+(uv.x-0.5)*(14.7+uv.y*0.9),20-uv.y*8,43+uv.y*0.9+sin(uv.x*19)*0.05))
	for y in range(16):
		for x in range(32):
			var a: int=y*33+x
			for index: int in [a,a+1,a+33,a+1,a+34,a+33]: curtain.add_index(index)
	curtain.generate_normals()
	var falling: ShaderMaterial=ShaderMaterial.new(); falling.shader=preload("res://Adventure/waterfall.gdshader")
	mesh_node(curtain.commit(),falling,_root,Vector3.ZERO)
	for side: float in [-1,1]:
		var formation: Node3D=_custom("CliffFormation_2")
		formation.position=Vector3(45+side*15,9,39); formation.scale=Vector3(0.64,0.68,0.8); formation.rotation.y=side*0.2; _root.add_child(formation); _static_meshes(formation)
	Effects.particles(_root,Vector3(45,12.5,46),Color(0.8,0.92,0.92,0.18),28,Vector3(6,0.2,1),1.2,3,2.5)
	Effects.particles(_root,Vector3(45,12.15,44),Color(0.8,0.94,0.94,0.55),35,Vector3(6,0.05,0.4),2.4,0.8,0.11)
	Effects.waterfall_audio(_root,Vector3(45,14,44))

func _ribbon(points: Array[Vector3],width: float,mat: Material) -> void:
	var surface: SurfaceTool=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var downstream: float=0
	for i in range(points.size()-1):
		var a: Vector3=points[i]
		var b: Vector3=points[i+1]
		var tangent_a: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var tangent_b: Vector3=points[mini(i+2,points.size()-1)]-points[i]
		var side_a: Vector3=Vector3(-tangent_a.z,0,tangent_a.x).normalized()*width
		var side_b: Vector3=Vector3(-tangent_b.z,0,tangent_b.x).normalized()*width
		var length: float=a.distance_to(b)
		var vertices: Array[Vector3]=[a-side_a,a+side_a,b-side_b,a+side_a,b+side_b,b-side_b]
		var uvs: Array[Vector2]=[Vector2(0,downstream),Vector2(1,downstream),Vector2(0,downstream+length),Vector2(1,downstream),Vector2(1,downstream+length),Vector2(0,downstream+length)]
		for j in range(6): surface.set_uv(uvs[j]); surface.add_vertex(vertices[j]+Vector3.UP*0.04)
		downstream+=length
	surface.generate_normals()
	mesh_node(surface.commit(),mat,_root,Vector3.ZERO)

func _normal_bridge(def: Dictionary) -> void:
	var bridge: Node3D=Node3D.new(); bridge.name=def["id"]
	bridge.position=Vector3(def["p"].x,def["height"],def["p"].y); bridge.rotation.y=def["yaw"]; _root.add_child(bridge); bridges.append(bridge)
	var family: String=def["kind"].capitalize()
	var native: Node3D=_custom("Bridge_"+family)
	var native_length: float=38 if family=="Stone" else (32 if family=="Rope" else 36)
	native.scale.z=def["span"]/native_length; bridge.add_child(native)
	var width: float=8 if family=="Stone" else (4 if family=="Rope" else 6)
	# A continuous deck collider and gently buried approach eliminate tiny plank steps.
	var surface: SurfaceTool=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: float=def["span"]
	for i in range(ceili(span)+8):
		var z0: float=-span/2-4+i; var z1: float=z0+1
		var y0: float=_deck_height(z0,span,family=="Rope"); var y1: float=_deck_height(z1,span,family=="Rope")
		for v: Vector3 in [Vector3(-width/2,y0,z0),Vector3(width/2,y0,z0),Vector3(-width/2,y1,z1),Vector3(width/2,y0,z0),Vector3(width/2,y1,z1),Vector3(-width/2,y1,z1)]: surface.add_vertex(v)
	var mesh: MeshInstance3D=MeshInstance3D.new(); mesh.mesh=surface.commit(); mesh.visible=false; bridge.add_child(mesh); mesh.create_trimesh_collision()
	# Narrow simplified rails keep travelers on the bridge without mesh collision on every rope.
	for side: float in [-1,1]:
		var body: StaticBody3D=StaticBody3D.new(); var shape: CollisionShape3D=CollisionShape3D.new(); var box: BoxShape3D=BoxShape3D.new()
		box.size=Vector3(0.12,1.1,span); shape.shape=box; shape.position=Vector3(side*(width/2-0.12),0.5,0); body.add_child(shape); bridge.add_child(body)

func _deck_height(z: float,span: float,rope: bool) -> float:
	if absf(z)>span/2: return 0.025-(absf(z)-span/2)*0.08
	return -sin((z/span+0.5)*PI)+0.025 if rope else 0.025

func _cord(parent: Node3D,a: Vector3,b: Vector3) -> void:
	var cylinder: CylinderMesh=CylinderMesh.new()
	cylinder.top_radius=0.035; cylinder.bottom_radius=0.035; cylinder.height=a.distance_to(b)
	mesh_node(cylinder,material(Color("bda879")),parent,(a+b)/2).basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))

func _settlements() -> void:
	for i in range(Geo.SETTLEMENTS.size()):
		var c: Vector2=Geo.SETTLEMENTS[i]
		for j in range(3 if i==0 else 2): _house(c+Vector2(-13 if j%2==0 else 13,-13 if j<2 else 13),3 if j==1 else 2,(i+j)%2)
		for j in range(10):
			var p: Vector2=c+Vector2(-22+j*4,22)
			var fence: Node3D=Modules.native_asset("Prop_WoodenFence_Single")
			fence.position=Vector3(p.x,height_at(p),p.y); _root.add_child(fence)
	for road: PackedVector2Array in Geo.ROADS:
		for i in range(road.size()-1):
			var distance: float=road[i].distance_to(road[i+1])
			for step in range(int(distance/2)):
				var p: Vector2=road[i].lerp(road[i+1],step*2/distance)
				for c: Vector2 in Geo.SETTLEMENTS:
					if p.distance_to(c)<30: _queue("RockPath_Square_Wide",p,0.95,0)

func _house(p: Vector2,depth: int,variant: int) -> void:
	var house: Node3D=Node3D.new()
	house.position=Vector3(p.x,height_at(p)+0.2,p.y); _root.add_child(house)
	for z in range(depth):
		for x in range(2):
			var floor: Node3D=Modules.visual("foundation_stone")
			floor.position=Vector3(x*2-1,0,z*2-(depth-1)); house.add_child(floor); Modules.collider(floor,"foundation_stone")
	for x in range(2):
		for side: int in [-1,1]:
			var id: String="door_flat" if x==0 and side==1 else "window_wide"
			var wall: Node3D=Modules.visual(id)
			wall.position=Vector3(x*2-1,0,side*depth); wall.rotation.y=PI if side==1 else 0
			house.add_child(wall); Modules.collider(wall,id)
	for z in range(depth):
		for side: int in [-1,1]:
			var id: String="wall_plaster" if variant==0 else "wall_brick"
			var wall: Node3D=Modules.visual(id)
			wall.position=Vector3(side*2,0,z*2-(depth-1)); wall.rotation.y=side*PI/2
			house.add_child(wall); Modules.collider(wall,id)
	var roof: Node3D=Modules.visual("roof_square" if depth==2 else "roof_long")
	roof.position.y=3; house.add_child(roof); Modules.collider(roof,"roof_square" if depth==2 else "roof_long")
	var chimney: Node3D=Modules.visual("chimney")
	chimney.position=Vector3(1.1,3,-1); house.add_child(chimney)
	Effects.particles(_root,house.position+Vector3(1.1,6.1,-1),Color(0.64,0.67,0.65,0.12),9,Vector3.ONE*0.12,0.7,6,1.4)
	_lantern(house.position+Vector3(-1.8,1.7,depth+0.12),0)

func _discoveries() -> void:
	_queue("TwistedTree_5",Vector2(-270,-307),2.1,PI)
	_watchtower(Vector2(140,-250))
	for i in range(6):
		var wall: Node3D=Modules.native_asset("Wall_UnevenBrick_Straight" if i%2==0 else "Wall_Arch")
		var p: Vector2=Vector2(-320,-220)+Vector2((i%3)*2-2,(i/3)*6-3)
		wall.position=Vector3(p.x,height_at(p)-0.2,p.y); wall.rotation.z=_rng.randf_range(-0.1,0.1)
		_root.add_child(wall); _static_meshes(wall)
	var cave: Node3D=_custom("HollowrootCave")
	cave.position=Vector3(-270,height_at(Vector2(-270,-45)),-45); _root.add_child(cave); _static_meshes(cave)
	for location: Vector3 in [Vector3(135,0,-300),Vector3(215,0,-280),Vector3(110,0,-345),Vector3(-281,0,-56)]:
		var p: Vector2=Vector2(location.x,location.z)
		var cliff: Node3D=_custom("CliffFormation_%d" % (1+int(absf(location.x))%4))
		cliff.position=Vector3(p.x,height_at(p)-3,p.y); cliff.rotation.y=0.4 if p.x>0 else -0.5; _root.add_child(cliff); _static_meshes(cliff)
	for mark: Dictionary in Geo.LANDMARKS:
		if mark["kind"]=="hidden":
			for i in range(18): _queue("Mushroom_Common",mark["p"]+Vector2(cos(i),sin(i))*_rng.randf_range(5,11),0.5,_rng.randf()*TAU)

func _nature(asset: String) -> Node3D:
	if "Tree" in asset or "Pine" in asset or "Mushroom" in asset or "Flower" in asset or "Bush" in asset:
		var group: Node3D=Node3D.new()
		for part: Dictionary in _meshes(asset):
			var visual: MeshInstance3D=MeshInstance3D.new(); visual.mesh=part["mesh"]; visual.transform=part["transform"]; group.add_child(visual)
		return group
	var packed: PackedScene=Nature.scene(asset)
	return packed.instantiate() as Node3D if packed!=null else Node3D.new()

func _watchtower(p: Vector2) -> void:
	var tower: Node3D=Node3D.new(); tower.name="GreycrownWatch"
	tower.position=Vector3(p.x,height_at(p)+0.1,p.y); _root.add_child(tower)
	for level in range(3):
		for x: float in [-1,1]:
			for z: float in [-1,1]:
				var floor: Node3D=Modules.visual("floor_brick"); floor.position=Vector3(x,level*3,z); tower.add_child(floor); Modules.collider(floor,"floor_brick")
		for side in range(4):
			for bay: float in [-1,1]:
				var id: String="door_round" if level==0 and side==0 and bay== -1 else "window_round"
				var part: Node3D=Modules.visual(id); part.rotation.y=side*PI/2
				part.position=Basis(Vector3.UP,side*PI/2)*Vector3(bay,level*3,2); tower.add_child(part); Modules.collider(part,id)
	var roof: Node3D=Modules.visual("roof_square"); roof.position.y=9; tower.add_child(roof)

func _static_meshes(node: Node3D) -> void:
	for child: Node in node.find_children("*","MeshInstance3D",true,false): (child as MeshInstance3D).create_trimesh_collision()
	if node is MeshInstance3D: (node as MeshInstance3D).create_trimesh_collision()

func _vegetation() -> void:
	Ecology.new().generate(self)

## True if a point (or its immediate surroundings) touches a river, lake or the sea --
## used for filling a bucket and for casting a fishing line.
func near_water(p: Vector3, radius: float = 1.8) -> bool:
	var here: Vector2 = Vector2(p.x, p.z)
	if geography.water_height(here) > height_at(here) - 0.3: return true
	for i in range(8):
		var sample: Vector2 = here + Vector2.from_angle(i * PI / 4) * radius
		if geography.water_height(sample) > height_at(sample) - 0.3: return true
	return false

func resource(id: String,kind: String,p: Vector2,charges: int,amount: int) -> void:
	resources[id]={"kind":kind,"p":Vector3(p.x,height_at(p),p.y),"charges":charges,"amount":amount}

func _crossing_clearance(p: Vector2) -> bool:
	for bridge: Dictionary in geography.bridge_defs:
		var local: Vector2=(p-bridge["p"]).rotated(bridge["yaw"])
		if absf(local.x)<7 and absf(local.y)<bridge["span"]/2+5: return true
	return false

func _solid_resource(id: String,p: Vector3,radius: float,height: float) -> void:
	var cell: Vector2i=Streamer.cell(p)
	if not solid_cells.has(cell): solid_cells[cell]=[]
	solid_cells[cell].append({"id":id,"p":p,"radius":radius,"height":height})

func _queue(asset: String,p: Vector2,size_value: float,yaw: float) -> void:
	_queue_resource(asset,p,size_value,yaw,"")

func _queue_resource(asset: String,p: Vector2,size_value: float,yaw: float,id: String) -> void:
	if asset.begins_with("Grass_"): return
	if id.is_empty() and ("Tree" in asset or "Pine" in asset):
		id="landmark_%s_%d_%d" % [asset,roundi(p.x),roundi(p.y)]
		resource(id,"wood",p,8,3)
		_solid_resource(id,Vector3(p.x,height_at(p)+2,p.y),.6*size_value,4)
	var key: String="%s:%d:%d" % [asset,floori(p.x/64),floori(p.y/64)]
	if not placements.has(key):
		placements[key]={"asset":asset,"transforms":[],"resources":[]}
		var cell: Vector2i=Vector2i(floori(p.x/64),floori(p.y/64))
		if not batch_cells.has(cell): batch_cells[cell]=[]
		batch_cells[cell].append(key)
	placements[key]["transforms"].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size_value),Vector3(p.x,height_at(p)-(0.18*size_value if "Rock_Medium" in asset else 0.02),p.y)))
	placements[key]["resources"].append(id)

func _meshes(asset: String) -> Array:
	if _cache.has(asset): return _cache[asset]
	var packed: PackedScene=Nature.scene(asset)
	if packed==null: return []
	var node: Node=packed.instantiate()
	var parts: Array=[]
	_collect(node,Transform3D.IDENTITY,parts); node.free()
	for part: Dictionary in parts:
		var mesh: ArrayMesh=(part["mesh"] as ArrayMesh).duplicate()
		for surface in range(mesh.get_surface_count()):
			var original: StandardMaterial3D=mesh.surface_get_material(surface) as StandardMaterial3D
			if original==null or "Rock" in asset or "Pebble" in asset: continue
			var mat: ShaderMaterial=ShaderMaterial.new()
			mat.shader=WIND
			mat.set_shader_parameter("has_texture",original.albedo_texture!=null)
			mat.set_shader_parameter("albedo_texture",original.albedo_texture)
			mat.set_shader_parameter("tint",original.albedo_color)
			mat.set_shader_parameter("has_normal",original.normal_enabled and original.normal_texture!=null)
			if original.normal_texture!=null: mat.set_shader_parameter("normal_texture",original.normal_texture)
			var tree: bool="Tree" in asset or "Pine" in asset
			var grass: bool="Grass" in asset
			mat.set_shader_parameter("grass",grass)
			if grass: mat.set_shader_parameter("ground_mask",grass_mask); wind_materials.append(mat)
			mat.set_shader_parameter("height_scale",7.0 if tree else 1.3)
			mat.set_shader_parameter("strength",0.08 if tree else (0.22 if grass else 0.12))
			mat.set_shader_parameter("visibility_end",240.0 if tree else 135.0)
			mesh.surface_set_material(surface,mat)
		part["mesh"]=mesh
	_cache[asset]=parts
	return parts

func _flush_instances() -> void:
	streamer=Streamer.new(); streamer.setup(self)

func make_far_canopies(parent: Node3D) -> void:
	var forest: Dictionary={}
	for batch: Dictionary in placements.values():
		var asset: String=batch["asset"]
		if not ("Tree" in asset or "Pine" in asset): continue
		if not forest.has(asset): forest[asset]={"asset":asset,"transforms":[],"resources":[]}
		forest[asset]["transforms"].append_array(batch["transforms"]); forest[asset]["resources"].append_array(batch["resources"])
	for batch: Dictionary in forest.values(): make_batch(batch,parent,true)

func make_batch(batch: Dictionary,parent: Node3D,far: bool) -> void:
	var asset: String=batch["asset"]
	var parts: Array=_meshes(asset)
	if far:
		if not _far_cache.has(asset):
			var copies: Array=[]
			for part: Dictionary in parts:
				var copy: Dictionary=part.duplicate(); var mesh: ArrayMesh=part["mesh"].duplicate()
				for surface in range(mesh.get_surface_count()):
					var original: Material=mesh.surface_get_material(surface)
					if original is ShaderMaterial:
						var material_copy: ShaderMaterial=original.duplicate(); material_copy.set_shader_parameter("visibility_start",240.0); material_copy.set_shader_parameter("visibility_end",1250.0); mesh.surface_set_material(surface,material_copy)
				copy["mesh"]=mesh; copies.append(copy)
			_far_cache[asset]=copies
		parts=_far_cache[asset]
	for part: Dictionary in parts:
		var multi: MultiMesh=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=part["mesh"]; multi.instance_count=batch["transforms"].size()
		for i in range(multi.instance_count):
			var t: Transform3D=batch["transforms"][i]*part["transform"]
			var id: String=batch["resources"][i]
			var displayed: Transform3D=t
			if not id.is_empty():
				var visuals: Dictionary=far_visuals if far else resource_visuals
				if not visuals.has(id): visuals[id]=[]
				visuals[id].append({"multi":multi,"index":i,"transform":t})
				if int(changed_resources.get(id,1))<=0: displayed.basis=Basis.IDENTITY.scaled(Vector3.ONE*0.00001)
			multi.set_instance_transform(i,displayed)
		var instance: MultiMeshInstance3D=MultiMeshInstance3D.new(); instance.multimesh=multi
		var tree: bool="Tree" in asset or "Pine" in asset
		instance.visibility_range_end=1300 if far else (335 if tree else 180)
		instance.lod_bias=0.12 if far else 0.7
		if far or not tree: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)

func update_streaming(view: Vector3,players: Array) -> void:
	_view_position=view; _simulation_positions=players.duplicate()
	if streamer!=null: streamer.update(view,players)

func apply_state(state: Dictionary, _animate: bool=true) -> void:
	if state.has("world_delta"): apply_delta(state["world_delta"])

func apply_delta(delta: Dictionary) -> void:
	if is_instance_valid(wildlife):
		wildlife.apply_state(delta.get("animals", {}))
		wildlife.apply_tamed(delta.get("tamed", {}))
	if is_instance_valid(farmland_view):
		farmland_view.apply_state(delta.get("farmland", {}), _time)
	apply_terrain_edits(delta.get("terrain_edits",{}))
	changed_resources=delta.get("resources",{}).duplicate()
	structure_records=delta.get("structures",[]).duplicate(true)
	grass_clearings=delta.get("grass_clearings",{}).duplicate(true)
	var signature: String=str(structure_records.hash())+str(grass_clearings.hash())
	if signature!=_structure_signature:
		_structure_signature=signature; _update_grass_mask()
	for id: String in changed_resources:
		var depleted: bool=int(changed_resources[id])<=0
		if extra_resource_nodes.has(id): extra_resource_nodes[id].visible=not depleted
		for visual: Dictionary in resource_visuals.get(id,[])+far_visuals.get(id,[]):
			var t: Transform3D=visual["transform"]
			if depleted: t.basis=Basis.IDENTITY.scaled(Vector3.ONE*0.00001)
			visual["multi"].set_instance_transform(visual["index"],t)
		if resource_colliders.has(id): resource_colliders[id].collision_layer=0 if depleted else 1
	stream_structures(_view_position,_simulation_positions)

func stream_structures(view: Vector3,players: Array) -> void:
	var wanted: Dictionary={}
	for record: Dictionary in structure_records:
		var p: Vector3=Vector3(record["position"][0],record["position"][1],record["position"][2])
		var nearby: bool=p.distance_to(view)<300
		for player: Vector3 in players: nearby=nearby or p.distance_to(player)<115
		if not nearby: continue
		wanted[record["id"]]=true
		if placed_nodes.has(record["id"]):
			placed_nodes[record["id"]].visible=p.distance_to(view)<300
			continue
		var node: Node3D=Modules.visual(record["module_id"]); node.position=p; node.rotation.y=int(record["rotation"])*PI/2
		placed_root.add_child(node); Modules.collider(node,record["module_id"])
		node.visible=p.distance_to(view)<300
		if Modules.definition(record["module_id"])["kind"]=="foundation" or (Modules.definition(record["module_id"])["kind"]=="floor" and p.y-height_at(Vector2(p.x,p.z))<=1.5): Modules.update_foundation_supports(node,self)
		placed_nodes[record["id"]]=node
	for id: String in placed_nodes.keys():
		if not wanted.has(id):
			placed_root.remove_child(placed_nodes[id]); placed_nodes[id].queue_free(); placed_nodes.erase(id)

func reset_persistence() -> void:
	apply_terrain_edits({})
	for node: Node3D in extra_resource_nodes.values(): node.show()
	_reveal_until=0; _stun_until=0; changed_resources.clear(); structure_records.clear(); grass_clearings.clear()
	for node: Node3D in placed_nodes.values(): placed_root.remove_child(node); node.queue_free()
	placed_nodes.clear()
	for visuals: Array in resource_visuals.values()+far_visuals.values():
		for visual: Dictionary in visuals: visual["multi"].set_instance_transform(visual["index"],visual["transform"])
	if streamer!=null: streamer.reset()
	update_streaming(spawn_position(0),[spawn_position(0)])

func _map_image() -> void:
	var image: Image=Image.create(128,128,false,Image.FORMAT_RGB8)
	for z in range(128):
		for x in range(128):
			var p: Vector2=Vector2(x,z)*8-Vector2.ONE*512
			var h: float=height_at(p)
			image.set_pixel(x,z,Color("39777c") if h<geography.water_height(p) else ground_color(p,h))
	map_texture=ImageTexture.create_from_image(image)

func _custom(asset: String) -> Node3D:
	var path: String="res://Adventure/generated/"+asset+".glb"
	var packed: PackedScene=load(path) as PackedScene
	if packed==null: push_error("Custom environment asset failed to load: "+path); return Node3D.new()
	return packed.instantiate() as Node3D

func _prop(asset: String,p: Vector3,yaw: float=0,size_value: float=1) -> Node3D:
	var path: String="res://Fantasy Props Megakit/Exports/FBX/"+asset+".fbx"
	var packed: PackedScene=load(path) as PackedScene
	if packed==null: push_error("Fantasy prop failed to load: "+path); return Node3D.new()
	var node: Node3D=packed.instantiate(); node.position=p; node.rotation.y=yaw; node.scale=Vector3.ONE*size_value; _root.add_child(node); return node

func _ground_prop(asset: String,p: Vector2,yaw: float=0) -> void:
	_prop(asset,Vector3(p.x,height_at(p),p.y),yaw)

func _lantern(p: Vector3,yaw: float) -> void:
	_prop("Lantern_Wall",p,yaw,0.55)
	var light: OmniLight3D=OmniLight3D.new(); light.position=p+Vector3(0,0.35,0.4); light.light_color=Color("ffd48a"); light.omni_range=7; light.light_energy=0.2
	light.distance_fade_enabled=true; light.distance_fade_begin=50; light.distance_fade_length=15; _root.add_child(light); practical_lights.append(light)

func _dress_locations() -> void:
	# Workshop: work surface, anvil, materials and a cart next to the road.
	_ground_prop("Workbench",Vector2(-109,148),PI/2)
	_ground_prop("Anvil_Log",Vector2(-112,148),0.4)
	_ground_prop("Crate_Wooden",Vector2(-109,150),0.1)
	_ground_prop("Barrel",Vector2(-111,151),0.2)
	_ground_prop("Stall_Cart_Empty",Vector2(-115,153),0.7)
	_prop("Axe_Bronze",Vector3(-109,height_at(Vector2(-109,148))+0.95,148),0.5)
	# Hamlet: a small timber work camp, kept to one composed cluster.
	_ground_prop("Workbench_Drawers",Vector2(-210,-84),PI/2)
	_ground_prop("Anvil_Log",Vector2(-213,-82))
	_ground_prop("Stall_Cart_Empty",Vector2(-207,-79),-0.5)
	_ground_prop("Crate_Wooden",Vector2(-211,-79),0.1)
	for i in range(3):
		var log_node: Node3D=_nature("DeadTree_%d" % (i+1))
		var log_id: String="camp_log_%d" % i
		resource(log_id,"wood",Vector2(-215+i,-82),3,2); extra_resource_nodes[log_id]=log_node
		log_node.position=Vector3(-215+i,height_at(Vector2(-215+i,-82))+0.3,-82); log_node.scale=Vector3.ONE*0.35; log_node.rotation=Vector3(0,0.3,PI/2); _root.add_child(log_node)
	# Farm market: produce crates and storage by the open square.
	for i in range(3): _ground_prop("FarmCrate_Apple" if i%2==0 else "FarmCrate_Carrot",Vector2(157+i*1.2,183),0.1*i)
	_ground_prop("Stall_Empty",Vector2(161,187),PI)
	_ground_prop("Bag",Vector2(159,185),0.5)
	_ground_prop("Barrel",Vector2(164,186),0.4)
	_watchtower(Vector2(175,210))
	var rotor: Node3D=_custom("WindmillRotor"); rotor.position=Vector3(175,height_at(Vector2(175,210))+8,213); _root.add_child(rotor); rotors.append(rotor)
	# Shore fishing spot: a low native timber platform and practical containers.
	var dock: Vector2=Vector2(-22,116)
	for z in range(4):
		var floor: Node3D=Modules.visual("foundation_wood"); floor.position=Vector3(dock.x+z*2,12.4,dock.y); _root.add_child(floor); Modules.collider(floor,"foundation_wood")
	_prop("Bucket_Wooden_1",Vector3(-22,12.45,116),0.2)
	_prop("Barrel",Vector3(-20,12.45,116.6),0.7)
	_ground_prop("Bench",Vector2(-27,113),PI/2)
	for x in range(4):
		for z in range(5): _queue("Plant_1",Vector2(157+x*1.1,195+z*1.3),0.6,0)

func set_night(amount: float) -> void:
	for i in range(practical_lights.size()):
		practical_lights[i].light_energy=(0.08+amount*2.3)*(1+sin(lantern_time*7+i)*0.025)

func tick(delta: float,server_time: float) -> void:
	_time=server_time; lantern_time+=delta
	for rotor: Node3D in rotors: rotor.rotation.z+=delta*0.48

func gather_feedback(p: Vector3,kind: String) -> void:
	Effects.impact(_root,p,kind)

func _mask_box(image: Image, box: AABB) -> void:
	var start: Vector2i=Vector2i(floori(box.position.x+512),floori(box.position.z+512))
	var end: Vector2i=Vector2i(ceili(box.end.x+512),ceili(box.end.z+512))
	var rect: Rect2i=Rect2i(start,end-start).intersection(Rect2i(0,0,1024,1024))
	if rect.has_area(): image.fill_rect(rect,Color.WHITE)

func _create_grass_mask() -> void:
	grass_base=Image.create(1024,1024,false,Image.FORMAT_RGBA8); grass_base.fill(Color.BLACK)
	for entries: Array in solid_cells.values():
		for record: Dictionary in entries:
			var radius: float=record.radius+0.45
			_mask_box(grass_base,AABB(record.p-Vector3(radius,0,radius),Vector3(radius*2,1,radius*2)))
	for shape: CollisionShape3D in _root.find_children("*","CollisionShape3D",true,false):
		if shape.shape==null: continue
		var box: AABB=shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
		if box.size.x<50 and box.size.z<50: _mask_box(grass_base,box.grow(0.3))
	grass_mask=ImageTexture.create_from_image(grass_base)
	for mat: ShaderMaterial in wind_materials: mat.set_shader_parameter("ground_mask",grass_mask)
	_update_grass_mask()

func _update_grass_mask() -> void:
	if grass_base==null: return
	var image: Image=grass_base.duplicate()
	for record: Dictionary in structure_records:
		var kind: String=Modules.definition(record.module_id).kind
		if kind not in ["foundation","floor","decoration","stairs"]: continue
		for cell: Vector2i in Modules.cells(record.module_id,preload("res://Adventure/construction.gd").position(record),int(record.rotation)):
			_mask_box(image,AABB(Vector3(cell.x*2-1.2,0,cell.y*2-1.2),Vector3(2.4,1,2.4)))
	for clearing: Array in grass_clearings.values():
		_mask_box(image,AABB(Vector3(float(clearing[0])-3,0,float(clearing[1])-3),Vector3(6,1,6)))
	for station: Vector3 in cooking_stations:
		_mask_box(image, AABB(station - Vector3(1.1, 0, 1.1), Vector3(2.2, 1, 2.2)))
	grass_mask_image=image
	grass_mask.update(image)

func update_player_effects(bodies: Array, delta: float) -> void:
	var positions: PackedVector3Array=PackedVector3Array()
	for body: CharacterBody3D in bodies:
		if positions.size()<6: positions.append(body.position)
		var key: int=body.get_instance_id()
		var surface: float=geography.water_height(Vector2(body.position.x,body.position.z))
		var wet: bool=surface>height_at(Vector2(body.position.x,body.position.z))+0.04 and absf(body.position.y-surface)<1.2
		splash_times[key]=float(splash_times.get(key,0))-delta
		var speed: float=(body.velocity if body.authoritative else body.remote_velocity).length()
		if wet and (not water_states.get(key,false) or (speed>0.5 and splash_times[key]<=0)):
			var landing: bool=not water_states.get(key,false)
			Effects.splash(_root,Vector3(body.position.x,surface+0.07,body.position.z),landing or speed>5)
			splash_times[key]=0.22 if speed>5 else 0.5
		water_states[key]=wet
	var count: int=positions.size()
	while positions.size()<6: positions.append(Vector3(0,-10000,0))
	for mat: ShaderMaterial in wind_materials:
		mat.set_shader_parameter("players",positions); mat.set_shader_parameter("player_count",count)
