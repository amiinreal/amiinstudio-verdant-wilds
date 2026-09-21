extends SceneTree
const PREVIEW := preload("res://styled Nature megaKit/ProceduralWorld/preview.tscn")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var preview: Node3D = PREVIEW.instantiate()
	root.add_child(preview)
	_check(preview.overview.current, "Overview camera not active on start")
	preview._toggle_mode()
	_check(preview.explorer.enabled and preview.explorer.camera.current, "Explore toggle failed")
	for i in range(100):
		await physics_frame
	_check(preview.explorer.is_on_floor(), "Explorer did not settle on terrain collision")
	var start: Vector3 = preview.explorer.position
	# Headless DisplayServer has no keyboard/captured mouse. Exercise the same
	# CharacterBody against actual terrain physics with an explicit walk velocity.
	preview.explorer.set_physics_process(false)
	for i in range(120):
		await physics_frame
		preview.explorer.velocity = Vector3(0, -2.0, -5.5)
		preview.explorer.move_and_slide()
	preview.explorer.set_physics_process(true)
	_check(preview.explorer.position.distance_to(start) > 5.0, "Explorer could not walk along the central trail")
	_check(preview.explorer.position.y > 3.5, "Explorer fell through terrain")
	preview._sound_site(1)
	_check(preview._activated.has(1), "Preview music activation failed")
	_check(preview._audio.stream != null, "Preview bell audio was not created")
	preview._sound_site(1)
	_check(not preview._activated.has(1), "Preview music deactivation failed")
	preview._seed_input.text = "42"
	preview._regenerate()
	_check(preview.world.world_seed == 42, "Seed field failed to regenerate the island")
	preview._seed_input.text = "invalid"
	preview._regenerate()
	_check(preview.world.world_seed == 42, "Invalid seed input changed the world")
	preview._toggle_mode()
	_check(preview.overview.current, "Returning to overview failed")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("PREVIEW VALIDATION ", "PASSED" if failures == 0 else "FAILED", " | ", failures, " failures | camera modes, standing/walking collision, bell, seed input")
	preview.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
