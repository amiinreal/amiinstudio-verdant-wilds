extends Node3D
var session: Node3D
var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_material: ShaderMaterial
func setup(value: Node3D,world_environment: WorldEnvironment,light: DirectionalLight3D) -> void:
	session=value; environment=world_environment.environment; sun=light
	sky_material=ShaderMaterial.new(); sky_material.shader=preload("res://Adventure/sky.gdshader")
	var sky: Sky=Sky.new(); sky.sky_material=sky_material; sky.process_mode=Sky.PROCESS_MODE_REALTIME; sky.radiance_size=Sky.RADIANCE_SIZE_128; environment.sky=sky
	moon=DirectionalLight3D.new(); moon.light_color=Color("91b8f0"); moon.light_energy=0.18; add_child(moon)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.tonemap_exposure=0.92
	environment.fog_enabled=true; environment.fog_density=0.00065
	environment.glow_enabled=true; environment.glow_intensity=0.35
	sun.shadow_enabled=true; sun.directional_shadow_max_distance=130

func _process(_delta: float) -> void:
	if session==null or sky_material==null: return
	var phase: float=session.state.get("day_time",0.32)
	var angle: float=(phase-0.25)*TAU
	var elevation: float=sin(angle)
	var day: float=smoothstep(-0.12,0.18,elevation)
	var golden: float=(1-smoothstep(0.05,0.5,absf(elevation)))*day
	sun.rotation=Vector3(-angle,-0.55,0); moon.rotation=Vector3(-angle-PI,-0.25,0)
	sun.light_energy=day*1.15; sun.light_color=Color("fff4dc").lerp(Color("ffad6a"),golden*0.55)
	moon.light_energy=(1-day)*0.26
	environment.ambient_light_color=Color("6482b9").lerp(Color("a8c4dd"),day)
	environment.ambient_light_energy=lerpf(0.27,0.40,day)
	environment.fog_light_color=Color("223959").lerp(Color("abbfca"),day).lerp(Color("cfb39b"),golden*0.4)
	environment.fog_density=0.00055+(1-day)*0.0004+golden*0.00025
	sky_material.set_shader_parameter("daylight",day)
	sky_material.set_shader_parameter("sun_direction",sun.global_basis.z)
	sky_material.set_shader_parameter("zenith",Color("101e3a").lerp(Color("397bad"),day))
	sky_material.set_shader_parameter("horizon",Color("293c61").lerp(Color("bbd4dc"),day).lerp(Color("eac09b"),golden*0.45))
	if session.world.has_method("set_night"): session.world.set_night(1-day)
