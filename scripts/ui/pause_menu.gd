extends Control

signal pause_requested
signal menu_requested


func _ready() -> void:
	$Center/Content/Resume.pressed.connect(func(): pause_requested.emit())
	$Center/Content/MainMenu.pressed.connect(func(): menu_requested.emit())
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		$Center/Content/Volume.value = run_state.master_volume
	$Center/Content/Volume.value_changed.connect(func(value: float): get_tree().call_group("game_audio", "set_master_volume", value))


func open() -> void:
	show()
	$Center/Content/Resume.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		pause_requested.emit()
