extends "res://Adventure/environment_base.gd"
const Geo := preload("res://Adventure/geography.gd")
const Modules := preload("res://Adventure/modules.gd")
const WIND := preload("res://Adventure/wind.gdshader")
var geography: RefCounted = Geo.new()
var resources: Dictionary = {}
var resource_visuals: Dictionary = {}
var resource_colliders: Dictionary = {}
var placed_root: Node3D
var placed_nodes: Dictionary = {}
var map_texture: ImageTexture
var generation_seconds: float = 0

func build(new_seed: int) -> void:
	var began: int = Time.get_ticks_msec()
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "ContinuousMainland"
	add_child(_root)
	seed_value = new_seed
	_rng.seed = seed_value
	geography.generate(seed_value)
	shrines.clear(); bridges.clear(); treasures.clear(); sentinels.clear()
	terrain_meshes.clear(); _materials.clear(); placements.clear()
	resources.clear(); resource_visuals.clear(); resource_colliders.clear(); placed_nodes.clear()
	_solved = [false,false,false,false,false,false,false]
	_reveal_until = 0
	_stun_until = 0
	_build_mainland()
	_build_watershed()
	for bridge: Dictionary in geography.bridge_defs: _normal_bridge(bridge)
	_settlements()
	_discoveries()
	for i in range(7):
		_build_shrine(i)
		for j in range(3): _build_treasure(i,j)
	_vegetation()
	_flush_instances()
	placed_root = Node3D.new()
	placed_root.name = "PlayerConstruction"
	_root.add_child(placed_root)
	_map_image()
	generation_seconds = (Time.get_ticks_msec()-began)/1000.0
	print("OPEN_WORLD seed=",seed_value," resources=",resources.size()," chunks=256 batches=",placements.size()," seconds=",generation_seconds)

func height_at(p: Vector2, _island: int = -1) -> float:
	return geography.height_at(p)

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
	var color: Color = Color("9fa766").lerp(Color("526f4a"),geography.forest_density(p))
	color = color.lerp(Color("929387"),smoothstep(46,100,h))
	color = color.lerp(Color("d8dacc"),smoothstep(112,145,h))
	color = color.lerp(Color("c4b58b"),1-smoothstep(0,4,h))
	var road: float = geography.road_distance(p,false)
	color = color.lerp(Color("ad9163"),1-smoothstep(2.4,4.8,road))
	color = color.lerp(Color("a18b5f"),(1-smoothstep(0.6,1.8,geography.road_distance(p)))*0.6)
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
			var terrain: MeshInstance3D=mesh_node(surface.commit(),mat,_root,Vector3.ZERO)
			terrain.name="Terrain_%d_%d" % [cx,cz]
			terrain.create_trimesh_collision()
			terrain_meshes.append(terrain)

func _build_watershed() -> void:
	var water: ShaderMaterial=ShaderMaterial.new()
	water.shader=WATER
	var ocean: PlaneMesh=PlaneMesh.new()
	ocean.size=Vector2(6000,6000)
	mesh_node(ocean,water,_root,Vector3(0,-0.4,0))
	_ribbon(Geo.RIVER,7.5,water)
	_ribbon(Geo.BROOK,3.5,water)
	_ribbon(Geo.STREAM,2.5,water)
	for lake: Vector4 in [Vector4(25,120,58,48),Vector4(190,160,12,12)]:
		var disk: CylinderMesh=CylinderMesh.new()
		disk.top_radius=lake.z; disk.bottom_radius=lake.z; disk.height=0.04; disk.radial_segments=64
		mesh_node(disk,water,_root,Vector3(lake.x,12 if lake.x==25 else 15,lake.y)).scale.z=lake.w/lake.z
	var fall: BoxMesh=BoxMesh.new()
	fall.size=Vector3(15,8,0.4)
	mesh_node(fall,water,_root,Vector3(45,16,43))
	var foam: TorusMesh=TorusMesh.new()
	foam.inner_radius=2.8; foam.outer_radius=3.2
	mesh_node(foam,material(Color("b8e2d7"),0.2),_root,Vector3(45,12.08,46)).scale.x=2.5
	for side: float in [-1,1]:
		for i in range(7):
			var rock: Node3D=_nature("Rock_Medium_%d" % (1+i%3))
			rock.position=Vector3(45+side*(10+i%3*3),10+i%3*2,36+i*2)
			rock.scale=Vector3(2.0,2.5+i%3,2.4); rock.rotation.y=i*0.83
			_root.add_child(rock); _static_meshes(rock)

