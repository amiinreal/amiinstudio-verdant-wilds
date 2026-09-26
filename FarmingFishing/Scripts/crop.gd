@tool
extends Node3D
## Ground-level origin. A crop grows only while watered; harvesting returns item data.
signal matured
signal harvested(item: String, amount: int)

const MODELS := "res://FarmingFishing/Models/"
@export_enum("carrot", "wheat") var crop_type: String = "carrot"
@export_range(1.0, 3600.0) var growth_seconds: float = 30.0
@export var watered: bool = true
@export var growing: bool = true
@export_range(0.0, 1.0) var initial_progress: float = 0.0
var progress: float = 0.0
var stage: int = -1
var planted: bool = true
var visual: Node3D
var emergence: Tween

func _ready() -> void:
	progress = initial_progress
	_update_stage(false)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not planted or not growing or not watered or progress >= 1.0:
		return
	progress = minf(1.0, progress + delta / growth_seconds)
	_update_stage(true)
	if progress >= 1.0:
		matured.emit()

func _update_stage(animate: bool) -> void:
	var next: int = mini(3, int(progress * 4.0))
	if next == stage:
		return
	stage = next
	if emergence and emergence.is_valid():
		emergence.kill()
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	var packed: PackedScene = load(MODELS + crop_type + "_stage_%d.glb" % stage)
	visual = packed.instantiate()
	add_child(visual)
	if animate and not Engine.is_editor_hint():
		visual.scale = Vector3.ONE * 0.55
		emergence = create_tween()
		emergence.tween_property(visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func plant(kind: String) -> void:
	if kind not in ["carrot", "wheat"]:
		return
	crop_type = kind
	progress = 0.0
	stage = -1
	planted = true
	_update_stage(true)

func is_mature() -> bool:
	return planted and progress >= 1.0

func harvest() -> Dictionary:
	if not is_mature():
		return {}
	planted = false
	if emergence and emergence.is_valid():
		emergence.kill()
	if is_instance_valid(visual):
		visual.queue_free()
	visual = null
	stage = -1
	var result: Dictionary = {"item": crop_type, "amount": 1, "seeds": 2}
	harvested.emit(crop_type, 1)
	return result
