extends Node3D
const Rules := preload("res://Adventure/rules.gd")
const KIT: String = "res://styled Nature megaKit/glTF/"
const WATER := preload("res://Adventure/water.gdshader")
var seed_value: int = 73129
var shrines: Array[Node3D] = []
var bridges: Array[Node3D] = []
var treasures: Array[Node3D] = []
var sentinels: Array[Node3D] = []
var terrain_meshes: Array[MeshInstance3D] = []
var placements: Dictionary = {}
var _cache: Dictionary = {}
var _noise: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _root: Node3D
var _materials: Array[StandardMaterial3D] = []
var _reveal_until: float = 0.0
var _stun_until: float = 0.0
var _time: float = 0.0
var _solved: Array = []

## Shared optional-music visuals. Terrain and placement are supplied by open_world.gd.
func height_at(_p: Vector2, _region: int=-1) -> float:
	return 0

func shrine_position(index: int) -> Vector3:
	return Vector3(Rules.CENTERS[index].x,0,Rules.CENTERS[index].y)

func _queue(_asset: String, _p: Vector2, _size: float, _yaw: float) -> void:
	pass

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func mesh_node(mesh: Mesh, mat: Material, parent: Node3D, p: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = p
	parent.add_child(instance)
	return instance

func _build_shrine(index: int) -> void:
	var shrine: Node3D = Node3D.new()
	shrine.name = "Shrine_%d" % index
	shrine.position = shrine_position(index)
	_root.add_child(shrine)
	shrines.append(shrine)
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 2.3
	cylinder.bottom_radius = 2.6
	cylinder.height = 0.25
	mesh_node(cylinder, material(Color("61766c")), shrine, Vector3(0, 0.04, 0))
	var mat: StandardMaterial3D = material(Rules.COLORS[index % 5], 0.5)
	_materials.append(mat)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 2.2
	ring.outer_radius = 2.32
	mesh_node(ring, mat, shrine, Vector3(0, 0.2, 0))
	var crystal: PrismMesh = PrismMesh.new()
	crystal.size = Vector3(0.7, 1.4, 0.7)
	var rune: MeshInstance3D = mesh_node(crystal, mat, shrine, Vector3(0, 1.8, 0))
	rune.name = "HeartRune"
	var label: Label3D = Label3D.new()
	label.text = Rules.NAMES[index]
	label.font_size = 34
	label.outline_size = 7
	label.pixel_size = 0.008
	label.position = Vector3(0, 4.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("efe6bf")
	shrine.add_child(label)
	var phrase: Array = Rules.melodies(seed_value)[index]
	for j in range(phrase.size()):
		var rock: BoxMesh = BoxMesh.new()
		rock.size = Vector3(0.7, 0.8 + phrase[j] * 0.2, 0.7)
		var node: MeshInstance3D = mesh_node(rock, material(Rules.COLORS[phrase[j]], 0.18), shrine, Vector3((j - (phrase.size() - 1) / 2.0) * 1.1, rock.size.y / 2, -3.1))
		var glyph: Label3D = Label3D.new()
		glyph.text = str(phrase[j] + 1)
		glyph.font_size = 54
		glyph.pixel_size = 0.009
		glyph.position.y = rock.size.y / 2 + 0.45
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(glyph)
	_queue("RockPath_Round_Wide", Rules.CENTERS[index] + Vector2(0, 3), 1.0, 0)
	if index == 6:
		_queue("TwistedTree_5", Rules.CENTERS[index] + Vector2(0, -9), 1.2, PI)

func _build_treasure(island: int, index: int) -> void:
	var angle: float = float(index) * TAU / 3.0 + 0.5
	var p: Vector2 = Rules.CENTERS[island] + Vector2(cos(angle), sin(angle)) * 16
	var treasure: Node3D = Node3D.new()
	treasure.name = "Memory_%d" % (island * 3 + index)
	treasure.position = Vector3(p.x, height_at(p, island) + 1.0, p.y)
	treasure.set_meta("id", island * 3 + index)
	treasure.set_meta("hidden", index == 2)
	treasure.set_meta("collected", false)
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.6, 1.1, 0.6)
	mesh_node(prism, material(Color("ffe5a4"), 1.8), treasure, Vector3.ZERO)
	_root.add_child(treasure)
	treasures.append(treasure)
	treasure.visible = index != 2

func _collect(node: Node, transform_so_far: Transform3D, parts: Array) -> void:
	var t: Transform3D = transform_so_far
	if node is Node3D:
		t *= (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		parts.append({"mesh": instance.mesh, "transform": t})
	for child: Node in node.get_children():
		_collect(child, t, parts)

func pulse(p: Vector3, color: Color, radius: float = 5.0) -> void:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	var node: MeshInstance3D = mesh_node(ring, material(color, 1.7), _root, p + Vector3.UP * 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector3(radius, 0.2, radius), 0.8)
	tween.tween_callback(node.queue_free)

func reveal() -> void:
	_reveal_until = _time + 15

func ward() -> void:
	_stun_until = _time + 8

func is_revealed() -> bool:
	return _time < _reveal_until

func is_stunned() -> bool:
	return _time < _stun_until

func tick(delta: float, server_time: float) -> void:
	_time = server_time
	for i in range(shrines.size()):
		var rune: Node3D = shrines[i].get_node("HeartRune")
		rune.rotation.y += delta * 0.6
		rune.position.y = 1.8 + sin(_time * 1.8 + i) * 0.16
	for treasure: Node3D in treasures:
		treasure.rotation.y += delta
		treasure.visible = not treasure.get_meta("collected") and (not treasure.get_meta("hidden") or is_revealed())
	for sentinel: Node3D in sentinels:
		var island: int = sentinel.get_meta("island")
		var angle: float = _time * 0.32 + island
		var p: Vector2 = Rules.CENTERS[island] + Vector2(cos(angle), sin(angle)) * 15.0
		sentinel.position = Vector3(p.x, height_at(p, island) + 1.6, p.y)
		sentinel.visible = not _solved[island]
		sentinel.rotation.z = 0.8 if is_stunned() else 0
