extends Node
## A small voice pool and cue throttling keep large crowds from flooding audio.

const CUES: Dictionary = {
	&"projectile": preload("res://assets/audio/projectile.wav"),
	&"hit": preload("res://assets/audio/hit.wav"),
	&"enemy_death": preload("res://assets/audio/enemy_death.wav"),
	&"pickup": preload("res://assets/audio/pickup.wav"),
	&"level_up": preload("res://assets/audio/level_up.wav"),
	&"player_damage": preload("res://assets/audio/player_damage.wav"),
	&"boss_arrival": preload("res://assets/audio/boss_arrival.wav"),
	&"boss_shot": preload("res://assets/audio/boss_shot.wav"),
	&"victory": preload("res://assets/audio/victory.wav"),
	&"death": preload("res://assets/audio/death.wav"),
	&"ui_select": preload("res://assets/audio/ui_select.wav"),
	&"pulse": preload("res://assets/audio/pulse.wav"),
}
const VOLUMES: Dictionary = {&"projectile": -24.0, &"hit": -26.0, &"enemy_death": -24.0, &"pickup": -21.0, &"level_up": -12.0, &"player_damage": -14.0, &"boss_arrival": -10.0, &"boss_shot": -16.0, &"victory": -9.0, &"death": -12.0, &"ui_select": -15.0, &"pulse": -22.0}
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var _last_played: Dictionary = {}
var _voice_index: int = 0
var _closing: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_close_requested)
	_rng.randomize()
	for index in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	var stream := preload("res://assets/audio/winter_ambience.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.volume_db = -21.0
	add_child(music)
	var run_state := get_node_or_null("/root/RunState")
	set_master_volume(run_state.master_volume if run_state != null else 0.65)
	music.play()


func set_master_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.master_volume = volume


func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null


func _on_close_requested() -> void:
	if _closing:
		return
	_closing = true
	stop_all()
	await get_tree().create_timer(0.12, true).timeout
	get_tree().quit()


func play_sound(cue: StringName) -> void:
	if not CUES.has(cue) or voices.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -1000)) < 70:
		return
	_last_played[cue] = now
	var voice := voices[_voice_index]
	_voice_index = (_voice_index + 1) % voices.size()
	voice.stream = CUES[cue]
	voice.volume_db = VOLUMES[cue]
	voice.pitch_scale = _rng.randf_range(0.97, 1.03)
	voice.play()
