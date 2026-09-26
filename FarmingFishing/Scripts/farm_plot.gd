@tool
extends Node3D
## One metre grid tile, surface at local Y=0; collision extends down into the soil.
@export var watered: bool = true
var soil: Node3D

func _ready() -> void:
	set_watered(watered)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.46, 1.0)
	collision.shape = shape
	collision.position.y = -0.20
	body.add_child(collision)
	add_child(body)

func set_watered(value: bool) -> void:
	watered = value
	_refresh_soil()
	for child in get_children():
		if child.has_method("plant"):
			child.set("watered", value)

func _refresh_soil() -> void:
	if is_instance_valid(soil):
		remove_child(soil)
		soil.queue_free()
	var path: String = "res://FarmingFishing/Models/farmland_%s.glb" % ("wet" if watered else "dry")
	var packed: PackedScene = load(path)
	soil = packed.instantiate()
	add_child(soil)
