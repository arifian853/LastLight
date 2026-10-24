extends Control

var _changing_scene: bool = false
var _fade_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	$Left/Start.pressed.connect(_start_run)
	$Credits.pressed.connect(_show_credits)
	$Left/Quit.pressed.connect(_quit)
	$Left/Start.grab_focus()
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		$Left/Volume.value = run_state.master_volume
		if not run_state.last_run_result.is_empty():
			var seconds: int = int(run_state.last_run_time)
			$Left/LastRun.text = "Last run: %02d:%02d  /  %d shadows banished" % [floori(float(seconds) / 60.0), seconds % 60, run_state.last_run_kills]
	$Left/Volume.value_changed.connect(func(value: float): get_tree().call_group("game_audio", "set_master_volume", value))
	_fade_tween = create_tween()
	_fade_tween.tween_property($Fade, "color:a", 0.0, 0.4)


func _start_run() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	$Left/Start.disabled = true
	get_tree().call_group("game_audio", "play_sound", &"ui_select")
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property($Fade, "color:a", 1.0, 0.25)
	await _fade_tween.finished
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _quit() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	$Left/Start.disabled = true
	$Left/Quit.disabled = true
	get_tree().call_group("game_audio", "stop_all")
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()


func _show_credits() -> void:
	var text := "LAST LIGHT\nMade with Godot Engine 4.7.2.\n\n"
	for path in ["res://licenses/GODOT_LICENSE.txt", "res://licenses/GODOT_COPYRIGHT.txt"]:
		text += FileAccess.get_file_as_string(path) + "\n\n"
	$CreditsDialog/Text.text = text
	$CreditsDialog.popup_centered(Vector2i(760, 480))
