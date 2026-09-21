extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	game.session.save_enabled=false; game.session.start_solo(73129,"Traveler"); game.set_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	root.size=Vector2i(1280,800)
	var actor: CharacterBody3D=game.session.players[1]
	var camera: Camera3D=game.get_node("Overview"); camera.make_current()
	for id: String in ["axe","pickaxe","hammer"]:
		game.session.equip(id)
		camera.position=actor.position+Vector3(2.6,2.2,-3.8); camera.look_at(actor.position+Vector3.UP*1.2)
		await create_timer(1).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/player_"+id+".png")
		print("HERO_GROUND ",actor.position," terrain=",game.session.world.height_at(Vector2(actor.position.x,actor.position.z))," floor=",actor.is_on_floor()," foot=",actor._skeleton.get_bone_global_pose(4).origin)
	game.hud.open_page("Camp"); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/escape_menu.png")
	game.session.stop(false); print("CHARACTER_CAPTURE_COMPLETE"); quit()
