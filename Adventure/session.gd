extends Node3D
signal state_changed
signal message(text: String)
signal session_started
signal session_stopped
const Rules := preload("res://Adventure/rules.gd")
const World := preload("res://Adventure/open_world.gd")
const Store := preload("res://Adventure/world_store.gd")
const Player := preload("res://Adventure/player.gd")
const PALETTE: Array[Color] = [Color("b0ce7e"), Color("7acbe0"), Color("dc98b4"), Color("e8be79"), Color("a99bdc"), Color("8cd6b1")]
var store: RefCounted = Store.new()
var local_profile: Dictionary = {}
var build_hint: String = ""
var _world_used: bool=false
var _hosting: bool=false
var _profile_timer: float = 0
var _save_timer: float = 0
var _stream_timer: float = 0
var _server_address: String = ""
var _resume_token: String = ""
var world: Node3D
var state: Dictionary = Rules.fresh_state(73129)
var players: Dictionary = {}
var _owner_profile: Dictionary = {}
var running: bool = false
var online: bool = false
var save_enabled: bool = true
var status: String = "Solo / up to 6 online explorers"
var local_name: String = "Traveler"
var clock_time: float = 0
var _pending: Dictionary = {}
var _actions: Dictionary = {}
var _ready_peers: Array[int] = []
var _inputs_seen: Dictionary = {}
var _last_input_at: Dictionary = {}
var _snapshot_time: float = 0
var _epoch: int = 0
var _connect_deadline: int = 0
var account_service: Node
var invite_code: String = ""
var relay_mode: bool = false

func _ready() -> void:
	account_service = Node.new()
	account_service.set_script(preload("res://Adventure/online_account.gd"))
	add_child(account_service)
	world = Node3D.new()
	world.set_script(World)
	world.name = "World"
	add_child(world)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_left)

func is_authority() -> bool:
	return not online or _hosting

func local_id() -> int:
	return multiplayer.get_unique_id() if online else 1

func local_player() -> CharacterBody3D:
	return players.get(local_id()) as CharacterBody3D

func account_save_folder() -> void:
	if not account_service.account.is_empty():
		store.directory = "user://accounts/" + str(account_service.account.id) + "/" + account_service.channel

func host_online(seed_value: int) -> void:
	if account_service.account.is_empty(): message.emit(account_service.error); return
	if account_service.busy: return
	account_service.busy = true
	message.emit("Opening online world…")
	stop(false); account_save_folder()
	# Prepare before publishing the room so guests never join a half-built world.
	local_name = str(account_service.account.username)
	state = Rules.fresh_state(seed_value)
	_prepare_world()
	var result: Dictionary = await account_service.api("/rooms", account_service.build_info())
	if result.is_empty(): account_service.busy = false; message.emit(account_service.error); return
	var peer = preload("res://Adventure/relay_peer.gd").new()
	peer._id = 1
	var error: Error = peer.connect_relay(account_service.relay_url(), str(result.ticket))
	var deadline: int = Time.get_ticks_msec() + 15000
	while error == OK and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		peer.poll(); await get_tree().process_frame
	account_service.busy = false
	if error != OK or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		peer.close(); message.emit("Relay connection failed. Try hosting again."); return
	multiplayer.multiplayer_peer = peer
	online = true; relay_mode = true; _hosting = true
	invite_code = str(result.code)
	store.enter(1, "", true); _publish_profile(1)
	_spawn(1, local_name, world.spawn_position(0))
	running = true; status = "Online · Invite " + invite_code
	session_started.emit(); state_changed.emit()
	message.emit("World ready. Invite code: " + invite_code)

func join_online(code: String) -> void:
	if account_service.account.is_empty(): message.emit(account_service.error); return
	if account_service.busy: return
	account_service.busy = true
	stop(false); account_save_folder()
	var result: Dictionary = await account_service.api("/rooms/" + code.strip_edges().to_upper().uri_encode() + "/join", account_service.build_info())
	account_service.busy = false
	if result.is_empty(): message.emit(account_service.error); return
	var peer = preload("res://Adventure/relay_peer.gd").new()
	peer._id = int(result.peer_id)
	if peer.connect_relay(account_service.relay_url(), str(result.ticket)) != OK:
		message.emit("Could not connect to the relay."); return
	local_name = str(account_service.account.username)
	online = true; relay_mode = true; _hosting = false; _resume_token = ""
	_connect_deadline = Time.get_ticks_msec() + 90000
	multiplayer.multiplayer_peer = peer
	status = "Joining online world…"; message.emit(status)

