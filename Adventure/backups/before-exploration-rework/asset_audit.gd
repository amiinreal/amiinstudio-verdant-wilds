extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failures: int=0
	var paths: PackedStringArray=DirAccess.get_files_at("res://styled Nature megaKit/FBX")
	for file: String in paths:
		if not file.ends_with(".fbx"): continue
		var path: String="res://styled Nature megaKit/FBX/"+file
		var scene: PackedScene=load(path) as PackedScene
		if scene==null: print("ASSET_FAIL ",path); failures+=1; continue
		var node: Node3D=scene.instantiate()
		var meshes: Array[Node]=node.find_children("*","MeshInstance3D",true,false)
		print("ASSET_OK ",path," meshes=",meshes.size())
		if file in ["CommonTree_1.fbx","Pine_1.fbx","TwistedTree_1.fbx","Grass_Common_Tall.fbx"]:
			for mesh: MeshInstance3D in meshes: print("BOUNDS ",file," ",mesh.get_aabb()," transform=",mesh.transform)
		node.free()
	var hero: Node3D=(load("res://PlayerMesh/hero_male.glb") as PackedScene).instantiate()
	root.add_child(hero)
	for node: Node in hero.find_children("*","AnimationPlayer",true,false): print("ANIMATIONS ",node.get_path()," ",node.get_animation_list())
	for node: Node in hero.find_children("*","Skeleton3D",true,false):
		print("SKELETON ",node.get_path())
		for i in range(node.get_bone_count()): print("BONE ",i," ",node.get_bone_name(i))
	for node: Node in hero.find_children("*","MeshInstance3D",true,false): print("HERO_MESH ",node.get_path()," ",node.get_aabb())
	for file: String in ["Axe_Bronze","Pickaxe_Bronze","Workbench","Lantern_Wall","Stall_Cart_Empty","Barrel","Anvil_Log"]:
		var path: String="res://Fantasy Props Megakit/Exports/FBX/"+file+".fbx"
		var packed: PackedScene=load(path) as PackedScene
		if packed==null: print("ASSET_FAIL ",path); failures+=1; continue
		var model: Node3D=packed.instantiate()
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): print("PROP_BOUNDS ",file," ",mesh.transform*mesh.get_aabb()," transform=",mesh.transform)
		model.free()
	print("ASSET_AUDIT_COMPLETE failures=",failures)
	quit(failures)
