extends MultiplayerPeerExtension
## Account-authenticated WSS transport. The relay assigns sender IDs; guests
## can send only to host 1. All RPCs still pass through Session's authority checks.
var socket := WebSocketPeer.new()
var identities: Dictionary = {}
var _id: int = 0
var _status: int = MultiplayerPeer.CONNECTION_CONNECTING
var _target: int = 1
var _channel: int = 0
var _mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _queue: Array[Dictionary] = []
var _last: Dictionary = {"sender": 1, "channel": 0}
var _heartbeat: int = 0
var _refuse: bool = false

func connect_relay(url: String, ticket: String) -> Error:
	socket.inbound_buffer_size = 8388608
	socket.outbound_buffer_size = 8388608
	socket.max_queued_packets = 2048
	socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + ticket])
	return socket.connect_to_url(url)

func _poll() -> void:
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_status = MultiplayerPeer.CONNECTION_DISCONNECTED
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if Time.get_ticks_msec() - _heartbeat > 20000:
		socket.send_text("ping"); _heartbeat = Time.get_ticks_msec()
	while socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = socket.get_packet()
		if socket.was_string_packet():
			var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if not data is Dictionary: continue
			match str(data.get("type", "")):
				"ready":
					_id = int(data.id)
					_status = MultiplayerPeer.CONNECTION_CONNECTED
					for info: Dictionary in data.peers:
						identities[int(info.id)] = info
						peer_connected.emit(int(info.id))
				"joined":
					identities[int(data.peer.id)] = data.peer
					peer_connected.emit(int(data.peer.id))
				"left":
					identities.erase(int(data.id))
					peer_disconnected.emit(int(data.id))
		elif packet.size() >= 8:
			_queue.append({"sender": packet.decode_s32(0), "channel": packet.decode_s32(4), "data": packet.slice(8)})
			if _queue.size() > 4096: _close(); return

func _get_packet_script() -> PackedByteArray:
	if _queue.is_empty(): return PackedByteArray()
	_last = _queue.pop_front()
	return _last.data

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED: return ERR_UNAVAILABLE
	var packet := PackedByteArray(); packet.resize(8)
	packet.encode_s32(0, _target); packet.encode_s32(4, _channel)
	packet.append_array(buffer)
	return socket.put_packet(packet)

func _get_available_packet_count() -> int: return _queue.size()
func _get_packet_peer() -> int: return int(_queue[0].sender) if not _queue.is_empty() else int(_last.sender)
func _get_packet_channel() -> int: return int(_queue[0].channel) if not _queue.is_empty() else int(_last.channel)
func _get_packet_mode() -> int: return MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_max_packet_size() -> int: return 4194296
func _get_unique_id() -> int: return _id
func _get_connection_status() -> int: return _status
func _is_server() -> bool: return _id == 1
func _is_server_relay_supported() -> bool: return false
func _set_target_peer(peer: int) -> void: _target = peer
func _set_transfer_channel(channel: int) -> void: _channel = channel
func _get_transfer_channel() -> int: return _channel
func _set_transfer_mode(mode: int) -> void: _mode = mode
func _get_transfer_mode() -> int: return _mode
func _set_refuse_new_connections(value: bool) -> void: _refuse = value
func _is_refusing_new_connections() -> bool: return _refuse
func _disconnect_peer(peer: int, _force: bool) -> void:
	if _id == 1 and peer > 1: socket.send_text(JSON.stringify({"kick": peer}))
func _close() -> void:
	socket.close(); _status = MultiplayerPeer.CONNECTION_DISCONNECTED; _queue.clear()