func start_solo(seed_value: int, display_name: String, resume: bool = false) -> void:
	if (account_service.build_version != "dev" or not OS.has_feature("editor")) and account_service.account.is_empty():
		message.emit(account_service.error); return
	stop(false)
	account_save_folder()
	local_name = clean_name(display_name)
	state = Rules.fresh_state(seed_value)
	if resume:
		var loaded: Dictionary = load_save()
		if not loaded.is_empty():
			state = loaded
	_prepare_world()
	store.enter(1, "", true)
	_publish_profile(1)
	_owner_profile[1] = store.profile(1).get("id", "")
	_spawn(1, local_name, world.spawn_position(0))
	running = true
	status = "Solo world"
	session_started.emit()
	state_changed.emit()

func host_game(seed_value: int, port: int, display_name: String) -> Error:
	if account_service.build_version != "dev":
		message.emit("Use Host online world in this release."); return ERR_UNAUTHORIZED
	stop(false)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, 5, 3)
	if error != OK:
		message.emit("Could not host on this port. Try a different port.")
		return error
	multiplayer.multiplayer_peer = peer
	online = true
	_hosting=true
	local_name = clean_name(display_name)
	state = Rules.fresh_state(seed_value)
	_prepare_world()
	store.enter(1, "", true)
	_publish_profile(1)
	_owner_profile[1] = store.profile(1).get("id", "")
	_spawn(1, local_name, world.spawn_position(0))
	running = true
	status = "Hosting · UDP %d" % port
	session_started.emit()
	state_changed.emit()
	return OK

func join_game(address: String, port: int, display_name: String) -> Error:
	if account_service.build_version != "dev":
		message.emit("Use your friend's invite code in this release."); return ERR_UNAUTHORIZED
	stop(false)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address.strip_edges(), port, 3)
	if error != OK:
		message.emit("Could not start the connection. Check the address and port.")
		return error
	multiplayer.multiplayer_peer = peer
	online = true
	local_name = clean_name(display_name)
	_connect_deadline = Time.get_ticks_msec() + 90000
	_server_address=address.strip_edges()+":"+str(port)
	_resume_token=_read_token()
	status = "Connecting…"
	message.emit("Connecting to the host…")
	return OK

func stop(emit_signal: bool = true) -> void:
	if running and is_authority(): _save()
	_epoch += 1
	running = false
	_connect_deadline = 0
	if online:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	relay_mode = false
	invite_code = ""
	_hosting=false
	store.bindings.clear()
	local_profile.clear()
	_clear_players()
	_pending.clear()
	_actions.clear()
	_ready_peers.clear()
	_last_input_at.clear()
	_inputs_seen.clear()
	if emit_signal:
		session_stopped.emit()

func _clear_players() -> void:
	for body: CharacterBody3D in players.values():
		remove_child(body)
		body.queue_free()
	players.clear()
	_owner_profile.clear()

func _prepare_world() -> void:
	preload("res://Adventure/loading_screen.gd").history.clear()
	preload("res://Adventure/loading_screen.gd").show_progress(2,"Opening world save…")
	_epoch += 1
	clock_time = 0
	if is_authority():
		if save_enabled: store.load_world(state["seed"])
		else: store.fresh(state["seed"])
		if not store.writable: message.emit("The save is damaged and has been preserved. This session cannot overwrite it.")
		state=store.data["world"].duplicate(true)
		state["world_delta"]=store.public_delta()
	if world.terrain_cells.is_empty() or world.seed_value!=state["seed"] or world.geography.landscape_version!=int(state.get("landscape_version",1)):
		world.build(state["seed"],int(state.get("landscape_version",1)))
	else:
		world.reset_persistence()
	_world_used=true
	if is_authority():
		store.migrate_resources(world)
		state["world_delta"]=store.public_delta()
	world.apply_state(state, false)
	preload("res://Adventure/loading_screen.gd").finish()

static func clean_name(value: String) -> String:
	var cleaned: String = value.strip_edges().replace("\n", " ").replace("\r", " ").left(20)
	return "Traveler" if cleaned.is_empty() else cleaned

func _spawn(id: int, display_name: String, p: Vector3) -> void:
	if players.has(id):
		return
	var body: CharacterBody3D = CharacterBody3D.new()
	body.set_script(Player)
	body.name = "Traveler_%d" % id
	add_child(body)
	body.configure(display_name, PALETTE[players.size() % PALETTE.size()], is_authority())
	body.teleport(p)
	players[id] = body
	if is_authority(): body.equip(store.profile(id).get("equipped","axe"))
	_last_input_at[id] = clock_time

func _connected() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1).set_timeout(32,30000,90000)
	_hello.rpc_id(1, local_name, Rules.VERSION, _resume_token)

