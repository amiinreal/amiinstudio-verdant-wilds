extends Node3D
## Standalone art review: 1 idle, 2 walk, 3 trot, 4 sniff/graze; Space pauses.
var players: Array[AnimationPlayer] = []
var species: Array[String] = []

func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("203c37")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8dece")
	env.environment.ambient_light_energy = 0.35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("536d52")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	var index: int = 0
	for kind: String in ["cat", "dog", "cow"]:
		var model: Node3D = load("res://Adventure/animals/" + kind + ".glb").instantiate()
		model.position.x = (index - 1) * 1.9
		model.rotation.y = PI - 0.35
		add_child(model)
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		players.append(player)
		species.append(kind)
		for clip: StringName in player.get_animation_list():
			if clip != &"RESET": player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play("idle")
		var label: Label3D = Label3D.new()
		label.text = kind.to_upper()
		label.position = Vector3(model.position.x, 0.02, 0.9)
		label.rotation_degrees.x = -70
		label.font_size = 48
		label.pixel_size = 0.004
		add_child(label)
		index += 1
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(3.7, 3.1, 6.3)
	add_child(camera)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.make_current()
	var help: Label = Label.new()
	help.text = "VERDANT WILDS / WOODLAND COMPANIONS\n1 Idle   2 Walk   3 Trot   4 Sniff / Graze   Space Pause"
	help.position = Vector2(28, 24)
	help.add_theme_font_size_override("font_size", 20)
	add_child(help)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	for i: int in range(players.size()):
		if event.keycode == KEY_SPACE:
			if players[i].is_playing(): players[i].pause()
			else: players[i].play()
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
			var clips: Array[String] = ["idle", "walk", "trot", "graze" if species[i] == "cow" else "sniff"]
			players[i].play(clips[event.keycode - KEY_1], 0.2)
