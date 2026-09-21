extends SceneTree
const Modules=preload("res://Adventure/modules.gd")
const Build=preload("res://Adventure/construction.gd")
const Loading=preload("res://Adventure/loading_screen.gd")
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func record(id: String,module: String,p: Vector3,turn: int=0,owner: String="host") -> Dictionary:
	return {"id":id,"module_id":module,"position":[p.x,p.y,p.z],"rotation":turn,"owner_id":owner,"building_id":"roof_test","created_at":0,"state":{}}
func run() -> void:
	var began: int=Time.get_ticks_msec()
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	print("MENU_READY_SECONDS ",(Time.get_ticks_msec()-began)/1000.0)
	check(game.session.world.terrain_cells.is_empty(),"menu opens without generating a world")
	game.session.save_enabled=false; game.session.start_solo(73129,"Roof builder")
	game.set_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	var session: Node3D=game.session; var world: Node3D=session.world
	var previous: float=0; var monotonic: bool=true
	for percent: float in Loading.history: monotonic=monotonic and percent>=previous; previous=percent
	check(monotonic and previous==100 and Loading.history.size()>5,"loading reports increasing stage progress through 100 percent")
	check(not is_instance_valid(Loading.layer),"loading overlay is removed on completion")
	check(not Modules.catalog().has("roof_small") and not Modules.catalog().has("roof_square"),"prebuilt roofs removed from selection")
	check(not Modules.definition("roof_small").is_empty(),"old saved roofs can still be reconstructed")
	var site: Vector3=Vector3(-64,world.height_at(Vector2(-64,192))+3,192)
	world.update_streaming(site,[site]); session.local_player().teleport(site+Vector3(3,0,4))
	await physics_frame
	var walls: Array=[record("wall","wall_plaster",site+Vector3(0,0,1))]
	var panel: Vector3=site+Vector3.UP*3
	check(Build.validate(world,walls,"roof_panel_slope",panel,0,"host",panel,false).ok,"one slope panel fits a single wall edge")
	check(not Build.validate(world,[],"roof_panel_slope",panel,0,"host",panel,false).ok,"floating roof is rejected")
	check(not Build.validate(world,walls,"roof_panel_slope",panel,0,"guest",panel,false).ok,"roof cannot attach to another player's house")
	var guest: Array=[record("guestwall","wall_plaster",site+Vector3(0,0,1),0,"guest")]
	check(Build.validate(world,guest,"roof_panel_slope",panel,0,"guest",panel,false).ok,"another player can build their own custom roof")
	var chain: Array=walls.duplicate(); chain.append(record("panel","roof_panel_slope",panel))
	check(Build.validate(world,chain,"roof_panel_slope",panel+Vector3(0,1,-2),0,"host",panel,false).ok,"roof extends uphill with matching one metre rise")
	check(Build.validate(world,chain,"roof_panel_slope",panel+Vector3(2,0,0),0,"host",panel,false).ok,"roof extends sideways")
	check(Build.validate(world,chain,"roof_panel_slope",panel+Vector3(0,0,-2),2,"host",panel,false).ok,"opposite slope joins into a ridge")
	var detached: Array=[record("panel","roof_panel_slope",panel),record("panel2","roof_panel_slope",panel+Vector3(2,0,0))]
	check(not Build.validate(world,detached,"roof_panel_slope",panel+Vector3(4,0,0),0,"host",panel,false).ok,"unanchored chain cannot support itself")
	for kind: String in ["flat","corner","steep"]:
		var p: Vector3=panel
		check(Build.validate(world,walls,"roof_panel_"+kind,p,0,"host",p,false).ok,"wall supports "+kind+" panel")
	check(Build.validate(world,chain,"roof_panel_valley",panel+Vector3(-2,0,0),0,"host",panel,false).ok,"inner corner joins the matching sloping edge")
	var snapped: Dictionary=Build.connector_candidate(chain,"roof_panel_slope",panel+Vector3(.1,1,-2),0)
	check(not snapped.is_empty() and snapped.position.distance_to(panel+Vector3(0,1,-2))<.01,"preview snaps exactly to a roof edge")
	check(not session.store.place(1,"roof_small",panel,0,panel,world,100).ok,"authority refuses new prefab roofs")
	var digest: int=world.placements.hash(); var heights: PackedFloat32Array=world.geography.heights.duplicate()
	var first: float=world.generation_seconds
	Loading.history.clear(); world.build(73129,2); Loading.finish()
	print("CACHE_LOAD_SECONDS ",world.generation_seconds," previous=",first)
	check(world.placements.hash()==digest and world.geography.heights==heights,"cached generation preserves exact placements and terrain")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,800)
		Loading.show_progress(50,"Growing woodland and gathering resources…")
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/loading-progress.png"); Loading.finish()
		var demo: Array=[]
		for x in range(3):
			for z in range(2):
				var p: Vector3=site+Vector3(x*2,0,-z*2)
				demo.append(record("floor%d%d" % [x,z],"foundation_wood",p))
				demo.append(record("roof%d%d" % [x,z],"roof_panel_slope",p+Vector3.UP*3,0 if z==0 else 2))
			for z in [1,-3]: demo.append(record("wall%d%d" % [x,z],"wall_timber",site+Vector3(x*2,0,z)))
		world.update_streaming(site,[site]); world.apply_delta({"structures":demo})
		var camera: Camera3D=game.get_node("Overview"); camera.make_current(); camera.position=site+Vector3(10,8,10); camera.look_at(site+Vector3(2,2,-1))
		game.hud._notice_time=0
		await create_timer(2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/custom-roof.png")
	print("ROOF_LOADING_CHECK_COMPLETE failures=",failures)
	session.stop(false); quit(failures)
