extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var body: CharacterBody3D=CharacterBody3D.new(); body.set_script(preload("res://Adventure/player.gd")); root.add_child(body); body.configure("Grip",Color.WHITE,true)
	body._animation.play("freehand_idle"); body._animation.advance(0.1)
	for name: String in ["hand.R","item_socket","forearm.R"]:
		var index: int=body._skeleton.find_bone(name); print(name," ",body._skeleton.get_bone_global_pose(index))
	for id: String in ["axe","pickaxe","hammer"]:
		var item: Node3D=preload("res://Adventure/items.gd").model(id); root.add_child(item)
		for mesh: MeshInstance3D in item.find_children("*","MeshInstance3D",true,false): print(id," BOUNDS ",mesh.global_transform*mesh.get_aabb())
	quit()