func _ribbon(points: Array[Vector3],width: float,mat: Material) -> void:
	var surface: SurfaceTool=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var a: Vector3=points[i]
		var b: Vector3=points[i+1]
		var tangent_a: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var tangent_b: Vector3=points[mini(i+2,points.size()-1)]-points[i]
		var side_a: Vector3=Vector3(-tangent_a.z,0,tangent_a.x).normalized()*width
		var side_b: Vector3=Vector3(-tangent_b.z,0,tangent_b.x).normalized()*width
		for v: Vector3 in [a-side_a,a+side_a,b-side_b,a+side_a,b+side_b,b-side_b]: surface.add_vertex(v+Vector3.UP*0.04)
	surface.generate_normals()
	mesh_node(surface.commit(),mat,_root,Vector3.ZERO)

func _normal_bridge(def: Dictionary) -> void:
	var bridge: Node3D=Node3D.new()
	bridge.name=def["id"]; bridge.position=Vector3(def["p"].x,def["height"],def["p"].y); bridge.rotation.y=def["yaw"]
	_root.add_child(bridge); bridges.append(bridge)
	var count: int=ceili(def["span"]/2)
	var columns: int=4 if def["kind"]=="stone" else (2 if def["kind"]=="rope" else 3)
	for i in range(count+1):
		var z: float=i*2-def["span"]/2
		var sag: float=-sin(float(i)/count*PI) if def["kind"]=="rope" else 0.0
		for x in range(columns):
			var floor: Node3D=Modules.native_asset("Floor_Brick" if def["kind"]=="stone" else "Floor_WoodDark")
			floor.position=Vector3((x-(columns-1)/2.0)*2,sag,z); bridge.add_child(floor)
		var body: StaticBody3D=StaticBody3D.new()
		var collision: CollisionShape3D=CollisionShape3D.new()
		var box: BoxShape3D=BoxShape3D.new()
		box.size=Vector3(columns*2,0.25,2.06)
		collision.shape=box; collision.position=Vector3(0,sag-0.12,z)
		body.add_child(collision); bridge.add_child(body)
		if def["kind"]=="rope": body.collision_layer=0
		for side: float in [-1,1]:
			if def["kind"]!="rope":
				var fence: Node3D=Modules.native_asset("Prop_MetalFence_Simple" if def["kind"]=="stone" else "Prop_WoodenFence_Single")
				fence.position=Vector3(side*(columns-0.1),sag,z); fence.rotation.y=PI/2; bridge.add_child(fence)
			elif i<count:
				_cord(bridge,Vector3(side*(columns-0.1),sag+0.95,z),Vector3(side*(columns-0.1),-sin(float(i+1)/count*PI)+0.95,z+2))
	for end: float in [-1,1]:
		for side: float in [-1,1]:
			var post: Node3D=Modules.native_asset("Corner_Exterior_Brick" if def["kind"]=="stone" else "Corner_Exterior_Wood")
			post.position=Vector3(side*(columns-0.1),-1.2,end*def["span"]/2); bridge.add_child(post)
	if def["kind"]=="rope":
		var ramp: SurfaceTool=SurfaceTool.new(); ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(count+1):
			var z0: float=i*2-def["span"]/2-1; var z1: float=z0+2
			var h0: float=-sin(clampf((z0+def["span"]/2)/def["span"],0,1)*PI)+0.04
			var h1: float=-sin(clampf((z1+def["span"]/2)/def["span"],0,1)*PI)+0.04
			for v: Vector3 in [Vector3(-columns,h0,z0),Vector3(columns,h0,z0),Vector3(-columns,h1,z1),Vector3(columns,h0,z0),Vector3(columns,h1,z1),Vector3(-columns,h1,z1)]: ramp.add_vertex(v)
		var collider: MeshInstance3D=MeshInstance3D.new(); collider.mesh=ramp.commit(); collider.visible=false; bridge.add_child(collider); collider.create_trimesh_collision()

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
	roof.position.y=3; house.add_child(roof)
	var chimney: Node3D=Modules.visual("chimney")
	chimney.position=Vector3(1.1,3,-1); house.add_child(chimney)

