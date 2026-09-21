extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game); game.session.save_enabled=false; game.session.start_solo(73129,"Traveler"); game.set_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	root.size=Vector2i(1280,800); game.hud._notice_time=0
	var actor: CharacterBody3D=game.session.local_player(); var world: Node3D=game.session.world
	var camera: Camera3D=game.get_node("Overview"); camera.make_current()
	for id: String in ["axe","pickaxe","hammer"]:
		game.session.equip(id); game.hud.selected_slot=["axe","pickaxe","hammer"].find(id)
		camera.position=actor.position+Vector3(2.8,2,-4); camera.look_at(actor.position+Vector3.UP)
		await create_timer(0.4).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/fixed_grip_"+id+".png")
	var site: Vector3=actor.position
	camera.position=site+Vector3(0,6,7); camera.look_at(site)
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://Adventure/qa/grass_before.png")
	game.session._clear_grass(1,site); await create_timer(0.9).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/grass_after.png")
	var lake: Vector2=Vector2.ZERO
	for z in range(90,151,4):
		if lake!=Vector2.ZERO: break
		for x in range(-10,61,4):
			var at: Vector2=Vector2(x,z)
			if world.geography.water_height(at)-world.height_at(at)>2: lake=at; break
	var level: float=world.geography.water_height(lake)
	actor.teleport(Vector3(lake.x,level-1.05,lake.y)); actor.move_input=Vector2(0,-1); game.session._last_input_at[1]=game.session.clock_time+100
	camera.position=actor.position+Vector3(3.8,2.3,-4.5); camera.look_at(actor.position+Vector3.UP*1.0)
	await create_timer(1.0).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/swimming.png")
	print("SWIM_RENDER ",actor.swimming," clip=",actor.animation_state," y=",actor.position.y," surface=",level)
	game.session.stop(false); quit()
