extends Node3D
signal state_changed
signal message(text: String)
signal session_started
signal session_stopped
signal note_played(position: Vector3, note: int, echo: bool)
const Rules := preload("res://Adventure/rules.gd")
const World := preload("res://Adventure/open_world.gd")
const Store := preload("res://Adventure/world_store.gd")
const Player := preload("res://Adventure/player.gd")
const PALETTE: Array[Color] = [Color("b0ce7e"), Color("7acbe0"), Color("dc98b4"), Color("e8be79"), Color("a99bdc"), Color("8cd6b1")]
const SAVE_PATH: String = "user://resonant_adventure_v1.json"
var store: RefCounted = Store.new()
var local_profile: Dictionary = {}
var build_hint: String = ""
var _world_used: bool=false
var _hosting: bool=false
var _profile_timer: float = 0
var _save_timer: float = 0
var _server_address: String = ""
var _resume_token: String = ""
var world: Node3D
var state: Dictionary = Rules.fresh_state(73129)
var players: Dictionary = {}
var running: bool = false
var online: bool = false
var save_enabled: bool = true
var status: String = "Solo / up to 6 online travelers"
var local_name: String = "Traveler"
var clock_time: float = 0
var progress: Array = [0, 0, 0, 0, 0, 0, 0]
var _contributors: Array = [{}, {}, {}, {}, {}, {}, {}]
var _pending: Dictionary = {}
var _ready_peers: Array[int] = []
var _histories: Dictionary = {}
var _cooldowns: Dictionary = {}
var _inputs_seen: Dictionary = {}
var _last_notes: Dictionary = {}
var _echo_until: Dictionary = {}
var _hurt_until: Dictionary = {}
var _spell_until: Dictionary = {}
var _last_input_at: Dictionary = {}
var _snapshot_time: float = 0
var _epoch: int = 0
var _connect_deadline: int = 0

func _ready() -> void:
	world = Node3D.new()
	world.set_script(World)
	world.name = "World"
	add_child(world)
	world.build(state["seed"])
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

func start_solo(seed_value: int, display_name: String, resume: bool = false) -> void:
	stop(false)
	local_name = clean_name(display_name)
	state = Rules.fresh_state(seed_value)
	if resume:
		var loaded: Dictionary = load_save()
		if not loaded.is_empty():
			state = loaded
	_prepare_world()
	store.enter(1, "", true)
	_publish_profile(1)
	_spawn(1, local_name, world.spawn_position(0))
	running = true
	status = "Solo expedition"
	session_started.emit()
	state_changed.emit()

func host_game(seed_value: int, port: int, display_name: String) -> Error:
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
	_spawn(1, local_name, world.spawn_position(0))
	running = true
	status = "Hosting · UDP %d" % port
	session_started.emit()
	state_changed.emit()
	return OK

func join_game(address: String, port: int, display_name: String) -> Error:
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
	_hosting=false
	store.bindings.clear()
	local_profile.clear()
	_clear_players()
	_pending.clear()
	_ready_peers.clear()
	_histories.clear()
	_last_notes.clear()
	_echo_until.clear()
	_hurt_until.clear()
	_spell_until.clear()
	_last_input_at.clear()
	_inputs_seen.clear()
	if emit_signal:
		session_stopped.emit()

func _clear_players() -> void:
	for body: CharacterBody3D in players.values():
		remove_child(body)
		body.queue_free()
	players.clear()

func _prepare_world() -> void:
	_epoch += 1
	progress = [0, 0, 0, 0, 0, 0, 0]
	_contributors = [{}, {}, {}, {}, {}, {}, {}]
	_histories.clear()
	_last_notes.clear()
	_echo_until.clear()
	_hurt_until.clear()
	_spell_until.clear()
	clock_time = 0
	if is_authority():
		if save_enabled: store.load_world(state["seed"])
		else: store.fresh(state["seed"])
		if not store.writable: message.emit("The save is damaged and has been preserved. This session cannot overwrite it.")
		state=store.data["music"].duplicate(true)
		state["world_delta"]=store.public_delta()
	if world.seed_value!=state["seed"]:
		world.build(state["seed"])
	else:
		world.reset_persistence()
	_world_used=true
	world.apply_state(state, false)

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
	_histories[id] = []
	_last_input_at[id] = clock_time

func _connected() -> void:
	(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1).set_timeout(32,30000,90000)
	_hello.rpc_id(1, local_name, Rules.VERSION, _resume_token)

