extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene: Node3D = load("res://Adventure/cooking/showcase.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/cooking-models.png")
	scene.queue_free()
	await process_frame
	var game: Node3D = load("res://Adventure/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for child: Node in game.get_children():
		if child is CanvasLayer and child.get_script() == load("res://Adventure/intro.gd"): child.hide()
	game.session.save_enabled = false
	game.session.start_solo(73129,"Cooking preview")
	game.session.set_physics_process(false)
	var station: Vector3 = game.session.world.cooking_stations[0]
	game.session.players[1].position = station + Vector3(0,0,1.8)
	var camera: Camera3D = game.get_node("Overview")
	camera.position = station + Vector3(2.8,2.0,4.0)
	camera.look_at(station + Vector3.UP*0.4)
	camera.make_current()
	game.session.world.update_streaming(station, [station])
	game.session.world.wildlife.tick(game.session.clock_time,0)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/cooking-in-game.png")
	game.session.store.profile(1).inventory.cooked_meat = 1
	game.session._publish_profile(1)
	game.hud.inventory_category = "Food"
	game.hud.inventory_item = "cooked_meat"
	game.hud.open_page("Inventory")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/cooked-food-inventory.png")
	game.session.stop(false)
	game.queue_free()
	await process_frame
	print("COOKING_CAPTURE_COMPLETE")
	quit()
