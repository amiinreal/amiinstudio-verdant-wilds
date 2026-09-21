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
		if session.world.resources[id]["kind"]=="wood": selected=id; break
	var target: Vector3=session.world.resources[selected]["p"]+Vector3(2,0.5,0)
	session.players[1].teleport(target); session.players[client].teleport(target+Vector3(0,0,1))
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
				session.players[1].teleport(p+Vector3(3,0,0)); session.store.profile(1)["inventory"]["wood"]=20; session.store.profile(1)["inventory"]["stone"]=20
				session._place(1,"foundation_stone",p,0); placed=true; break
	check(session.store.data["structures"].size()==1,"server building request accepted")
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
	check(not resource.is_empty(),"server position snapshot reaches gathering spot")
	for i in range(4):
		session.gather(); await create_timer(0.75).timeout
	await create_timer(3).timeout
	check(session.local_profile.get("inventory",{}).get("wood",0)>0,"private inventory response")
	check(session.world.placed_nodes.size()==1,"replicated native modular construction")
	check(not session.state.has("profiles") and not session.state.get("world_delta",{}).has("profiles"),"other player profiles never broadcast")
	var wood: int=int(session.local_profile["inventory"]["wood"])
	var record_id: String=session.world.placed_nodes.keys()[0] if session.world.placed_nodes.size()>0 else ""
	session.stop(false); await create_timer(1).timeout
	session.join_game("127.0.0.1",27983,"Renamed Friend"); session._resume_token=token
	timeout=Time.get_unix_time_from_system()+65
	while session.local_player()==null and Time.get_unix_time_from_system()<timeout: await create_timer(0.1).timeout
	await create_timer(1).timeout
	check(session.local_profile.get("id","")==owner,"rename does not change persistent identity")
	check(int(session.local_profile.get("inventory",{}).get("wood",0))==wood,"inventory survives reconnection")
	check(session.world.placed_nodes.has(record_id),"late join restores placed structure IDs")
