extends SceneTree
const Session := preload("res://Adventure/session.gd")
const Build := preload("res://Adventure/construction.gd")
var session: Node3D
var mode: String="host"
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",mode," ",text)
	if not ok: failures+=1
func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if not args.is_empty(): mode=args[0]
	session=Node3D.new(); session.set_script(Session); session.name="Session"; root.add_child(session); session.save_enabled=false
	if mode=="host": await host_run()
	else: await client_run()
	session.stop(false)
	print("NETWORK_CHECK_COMPLETE ",mode," failures=",failures)
	quit(1 if failures else 0)
func host_run() -> void:
	check(session.host_game(73129,27983,"QA Host")==OK,"host six-player ENet session")
	var timeout: float=Time.get_unix_time_from_system()+100
	while session.players.size()<2 and Time.get_unix_time_from_system()<timeout: await create_timer(0.1).timeout
	check(session.players.size()==2,"client handshake and roster")
	if session.players.size()<2: return
	var client: int=session.players.keys()[1]
	var stable: String=session.store.bindings[client]
	# Put both server-simulated travelers beside a resource. The client still has to request gathering.
	var selected: String=""
	for id: String in session.world.resources:
		if session.world.resources[id]["kind"]=="wood" and not id.begins_with("landmark_") and not id.begins_with("camp_"): selected=id; break
	var target: Vector3=session.world.resources[selected]["p"]+Vector3(2,0.5,0)
	session.world.update_streaming(target,[target,target+Vector3(0,0,1)])
	await physics_frame
	session.players[1].teleport(target); session.players[client].teleport(target+Vector3(0,0,1))
	print("GATHER_FIXTURE ",selected," ",target)
	await create_timer(5).timeout
	check(session.store.profile(client)["stats"]["wood_gathered"]>0,"client request grants authoritative inventory")
	check(session.state["world_delta"]["resources"].has(selected),"resource depletion enters shared world state")
	# Build one server-approved foundation; clients reconstruct its native kit asset.
	var placed: bool=false
	for z in range(50,220,4):
		if placed: break
		for x in range(-70,0,4):
			var p: Vector3=Vector3(x,session.world.height_at(Vector2(x,z))+0.5,z)
			if Build.validate(session.world,[],"foundation_stone",p,0,"host",p)["ok"]:
				session.players[1].teleport(p+Vector3(3,0,0)); session.store.profile(1)["inventory"]["wood"]=100; session.store.profile(1)["inventory"]["stone"]=20; session.store.profile(1)["inventory"]["fiber"]=20
				session._place(1,"foundation_stone",p,0)
				await create_timer(.4).timeout
				session._place(1,"wall_plaster",p+Vector3(0,0,1),0)
				await create_timer(.4).timeout
				session._place(1,"roof_panel_slope",p+Vector3.UP*3,0); placed=true; break
	check(session.store.data["structures"].size()==3,"server building request accepted")
	await create_timer(0.9).timeout
	session._clear_grass(1,session.players[1].position)
	check(session.store.data.get("grass_clearings",{}).size()==1,"host clears grass authoritatively")
	await create_timer(1.0).timeout
	var flat: Vector3=Vector3(-64,session.world.height_at(Vector2(-64,192))+.2,192)
	session.world.update_streaming(flat,[flat,session.players[client].position]); await physics_frame
	session.players[1].teleport(flat); session._flatten_land(1,flat)
	check(not session.world.terrain_edits.is_empty(),"host flattens terrain authoritatively")
	var lake: Vector2=Vector2.ZERO
	for z in range(90,151,4):
		if lake!=Vector2.ZERO: break
		for x in range(-10,61,4):
			var at: Vector2=Vector2(x,z)
			if session.world.geography.water_height(at)-session.world.height_at(at)>2: lake=at; break
	session.players[1].teleport(Vector3(lake.x,session.world.geography.water_height(lake)-1.05,lake.y))
	var timeout_rejoin: float=Time.get_unix_time_from_system()+65
	var departed: bool=false; var rejoined: bool=false
	while Time.get_unix_time_from_system()<timeout_rejoin:
		if not session.players.has(client): departed=true
		if departed and session.players.size()==2:
			for peer: int in session.players:
				if peer!=1:
					rejoined=session.store.bindings[peer]==stable and session.store.profile(peer)["stats"]["sessions"]==2
			break
		await create_timer(0.1).timeout
	check(rejoined,"same persistent traveler resumes after reconnect")
	await create_timer(4).timeout
