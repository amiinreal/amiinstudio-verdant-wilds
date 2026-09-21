extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var body: CharacterBody3D=CharacterBody3D.new(); body.set_script(preload("res://Adventure/player.gd")); root.add_child(body); body.configure("Audit",Color.WHITE,true)
	print("LOADED_ACTIONS ",body._animation.get_animation_list())
	var failures: int=0
	for name: String in ["AxeSwing","PickaxeSwing","HammerBuild","GatherPlant","CraftStanding","CraftWorkbench","Pickup"]:
		if not body._animation.has_animation("gameplay/"+name): failures+=1; continue
		var clip: Animation=body._animation.get_animation("gameplay/"+name)
		for track: int in range(clip.get_track_count()):
			var path: NodePath=clip.track_get_path(track)
			var target: Node=body._animation.get_node(body._animation.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			if target==null: print("BAD_TRACK ",name," ",path); failures+=1
		body.action(name,clip.length); body._visual(0.1); await process_frame
	print("ACTION_AUDIT_COMPLETE failures=",failures); quit(failures)
