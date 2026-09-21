extends CharacterBody3D
## Preview-only controls. Uses physical keys without changing the project's InputMap.
var enabled: bool = false
var pitch: float = -0.08
@onready var camera: Camera3D = $Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.35, 1.35)
		camera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var input_direction: Vector2 = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction: Vector3 = basis * Vector3(input_direction.x, 0, input_direction.y)
	var speed: float = 10.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 5.5
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 28.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 28.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = 6.5
	move_and_slide()
