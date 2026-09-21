extends SceneTree
const Main := preload("res://Adventure/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var game: Node3D = Main.instantiate()
	root.add_child(game)
	game.session.save_enabled = false
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/menu.png")
	game.session.start_solo(73129, "Traveler")
	game.set_process(false)
	game.rig.position = game.session.local_player().position + Vector3(0, 1.5, 0)
	game.rig.rotation = Vector3(-0.35, 0, 0)
	for i in range(100):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/adventure.png")
	_check_panels(game)
	for note: int in [0, 1, 2]:
		game.session.play_note(note)
		await create_timer(0.2).timeout
	await create_timer(2.1).timeout
	game.hud.toggle_map()
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/map.png")
	_check_panels(game)
	game.hud.toggle_map()
	game.hud.toggle_book()
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Adventure/qa/songbook.png")
	_check_panels(game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("CAPTURE_PASS menu adventure map songbook")
	game.session.stop(false)
	quit()

func _check_panels(game: Node3D) -> void:
	for panel: Node in game.hud._root.find_children("*", "PanelContainer", true, false):
		if panel.is_visible_in_tree():
			var rect: Rect2 = panel.get_global_rect()
			if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 1281 or rect.end.y > 801:
				push_error("UI panel outside viewport: " + str(rect))
