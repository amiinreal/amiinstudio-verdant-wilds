extends SceneTree
const Store=preload("res://Adventure/world_store.gd")
const Build=preload("res://Adventure/construction.gd")
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	game.session.save_enabled=false; game.session.start_solo(73129,"Woodland QA")
	game.set_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	var session: Node3D=game.session; var world: Node3D=session.world
	var actor: CharacterBody3D=session.local_player()
	var center: Vector2=Vector2(-64,192)
	var site: Vector3=Vector3(center.x,world.height_at(center)+.2,center.y)
	world.update_streaming(site,[site]); actor.teleport(site)
	await physics_frame; await physics_frame
	check(world.resources.has("landmark_TwistedTree_5_-270_-307"),"elder tree is registered for harvesting")
	check(world.resources.has("camp_log_0"),"fallen camp logs are harvestable")
	check(world.meadow.meshes.size()==3,"three Blender grass variants imported")
	check(game.music.playing and game.music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"peaceful music plays and loops")
	var before: float=world.height_at(center+Vector2(4,0))
	var level: float=world.height_at(center)
	session._flatten_land(1,site)
	check(not world.terrain_edits.is_empty(),"authority records terrain edit")
	check(absf(world.height_at(center+Vector2(4,0))-level)<.001,"flattened center is level")
	check(absf(before-world.height_at(center+Vector2(4,0)))>.01,"flattening changes sloped terrain")
	await physics_frame; await physics_frame
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Vector3(center.x+4,level+10,center.y),Vector3(center.x+4,level-10,center.y),1)
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y-level)<.02,"rebuilt collision matches flattened surface")
	var delta: Dictionary=session.store.public_delta()
	session.store.directory="res://Adventure/qa/woodland-save"
	check(session.store.save(session.state),"terrain save succeeds")
	var restored: RefCounted=Store.new(); restored.directory=session.store.directory
	var loaded: bool=restored.load_world(73129)
	var same: bool=loaded and restored.public_delta().terrain_edits.size()==delta.terrain_edits.size()
	for key: String in delta.terrain_edits: same=same and is_equal_approx(float(restored.data.terrain_edits.get(key,-999)),float(delta.terrain_edits[key]))
	check(same,"terrain survives save and reload")
	world.apply_terrain_edits({}); check(absf(world.height_at(center+Vector2(4,0))-before)<.001,"reset restores original seed terrain")
	world.apply_delta(restored.public_delta()); check(absf(world.height_at(center+Vector2(4,0))-level)<.001,"late delta restores flattened height")
	var edit_count: int=world.terrain_edits.size(); session.store.cooldowns.clear()
	session._flatten_land(1,site+Vector3(100,0,0)); check(world.terrain_edits.size()==edit_count,"remote terraforming rejected")
	var bad: Dictionary=session.store.data.duplicate(true); bad.terrain_edits={"999999":0}
	check(not Store.valid_save(bad,73129),"out of bounds terrain save rejected")
	var p: Vector3=Vector3(-64,level+.25,192)
	check(Build.validate(world,[],"floor_oak",p,0,"host",p,false).ok,"floor can start directly on terrain")
	check(Build.validate(world,[],"foundation_wood",p+Vector3.UP*4,0,"host",p,false).ok,"foundation supports uneven ground beyond old 1.5 m limit")
	var road: Vector2=Vector2(-140,70); var rp: Vector3=Vector3(road.x,world.height_at(road)+1,road.y)
	check(Build.validate(world,[],"foundation_wood",rp,0,"host",rp,false).ok,"roads no longer carry blanket building restriction")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1440,900); game.hud._notice_time=0
		var camera: Camera3D=game.get_node("Overview"); camera.make_current()
		var photo: Vector2=Vector2(-65,180); var focus: Vector3=Vector3(photo.x,world.height_at(photo),photo.y)
		actor.teleport(focus); world.update_streaming(focus,[focus])
		camera.position=focus+Vector3(5,3.2,7); camera.look_at(focus+Vector3(0,.6,-4))
		await create_timer(4).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/woodland-grass.png")
		camera.position=site+Vector3(8,10,12); camera.look_at(site)
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://Adventure/qa/woodland-flatten.png")
	print("WOODLAND_CHECK_COMPLETE failures=",failures)
	session.stop(false); quit(failures)