func client_run() -> void:
	check(session.join_game("127.0.0.1",27983,"QA Friend")==OK,"connect")
	var timeout: float=Time.get_unix_time_from_system()+95
	while session.local_player()==null and Time.get_unix_time_from_system()<timeout: await create_timer(0.1).timeout
	check(session.players.size()==2,"two-player replicated roster")
	if session.local_player()==null: return
	var owner: String=session.local_profile.get("id","")
	var token: String=session._resume_token
	check(not owner.is_empty() and token.length()==48,"server-issued private identity")
	await create_timer(1).timeout
	var resource: String=session.nearest_resource(session.local_id())
	print("CLIENT_GATHER_POSITION ",session.local_player().position," tool=",session.local_player().equipped_tool," target=",resource)
	check(not resource.is_empty(),"server position snapshot reaches gathering spot")
	for i in range(4):
		session.gather(); await create_timer(0.75).timeout
	var fixture_timeout: float=Time.get_unix_time_from_system()+20
	while Time.get_unix_time_from_system()<fixture_timeout:
		if not session.world.terrain_edits.is_empty() and session.players.has(1) and session.players[1].swimming: break
		await create_timer(.1).timeout
	check(session.local_profile.get("inventory",{}).get("wood",0)>0,"private inventory response")
	var records: Array=session.state.get("world_delta",{}).get("structures",[])
	check(records.size()==3,"replicated authoritative modular construction")
	if records.size()==3:
		session.world.stream_structures(Build.position(records[0]),[])
		check(session.world.placed_nodes.has(records[0].id),"native model streams when entering building range")
	check(session.world.grass_clearings.size()>=1,"cleared grass replicated to client")
	check(records.any(func(r: Dictionary) -> bool: return r.module_id=="roof_panel_slope"),"custom roof panel replicated")
	check(not session.world.terrain_edits.is_empty(),"terrain edits replicate to client")
	check(absf(session.world.height_at(Vector2(-64,192))-session.world.height_at(Vector2(-60,192)))<.001,"client terrain is level")
	check(session.players[1].swimming and session.players[1].animation_state.begins_with("gameplay/Swim"),"swimming state and clip replicated")
	check(not session.state.has("profiles") and not session.state.get("world_delta",{}).has("profiles"),"other player profiles never broadcast")
	var wood: int=int(session.local_profile["inventory"]["wood"])
	var record_id: String=records[0].id if records.size()>0 else ""
	session.stop(false); await create_timer(1).timeout
	session.join_game("127.0.0.1",27983,"Renamed Friend"); session._resume_token=token
	timeout=Time.get_unix_time_from_system()+65
	while session.local_player()==null and Time.get_unix_time_from_system()<timeout: await create_timer(0.1).timeout
	await create_timer(1).timeout
	check(session.local_profile.get("id","")==owner,"rename does not change persistent identity")
	check(int(session.local_profile.get("inventory",{}).get("wood",0))==wood,"inventory survives reconnection")
	var restored: bool=false
	for record: Dictionary in session.state.get("world_delta",{}).get("structures",[]):
		if record.id==record_id: restored=true
	check(restored,"late join restores placed structure IDs")
	check(session.world.grass_clearings.size()>=1,"cleared grass survives reconnect")
	check(not session.world.terrain_edits.is_empty(),"terrain edits survive client reconnect")
