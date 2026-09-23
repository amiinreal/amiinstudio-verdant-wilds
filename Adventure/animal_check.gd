extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	print("PASS " if ok else "FAIL ", detail)
	if not ok: failures += 1
func run() -> void:
	for kind: String in ["cat", "dog", "cow"]:
		var packed: PackedScene = load("res://Adventure/animals/" + kind + ".glb")
		check(packed != null, kind + " loads as a PackedScene")
		if packed == null: continue
		var model: Node3D = packed.instantiate()
		root.add_child(model)
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(skeleton != null and skeleton.get_bone_count() >= 19, kind + " has articulated skeleton")
		check(player != null, kind + " has AnimationPlayer")
		if player:
			for clip: String in ["idle", "walk", "trot", "graze" if kind == "cow" else "sniff"]:
				check(player.has_animation(clip), kind + "/" + clip + " exists")
				if not player.has_animation(clip): continue
				var anim: Animation = player.get_animation(clip)
				check(anim.length > 0.5 and anim.get_track_count() > 10, kind + "/" + clip + " contains skeletal tracks")
				player.play(clip)
				player.seek(0.0, true)
				var initial: Array[Transform3D] = []
				for i: int in range(skeleton.get_bone_count()): initial.append(skeleton.get_bone_pose(i))
				player.seek(anim.length * 0.37, true)
				var changed: bool = false
				for i: int in range(skeleton.get_bone_count()):
					changed = changed or not initial[i].is_equal_approx(skeleton.get_bone_pose(i))
				check(changed, kind + "/" + clip + " moves the skeleton")
				player.seek(anim.length, true)
				var seamless: bool = true
				for i: int in range(skeleton.get_bone_count()):
					seamless = seamless and initial[i].is_equal_approx(skeleton.get_bone_pose(i))
				check(seamless, kind + "/" + clip + " loop endpoints match")
		model.free()
	print("ANIMAL_CHECK_COMPLETE failures=", failures)
	quit(failures)
