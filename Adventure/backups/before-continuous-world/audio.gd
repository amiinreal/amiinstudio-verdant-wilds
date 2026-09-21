extends Node
const FREQUENCIES: Array[float] = [261.63, 293.66, 329.63, 392.0, 440.0]
var _notes: Dictionary = {}
var _music: AudioStreamPlayer
var _layers: int = -1
var muted: bool = false

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = -24
	add_child(_music)

func play_note(note: int, echo: bool = false) -> void:
	if muted or note < 0 or note > 4:
		return
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = _note_stream(note)
	voice.volume_db = -14 if echo else -10
	voice.pitch_scale = 0.998 if echo else 1.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _note_stream(note: int) -> AudioStreamWAV:
	if _notes.has(note):
		return _notes[note]
	var rate: int = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(rate * 2)
	for i in range(rate):
		var t: float = float(i) / rate
		var envelope: float = minf(t * 90, 1) * exp(-t * 4) * (1 - t)
		var sample: float = (sin(TAU * FREQUENCIES[note] * t) + 0.18 * sin(TAU * FREQUENCIES[note] * 2 * t)) * envelope * 0.68
		data.encode_s16(i * 2, int(sample * 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	_notes[note] = stream
	return stream

func set_layers(restored: int) -> void:
	if _layers == restored:
		return
	_layers = restored
	var rate: int = 22050
	var length: int = rate * 8
	var data: PackedByteArray = PackedByteArray()
	data.resize(length * 2)
	for i in range(length):
		var t: float = float(i) / rate
		var beat: float = fmod(t, 0.5)
		var chord: int = int(t / 2.0) % 4
		var roots: Array[int] = [0, 3, 4, 2]
		var frequency: float = FREQUENCIES[roots[chord]] / 2
		var sample: float = sin(TAU * frequency * t) * 0.13 * exp(-beat * 5)
		if restored >= 1:
			sample += sin(TAU * frequency * 2 * t) * 0.035 * (0.6 + 0.4 * sin(t * PI))
		if restored >= 3:
			var note: int = (int(t * 2) + chord) % 5
			sample += sin(TAU * FREQUENCIES[note] * t) * 0.07 * exp(-beat * 8)
		if restored >= 5:
			sample += sin(TAU * 66 * t + sin(TAU * 39 * t)) * 0.06 * exp(-beat * 18)
		# Fade loop boundary to prevent discontinuities.
		sample *= minf(1.0, minf(t * 40, (8 - t) * 40))
		data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = length
	_music.stream = stream
	if not muted:
		_music.play()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		_music.stop()
	else:
		_music.play()
