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

## Shared mesh utilities; terrain and ecology live in open_world.gd.
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

func _collect(node: Node, transform_so_far: Transform3D, parts: Array) -> void:
	var t: Transform3D = transform_so_far
	if node is Node3D:
		t *= (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		parts.append({"mesh": instance.mesh, "transform": t})
	for child: Node in node.get_children():
		_collect(child, t, parts)

func tick(_delta: float, server_time: float) -> void:
	_time=server_time