func _discoveries() -> void:
	_queue("TwistedTree_5",Vector2(-270,-307),2.1,PI)
	_house(Vector2(140,-250),2,1)
	for i in range(6):
		var wall: Node3D=Modules.native_asset("Wall_UnevenBrick_Straight" if i%2==0 else "Wall_Arch")
		var p: Vector2=Vector2(-320,-220)+Vector2((i%3)*2-2,(i/3)*6-3)
		wall.position=Vector3(p.x,height_at(p)-0.2,p.y); wall.rotation.z=_rng.randf_range(-0.1,0.1)
		_root.add_child(wall); _static_meshes(wall)
	# A walkable rock grotto with side walls, open mouth and a roof, using kit boulders.
	for i in range(5):
		for side: float in [-1,1]:
			var rock: Node3D=_nature("Rock_Medium_3")
			rock.position=Vector3(-270+side*4,height_at(Vector2(-270,-45)),-45-i*3); rock.scale=Vector3(2.1,3,2.1)
			_root.add_child(rock); _static_meshes(rock)
		var roof: Node3D=_nature("Rock_Medium_1")
		roof.position=Vector3(-270,height_at(Vector2(-270,-45))+5,-45-i*3); roof.scale=Vector3(3.2,1.8,2)
		_root.add_child(roof); _static_meshes(roof)
	for mark: Dictionary in Geo.LANDMARKS:
		if mark["kind"]=="hidden":
			for i in range(18): _queue("Mushroom_Common",mark["p"]+Vector2(cos(i),sin(i))*_rng.randf_range(5,11),0.5,_rng.randf()*TAU)

func _nature(asset: String) -> Node3D:
	if "Tree" in asset or "Pine" in asset or "Mushroom" in asset or "Flower" in asset or "Bush" in asset:
		var group: Node3D=Node3D.new()
		for part: Dictionary in _meshes(asset):
			var visual: MeshInstance3D=MeshInstance3D.new(); visual.mesh=part["mesh"]; visual.transform=part["transform"]; group.add_child(visual)
		return group
	return (load(KIT+asset+".gltf") as PackedScene).instantiate() as Node3D

func _static_meshes(node: Node3D) -> void:
	for child: Node in node.find_children("*","MeshInstance3D",true,false): (child as MeshInstance3D).create_trimesh_collision()
	if node is MeshInstance3D: (node as MeshInstance3D).create_trimesh_collision()

