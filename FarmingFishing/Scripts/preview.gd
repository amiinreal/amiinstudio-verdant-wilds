extends Node3D

const Crop = preload("res://FarmingFishing/Scripts/crop.gd")
const Plot = preload("res://FarmingFishing/Scripts/farm_plot.gd")
var crops: Array[Node3D] = []
var plots: Array[Node3D] = []
var fish: Array[Node3D] = []
var camera: Camera3D
var status: Label
var elapsed: float = 0.0
var paused: bool = false
var water: bool = true
var collected: int = 0
var yaw: float = 0.0

func model(key: String, at: Vector3, size: float = 1.0) -> Node3D:
	var packed: PackedScene = load("res://FarmingFishing/Models/" + key + ".glb")
	var item: Node3D = packed.instantiate()
	add_child(item)
	item.position = at
	item.scale = Vector3.ONE * size
	return item

func block(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cube.material = mat
	mesh.mesh = cube
	mesh.position = at
	add_child(mesh)

func label3(text: String, at: Vector3, size: int = 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f5e8cd")
	add_child(label)

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("253f46")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e4df")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.4
	add_child(camera)
	camera.position = Vector3(7, 11, 14)
	camera.look_at(Vector3(0, 0, 0))
	block(Vector3(0, -.65, 0), Vector3(12.5, .35, 8.5), Color("50634b"))
	# Fixed growth-stage display across the rear.
	for row in range(2):
		var kind: String = "carrot" if row == 0 else "wheat"
		var z: float = -2.9 + row * 1.5
		label3(kind.to_upper(), Vector3(-4.8, .35, z))
		model(kind + "_seeds", Vector3(-3.5, .05, z), 2.3)
		for stage in range(4):
			var x: float = -2.0 + stage * 1.4
			model("farmland_wet", Vector3(x, 0, z))
			model(kind + "_stage_%d" % stage, Vector3(x, .03, z))
			label3(["SPROUT", "YOUNG", "GROWING", "MATURE"][stage], Vector3(x, .05, z+.65), 20)
		model(kind + "_harvest", Vector3(4.0, .1, z), 1.2)
	label3("LIVE GROWTH", Vector3(-3.3, .2, .20), 30)
	for row in range(2):
		for col in range(3):
			var plot := Node3D.new()
			plot.set_script(Plot)
			plot.position = Vector3(-4.5+col*1.04, 0, 1.15+row*1.04)
			add_child(plot)
			plots.append(plot)
			var crop := Node3D.new()
			crop.set_script(Crop)
			crop.set("crop_type", "carrot" if row==0 else "wheat")
			crop.set("growth_seconds", 16.0)
			plot.add_child(crop)
			crops.append(crop)
	for row in range(2):
		model("irrigation_channel", Vector3(-1.36, 0, 1.15+row*1.04))
	model("farmland_dry", Vector3(-4.5, 0, 3.2))
	label3("DRY", Vector3(-3.55, .05, 3.2), 22)
	model("fishing_rod", Vector3(.1, 0, 1.9))
	model("landing_net", Vector3(1.25, 0, 1.8))
	model("fishing_bobber", Vector3(.35, .05, 3.1), 1.8)
	model("fishing_hook", Vector3(1.2, .05, 3.1), 2.0)
	label3("FISHING KIT", Vector3(.7, .1, 3.65), 26)
	block(Vector3(3.7, -.15, 1.9), Vector3(3.0, .3, 3.0), Color("387d87"))
	for i in range(2):
		var item: Node3D = model("river_fish" if i==0 else "salmon", Vector3(3.7, .3, 1.15+i*1.3), 1.8)
		fish.append(item)
		_play_animations(item)
	label3("RIVER FISH  /  SALMON", Vector3(3.7, .2, 3.65), 24)
	_make_ui()

func _play_animations(node: Node) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node as AnimationPlayer
		for animation_name in player.get_animation_list():
			if animation_name != "RESET":
				player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
				player.play(animation_name)
				break
	for child in node.get_children():
		_play_animations(child)

func _make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	canvas.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var title := Label.new()
	title.text = "  FIELD & STREAM  |  Farming + fishing  "
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	var hint := Label.new()
	hint.text = "  Right-drag: orbit  /  Scroll: zoom  /  Live crops: 16 seconds  "
	layout.add_child(hint)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	for entry: Array in [["Replant", _replant], ["Harvest ripe crops", _harvest], ["Water / dry", _water], ["Pause / resume", _pause]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	status = Label.new()
	layout.add_child(status)

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(fish.size()):
		fish[i].position.y = .35 + sin(elapsed*2.0+i)*.05
		fish[i].rotation.y = sin(elapsed+i)*.12
	var ripe: int = 0
	for crop in crops:
		if crop.call("is_mature"):
			ripe += 1
	status.text = "  %s  |  %s  |  Ripe: %d/6  |  Harvested: %d" % ["Watered" if water else "Dry: growth stopped", "Paused" if paused else "Growing", ripe, collected]

func _replant() -> void:
	for crop in crops:
		crop.call("plant", crop.get("crop_type"))

func _harvest() -> void:
	for crop in crops:
		var result: Dictionary = crop.call("harvest")
		collected += int(result.get("amount", 0))

func _water() -> void:
	water = not water
	for plot in plots:
		plot.call("set_watered", water)

func _pause() -> void:
	paused = not paused
	for crop in crops:
		crop.set("growing", not paused)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * .006
		camera.position = Vector3(sin(yaw+.46)*15.7, 11, cos(yaw+.46)*15.7)
		camera.look_at(Vector3.ZERO)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(5.0, camera.size-0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(23.0, camera.size+0.7)
