extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	game.session.save_enabled=false; game.session.start_solo(73129,"Traveler"); game.set_process_input(false); game.set_process_unhandled_input(false)
	root.size=Vector2i(1280,800)
	var profile: Dictionary=game.session.store.profile(1)
	for id: String in profile.inventory: profile.inventory[id]=40
	game.session._publish_profile(1)
	game.hud._notice_time=0
	await create_timer(2).timeout
	for page: String in ["Build","Inventory","Crafting"]:
		game.hud.open_page(page); await create_timer(0.5).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/polish_"+page.to_lower()+".png")
	game.hud.close_menu(); game.set_process(false)
	var actor: CharacterBody3D=game.session.local_player()
	var camera: Camera3D=game.get_node("Overview"); camera.make_current(); camera.position=actor.position+Vector3(2.6,2.2,-3.8); camera.look_at(actor.position+Vector3.UP*1.2)
	actor.action("AxeSwing",2); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/polish_axe.png")
	var site: Vector3=Vector3.ZERO
	var build: Script=preload("res://Adventure/construction.gd")
	for z in range(50,230,4):
		if site!=Vector3.ZERO: break
		for x in range(-70,0,4):
			var candidate: Vector3=Vector3(x,game.session.world.height_at(Vector2(x,z))+0.5,z)
			if build.validate(game.session.world,[],"foundation_stone",candidate,0,"host",candidate,false).ok: site=candidate; break
	actor.teleport(site+Vector3(4,1,0)); camera.position=site+Vector3(0,5,8); camera.look_at(site)
	game._build_selected(preload("res://Adventure/modules.gd").catalog().keys().find("foundation_stone"))
	await create_timer(2).timeout
	game.builder.update(camera,false); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/polish_preview.png")
	print("PREVIEW_VALID ",game.builder.valid," ",game.session.build_hint)
	game.builder.enabled=false; game.builder.update(camera,false)
	game.hud.hide(); camera.position=Vector3(105,38,90); camera.look_at(Vector3(42,17,36)); await create_timer(2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/polish_waterfall.png")
	print("POLISH_CAPTURE_COMPLETE"); game.session.stop(false); quit()
