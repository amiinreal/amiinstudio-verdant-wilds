extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	root.size=Vector2i(1280,800)
	await create_timer(0.3).timeout
	for child: Node in game.get_children():
		if child is CanvasLayer and child.get_script()==preload("res://Adventure/intro.gd"):
			var key: InputEventKey=InputEventKey.new(); key.pressed=true; key.keycode=KEY_ENTER
			child._unhandled_input(key)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("res://Adventure/qa/welcome-ui.png")
	print("WELCOME_CAPTURE_COMPLETE")
	game.queue_free(); quit()
