extends Node3D
## Deterministic short grass, streamed in 16 m tiles; shared mask and height field.
var world: Node3D
var meshes: Array[Mesh]=[]
var chunks: Dictionary={}
var pending: Array[Vector2i]=[]
var center: Vector2i=Vector2i(9999,9999)
var material: ShaderMaterial
var height_texture: ImageTexture

func setup(value: Node3D) -> void:
	world=value
	material=ShaderMaterial.new(); material.shader=preload("res://Adventure/meadow.gdshader")
	material.set_shader_parameter("ground_mask",world.grass_mask)
	update_height()
	world.wind_materials.append(material)
	for i in range(3):
		var scene: Node=load("res://Adventure/generated/WoodlandGrass_%d.glb" % i).instantiate()
		var part: MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
		meshes.append(part.mesh); scene.free()

func update_height() -> void:
	var data: Image=Image.create_from_data(257,257,false,Image.FORMAT_RF,world.geography.heights.to_byte_array())
	if height_texture==null: height_texture=ImageTexture.create_from_image(data)
	else: height_texture.update(data)
	material.set_shader_parameter("terrain_height",height_texture)

func _process(_delta: float) -> void:
	var next: Vector2i=Vector2i(floori(world._view_position.x/16),floori(world._view_position.z/16))
	if next!=center:
		center=next; pending.clear()
		for key: Vector2i in chunks.keys():
			if absi(key.x-center.x)>3 or absi(key.y-center.y)>3:
				chunks[key].queue_free(); chunks.erase(key)
		for z in range(-3,4):
			for x in range(-3,4):
				var key: Vector2i=center+Vector2i(x,z)
				if not chunks.has(key): pending.append(key)
		pending.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.distance_squared_to(center)<b.distance_squared_to(center))
	for i in range(mini(2,pending.size())): _chunk(pending.pop_front())

func _chunk(key: Vector2i) -> void:
	var rng: RandomNumberGenerator=RandomNumberGenerator.new(); rng.seed=world.seed_value+key.x*73856093+key.y*19349663
	var transforms: Array[Transform3D]=[]
	for z in range(13):
		for x in range(13):
			var p: Vector2=Vector2(key)*16+Vector2(x+.5,z+.5)*(16.0/13)+Vector2(rng.randf_range(-.16,.16),rng.randf_range(-.16,.16))
			var h: float=world.height_at(p)
			if p.abs().x>505 or p.abs().y>505 or h<world.geography.water_height(p)+.18 or h>105 or world.geography.road_distance(p)<1.6: continue
			var scale_y: float=rng.randf_range(.65,1.1)*(0.8 if world.geography.forest_density(p)>.7 else 1.0)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1,scale_y,1)),Vector3(p.x,h,p.y)))
	var multi: MultiMesh=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.mesh=meshes[posmod(key.x+key.y,3)]; multi.instance_count=transforms.size()
	for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
	var node: MultiMeshInstance3D=MultiMeshInstance3D.new(); node.multimesh=multi; node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Shader fits every blade to edited terrain; expand bounds for deformation.
	node.extra_cull_margin=16; add_child(node); chunks[key]=node

func invalidate() -> void:
	for node: Node in chunks.values(): node.queue_free()
	chunks.clear(); center=Vector2i(9999,9999); update_height()