@rpc("any_peer", "call_remote", "reliable")
func _hello(display_name: String, version: int, token: String = "") -> void:
	if not is_authority() or not running:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if version != Rules.VERSION or players.size() + _pending.size() >= 6 or players.has(id) or _pending.has(id):
		return
	(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id).set_timeout(32,30000,90000)
	var identity: Dictionary=store.enter(id,token)
	if identity.is_empty():
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_credentials.rpc_id(id,identity["token"])
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
	status = "Connected · shared expedition"
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
		roster[id] = {"name": players[id].nickname, "p": players[id].position}
	for peer: int in _ready_peers:
		_receive_roster.rpc_id(peer, roster)
	state_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_roster(roster: Dictionary) -> void:
	for id: int in players.keys():
		if not roster.has(id):
			players[id].queue_free()
			players.erase(id)
	for id: int in roster:
		_spawn(id, roster[id]["name"], roster[id]["p"])
	state_changed.emit()

func _peer_left(id: int) -> void:
	if is_authority():
		_save()
		store.leave(id)
	_pending.erase(id)
	_ready_peers.erase(id)
	if players.has(id):
		var display_name: String = players[id].nickname
		players[id].queue_free()
		players.erase(id)
		_histories.erase(id)
		if is_authority() and running:
			_send_roster()
			_announce(display_name + " left the expedition.")

func _connection_failed() -> void:
	stop()
	message.emit("Connection failed. Verify the host address, UDP port, and that the host is running.")

func _server_left() -> void:
	stop()
	message.emit("The host disconnected. Your local game is safe; start a solo expedition or join again.")

func submit_input(direction: Vector2, yaw: float, jump: bool) -> void:
	if not running:
		return
	if is_authority():
		_accept_input(1, direction, yaw, jump)
	else:
		_input_packet.rpc_id(1, direction, yaw, jump)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _input_packet(direction: Vector2, yaw: float, jump: bool) -> void:
	if is_authority():
		_accept_input(multiplayer.get_remote_sender_id(), direction, yaw, jump)

func _accept_input(id: int, direction: Vector2, yaw: float, jump: bool) -> void:
	if not players.has(id) or not direction.is_finite() or not is_finite(yaw):
		return
	players[id].move_input = direction.limit_length(1)
	players[id].wants_jump = players[id].wants_jump or jump
	_last_input_at[id] = clock_time
	_inputs_seen[id] = true

func _physics_process(delta: float) -> void:
	if _connect_deadline > 0 and Time.get_ticks_msec() > _connect_deadline:
		_connection_failed()
	if not running:
		return
	clock_time += delta
	world.tick(delta, clock_time)
	if is_authority():
		for id: int in players:
			var body: CharacterBody3D = players[id]
			if clock_time - float(_last_input_at.get(id, 0)) > 0.5:
				body.move_input = Vector2.ZERO
			var before: Vector3=body.position
			body.simulate(delta)
			store.tick(id,body.position,body.position.distance_to(before),delta,world)
			if body.position.y < -2.5:
				_damage(id, 15)
				_respawn(id)
			_check_treasures(id)
			if not world.is_stunned():
				for sentinel: Node3D in world.sentinels:
					if sentinel.visible and sentinel.position.distance_to(body.position + Vector3.UP) < 2.1:
						_damage(id, 20)
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
				poses[id] = {"p": p.position, "v": p.velocity, "yaw": p.facing, "h": p.health, "checkpoint": p.checkpoint}
			for peer: int in _ready_peers:
				_receive_poses.rpc_id(peer, poses, clock_time, Vector2(world._reveal_until, world._stun_until))
	else:
		for body: CharacterBody3D in players.values():
			body.interpolate(delta)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_poses(poses: Dictionary, server_time: float, effect_deadlines: Vector2) -> void:
	clock_time = server_time
	world._reveal_until = effect_deadlines.x
	world._stun_until = effect_deadlines.y
	for id: int in poses:
		if players.has(id):
			var body: CharacterBody3D = players[id]
			body.remote_position = poses[id]["p"]
			body.remote_yaw = poses[id]["yaw"]
			body.remote_velocity = poses[id]["v"]
			body.health = poses[id]["h"]
			body.checkpoint = poses[id]["checkpoint"]
			if body.position.distance_to(body.remote_position) > 15:
				body.teleport(body.remote_position)

func nearest_site(id: int) -> int:
	if not players.has(id):
		return -1
	for i in range(7):
		if players[id].position.distance_to(world.shrine_position(i)) < 10.0:
			return i
	return -1

func play_note(note: int) -> void:
	if not running:
		return
	if is_authority():
		_handle_note(1, note, false)
	else:
		_note_request.rpc_id(1, note)

@rpc("any_peer", "call_remote", "reliable", 2)
func _note_request(note: int) -> void:
	if is_authority():
		_handle_note(multiplayer.get_remote_sender_id(), note, false)

