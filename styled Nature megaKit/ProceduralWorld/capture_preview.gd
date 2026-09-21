extends SceneTree
## Optional visual QA. Launch with a graphics renderer, not --headless.
const PREVIEW := preload("res://styled Nature megaKit/ProceduralWorld/preview.tscn")
const OUTPUT := "res://styled Nature megaKit/ProceduralWorld/"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var preview: Node3D = PREVIEW.instantiate()
	root.add_child(preview)
	for i in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "preview_overview.png")
	preview.set_process(false)
	preview.overview.position = Vector3(6, 13, 31)
	preview.overview.look_at(Vector3(-7, 5, -12))
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "preview_ground.png")
	print("Visual previews saved inside ProceduralWorld.")
	quit()
