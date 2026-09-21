extends Node
signal changed
var endpoint: String = ""
var token: String = ""
var account: Dictionary = {}
var channel: String = "public"
var build_version: String = "dev"
var error: String = "Start the game through Amiin Launcher to sign in."
var busy: bool = false

func _ready() -> void:
	endpoint = OS.get_environment("AMIIN_API").trim_suffix("/")
	channel = OS.get_environment("AMIIN_CHANNEL")
	if channel.is_empty(): channel = "public"
	if FileAccess.file_exists("res://Adventure/release.json"):
		var build: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Adventure/release.json"))
		if build is Dictionary: build_version = str(build.get("version", "dev"))
	var ticket: String = OS.get_environment("AMIIN_LAUNCH_TICKET")
	OS.set_environment("AMIIN_LAUNCH_TICKET", "")
	if ticket.is_empty(): return
	if not endpoint.begins_with("https://") and not endpoint.begins_with("http://127.0.0.1:"):
		error = "The launcher supplied an unsafe server address."; changed.emit(); return
	busy = true; error = "Signing in…"; changed.emit()
	var result: Dictionary = await api("/auth/exchange", {}, ticket)
	token = str(result.get("token", ""))
	if not token.is_empty():
		result = await api("/play/validate", build_info())
		if result.has("id"): account = result; error = ""
	busy = false; changed.emit()

func build_info() -> Dictionary:
	return {"channel": channel, "version": build_version, "protocol": 1}

func api(path: String, data: Dictionary, bearer: String = "") -> Dictionary:
	if endpoint.is_empty(): error = "Start the game from Amiin Launcher."; return {}
	var http := HTTPRequest.new(); add_child(http); http.timeout = 100
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + (token if bearer.is_empty() else bearer)])
	var code: Error = http.request(endpoint + path, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if code != OK: http.queue_free(); error = "Cannot connect to Amiin Studio."; return {}
	var response: Array = await http.request_completed
	http.queue_free()
	var body: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if response[0] != HTTPRequest.RESULT_SUCCESS or int(response[1]) >= 400 or not body is Dictionary:
		error = str(body.get("detail", "Service unavailable. Try again shortly.")) if body is Dictionary else "Waking server or connection unavailable. Try again shortly."
		changed.emit(); return {}
	return body

func relay_url() -> String:
	return endpoint.replace("https://", "wss://").replace("http://", "ws://") + "/relay"
