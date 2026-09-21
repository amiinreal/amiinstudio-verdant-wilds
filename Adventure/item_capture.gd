extends SceneTree
const Items = preload("res://Adventure/items.gd")
func _initialize() -> void: call_deferred("run")
func mesh_node(mesh: Mesh, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var node: MeshInstance3D=MeshInstance3D.new(); node.mesh=mesh; node.position=p; parent.add_child(node); return node
func item_model(id: String) -> Node3D:
	if id in ["axe","pickaxe","hammer"]: return (load(Items.tool(id).model) as PackedScene).instantiate()
	if id=="stone": return (load("res://styled Nature megaKit/FBX/Rock_Medium_1.fbx") as PackedScene).instantiate()
	if id=="fiber": return (load("res://styled Nature megaKit/FBX/Plant_1.fbx") as PackedScene).instantiate()
	if id=="rope": return (load("res://Fantasy Props Megakit/Exports/FBX/Rope_1.fbx") as PackedScene).instantiate()
	var model: Node3D=Node3D.new()
	var wood: StandardMaterial3D=StandardMaterial3D.new(); wood.albedo_color=Color("94673e"); wood.roughness=0.9
	for i in range(3):
		if id=="wood":
			var log_mesh: CylinderMesh=CylinderMesh.new(); log_mesh.top_radius=0.16; log_mesh.bottom_radius=0.18; log_mesh.height=1.1; log_mesh.radial_segments=12; log_mesh.material=wood
			var log_node: MeshInstance3D=mesh_node(log_mesh,Vector3(0,i*0.13,i*0.23),model); log_node.rotation.z=PI/2
		else:
			var plank: BoxMesh=BoxMesh.new(); plank.size=Vector3(1.1,0.11,0.3); plank.material=wood; mesh_node(plank,Vector3(i*0.07,i*0.13,0),model)
	return model
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://Adventure/generated/items")
	var viewport: SubViewport=SubViewport.new(); viewport.size=Vector2i(144,144); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var camera: Camera3D=Camera3D.new(); viewport.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var light: DirectionalLight3D=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-35,-35,0); light.light_energy=1.8; viewport.add_child(light)
	var env: WorldEnvironment=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color(0.85,0.9,1); env.environment.ambient_light_energy=0.65; viewport.add_child(env)
	for id: String in ["axe","pickaxe","hammer","wood","stone","fiber","planks","rope"]:
		var model: Node3D=item_model(id); viewport.add_child(model)
		var box: AABB=AABB(); var first: bool=true
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=mesh.global_transform*mesh.get_aabb(); box=bounds if first else box.merge(bounds); first=false
		camera.size=box.size.length()*1.04; camera.position=box.get_center()+Vector3(0.7,0.4,1.6).normalized()*box.size.length()*3; camera.look_at(box.get_center())
		await process_frame; await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://Adventure/generated/items/"+id+".png")
		viewport.remove_child(model); model.free()
	print("ITEM_ICONS_COMPLETE 8"); quit()
