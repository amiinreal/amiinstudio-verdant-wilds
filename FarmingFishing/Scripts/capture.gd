extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1600, 1000)
	var packed: PackedScene = load("res://FarmingFishing/Scenes/preview.tscn")
	var preview: Node3D = packed.instantiate()
	root.add_child(preview)
	for crop: Node3D in preview.get("crops"):
		crop.set("progress", 1.0)
		crop.call("_update_stage", false)
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://FarmingFishing/godot_preview.png")
	print("FARMING_CAPTURE_OK")
	quit()