@rpc("any_peer", "call_remote", "reliable")
func _hello(display_name: String, version: int, token: String = "") -> void:
	if not is_authority() or not running:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if version != Rules.VERSION or players.size() + _pending.size() >= 6 or players.has(id) or _pending.has(id):
		return
	var identity: Dictionary
	if relay_mode:
		var verified: Dictionary = multiplayer.multiplayer_peer.identities.get(id, {})
		if verified.is_empty(): return
		display_name = str(verified.username)
		identity = store.enter_account(id, str(verified.account_id))
	else:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id).set_timeout(32,30000,90000)
		identity = store.enter(id,token)
	if identity.is_empty():
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if not relay_mode: _credentials.rpc_id(id,identity["token"])
	_pending[id] = clean_name(display_name)
	_load_world.rpc_id(id, state)

@rpc("authority", "call_remote", "reliable")
func _load_world(snapshot: Dictionary) -> void:
	if not Rules.validate_state(snapshot):
		message.emit("The host sent an incompatible world.")
		stop()
		return
	_clear_players()
	state = snapshot.duplicate(true)
	_prepare_world()
	running = true
	status = "Connected world"
	_connect_deadline = 0
	_client_loaded.rpc_id(1)
	session_started.emit()
	state_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func _client_loaded() -> void:
	if not is_authority():
		return
	var id: int = multiplayer.get_remote_sender_id()
	if not _pending.has(id):
		return
	var checkpoint: int = players[1].checkpoint if players.has(1) else 0
	_spawn(id, _pending[id], world.spawn_position(checkpoint, players.size()))
	players[id].checkpoint = checkpoint
	_pending.erase(id)
	_ready_peers.append(id)
	_publish_profile(id)
	_send_roster()
	_send_state()
	_announce("%s joined the expedition." % players[id].nickname)

func _send_roster() -> void:
	var roster: Dictionary = {}
	for id: int in players:
		roster[id] = {"name": players[id].nickname, "p": players[id].position, "profile": store.profile(id).get("id", "")}
		_owner_profile[id] = roster[id]["profile"]
	for peer: int in _ready_peers:
		_receive_roster.rpc_id(peer, roster)
	state_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_roster(roster: Dictionary) -> void:
	for id: int in players.keys():
		if not roster.has(id):
			players[id].queue_free()
			players.erase(id)
			_owner_profile.erase(id)
	for id: int in roster:
		_spawn(id, roster[id]["name"], roster[id]["p"])
		_owner_profile[id] = roster[id].get("profile", "")
	state_changed.emit()

func _peer_left(id: int) -> void:
	if is_authority():
		_save()
		store.leave(id)
	_pending.erase(id)
	_actions.erase(id)
	_ready_peers.erase(id)
	if players.has(id):
		var display_name: String = players[id].nickname
		players[id].queue_free()
		players.erase(id)
		if is_authority() and running:
			_send_roster()
			_announce(display_name + " left the expedition.")

func _connection_failed() -> void:
	var was_relay: bool = relay_mode
	stop()
	message.emit("Online connection closed. Check your connection and ask the host for a fresh invite." if was_relay else "Connection failed. Verify the host address, UDP port, and that the host is running.")

func _server_left() -> void:
	stop()
	message.emit("The host or relay disconnected. Progress is stored on the host's computer; ask them to reopen the world to rejoin.")

func submit_input(direction: Vector2, yaw: float, jump: bool, sprint: bool=false) -> void:
	if not running:
		return
	if is_authority():
		_accept_input(1, direction, yaw, jump, sprint)
	else:
		_input_packet.rpc_id(1, direction, yaw, jump, sprint)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _input_packet(direction: Vector2, yaw: float, jump: bool, sprint: bool=false) -> void:
	if is_authority():
		_accept_input(multiplayer.get_remote_sender_id(), direction, yaw, jump, sprint)

func _accept_input(id: int, direction: Vector2, yaw: float, jump: bool, sprint: bool=false) -> void:
	if not players.has(id) or not direction.is_finite() or not is_finite(yaw):
		return
	players[id].move_input = direction.limit_length(1)
	players[id].sprinting=sprint
	players[id].wants_jump = players[id].wants_jump or jump
	_last_input_at[id] = clock_time
	_inputs_seen[id] = true