func _vegetation() -> void:
	for z in range(-57,58):
		for x in range(-57,58):
			var p: Vector2=Vector2(x,z)*7.5+Vector2(_rng.randf_range(-2,2),_rng.randf_range(-2,2))
			var h: float=height_at(p)
			if h<geography.water_height(p)+1.8 or h>105 or p.length()>430 or geography.road_distance(p)<5 or geography.slope_at(p)>0.8 or _crossing_clearance(p): continue
			if _rng.randf()>geography.forest_density(p): continue
			var asset: String="Pine_%d" % _rng.randi_range(1,5) if h>46 or p.y< -160 else "CommonTree_%d" % _rng.randi_range(1,5)
			var size_value: float=_rng.randf_range(1,1.8)
			if p.x< -200 and _rng.randf()<0.2:
				asset="TwistedTree_%d" % _rng.randi_range(1,5); size_value*=0.48
			var id: String="tree_%d_%d" % [x,z]
			resource(id,"wood",p,3,4)
			_queue_resource(asset,p,size_value,_rng.randf()*TAU,id)
			_solid_resource(id,Vector3(p.x,h+1.5,p.y),0.5,3)
			if _rng.randf()<0.05:
				var log_node: Node3D=_nature("DeadTree_1")
				log_node.position=Vector3(p.x+3,h+0.3,p.y+2); log_node.rotation=Vector3(0,_rng.randf()*TAU,PI/2); log_node.scale=Vector3.ONE*0.5
				_root.add_child(log_node)
	for i in range(62000):
		var p: Vector2=Vector2(_rng.randf_range(-440,440),_rng.randf_range(-430,425))
		var h: float=height_at(p)
		var road: float=geography.road_distance(p)
		if h<geography.water_height(p)+1.3 or h>112 or p.length()>440 or road<1.8 or geography.slope_at(p)>0.85 or _crossing_clearance(p): continue
		if _rng.randf()>smoothstep(-0.35,0.45,geography.detail.get_noise_2dv(p*0.8)): continue
		var choice: float=_rng.randf()
		var asset: String="Grass_Common_Short" if road<6 else "Grass_Wispy_Tall"
		var size_value: float=_rng.randf_range(0.65,1.2)
		var id: String=""
		if choice<0.06:
			asset="Rock_Medium_%d" % _rng.randi_range(1,3); id="stone_%d" % i
			resource(id,"stone",p,3,3); _solid_resource(id,Vector3(p.x,h+0.5,p.y),0.7,1)
		elif choice<0.12:
			asset="Bush_Common"; id="fiber_%d" % i; resource(id,"fiber",p,2,3)
		elif choice<0.22: asset="Mushroom_Common" if geography.forest_density(p)>0.45 else "Flower_4_Group"
		elif choice<0.33: asset="Fern_1" if geography.forest_density(p)>0.4 else "Flower_3_Group"
		_queue_resource(asset,p,size_value,_rng.randf()*TAU,id)
		if "Grass" in asset:
			# Small clustered patches leave irregular gaps, with shorter growth beside paths.
			for blade in range(9):
				var q: Vector2=p+Vector2(_rng.randf_range(-2.8,2.8),_rng.randf_range(-2.8,2.8))
				if geography.road_distance(q)<1.8 or height_at(q)<geography.water_height(q)+1: continue
				_queue(asset,q,size_value*_rng.randf_range(0.7,1.3),_rng.randf()*TAU)

func resource(id: String,kind: String,p: Vector2,charges: int,amount: int) -> void:
	resources[id]={"kind":kind,"p":Vector3(p.x,height_at(p),p.y),"charges":charges,"amount":amount}

func _crossing_clearance(p: Vector2) -> bool:
	for bridge: Dictionary in geography.bridge_defs:
		var local: Vector2=(p-bridge["p"]).rotated(bridge["yaw"])
		if absf(local.x)<7 and absf(local.y)<bridge["span"]/2+5: return true
	return false

func _solid_resource(id: String,p: Vector3,radius: float,height: float) -> void:
	var body: StaticBody3D=StaticBody3D.new()
	body.position=p; body.set_meta("resource_id",id)
	var collision: CollisionShape3D=CollisionShape3D.new()
	var cylinder: CylinderShape3D=CylinderShape3D.new()
	cylinder.radius=radius; cylinder.height=height; collision.shape=cylinder
	body.add_child(collision); _root.add_child(body); resource_colliders[id]=body

func _queue(asset: String,p: Vector2,size_value: float,yaw: float) -> void:
	_queue_resource(asset,p,size_value,yaw,"")

func _queue_resource(asset: String,p: Vector2,size_value: float,yaw: float,id: String) -> void:
	var key: String="%s:%d:%d" % [asset,floori(p.x/64),floori(p.y/64)]
	if not placements.has(key): placements[key]={"asset":asset,"transforms":[],"resources":[]}
	placements[key]["transforms"].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size_value),Vector3(p.x,height_at(p)-0.03,p.y)))
	placements[key]["resources"].append(id)

