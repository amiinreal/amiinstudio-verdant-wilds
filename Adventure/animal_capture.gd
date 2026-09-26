extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene: Node3D = load("res://Adventure/animals/showcase.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	for clip: String in ["idle", "walk", "trot", "forage"]:
		for i: int in range(scene.players.size()):
			var player: AnimationPlayer = scene.players[i]
			player.play(("graze" if i == 2 else "sniff") if clip == "forage" else clip)
			player.seek(2.0 if clip == "forage" else 0.25, true)
			player.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/animals-" + clip + ".png")
	print("ANIMAL_CAPTURE_COMPLETE")
	quit()