func _physics_process(delta: float) -> void:
	if _connect_deadline > 0 and Time.get_ticks_msec() > _connect_deadline:
		_connection_failed()
	if not running:
		return
	clock_time += delta
	if is_instance_valid(world.wildlife):
		var owners: Dictionary = {}
		for peer_id: int in players:
			if _owner_profile.has(peer_id): owners[_owner_profile[peer_id]] = players[peer_id].position
		world.wildlife.tick(clock_time, delta, owners)
	state["day_time"]=fposmod(float(state.get("day_time",0.32))+delta/1200.0,1.0)
	_stream_timer+=delta
	if _stream_timer>0.4 and local_player()!=null:
		_stream_timer=0
		var positions: Array=[]
		if is_authority():
			for body: CharacterBody3D in players.values(): positions.append(body.position)
		else: positions.append(local_player().position)
		world.update_streaming(local_player().position,positions)
	world.tick(delta, clock_time)
	world.update_player_effects(players.values(),delta)
	if is_authority():
		_tick_actions()
		for id: int in players:
			var body: CharacterBody3D = players[id]
			if clock_time - float(_last_input_at.get(id, 0)) > 0.5:
				body.move_input = Vector2.ZERO
			var before: Vector3=body.position
			body.update_water(world.geography.water_height(Vector2(body.position.x,body.position.z)),world.height_at(Vector2(body.position.x,body.position.z)))
			body.simulate(delta)
			store.tick(id,body.position,body.position.distance_to(before),delta,world)
			if body.position.y < -2.5:
				_respawn(id)
		_profile_timer+=delta; _save_timer+=delta
		if _profile_timer>=2:
			_profile_timer=0
			for id: int in players: _publish_profile(id)
		if _save_timer>=30:
			_save_timer=0; _save()
		_snapshot_time += delta
		if online and _snapshot_time >= 0.05:
			_snapshot_time = 0
			var poses: Dictionary = {}
			for id: int in players:
				var p: CharacterBody3D = players[id]
				poses[id] = {"p": p.position, "v": p.velocity, "yaw": p.facing, "checkpoint": p.checkpoint,"animation":p.animation_state,"tool":p.equipped_tool,"action":p._action_name,"action_left":p._action,"swimming":p.swimming}
			for peer: int in _ready_peers:
				_receive_poses.rpc_id(peer, poses, clock_time, float(state["day_time"]))
	else:
		for body: CharacterBody3D in players.values():
			body.interpolate(delta)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_poses(poses: Dictionary, server_time: float, day_time: float) -> void:
	clock_time = server_time
	state["day_time"]=day_time
	for id: int in poses:
		if players.has(id):
			var body: CharacterBody3D = players[id]
			body.remote_position = poses[id]["p"]
			body.remote_yaw = poses[id]["yaw"]
			body.remote_velocity = poses[id]["v"]
			body.checkpoint = poses[id]["checkpoint"]
			if poses[id].get("animation","") in Player.ANIMATIONS or poses[id].get("animation","") in ["gameplay/SwimIdle","gameplay/SwimForward"]: body.animation_state=poses[id]["animation"]
			body.swimming=bool(poses[id].get("swimming",false))
			body.equip(poses[id].get("tool","hand"))
			if float(poses[id].get("action_left",0))>0 and body._action<=0:
				body.action(poses[id].get("action","HammerBuild"),float(poses[id].action_left))
			if body.position.distance_to(body.remote_position) > 15:
				body.teleport(body.remote_position)

func interact() -> void:
	if is_authority():
		_interact(1)
	else:
		_interact_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _interact_request() -> void:
	if is_authority():
		_interact(multiplayer.get_remote_sender_id())

func _interact(id: int) -> void:
	if not running or not players.has(id): return
	var resource_id: String=nearest_resource(id)
	if not resource_id.is_empty(): _gather(id,resource_id)
	else: _private_message(id,"Nothing within reach. Explore a trail or find a resource node.")

func recall() -> void:
	if is_authority():
		_respawn(1)
	else:
		_recall_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _recall_request() -> void:
	if is_authority():
		_respawn(multiplayer.get_remote_sender_id())

func _respawn(id: int) -> void:
	if players.has(id):
		players[id].teleport(world.spawn_position(players[id].checkpoint, 0))

func _send_state() -> void:
	if is_authority(): state["world_delta"]=store.public_delta()
	world.apply_state(state)
	state_changed.emit()
	if online:
		for peer: int in _ready_peers:
			_receive_state.rpc_id(peer, state)

@rpc("authority", "call_remote", "reliable")
func _receive_state(snapshot: Dictionary) -> void:
	if Rules.validate_state(snapshot):
		state = snapshot.duplicate(true)
		world.apply_state(state)
		state_changed.emit()

func _private_message(id: int, text: String) -> void:
	if id == 1:
		message.emit(text)
	elif online and id in _ready_peers:
		_receive_message.rpc_id(id, text)

func _announce(text: String) -> void:
	message.emit(text)
	if online:
		for peer: int in _ready_peers:
			_receive_message.rpc_id(peer, text)

@rpc("authority", "call_remote", "reliable")
func _receive_message(text: String) -> void:
	message.emit(text)

func _save() -> void:
	if save_enabled and is_authority() and not store.data.is_empty():
		if not store.save(state): message.emit("World save failed. Existing save files have been preserved.")

func load_save() -> Dictionary:
	var manifest: String=store.directory+"/latest.txt"
	if not FileAccess.file_exists(manifest) and store.directory=="user://openworld_v3": manifest="user://openworld_v2/latest.txt"
	if not FileAccess.file_exists(manifest): return {}
	var seed_text: String=FileAccess.get_file_as_string(manifest).strip_edges()
	if not seed_text.is_valid_int(): return {}
	return Rules.fresh_state(int(seed_text))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and running and is_authority(): _save()

