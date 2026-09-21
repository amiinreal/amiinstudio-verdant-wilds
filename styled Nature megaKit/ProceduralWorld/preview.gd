extends Node3D
const MAP_SCRIPT := preload("res://styled Nature megaKit/ProceduralWorld/map.gd")
@onready var world: Node3D = $World
@onready var explorer: CharacterBody3D = $Explorer
@onready var overview: Camera3D = $Overview
var _seed_input: LineEdit
var _status: Label
var _mode_button: Button
var _map: Control
var _orbit: float = 0.38
var _distance: float = 190.0
var _nearest: int = -1
var _activated: Dictionary = {}
var _audio: AudioStreamPlayer

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_ui()
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -16.0
	add_child(_audio)
	_position_explorer()
	_update_camera()

func _position_explorer() -> void:
	explorer.position = Vector3(0, world.sample_height(Vector2(0, 11)) + 1.5, 11)
	explorer.velocity = Vector3.ZERO
	explorer.rotation = Vector3.ZERO
	explorer.reset_physics_interpolation()

func _process(delta: float) -> void:
	if not explorer.enabled:
		_orbit += delta * 0.015
		_update_camera()
	else:
		var p: Vector3 = explorer.position
		# Preview safety: water has no swimming system; return to the dry gathering area.
		if p.y < 0.45 or Vector2(p.x, p.z).length() > world.world_size * 0.46:
			_position_explorer()
	_nearest = -1
	if explorer.enabled:
		for i in range(world.sites.size()):
			if explorer.position.distance_to(world.sites[i]) < 7.0 * world.world_size / 224.0:
				_nearest = i
	var biome: String = world.biome_at(Vector2(explorer.position.x, explorer.position.z)) if explorer.enabled else "ISLAND OVERVIEW"
	_status.text = "%s   /   %d of 6 sites resonating" % [biome, _activated.size()]
	if _nearest >= 0:
		_status.text = world.SITE_NAMES[_nearest] + "   /   E to sound the clearing"
	_map.queue_redraw()

func _update_camera() -> void:
	var factor: float = world.world_size / 224.0
	overview.position = Vector3(sin(_orbit) * _distance, _distance * 0.71, cos(_orbit) * _distance) * factor
	overview.look_at(Vector3(0, 1, 0))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_TAB:
			_toggle_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and _nearest >= 0 and not _seed_input.has_focus():
			_sound_site(_nearest)

func _unhandled_input(event: InputEvent) -> void:
	if not explorer.enabled and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_orbit -= event.relative.x * 0.006
	if not explorer.enabled and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(45.0, _distance - 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(240.0, _distance + 8.0)

func _toggle_mode() -> void:
	explorer.enabled = not explorer.enabled
	if explorer.enabled:
		explorer.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mode_button.text = "Island overview  [Tab]"
	else:
		overview.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mode_button.text = "Explore on foot  [Tab]"

func _regenerate() -> void:
	if not _seed_input.text.is_valid_int():
		_seed_input.text = str(world.world_seed)
		return
	world.world_seed = int(_seed_input.text)
	world.generate()
	_activated.clear()
	_position_explorer()
	_seed_input.release_focus()

func _sound_site(index: int) -> void:
	var active: bool = not _activated.has(index)
	if active:
		_activated[index] = true
	else:
		_activated.erase(index)
	world.set_resonance(index, active)
	# Original synthesized bell; no external audio files or global audio settings.
	var notes: Array[float] = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
	var bytes: PackedByteArray = PackedByteArray()
	var sample_rate: int = 22050
	bytes.resize(sample_rate * 2)
	for i in range(sample_rate):
		var t: float = float(i) / sample_rate
		var envelope: float = minf(t * 80.0, 1.0) * exp(-t * 5.5) * (1.0 - t)
		var value: float = (sin(TAU * notes[index] * t) + sin(TAU * notes[index] * 2.0 * t) * 0.25) * envelope * 0.65
		bytes.encode_s16(i * 2, int(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	_audio.stream = stream
	_audio.play()

func _panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.085, 0.075, 0.90)
	style.border_color = Color(0.65, 0.76, 0.56, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _label(text_value: String, font_size: int, color: Color = Color("edead8")) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(26, 26)
	panel.add_theme_stylebox_override("panel", _panel())
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	stack.add_child(_label("N A T U R E   M E G A K I T   /   W O R L D   S T U D Y", 11, Color("a8c29a")))
	stack.add_child(_label("Resonant Wilds", 32))
	stack.add_child(_label("Six clearings. One connected wilderness.", 14, Color("b4c3b5")))
	var controls: PanelContainer = PanelContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.position = Vector2(-258, 26)
	controls.custom_minimum_size = Vector2(232, 0)
	controls.add_theme_stylebox_override("panel", _panel())
	root.add_child(controls)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	controls.add_child(box)
	box.add_child(_label("ISLAND SEED", 11, Color("a8c29a")))
	_seed_input = LineEdit.new()
	_seed_input.text = str(world.world_seed)
	_seed_input.max_length = 10
	_seed_input.text_submitted.connect(func(_text: String) -> void: _regenerate())
	box.add_child(_seed_input)
	var rebuild: Button = Button.new()
	rebuild.text = "Generate island"
	rebuild.pressed.connect(_regenerate)
	box.add_child(rebuild)
	_mode_button = Button.new()
	_mode_button.text = "Explore on foot  [Tab]"
	_mode_button.pressed.connect(_toggle_mode)
	box.add_child(_mode_button)
	_map = Control.new()
	_map.set_script(MAP_SCRIPT)
	_map.world = world
	_map.explorer = explorer
	_map.custom_minimum_size = Vector2(192, 192)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_map)
	box.add_child(_label("N  /  PINEWATCH\nW  /  WHISPERWOOD\nE  /  SUNMEADOW", 11, Color("b4c3b5")))
	var footer: PanelContainer = PanelContainer.new()
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 26
	footer.offset_right = -26
	footer.offset_top = -102
	footer.offset_bottom = -26
	footer.add_theme_stylebox_override("panel", _panel())
	var footbox: VBoxContainer = VBoxContainer.new()
	footer.add_child(footbox)
	_status = _label("ISLAND OVERVIEW", 15)
	footbox.add_child(_status)
	footbox.add_child(_label("WASD  Move     Shift  Run     Space  Jump     E  Resonate     Tab  View     Esc  Cursor     Overview: right-drag / scroll", 12, Color("a8bcae")))
