extends CharacterBody3D
var nickname: String = "Traveler"
var health: int = 100
var checkpoint: int = 0
var move_input: Vector2 = Vector2.ZERO
var wants_jump: bool = false
var facing: float = 0.0
var remote_position: Vector3 = Vector3.ZERO
var remote_yaw: float = 0.0
var remote_velocity: Vector3 = Vector3.ZERO
var authoritative: bool = true
var _model: Node3D
var _cape: MeshInstance3D
var _label: Label3D
var _time: float = 0

func configure(display_name: String, color: Color, server_body: bool) -> void:
	nickname = display_name
	authoritative = server_body
	collision_layer = 2 if server_body else 0
	collision_mask = 5 if server_body else 0
	floor_snap_length = 0.5
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	_model = Node3D.new()
	add_child(_model)
	var cloak: CylinderMesh = CylinderMesh.new()
	cloak.top_radius = 0.25
	cloak.bottom_radius = 0.52
	cloak.height = 0.95
	_cape = _part(cloak, color, Vector3(0, 0.73, 0))
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.28
	head.height = 0.55
	_part(head, Color("e9c39c"), Vector3(0, 1.43, -0.03))
	var hood: CylinderMesh = CylinderMesh.new()
	hood.top_radius = 0.0
	hood.bottom_radius = 0.39
	hood.height = 0.5
	_part(hood, color.darkened(0.2), Vector3(0, 1.77, 0.06))
	var eye: SphereMesh = SphereMesh.new()
	eye.radius = 0.04
	eye.height = 0.07
	_part(eye, Color("233335"), Vector3(-0.105, 1.47, -0.27))
	_part(eye, Color("233335"), Vector3(0.105, 1.47, -0.27))
	var foot: BoxMesh = BoxMesh.new()
	foot.size = Vector3(0.2, 0.22, 0.38)
	_part(foot, Color("48453a"), Vector3(-0.19, 0.11, -0.04))
	_part(foot, Color("48453a"), Vector3(0.19, 0.11, -0.04))
	var instrument: CylinderMesh = CylinderMesh.new()
	instrument.top_radius = 0.11
	instrument.bottom_radius = 0.11
	instrument.height = 0.8
	var flute: MeshInstance3D = _part(instrument, Color("f2d897"), Vector3(0.38, 0.88, -0.2))
	flute.rotation.z = -0.25
	_label = Label3D.new()
	_label.text = nickname
	_label.position.y = 2.25
	_label.font_size = 30
	_label.pixel_size = 0.007
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

func _part(mesh: Mesh, color: Color, p: Vector3) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.mesh = mesh
	node.material_override = mat
	node.position = p
	_model.add_child(node)
	return node

func simulate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, move_input.x * 7.5, delta * 32.0)
	velocity.z = move_toward(velocity.z, move_input.y * 7.5, delta * 32.0)
	if not is_on_floor():
		velocity.y -= 19.0 * delta
	elif wants_jump:
		velocity.y = 7.3
	wants_jump = false
	move_and_slide()
	if move_input.length() > 0.05:
		facing = atan2(-move_input.x, -move_input.y)
	_model.rotation.y = lerp_angle(_model.rotation.y, facing, minf(1, delta * 12))
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func interpolate(delta: float) -> void:
	position = position.lerp(remote_position, minf(delta * 18, 1))
	_model.rotation.y = lerp_angle(_model.rotation.y, remote_yaw, minf(delta * 18, 1))
	_animate(delta, Vector2(remote_velocity.x, remote_velocity.z).length())

func _animate(delta: float, speed: float) -> void:
	_time += delta
	_cape.rotation.z = sin(_time * 12) * minf(speed * 0.012, 0.09)
	_model.position.y = absf(sin(_time * 10)) * minf(speed * 0.008, 0.055)

func teleport(p: Vector3) -> void:
	position = p
	remote_position = p
	velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	reset_physics_interpolation()
