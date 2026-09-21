extends CharacterBody3D
const Items := preload("res://Adventure/items.gd")
const HERO: String="res://PlayerMesh/hero_male.glb"
const ANIMATIONS: Array[String]=["freehand_idle","freehand_walk","freehand_run","jump_start","freehand_fall","landing_soft","pose_lean_right"]
var nickname: String="Traveler"
var checkpoint: int=0
var move_input: Vector2=Vector2.ZERO
var wants_jump: bool=false
var sprinting: bool=false
var swimming: bool=false
var water_surface: float=-1000
var water_depth: float=0
var facing: float=0
var remote_position: Vector3=Vector3.ZERO
var remote_velocity: Vector3=Vector3.ZERO
var remote_yaw: float=0
var authoritative: bool=true
var animation_state: String="freehand_idle"
var equipped_tool: String="hand"
var _model: Node3D
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _tool_pivot: Node3D
var _tool: Node3D
var _action: float=0
var _action_name: String="HammerBuild"
var _work_clock: float=0
var _landing: float=0
var _was_grounded: bool=false

func configure(display_name: String,_color: Color,server_body: bool) -> void:
	nickname=display_name; authoritative=server_body
	collision_layer=2 if server_body else 0; collision_mask=5 if server_body else 0
	floor_snap_length=0.4; floor_max_angle=deg_to_rad(46); floor_constant_speed=true
	var collision: CollisionShape3D=CollisionShape3D.new(); var capsule: CapsuleShape3D=CapsuleShape3D.new(); capsule.radius=0.30; capsule.height=1.8
	collision.shape=capsule; collision.position.y=0.9; add_child(collision)
	var packed: PackedScene=load(HERO) as PackedScene
	if packed==null: push_error("PlayerMesh failed to load: "+HERO); return
	_model=packed.instantiate(); add_child(_model)
	_animation=_model.get_node("AnimationPlayer") as AnimationPlayer
	_skeleton=_model.get_node("HeroRig_export/Skeleton3D") as Skeleton3D
	for name: String in ANIMATIONS:
		if not _animation.has_animation(name): push_error("Missing verified PlayerMesh animation: "+name)
	for name: String in ["freehand_idle","freehand_walk","freehand_run","freehand_fall"]:
		_animation.get_animation(name).loop_mode=Animation.LOOP_LINEAR
	var actions: PackedScene=load("res://Adventure/generated/GameplayActions.glb") as PackedScene
	if actions!=null:
		var imported: Node=actions.instantiate()
		var source: AnimationPlayer=imported.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if source!=null:
			var library: AnimationLibrary=AnimationLibrary.new()
			for action_name: String in source.get_animation_list():
				if action_name=="RESET": continue
				var clip: Animation=source.get_animation(action_name).duplicate()
				if action_name.begins_with("Swim"): clip.loop_mode=Animation.LOOP_LINEAR
				library.add_animation(action_name,clip)
			_animation.add_animation_library("gameplay",library)
		imported.free()
	_animation.play("freehand_idle",0.15)
	var socket: BoneAttachment3D=BoneAttachment3D.new(); socket.bone_name="item_socket"; _skeleton.add_child(socket)
	_tool_pivot=Node3D.new(); socket.add_child(_tool_pivot)
	var label: Label3D=Label3D.new(); label.text=nickname; label.position.y=2.35; label.font_size=28; label.pixel_size=0.005; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end=28; label.modulate=Color("e6e9d7"); add_child(label)

func equip(id: String) -> void:
	if equipped_tool==id or Items.tool(id).is_empty(): return
	equipped_tool=id
	if _tool!=null: _tool.queue_free()
	if _tool_pivot==null: return
	_tool=Items.model(id); _tool_pivot.add_child(_tool)

func simulate(delta: float) -> void:
	var target: Vector2=move_input*((3.4 if sprinting else 2.4) if swimming else (7.5 if sprinting else 3.8))
	var acceleration: float=24 if move_input.length()>0.05 else 32
	velocity.x=move_toward(velocity.x,target.x,acceleration*delta)
	velocity.z=move_toward(velocity.z,target.y,acceleration*delta)
	var grounded: bool=is_on_floor()
	if swimming:
		floor_snap_length=0
		velocity.y=clampf((water_surface-1.05-position.y)*5.5,-3.0,3.0)
		if wants_jump: velocity.y=4.0
	else:
		floor_snap_length=0.4
		if not grounded: velocity.y-=22*delta
		elif wants_jump: velocity.y=7.8; grounded=false
	wants_jump=false; move_and_slide()
	if move_input.length()>0.05: facing=atan2(-move_input.x,-move_input.y)
	if is_on_floor() and not _was_grounded and velocity.length()<1: _landing=0.22
	_was_grounded=is_on_floor()
	var speed: float=Vector2(velocity.x,velocity.z).length()
	if swimming: animation_state="gameplay/SwimForward" if speed>0.25 else "gameplay/SwimIdle"
	elif not is_on_floor(): animation_state="jump_start" if velocity.y>0.5 else "freehand_fall"
	elif speed>5: animation_state="freehand_run"
	elif speed>0.25: animation_state="freehand_walk"
	else: animation_state="landing_soft" if _landing>0 else "freehand_idle"
	_visual(delta)

func interpolate(delta: float) -> void:
	position=position.lerp(remote_position,1-exp(-delta*18))
	facing=remote_yaw; _visual(delta)

func _visual(delta: float) -> void:
	if _model==null: return
	# The imported hero faces +Z; controller facing uses Godot's -Z forward.
	_model.rotation.x=lerpf(_model.rotation.x,0.55 if swimming and (move_input.length()>0.1 or Vector2(remote_velocity.x,remote_velocity.z).length()>0.25) else 0.0,1-exp(-delta*5))
	_model.rotation.y=lerp_angle(_model.rotation.y,facing+PI,1-exp(-delta*13))
	_landing=maxf(0,_landing-delta); _action=maxf(0,_action-delta)
	if _tool!=null: _tool.visible=not swimming and not (_action>0 and _action_name in ["GatherPlant","CraftStanding","CraftWorkbench","Pickup"])
	if _action>0 and _action_name in ["CraftStanding","CraftWorkbench"]:
		_work_clock+=delta
		if _work_clock>0.55:
			_work_clock=0
			var work: Vector3=_tool_pivot.global_position if _tool_pivot!=null else global_position+Vector3.UP
			preload("res://Adventure/effects.gd").particles(get_parent(),work,Color(0.7,0.6,0.4,0.25),4,Vector3.ONE*0.04,0.35,0.4,0.04,true)
	if _action<=0: _animation.speed_scale=1
	var desired: String="gameplay/"+_action_name if _action>0 and not swimming else animation_state
	if _animation.has_animation(desired) and _animation.current_animation!=desired: _animation.play(desired,0.15)
	if _tool_pivot!=null: _tool_pivot.rotation=Vector3.ZERO

func action(action_name: String="HammerBuild",duration: float=0.65) -> void:
	_action=duration; _action_name=action_name
	if _animation!=null and _animation.has_animation("gameplay/"+action_name):
		_animation.speed_scale=_animation.get_animation("gameplay/"+action_name).length/maxf(0.1,duration)
		_animation.play("gameplay/"+action_name,0.08)

func teleport(p: Vector3) -> void:
	position=p; remote_position=p; velocity=Vector3.ZERO

func update_water(surface: float, ground: float) -> void:
	water_surface=surface; water_depth=surface-ground
	swimming=water_depth>1.25 and position.y<surface-0.25
	if swimming: _action=0
