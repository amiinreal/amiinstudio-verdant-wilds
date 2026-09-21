extends RefCounted
static var sounds: Dictionary={}
static func particles(parent: Node3D,position: Vector3,color: Color,count: int,spread: Vector3,up: float,lifetime: float,size_value: float,one_shot: bool=false) -> GPUParticles3D:
	var node: GPUParticles3D=GPUParticles3D.new(); node.position=position; node.amount=count; node.lifetime=lifetime; node.one_shot=one_shot; node.explosiveness=0.9 if one_shot else 0; node.preprocess=0 if one_shot else lifetime
	node.visibility_aabb=AABB(Vector3(-10,-4,-10),Vector3(20,24,20)); node.local_coords=false
	var process: ParticleProcessMaterial=ParticleProcessMaterial.new(); process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX; process.emission_box_extents=spread
	process.direction=Vector3(0,1,0); process.spread=25; process.initial_velocity_min=up*0.7; process.initial_velocity_max=up; process.gravity=Vector3(0,-0.7 if one_shot else 0.05,0)
	process.scale_min=size_value*0.6; process.scale_max=size_value
	var gradient: Gradient=Gradient.new(); gradient.set_color(0,Color(1,1,1,0.8)); gradient.set_color(1,Color(1,1,1,0))
	var texture: GradientTexture1D=GradientTexture1D.new(); texture.gradient=gradient; process.color_ramp=texture; node.process_material=process
	var quad: QuadMesh=QuadMesh.new(); quad.size=Vector2.ONE
	var material: ShaderMaterial=ShaderMaterial.new(); material.shader=preload("res://Adventure/soft_particle.gdshader"); material.set_shader_parameter("tint",color); quad.material=material; node.draw_pass_1=quad
	parent.add_child(node)
	if one_shot: node.finished.connect(node.queue_free)
	return node

static func impact(parent: Node3D,p: Vector3,kind: String) -> void:
	var color: Color=Color("926334") if kind=="wood" else (Color("87aa53") if kind=="fiber" else Color("b1b5af"))
	var chips: GPUParticles3D=particles(parent,p+Vector3.UP,color,8,Vector3.ONE*0.1,1.7 if kind=="fiber" else 2.5,0.65,0.06,true)
	var chip: BoxMesh=BoxMesh.new(); chip.size=Vector3(1,0.12,0.35) if kind in ["wood","fiber"] else Vector3(0.55,0.5,0.6)
	var material: StandardMaterial3D=StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.95; chip.material=material; chips.draw_pass_1=chip
	particles(parent,p+Vector3.UP,Color(color,0.35),5,Vector3.ONE*0.12,0.7,0.55,0.15,true)
	var audio: AudioStreamPlayer3D=AudioStreamPlayer3D.new(); audio.position=p; audio.max_distance=28; audio.unit_size=5; audio.volume_db=-10
	if not sounds.has(kind):
		var wave: AudioStreamWAV=AudioStreamWAV.new(); wave.format=AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate=22050
		var bytes: PackedByteArray=PackedByteArray(); bytes.resize(6615*2)
		var random: RandomNumberGenerator=RandomNumberGenerator.new(); random.seed=315
		for i in range(6615):
			var t: float=float(i)/22050; var frequency: float=155 if kind=="wood" else 780
			var sample: float=(sin(t*frequency*TAU)*0.5+random.randf_range(-1,1)*0.35)*exp(-t*27)
			bytes.encode_s16(i*2,int(sample*22000))
		wave.data=bytes; sounds[kind]=wave
	audio.stream=sounds[kind]; parent.add_child(audio); audio.finished.connect(audio.queue_free); audio.play()

static func splash(parent: Node3D, p: Vector3, large: bool=false) -> void:
	particles(parent,p,Color(0.7,0.9,0.91,0.65),10 if large else 5,Vector3(0.22,0.03,0.22),1.6 if large else 0.7,0.5,0.09,true)
	var ring: MeshInstance3D=MeshInstance3D.new(); var mesh: TorusMesh=TorusMesh.new(); mesh.inner_radius=0.38; mesh.outer_radius=0.42; mesh.rings=24; mesh.ring_segments=6; ring.mesh=mesh; ring.position=p
	var material: StandardMaterial3D=StandardMaterial3D.new(); material.albedo_color=Color(0.75,0.92,0.9,0.5); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; ring.material_override=material; parent.add_child(ring)
	var tween: Tween=parent.create_tween(); tween.set_parallel(true); tween.tween_property(ring,"scale",Vector3(3,0.2,3),0.8); tween.tween_property(material,"albedo_color:a",0.0,0.8); tween.chain().tween_callback(ring.queue_free)

static func waterfall_audio(parent: Node3D, p: Vector3) -> void:
	var wave: AudioStreamWAV=AudioStreamWAV.new(); wave.format=AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate=22050
	var bytes: PackedByteArray=PackedByteArray(); bytes.resize(44100*2)
	var random: RandomNumberGenerator=RandomNumberGenerator.new(); random.seed=5141
	var filtered: float=0
	for i in range(44100):
		filtered=lerpf(filtered,random.randf_range(-1,1),0.22)
		bytes.encode_s16(i*2,int(filtered*11000))
	wave.data=bytes; wave.loop_mode=AudioStreamWAV.LOOP_FORWARD; wave.loop_begin=0; wave.loop_end=44100
	var player: AudioStreamPlayer3D=AudioStreamPlayer3D.new(); player.position=p; player.stream=wave; player.max_distance=85; player.unit_size=12; player.volume_db=-15; parent.add_child(player); player.play()
