extends SceneTree
const Modules = preload("res://Adventure/modules.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://Adventure/generated/thumbnails")
	var viewport: SubViewport=SubViewport.new(); viewport.size=Vector2i(256,160); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var camera: Camera3D=Camera3D.new(); viewport.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var light: DirectionalLight3D=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-30,0); light.light_energy=1.5; viewport.add_child(light)
	var environment: WorldEnvironment=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color(0.8,0.86,0.95); environment.environment.ambient_light_energy=0.6; viewport.add_child(environment)
	for id: String in Modules.catalog():
		var model: Node3D=Modules.visual(id); viewport.add_child(model)
		var box: AABB=AABB(); var first: bool=true
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=mesh.global_transform*mesh.get_aabb()
			box=bounds if first else box.merge(bounds); first=false
		var center: Vector3=box.get_center(); camera.size=maxf(1.3,box.size.length()*0.95); camera.position=center+Vector3(1,0.8,1.3).normalized()*maxf(5,box.size.length()*2); camera.look_at(center)
		await process_frame; await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://Adventure/generated/thumbnails/"+id+".png")
		viewport.remove_child(model); model.free()
	print("THUMBNAILS_COMPLETE ",Modules.catalog().size()); quit()