func _meshes(asset: String) -> Array:
	if _cache.has(asset): return _cache[asset]
	var node: Node=(load(KIT+asset+".gltf") as PackedScene).instantiate()
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
			mat.set_shader_parameter("height_scale",7.0 if tree else 1.3)
			mat.set_shader_parameter("strength",0.28 if tree else 0.13)
			mesh.surface_set_material(surface,mat)
		part["mesh"]=mesh
	_cache[asset]=parts
	return parts

func _flush_instances() -> void:
	for key: String in placements:
		var batch: Dictionary=placements[key]
		for part: Dictionary in _meshes(batch["asset"]):
			var multi: MultiMesh=MultiMesh.new()
			multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=part["mesh"]; multi.instance_count=batch["transforms"].size()
			for i in range(multi.instance_count):
				var t: Transform3D=batch["transforms"][i]*part["transform"]
				multi.set_instance_transform(i,t)
				var id: String=batch["resources"][i]
				if not id.is_empty():
					if not resource_visuals.has(id): resource_visuals[id]=[]
					resource_visuals[id].append({"multi":multi,"index":i,"transform":t})
			var instance: MultiMeshInstance3D=MultiMeshInstance3D.new()
			instance.multimesh=multi
			var tree: bool="Tree" in batch["asset"] or "Pine" in batch["asset"]
			instance.visibility_range_end=1200 if tree else 130
			instance.lod_bias=0.6 if tree else 1.0
			if not tree: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(instance)

func apply_state(state: Dictionary, _animate: bool=true) -> void:
	# Optional music changes its stones, never environmental access.
	_solved=state["solved"].duplicate()
	for i in range(_materials.size()): _materials[i].emission_energy_multiplier=2.2 if _solved[i] else 0.5
	for treasure: Node3D in treasures: treasure.set_meta("collected",int(treasure.get_meta("id")) in state["collected"])
	if state.has("world_delta"): apply_delta(state["world_delta"])

func apply_delta(delta: Dictionary) -> void:
	for id: String in delta.get("resources",{}):
		var depleted: bool=int(delta["resources"][id])<=0
		for visual: Dictionary in resource_visuals.get(id,[]):
			var t: Transform3D=visual["transform"]
			if depleted: t.basis=Basis.IDENTITY.scaled(Vector3.ONE*0.00001)
			visual["multi"].set_instance_transform(visual["index"],t)
		if resource_colliders.has(id): resource_colliders[id].collision_layer=0 if depleted else 1
	for record: Dictionary in delta.get("structures",[]):
		if placed_nodes.has(record["id"]): continue
		var node: Node3D=Modules.visual(record["module_id"])
		node.position=Vector3(record["position"][0],record["position"][1],record["position"][2]); node.rotation.y=int(record["rotation"])*PI/2
		placed_root.add_child(node); Modules.collider(node,record["module_id"])
		if Modules.definition(record["module_id"])["kind"]=="foundation":
			for x: float in [-0.85,0.85]:
				for z: float in [-0.85,0.85]:
					var ground: float=height_at(Vector2(node.position.x+x,node.position.z+z))
					var support: Node3D=Modules.native_asset("Corner_Exterior_Brick")
					support.position=Vector3(x,ground-node.position.y,z)
					support.scale.y=maxf(0.04,(node.position.y-ground)/3); node.add_child(support)
		placed_nodes[record["id"]]=node

func reset_persistence() -> void:
	_reveal_until=0; _stun_until=0
	for node: Node3D in placed_nodes.values():
		placed_root.remove_child(node); node.queue_free()
	placed_nodes.clear()
	for visuals: Array in resource_visuals.values():
		for visual: Dictionary in visuals: visual["multi"].set_instance_transform(visual["index"],visual["transform"])
	for body: StaticBody3D in resource_colliders.values(): body.collision_layer=1

func _map_image() -> void:
	var image: Image=Image.create(128,128,false,Image.FORMAT_RGB8)
	for z in range(128):
		for x in range(128):
			var p: Vector2=Vector2(x,z)*8-Vector2.ONE*512
			var h: float=height_at(p)
			image.set_pixel(x,z,Color("39777c") if h<geography.water_height(p) else ground_color(p,h))
	map_texture=ImageTexture.create_from_image(image)
