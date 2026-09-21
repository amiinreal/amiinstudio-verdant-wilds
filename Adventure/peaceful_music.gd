extends AudioStreamPlayer
var level: float=0.45
func _ready() -> void:
	stream=load("res://Adventure/generated/PeacefulWoodland.wav").duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0; stream.loop_end=int(stream.get_length()*stream.mix_rate)
	var config: ConfigFile=ConfigFile.new()
	if config.load("user://woodland_audio.cfg")==OK: level=clampf(float(config.get_value("audio","music",0.45)),0,1)
	set_level(level,false); play()

func set_level(value: float, save: bool=true) -> void:
	level=clampf(value,0,1); volume_db=linear_to_db(maxf(level,0.00001))-12
	stream_paused=level==0
	if save:
		var config: ConfigFile=ConfigFile.new(); config.set_value("audio","music",level); config.save("user://woodland_audio.cfg")