func _read_token() -> String:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://traveler_keys_v2.json")) if FileAccess.file_exists("user://traveler_keys_v2.json") else {}
	return str(parsed.get(_server_address,"")) if parsed is Dictionary else ""

@rpc("authority","call_remote","reliable")
func _credentials(token: String) -> void:
	_resume_token=token
	if not save_enabled: return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://traveler_keys_v2.json")) if FileAccess.file_exists("user://traveler_keys_v2.json") else {}
	var keys: Dictionary=parsed if parsed is Dictionary else {}
	keys[_server_address]=token
	var file: FileAccess=FileAccess.open("user://traveler_keys_v2.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(keys))

func _publish_profile(id: int) -> void:
	var value: Dictionary=store.view(id)
	if id==1: local_profile=value
	elif online and id in _ready_peers: _receive_profile.rpc_id(id,value)

@rpc("authority","call_remote","reliable")
func _receive_profile(value: Dictionary) -> void:
	local_profile=value

func nearest_resource(id: int, matching_tool: bool=true) -> String:
	if not players.has(id): return ""
	var nearest: String=""; var distance: float=4.5
	for key: String in world.resources:
		var r: Dictionary=world.resources[key]
		if matching_tool and r.kind!=preload("res://Adventure/items.gd").tool(players[id].equipped_tool).get("resource",""): continue
		if int(state.get("world_delta",{}).get("resources",{}).get(key,r["charges"]))<=0: continue
		var d: float=players[id].position.distance_to(r["p"])
		if d<distance: nearest=key; distance=d
	return nearest

func gather() -> void:
	var animal: Node3D = nearest_animal(local_id())
	if animal != null:
		if is_authority(): _attack_animal(1, animal.animal_id)
		else: _attack_animal_request.rpc_id(1, animal.animal_id)
		return
	var id: String=nearest_resource(local_id())
	if id.is_empty():
		var nearby: String=nearest_resource(local_id(),false)
		message.emit("Use 1 Axe for trees, 2 Pickaxe for rock, or 6 Hands for plants." if not nearby.is_empty() else "Move within reach of a tree, rock or plant."); return
	if is_authority(): _gather(1,id)
	else: _gather_request.rpc_id(1,id)

@rpc("any_peer","call_remote","reliable")
func _gather_request(resource_id: String) -> void:
	if is_authority(): _gather(multiplayer.get_remote_sender_id(),resource_id)

func _gather(id: int, resource_id: String) -> void:
	if not running or not players.has(id) or players[id].swimming: return
	if _actions.has(id): return
	var resource: Dictionary=world.resources.get(resource_id,{})
	if resource.is_empty() or players[id].position.distance_to(resource.p)>4.5: return
	var kind: String=resource.kind
	var tool: String=store.profile(id).get("equipped","hand")
	if kind!="fiber" and preload("res://Adventure/items.gd").tool(tool).get("resource","")!=kind:
		_private_message(id,"Equip an axe for wood or a pickaxe for stone."); return
	var animation: String="GatherPlant" if kind=="fiber" else ("AxeSwing" if kind=="wood" else "PickaxeSwing")
	_actions[id]={"type":"gather","resource":resource_id,"origin":players[id].position,"due":clock_time+(0.495 if kind=="stone" else 0.44),"tool":tool}
	_start_action(id,animation,resource.p,0.9 if kind=="stone" else 0.8)

func craft(recipe: String) -> void:
	if is_authority(): _craft(1,recipe)
	else: _craft_request.rpc_id(1,recipe)

@rpc("any_peer","call_remote","reliable")
func _craft_request(recipe: String) -> void:
	if is_authority(): _craft(multiplayer.get_remote_sender_id(),recipe)

func _craft(id: int, recipe: String) -> void:
	if not running or not players.has(id) or _actions.has(id) or players[id].swimming: return
	var recipes: Dictionary=preload("res://Adventure/items.gd").recipes()
	if not recipes.has(recipe): return
	var data: Resource=recipes[recipe].data
	if not Store.afford(store.profile(id),data.ingredients): _private_message(id,"Not enough materials."); return
	if not _station_available(id,data.required_station): _private_message(id,"Move beside the required workstation."); return
	_actions[id]={"type":"craft","recipe":recipe,"origin":players[id].position,"due":clock_time+data.craft_time}
	var work_target: Vector3=players[id].position+Basis(Vector3.UP,players[id].facing)*Vector3(0,0,-0.7)
	if not data.required_station.is_empty():
		if data.required_station == "cooking_fire":
			for position: Vector3 in world.cooking_stations:
				if position.distance_to(players[id].position) < 3.0: work_target = position; break
		for record: Dictionary in store.data.structures:
			var station_position: Vector3=preload("res://Adventure/construction.gd").position(record)
			if record.module_id==data.required_station and station_position.distance_to(players[id].position)<3: work_target=station_position; break
	_start_action(id,data.animation_type,work_target,data.craft_time)
	_private_message(id,"Crafting "+data.display_name+"…")

func place(module: String, p: Vector3, turn: int) -> void:
	if is_authority(): _place(1,module,p,turn)
	else: _place_request.rpc_id(1,module,p,turn)

@rpc("any_peer","call_remote","reliable")
func _place_request(module: String, p: Vector3, turn: int) -> void:
	if is_authority(): _place(multiplayer.get_remote_sender_id(),module,p,turn)

func _place(id: int, module: String, p: Vector3, turn: int) -> void:
	if not running or not players.has(id) or players[id].swimming: return
	if _actions.has(id): return
	var result: Dictionary=store.place(id,module,p,turn,players[id].position,world,clock_time)
	_economy_result(id,result)
	if result.ok:
		_start_action(id,"HammerBuild",p,0.65)
		var cost: Dictionary=preload("res://Adventure/modules.gd").definition(module).cost
		var epoch: int=_epoch
		await get_tree().create_timer(0.3575).timeout
		if running and _epoch==epoch: _emit_impact(p,"stone" if int(cost.get("stone",0))>int(cost.get("wood",0)) else "wood")

func _economy_result(id: int, result: Dictionary) -> void:
	_private_message(id,result["reason"])
	if result["ok"]:
		_publish_profile(id); _send_state(); _save()

func equip(tool: String) -> void:
	if is_authority(): _equip(1,tool)
	else: _equip_request.rpc_id(1,tool)

@rpc("any_peer","call_remote","reliable")
func _equip_request(tool: String) -> void:
	if is_authority(): _equip(multiplayer.get_remote_sender_id(),tool)

func _equip(id: int, tool: String) -> void:
	if not running or not players.has(id): return
	var result: Dictionary=store.equip(id,tool)
	if result["ok"]: players[id].equip(tool); _publish_profile(id)
	else: _private_message(id,result["reason"])

@rpc("authority","call_remote","reliable")
func _gather_feedback(id: int, kind: String, position: Vector3) -> void:
	if players.has(id): players[id].action("GatherPlant" if kind=="fiber" else "AxeSwing",0.8)
	if world.has_method("gather_feedback"): world.gather_feedback(position,kind)

func _station_available(id: int, station: String) -> bool:
	if station.is_empty(): return true
	if station == "cooking_fire":
		for position: Vector3 in world.cooking_stations:
			if position.distance_to(players[id].position) < 3.0: return true
	for record: Dictionary in store.data.structures:
		if record.module_id==station and preload("res://Adventure/construction.gd").position(record).distance_to(players[id].position)<3: return true
	return false

func _tick_actions() -> void:
	for id: int in _actions.keys():
		var job: Dictionary=_actions[id]
		if not players.has(id): _actions.erase(id); continue
		if players[id].swimming or players[id].position.distance_to(job.origin)>1.4:
			_actions.erase(id); _private_message(id,"Action cancelled: you moved away."); continue
		if clock_time<job.due: continue
		_actions.erase(id)
		if job.type=="gather":
			if store.profile(id).get("equipped","")!=job.tool: continue
			var result: Dictionary=store.gather(id,job.resource,players[id].position,world,clock_time)
			_economy_result(id,result)
			if result.ok: _emit_impact(world.resources[job.resource].p,world.resources[job.resource].kind)
		elif job.type=="attack":
			if store.profile(id).get("equipped", "hand") != job.tool: continue
			var animal: Node3D = world.wildlife.find_animal(job.animal)
			if not _animal_in_reach(id, animal): continue
			_economy_result(id, store.hit_animal(id, animal, clock_time))
		else:
			var data: Resource=preload("res://Adventure/items.gd").recipes()[job.recipe].data
			if not _station_available(id,data.required_station): _private_message(id,"Craft cancelled: station out of reach."); continue
			var result: Dictionary=store.craft(id,job.recipe,clock_time)
			_economy_result(id,result)
			if result.ok: _emit_impact(players[id].position+Basis(Vector3.UP,players[id].facing)*Vector3(0,0,-0.6),data.effect_type)

func nearest_animal(id: int) -> Node3D:
	if not running or not players.has(id) or not is_instance_valid(world.wildlife): return null
	var result: Node3D = null
	var distance: float = 3.0
	for animal: Node3D in world.wildlife.get_children():
		var d: float = players[id].position.distance_to(animal.position)
		if d < distance and _animal_in_reach(id, animal):
			result = animal
			distance = d
	return result

func _animal_in_reach(id: int, animal: Node3D) -> bool:
	if animal == null or animal.health <= 0 or not players.has(id): return false
	var body: CharacterBody3D = players[id]
	if body.position.distance_to(animal.position) > 3.0: return false
	var direction: Vector3 = animal.position - body.position
	direction.y = 0.0
	if direction.length() > 0.5 and (Basis(Vector3.UP, body.facing) * Vector3.FORWARD).dot(direction.normalized()) < 0.35: return false
	var target: Vector3 = animal.position + Vector3.UP * (0.65 if animal.species == "cow" else 0.3)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(body.position + Vector3.UP, target, 5)
	ray.exclude = [body.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

@rpc("any_peer", "call_remote", "reliable")
func _attack_animal_request(animal_id: String) -> void:
	if is_authority(): _attack_animal(multiplayer.get_remote_sender_id(), animal_id)

func _attack_animal(id: int, animal_id: String) -> void:
	if not running or not players.has(id) or _actions.has(id) or players[id].swimming: return
	if not is_instance_valid(world.wildlife) or clock_time < float(store.cooldowns.get(id, 0)): return
	var animal: Node3D = world.wildlife.find_animal(animal_id)
	if not _animal_in_reach(id, animal): return
	var tool: String = store.profile(id).get("equipped", "hand")
	_actions[id] = {"type":"attack", "animal":animal_id, "origin":players[id].position, "due":clock_time + 0.4, "tool":tool}
	_start_action(id, "AxeSwing" if tool == "axe" else ("PickaxeSwing" if tool == "pickaxe" else "HammerBuild"), animal.position, 0.8)

## Pet a nearby animal (free), or feed it a bone/meat to tame a cat or dog for life.
func pet_animal() -> void:
	var animal: Node3D = nearest_animal(local_id())
	if animal == null:
		message.emit("Move closer to a cat, dog or cow to pet or feed it."); return
	if is_authority(): _interact_animal(1, animal.animal_id)
	else: _interact_animal_request.rpc_id(1, animal.animal_id)

@rpc("any_peer", "call_remote", "reliable")
func _interact_animal_request(animal_id: String) -> void:
	if is_authority(): _interact_animal(multiplayer.get_remote_sender_id(), animal_id)

func _interact_animal(id: int, animal_id: String) -> void:
	if not running or not players.has(id) or not is_instance_valid(world.wildlife): return
	var animal: Node3D = world.wildlife.find_animal(animal_id)
	if not _animal_in_reach(id, animal): return
	var result: Dictionary = store.interact_animal(id, animal)
	_economy_result(id, result)
	if result.ok: _broadcast_affection(animal_id)

func _broadcast_affection(animal_id: String) -> void:
	_show_affection(animal_id)
	for peer: int in _ready_peers: _show_affection.rpc_id(peer, animal_id)

@rpc("authority", "call_remote", "reliable")
func _show_affection(animal_id: String) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.wildlife): return
	var animal: Node3D = world.wildlife.find_animal(animal_id)
	if animal != null: animal.show_affection()

func inventory_action(item: String, action: String) -> void:
	if is_authority(): _inventory_action(1, item, action)
	else: _inventory_action_request.rpc_id(1, item, action)

@rpc("any_peer", "call_remote", "reliable")
func _inventory_action_request(item: String, action: String) -> void:
	if is_authority(): _inventory_action(multiplayer.get_remote_sender_id(), item, action)

func _inventory_action(id: int, item: String, action: String) -> void:
	if not running or not players.has(id) or _actions.has(id): return
	var result: Dictionary = store.inventory_action(id, item, action, clock_time)
	if result.ok: players[id].equip(store.profile(id).get("equipped", "hand"))
	_economy_result(id, result)

func _start_action(id: int, animation: String, target: Vector3, duration: float) -> void:
	_action_feedback(id,animation,target,duration)
	for peer: int in _ready_peers: _action_feedback.rpc_id(peer,id,animation,target,duration)

@rpc("authority","call_remote","reliable")
func _action_feedback(id: int, animation: String, target: Vector3, duration: float) -> void:
	if not players.has(id): return
	var direction: Vector3=target-players[id].position
	if direction.length()>0.1: players[id].facing=atan2(-direction.x,-direction.z); players[id].remote_yaw=players[id].facing
	players[id].action(animation,duration)

func _emit_impact(p: Vector3, kind: String) -> void:
	_impact_feedback(p,kind)
	for peer: int in _ready_peers: _impact_feedback.rpc_id(peer,p,kind)

@rpc("authority","call_remote","reliable")
func _impact_feedback(p: Vector3, kind: String) -> void:
	world.gather_feedback(p,kind)

func remove_structure(structure_id: String) -> void:
	if is_authority(): _remove_structure(1,structure_id)
	else: _remove_request.rpc_id(1,structure_id)

@rpc("any_peer","call_remote","reliable")
func _remove_request(structure_id: String) -> void:
	if is_authority(): _remove_structure(multiplayer.get_remote_sender_id(),structure_id)

func _remove_structure(id: int, structure_id: String) -> void:
	if not running or not players.has(id) or _actions.has(id) or players[id].swimming: return
	_economy_result(id,store.disassemble(id,structure_id,players[id].position,world,clock_time))

func clear_grass(p: Vector3) -> void:
	if is_authority(): _clear_grass(1,p)
	else: _clear_grass_request.rpc_id(1,p)

func flatten_land(p: Vector3) -> void:
	if is_authority(): _flatten_land(1,p)
	else: _flatten_request.rpc_id(1,p)

@rpc("any_peer","call_remote","reliable")
func _flatten_request(p: Vector3) -> void:
	if is_authority(): _flatten_land(multiplayer.get_remote_sender_id(),p)

func _flatten_land(id: int,p: Vector3) -> void:
	if not running or not players.has(id) or not p.is_finite() or _actions.has(id): return
	if players[id].position.distance_to(p)>10 or clock_time<float(store.cooldowns.get(id,0)): return
	var center: Vector2=Vector2(snappedf(p.x,4),snappedf(p.z,4))
	if center.abs().x>490 or center.abs().y>490: return
	if store.data.get("grass_clearings",{}).size()>9996:
		_private_message(id,"This world's cleared-ground budget has been reached."); return
	var level: float=world.height_at(center)
	# Never undermine existing player homes or authored settlement structures.
	for record: Dictionary in store.data.structures:
		var q: Vector3=preload("res://Adventure/construction.gd").position(record)
		if Vector2(q.x,q.z).distance_to(center)<17:
			_private_message(id,"Flatten the site before building, at least 17 m from existing pieces."); return
	var shape: BoxShape3D=BoxShape3D.new(); shape.size=Vector3(27,24,27)
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.transform.origin=Vector3(center.x,level+6,center.y); query.collision_mask=5
	for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,128):
		var collider: Node=hit.collider
		if collider.has_meta("resource_id") or collider.get_parent().name.begins_with("Physics_"): continue
		_private_message(id,"Move the flattening area away from an existing building or bridge."); return
	var edits: Dictionary=store.data.get("terrain_edits",{}).duplicate()
	var grid: Vector2i=Vector2i((center+Vector2.ONE*512)/4)
	for z in range(-3,4):
		for x in range(-3,4):
			var distance: float=Vector2(x,z).length()*4
			if distance>=12: continue
			var index: int=(grid.y+z)*257+grid.x+x
			var current: float=world.geography.heights[index]
			if absf(current-level)>8: _private_message(id,"This cliff is too steep to level in one area. Use foundation supports here."); return
			edits[str(index)]=lerpf(level,current,smoothstep(6,12,distance))
	store.data.terrain_edits=edits
	# Clear the level center while leaving a soft grassy border.
	if not store.data.has("grass_clearings"): store.data.grass_clearings={}
	for offset: Vector2 in [Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]:
		var at: Vector2=center+offset
		store.data.grass_clearings["%d:%d" % [roundi(at.x/2),roundi(at.y/2)]]=[roundi(at.x),roundi(at.y)]
	store.cooldowns[id]=clock_time+1.0
	_economy_result(id,{"ok":true,"reason":"Land flattened: level center with a smooth edge. C clears more grass."})
	for player: CharacterBody3D in players.values():
		var ground: float=world.height_at(Vector2(player.position.x,player.position.z))
		if player.position.y<ground+.15: player.position.y=ground+.2; player.velocity.y=0

