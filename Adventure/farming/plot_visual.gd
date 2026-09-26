extends Node3D
## Purely a renderer: crop stage and soil moisture are decided by the authority and
## replicated as plain data (crop, progress, watered_until), never simulated locally.
const MODELS := "res://FarmingFishing/Models/"
var _soil: Node3D
var _crop: Node3D
var _crop_stage: int = -1
var _crop_kind: String = ""
var _watered: bool = false

func apply(record: Dictionary, now: float) -> void:
	var crop: String = str(record.get("crop", ""))
	var progress: float = float(record.get("progress", 0.0))
	var watered: bool = now < float(record.get("watered_until", 0.0))
	if watered != _watered or _soil == null:
		_watered = watered
		if is_instance_valid(_soil):
			_soil.queue_free()
		var packed: PackedScene = load(MODELS + ("farmland_wet.glb" if watered else "farmland_dry.glb"))
		_soil = packed.instantiate()
		add_child(_soil)
	var stage: int = -1 if crop.is_empty() else mini(3, int(progress * 4.0))
	if stage != _crop_stage or crop != _crop_kind:
		_crop_stage = stage
		_crop_kind = crop
		if is_instance_valid(_crop):
			_crop.queue_free()
			_crop = null
		if stage >= 0:
			var packed: PackedScene = load(MODELS + crop + "_stage_%d.glb" % stage)
			_crop = packed.instantiate()
			add_child(_crop)