func _handle_note(id: int, note: int, echo: bool) -> void:
	if not players.has(id) or note < 0 or note > 4:
		return
	if not echo and clock_time - float(_last_notes.get(id, -10)) < 0.10:
		return
	if not echo:
		_last_notes[id] = clock_time
		var history: Array = _histories.get(id, [])
		history.append(note)
		if history.size() > 5:
			history.pop_front()
		_histories[id] = history
	var p: Vector3 = players[id].position
	_note_effect(p, note, echo)
	if online:
		for peer: int in _ready_peers:
			_note_effect.rpc_id(peer, p, note, echo)
	var site: int = nearest_site(id)
	if site >= 0 and not state["solved"][site]:
		if not Rules.prerequisites(site, state["solved"]):
			_private_message(id, "This shrine needs the earlier voices. Check the songbook [J].")
		else:
			var required: Array = Rules.required_phrase(state["seed"], site)
			var step: int = progress[site]
			if note == required[step]:
				progress[site] = step + 1
				_contributors[site][str(id) + ("echo" if echo else "")] = true
			else:
				progress[site] = 1 if note == required[0] else 0
				_contributors[site] = {}
				if progress[site] == 1:
					_contributors[site][str(id)] = true
				_private_message(id, "The phrase slipped. Listen with Q and try again.")
			if progress[site] == required.size():
				if site == 5 and not echo and _contributors[site].size() < 2:
					_private_message(id, "The Observatory heard you. Press R: let your Echo answer the phrase.")
				else:
					_solve(site, id)
				progress[site] = 0
				_contributors[site] = {}
			_publish_progress()
	if not echo:
		_check_spell(id)

@rpc("authority", "call_remote", "reliable", 2)
func _note_effect(p: Vector3, note: int, echo: bool) -> void:
	world.pulse(p, Rules.COLORS[note], 2.5 if echo else 1.8)
	note_played.emit(p, note, echo)

func _solve(site: int, id: int) -> void:
	state["solved"][site] = true
	state["shards"] += 3
	players[id].checkpoint = site
	players[id].health = 100
	_send_state()
	var reward: String = ["Bloom learned. The valley answers your song.", "Gust learned. Ride the wind with 5 · 3 · 1.", "Reveal learned. Find hidden memories with 2 · 4 · 2.", "Ward learned. Quiet Discord with 1 · 3 · 5.", "The ancient grove is singing again.", "Your Echo restored the hilltop harmony.", "The Heart is singing. Every voice returns to the world!"][site]
	_announce(reward)
	_save()

func _check_spell(id: int) -> void:
	var history: Array = _histories.get(id, [])
	if history.size() < 3:
		return
	var phrase: Array = history.slice(history.size() - 3)
	for i in range(4):
		if state["solved"][i] and phrase == Rules.SPELLS[i]:
			var key: String = "%d:%d" % [id, i]
			if clock_time < float(_spell_until.get(key, 0)):
				return
			_spell_until[key] = clock_time + 2
			if i == 0:
				for body: CharacterBody3D in players.values():
					if body.position.distance_to(players[id].position) < 12:
						body.health = mini(100, body.health + 20)
			elif i == 1:
				players[id].velocity.y = 12
			_spell_effect(i, players[id].position)
			if online:
				for peer: int in _ready_peers:
					_spell_effect.rpc_id(peer, i, players[id].position)
			_private_message(id, Rules.SPELL_NAMES[i] + "! " + ["Nearby travelers recover 20 health.", "The wind carries you upward.", "Hidden memories shine for 15 seconds.", "Discord is silenced for 8 seconds."][i])

@rpc("authority", "call_remote", "reliable")
func _spell_effect(spell: int, p: Vector3) -> void:
	world.pulse(p, Rules.COLORS[spell], 12)
	if spell == 2:
		world.reveal()
	elif spell == 3:
		world.ward()

func request_echo() -> void:
	if is_authority():
		_start_echo(1)
	else:
		_echo_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _echo_request() -> void:
	if is_authority():
		_start_echo(multiplayer.get_remote_sender_id())