@rpc("any_peer","call_remote","reliable")
func _clear_grass_request(p: Vector3) -> void:
	if is_authority(): _clear_grass(multiplayer.get_remote_sender_id(),p)

func _clear_grass(id: int, p: Vector3) -> void:
	if not running or not players.has(id) or not p.is_finite() or _actions.has(id): return
	if players[id].position.distance_to(p)>10: _private_message(id,"Move within 10 m to clear grass."); return
	if clock_time<float(store.cooldowns.get(id,0)): return
	for record: Dictionary in store.data.structures:
		if record.owner_id!=store.profile(id).id and preload("res://Adventure/construction.gd").position(record).distance_to(p)<5:
			_private_message(id,"Leave another traveler's building area clear."); return
	if not store.data.has("grass_clearings"): store.data.grass_clearings={}
	if store.data.grass_clearings.size()>=10000: return
	var cell: Vector2i=Vector2i(roundi(p.x/2),roundi(p.z/2))
	store.data.grass_clearings[str(cell.x)+":"+str(cell.y)]=[cell.x*2,cell.y*2]
	store.cooldowns[id]=clock_time+0.8
	_start_action(id,"GatherPlant",p,0.8)
	_economy_result(id,{"ok":true,"reason":"Grass cleared. You can build here if the ground is suitable."})
