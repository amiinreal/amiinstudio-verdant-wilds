extends SceneTree

const Crop = preload("res://FarmingFishing/Scripts/crop.gd")
const Plot = preload("res://FarmingFishing/Scripts/farm_plot.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://FarmingFishing/Models")
	var count: int = 0
	for file in files:
		if not file.ends_with(".glb"):
			continue
		var asset: PackedScene = load("res://FarmingFishing/Models/" + file)
		check(asset != null, "Cannot load " + file)
		if asset:
			var instance: Node = asset.instantiate()
			root.add_child(instance)
			if file.contains("growing") or file in ["river_fish.glb", "salmon.glb"]:
				var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
				check(not players.is_empty(), "Missing animation: " + file)
				for node in players:
					var player: AnimationPlayer = node as AnimationPlayer
					for animation_name in player.get_animation_list():
						if animation_name == "RESET":
							continue
						var animation: Animation = player.get_animation(animation_name)
						check(animation.get_track_count() > 0, "Empty animation: " + file)
						if file.contains("growing"):
							check(animation.length >= 9.9, "Growth animation too short: " + file)
						player.play(animation_name)
						player.seek(animation.length, true)
						player.advance(0.0)
			instance.queue_free()
		count += 1
	check(count == 23, "Expected 23 models, found %d" % count)
	for kind: String in ["carrot", "wheat"]:
		var plot := Node3D.new()
		plot.set_script(Plot)
		root.add_child(plot)
		var crop := Node3D.new()
		crop.set_script(Crop)
		crop.set("crop_type", kind)
		crop.set("growth_seconds", 4.0)
		plot.add_child(crop)
		crop.set_process(false)
		check(crop.get("stage") == 0, "Must start as sprout")
		check(crop.call("harvest").is_empty(), "Immature crops cannot be harvested")
		plot.call("set_watered", false)
		crop.call("_process", 2.0)
		check(crop.get("progress") == 0.0, "Dry crop must stop growing")
		plot.call("set_watered", true)
		for stage in range(1, 4):
			crop.call("_process", 1.0)
			check(crop.get("stage") == stage, "Incorrect growth stage")
		check(not crop.call("is_mature"), "Final stage must finish growing before harvest")
		crop.call("_process", 1.0)
		check(crop.call("is_mature"), "Crop did not mature")
		var result: Dictionary = crop.call("harvest")
		check(result.get("item") == kind and result.get("seeds") == 2, "Incorrect harvest")
		check(crop.call("harvest").is_empty(), "Cannot harvest twice")
		crop.call("plant", kind)
		check(crop.get("stage") == 0 and crop.get("planted"), "Cannot replant")
		plot.queue_free()
	await process_frame
	print("FARMING_VALIDATION: %d models, %d failures" % [count, failures])
	quit(1 if failures else 0)
