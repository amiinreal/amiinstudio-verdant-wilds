extends Node3D
@onready var session: Node3D=$Session
@onready var hud: CanvasLayer=$HUD
@onready var camera: Camera3D=$CameraRig/SpringArm3D/Camera3D
@onready var rig: Node3D=$CameraRig
@onready var arm: SpringArm3D=$CameraRig/SpringArm3D
@onready var overview: Camera3D=$Overview
var builder: Node3D
var music: AudioStreamPlayer
var atmosphere: Node3D
var camera_yaw: float=0
var camera_pitch: float=-0.24
var sensitivity: float=0.0025
var _input_timer: float=0
var _jump: bool=false
var _orbit: float=0

func _ready() -> void:
	music=AudioStreamPlayer.new(); music.set_script(preload("res://Adventure/peaceful_music.gd")); add_child(music)
	DisplayServer.window_set_title("The Verdant Wilds")
	get_viewport().msaa_3d=Viewport.MSAA_2X
	builder=Node3D.new(); builder.set_script(preload("res://Adventure/builder.gd")); builder.session=session; add_child(builder)
	hud.bind_session(session); hud.game=self
	hud.solo_requested.connect(session.start_solo); hud.host_requested.connect(session.host_game); hud.join_requested.connect(session.join_game)
	hud.leave_requested.connect(session.stop); hud.build_requested.connect(_build_selected)
	session.message.connect(hud.show_message); session.session_started.connect(_started); session.session_stopped.connect(_stopped)
	arm.collision_mask=5; arm.spring_length=5.5
	atmosphere=Node3D.new(); atmosphere.set_script(preload("res://Adventure/atmosphere.gd")); add_child(atmosphere); atmosphere.setup(session,$WorldEnvironment,$Sun)
	var intro: CanvasLayer=CanvasLayer.new(); intro.set_script(preload("res://Adventure/intro.gd")); add_child(intro)
	if "--no-save" in OS.get_cmdline_user_args(): session.save_enabled=false

func _started() -> void:
	hud.started(); camera_yaw=0; camera_pitch=-0.24; camera.make_current()

func _stopped() -> void:
	builder.enabled=false; session.build_hint=""; hud.stopped(); overview.make_current()

func _build_selected(index: int) -> void:
	builder.index=index; builder.enabled=true
	if session.has_method("equip"): session.equip("hammer")
	hud.close_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and session.running and (not hud.menu_open or hud.page=="Inventory"):
		builder.enabled=false; session.build_hint=""
		if hud.menu_open and hud.page=="Inventory": hud.close_menu()
		else: hud.open_page("Inventory")
		get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B and hud.menu_open and hud.page=="Build" and not get_viewport().gui_get_focus_owner() is LineEdit:
		hud.close_menu(); builder.enabled=false; session.build_hint=""; get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion and session.running and not hud.blocks_movement() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		camera_yaw-=event.relative.x*sensitivity
		camera_pitch=clampf(camera_pitch-event.relative.y*sensitivity,-1.1,0.35)
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE):
		builder.enabled=false; session.build_hint=""; hud.toggle_menu(); get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not session.running or hud.blocks_movement(): return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if builder.enabled:
			if builder.removal_armed and not builder.removal_id.is_empty(): hud.confirm_removal(builder.removal_id)
			elif builder.valid: session.place(preload("res://Adventure/modules.gd").catalog().keys()[builder.index],builder.candidate,builder.turn)
		else: session.gather()
	if event is InputEventMouseButton and event.pressed and builder.enabled:
		if event.button_index==MOUSE_BUTTON_RIGHT: builder.enabled=false; session.build_hint=""; hud.open_page("Build")
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP: builder.index=posmod(builder.index+1,preload("res://Adventure/modules.gd").catalog().size())
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: builder.index=posmod(builder.index-1,preload("res://Adventure/modules.gd").catalog().size())
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key>=KEY_1 and key<=KEY_8:
			hud.selected_slot=key-KEY_1
			var tool: String=["axe","pickaxe","hammer","hand","hand","hand","hand","hand"][hud.selected_slot]
			if session.has_method("equip"): session.equip(tool)
			builder.enabled=false; session.build_hint=""
		elif key==KEY_B:
			if builder.enabled: builder.enabled=false; session.build_hint=""
			else: hud.open_page("Build")
		elif key==KEY_M: hud.open_page("Map")
		elif builder.key(key):
			if builder.enabled and session.has_method("equip"): session.equip("hammer")
		elif key==KEY_C:
			var actor: CharacterBody3D=session.local_player()
			if actor!=null: session.clear_grass(builder.candidate if builder.enabled and builder.ghost!=null and builder.ghost.visible else actor.position)
		elif key==KEY_V:
			var actor: CharacterBody3D=session.local_player()
			if actor!=null: session.flatten_land(builder.candidate if builder.enabled and builder.ghost!=null and builder.ghost.visible else actor.position)
		elif key==KEY_G or key==KEY_Q: session.gather()
		elif key==KEY_SPACE: _jump=true
		elif key==KEY_DELETE and builder.enabled and session.has_method("remove_nearest"): session.remove_nearest()

func _process(delta: float) -> void:
	builder.update(camera,hud.blocks_movement())
	if not session.running:
		_orbit+=delta*0.018
		overview.position=Vector3(sin(_orbit)*30-50,38,cos(_orbit)*30+185)
		overview.look_at(Vector3(-95,15,145)); return
	var player: CharacterBody3D=session.local_player()
	if player==null: return
	var target: Vector3=player.position+Vector3(0,1.55,0)
	rig.position=target if rig.position.distance_to(target)>20 else rig.position.lerp(target,1-exp(-delta*14))
	rig.rotation=Vector3(camera_pitch,camera_yaw,0)
	_input_timer+=delta
	if _input_timer>=0.033:
		_input_timer=0
		var input_direction: Vector2=Vector2.ZERO
		if not hud.blocks_movement():
			input_direction=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
		var direction: Vector3=Basis(Vector3.UP,camera_yaw)*Vector3(input_direction.x,0,input_direction.y)
		session.submit_input(Vector2(direction.x,direction.z),camera_yaw,_jump,Input.is_physical_key_pressed(KEY_SHIFT) and not hud.blocks_movement())
		_jump=false
