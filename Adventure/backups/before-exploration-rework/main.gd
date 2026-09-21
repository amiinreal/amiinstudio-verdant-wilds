extends Node3D
const Rules := preload("res://Adventure/rules.gd")
@onready var session: Node3D = $Session
@onready var hud: CanvasLayer = $HUD
@onready var audio: Node = $Audio
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var rig: Node3D = $CameraRig
@onready var arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var overview: Camera3D = $Overview
var builder: Node3D
var camera_yaw: float = 0
var camera_pitch: float = -0.35
var _input_timer: float = 0
var _jump: bool = false
var _listen_epoch: int = 0
var _orbit: float = 0

func _ready() -> void:
	builder=Node3D.new(); builder.set_script(preload("res://Adventure/builder.gd")); builder.session=session; add_child(builder)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	hud.bind_session(session)
	hud.solo_requested.connect(session.start_solo)
	hud.host_requested.connect(session.host_game)
	hud.join_requested.connect(session.join_game)
	hud.note_requested.connect(session.play_note)
	hud.next_requested.connect(_next_expedition)
	hud.mute_requested.connect(audio.toggle_mute)
	session.message.connect(hud.show_message)
	session.session_started.connect(_started)
	session.session_stopped.connect(_stopped)
	session.state_changed.connect(_state_changed)
	session.note_played.connect(_note)
	audio.set_layers(0)
	arm.collision_mask = 5
	if "--no-save" in OS.get_cmdline_user_args():
		session.save_enabled = false

func _started() -> void:
	_listen_epoch += 1
	hud.started()
	camera_yaw = 0
	camera_pitch = -0.35
	camera.make_current()

func _stopped() -> void:
	_listen_epoch += 1
	hud.stopped()
	overview.make_current()

func _next_expedition() -> void:
	if session.is_authority() and session.state["solved"][6]:
		session.next_expedition()
		hud.started()

func _state_changed() -> void:
	hud.refreshed()
	audio.set_layers(session.state["solved"].count(true))
	if not session.state["solved"][6]:
		hud._victory.hide()

func _note(p: Vector3, note: int, echo: bool) -> void:
	var player: CharacterBody3D = session.local_player()
	if player != null and player.position.distance_to(p) < 65:
		audio.play_note(note, echo)
		hud.flash_note(note)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and session.running and not hud.blocks_movement() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -1.1, 0.18)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			hud.toggle_menu()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not session.running or hud.menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_M:
			hud.toggle_map()
		elif key == KEY_J:
			hud.toggle_book()
		elif not hud.blocks_movement():
			if builder.key(key):
				pass
			elif key == KEY_G:
				session.gather()
			elif key == KEY_C:
				session.craft("planks")
			elif key == KEY_V:
				session.craft("rope")
			elif key >= KEY_1 and key <= KEY_5:
				session.play_note(key - KEY_1)
			elif key == KEY_Q:
				_listen()
			elif key == KEY_E:
				session.interact()
			elif key == KEY_R:
				session.request_echo()
			elif key == KEY_H:
				session.recall()
			elif key == KEY_SPACE:
				_jump = true

func _process(delta: float) -> void:
	builder.update(camera_yaw,hud.blocks_movement())
	if not session.running:
		_orbit += delta * 0.018
		overview.position = Vector3(sin(_orbit) * 210 + 230, 290, cos(_orbit) * 180 + 320)
		overview.look_at(Vector3(0, 25, -85))
		return
	var player: CharacterBody3D = session.local_player()
	if player == null:
		return
	var target: Vector3 = player.position + Vector3(0, 1.5, 0)
	if rig.position.distance_to(target) > 20:
		rig.position = target
	else:
		rig.position = rig.position.lerp(target, minf(1, delta * 16))
	rig.rotation = Vector3(camera_pitch, camera_yaw, 0)
	_input_timer += delta
	if _input_timer >= 0.033:
		_input_timer = 0
		var input_direction: Vector2 = Vector2.ZERO
		if not hud.blocks_movement():
			input_direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
		var direction: Vector3 = Basis(Vector3.UP, camera_yaw) * Vector3(input_direction.x, 0, input_direction.y)
		session.submit_input(Vector2(direction.x, direction.z), camera_yaw, _jump)
		_jump = false

func _listen() -> void:
	var site: int = session.nearest_site(session.local_id())
	if site < 0:
		hud.show_message("Move close to a shrine to hear its melody. The songbook [J] holds your learned spells.")
		return
	_listen_epoch += 1
	var epoch: int = _listen_epoch
	var phrase: Array = Rules.melodies(session.state["seed"])[site]
	hud.show_message("Listen: " + Rules.phrase_text(phrase) + (". The wind answers backwards." if site == 1 else ". Answer with keys 1–5."))
	for note: int in phrase:
		if epoch != _listen_epoch or not session.running:
			return
		audio.play_note(note)
		hud.flash_note(note)
		await get_tree().create_timer(0.48).timeout