func _start_echo(id: int) -> void:
	if not running or not players.has(id) or clock_time < float(_echo_until.get(id, 0)):
		return
	var history: Array = _histories.get(id, [])
	if history.size() < 3:
		_private_message(id, "Play a phrase first. R asks your Echo to repeat the last four notes.")
		return
	var phrase: Array = history.slice(maxi(0, history.size() - 4)).duplicate()
	var origin: Vector3 = players[id].position
	var epoch: int = _epoch
	_echo_until[id] = clock_time + 4
	for note: int in phrase:
		await get_tree().create_timer(0.42).timeout
		if epoch != _epoch or not players.has(id) or players[id].position.distance_to(origin) > 10:
			return
		_handle_note(id, note, true)

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
	var site: int = nearest_site(id)
	if site < 0:
		_private_message(id, "Explore roads and side trails. G gathers nearby wood, stone and fiber. B opens construction controls.")
	elif state["solved"][site]:
		players[id].checkpoint = site
		players[id].health = 100
		_private_message(id, "Checkpoint tuned: " + Rules.NAMES[site] + ". Health restored.")
	else:
		_private_message(id, Rules.DESCRIPTIONS[site])

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

func _damage(id: int, amount: int) -> void:
	if clock_time < float(_hurt_until.get(id, 0)):
		return
	_hurt_until[id] = clock_time + 2
	players[id].health -= amount
	_private_message(id, "Discord struck! Play Ward (1 · 3 · 5) or move away.")
	if players[id].health <= 0:
		players[id].health = 100
		_respawn(id)
		_private_message(id, "Your last shrine called you back. No memories were lost.")

func _check_treasures(id: int) -> void:
	for treasure: Node3D in world.treasures:
		var treasure_id: int = treasure.get_meta("id")
		if treasure_id in state["collected"]:
			continue
		if treasure.get_meta("hidden") and not world.is_revealed():
			continue
		if players[id].position.distance_to(treasure.position) < 1.7:
			state["collected"].append(treasure_id)
			state["shards"] += 1
			players[id].health = mini(100, players[id].health + 10)
			_send_state()
			_private_message(id, "Memory recovered · +1 harmony · +10 health")
			_save()

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

func _publish_progress() -> void:
	state_changed.emit()
	if online:
		for peer: int in _ready_peers:
			_receive_progress.rpc_id(peer, progress)

@rpc("authority", "call_remote", "reliable", 2)
func _receive_progress(value: Array) -> void:
	progress = value.duplicate()
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

func next_expedition() -> void:
	message.emit("This world is persistent. Choose another seed from the menu to visit a different world.")

func _save() -> void:
	if save_enabled and is_authority() and not store.data.is_empty():
		if not store.save(state): message.emit("World save failed. Existing save files have been preserved.")

func load_save() -> Dictionary:
	var manifest: String=store.directory+"/latest.txt"
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

func nearest_resource(id: int) -> String:
	if not players.has(id): return ""
	var nearest: String=""; var distance: float=4.5
	for key: String in world.resources:
		var r: Dictionary=world.resources[key]
		if int(state.get("world_delta",{}).get("resources",{}).get(key,r["charges"]))<=0: continue
		var d: float=players[id].position.distance_to(r["p"])
		if d<distance: nearest=key; distance=d
	return nearest

func gather() -> void:
	var id: String=nearest_resource(local_id())
	if id.is_empty(): message.emit("Move close to a tree, rock or bush to gather."); return
	if is_authority(): _gather(1,id)
	else: _gather_request.rpc_id(1,id)

@rpc("any_peer","call_remote","reliable")
func _gather_request(resource_id: String) -> void:
	if is_authority(): _gather(multiplayer.get_remote_sender_id(),resource_id)

func _gather(id: int, resource_id: String) -> void:
	if not running or not players.has(id): return
	_economy_result(id,store.gather(id,resource_id,players[id].position,world,clock_time))

func craft(recipe: String) -> void:
	if is_authority(): _craft(1,recipe)
	else: _craft_request.rpc_id(1,recipe)

@rpc("any_peer","call_remote","reliable")
func _craft_request(recipe: String) -> void:
	if is_authority(): _craft(multiplayer.get_remote_sender_id(),recipe)

func _craft(id: int, recipe: String) -> void:
	if running and players.has(id): _economy_result(id,store.craft(id,recipe,clock_time))

func place(module: String, p: Vector3, turn: int) -> void:
	if is_authority(): _place(1,module,p,turn)
	else: _place_request.rpc_id(1,module,p,turn)

@rpc("any_peer","call_remote","reliable")
func _place_request(module: String, p: Vector3, turn: int) -> void:
	if is_authority(): _place(multiplayer.get_remote_sender_id(),module,p,turn)

func _place(id: int, module: String, p: Vector3, turn: int) -> void:
	if not running or not players.has(id): return
	_economy_result(id,store.place(id,module,p,turn,players[id].position,world,clock_time))

func _economy_result(id: int, result: Dictionary) -> void:
	_private_message(id,result["reason"])
	if result["ok"]:
		_publish_profile(id); _send_state(); _save()
