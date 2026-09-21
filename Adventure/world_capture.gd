extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.session.save_enabled=false; game.session.start_solo(73129,"Traveler")
	game.set_process(false); game.hud.hide()
	var camera: Camera3D=game.get_node("Overview"); camera.make_current(); camera.far=2500
	root.size=Vector2i(1280,800)
	var shots: Array=[["mainland",Vector3(295,290,365),Vector3(-25,25,-95)],["village",Vector3(-50,38,200),Vector3(-97,15,143)],["waterfall",Vector3(105,38,90),Vector3(42,17,36)],["forest",Vector3(-210,62,-118),Vector3(-255,40,-180)]]
	for shot: Array in shots:
		camera.position=shot[1]; camera.look_at(shot[2])
		await create_timer(2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/openworld_"+shot[0]+".png")
	game.hud.show(); game.hud.toggle_map()
	await create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/openworld_map.png")
	print("CAPTURE_COMPLETE")
	game.session.stop(false); quit()
