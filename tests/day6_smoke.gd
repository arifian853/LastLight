extends SceneTree

const MenuScene = preload("res://scenes/main/main_menu.tscn")
const BulletScene = preload("res://scenes/weapons/enemy_projectile.tscn")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _isolate(game: Node) -> void:
	game.spawner.set_physics_process(false)
	game.difficulty.set_physics_process(false)
	for weapon in game.player.get_node("WeaponPivot").get_children():
		weapon.enabled = false


func _clear_bullets(game: Node) -> void:
	for bullet in game.get_node("World/EnemyProjectileContainer").get_children():
		bullet.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var menu = MenuScene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	_check(menu.get_node("Left/Start").has_focus(), "Main menu defaults to Start Run")
	var session = root.get_node("RunState")
	menu.get_node("Left/Volume").value = 0.37
	_check(is_equal_approx(session.master_volume, 0.37) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.37), "Volume slider controls master audio and persists its preference")
	var audio = menu.get_node("Audio")
	_check(audio.voices.size() == 8 and audio.CUES.size() == 12, "Audio has a bounded voice pool and all twelve effect cues")
	_check(audio.music.playing and audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and audio.music.stream.get_length() >= 19.9, "Ambient music plays as a twenty-second loop")
	for cue in audio.CUES:
		_check(audio.CUES[cue].get_length() > 0.0, "Audio cue loads: " + str(cue))
	menu.get_node("Left/Start").pressed.emit()
	menu.get_node("Left/Start").pressed.emit()
	await scene_changed
	await process_frame
	var game = current_scene
	_isolate(game)
	_check(game.name == &"Game" and game.state == game.State.PLAYING, "Start Run transitions to a playable run exactly once")
	_check(not game.boss_spawned and game.kills == 0 and not game.player.run_finished, "Fresh run has no boss, kills, or terminal state")
	var enemy = game.spawner.spawn_enemy(0)
	enemy.position = Vector2(300, 0)
	game.difficulty.set_physics_process(true)
	await _escape()
	_check(paused and game.state == game.State.PAUSED and game.pause_menu.visible, "Escape opens pause menu")
	var before: Vector2 = enemy.position
	var time_before: float = game.difficulty.elapsed_time
	Input.action_press("move_right")
	for frame in range(12):
		await physics_frame
	Input.action_release("move_right")
	_check(enemy.position == before and game.difficulty.elapsed_time == time_before, "Pause freezes enemies and survival clock")
	_check(game.pause_menu.can_process() and game.get_node("Audio").can_process(), "Pause controls and audio remain responsive")
	game.pause_menu.get_node("Center/Content/Volume").value = 0.0
	_check(AudioServer.is_bus_mute(0), "Zero master volume mutes audio")
	game.pause_menu.get_node("Center/Content/Volume").value = 0.37
	_check(not AudioServer.is_bus_mute(0), "Raising volume unmutes audio")
	game.pause_menu.get_node("Center/Content/Resume").pressed.emit()
	await process_frame
	_check(not paused and game.state == game.State.PLAYING, "Resume button restores gameplay")
	await _escape()
	await _escape()
	_check(not paused and not game.pause_menu.visible, "Escape toggles pause and resume")
	game.difficulty.set_physics_process(false)
	enemy.free()

	game.difficulty.set_elapsed_time(479.0)
	_check(not game.boss_spawned, "Boss does not appear before minute eight")
	game.spawner.max_enemies = 0
	game.difficulty.set_elapsed_time(480.0)
	var boss = game.boss
	_check(game.boss_spawned and is_instance_valid(boss), "Boss appears at minute eight")
	_check(boss.max_health == 2000.0 and boss.current_health == 2000.0 and boss.movement_speed == 45.0, "Boss uses fixed authored stats")
	_check(not game.spawner.visible_world_rect().grow(170.0).has_point(boss.global_position), "Large boss starts fully outside the camera")
	_check(game.get_node("HUD/Layout/BossPanel").visible and game.get_node("HUD/Layout/BossNotice").visible, "Boss arrival and health UI appear")
	game.difficulty.set_elapsed_time(481.0)
	_check(game.spawner.enemy_container.get_child_count() == 1, "Boss spawns only once")
	boss.position = Vector2(0, -220)
	boss._attack_left = 0.02
	boss._warning_left = 0.0
	for frame in range(4):
		await physics_frame
	_check(boss._warning_left > 0.0 and game.get_node("World/EnemyProjectileContainer").get_child_count() == 0, "Radial attack is telegraphed before firing")
	for frame in range(60):
		await physics_frame
	boss.set_physics_process(false)
	var bullets: Node2D = game.get_node("World/EnemyProjectileContainer")
	_check(bullets.get_child_count() == 12, "Boss fires twelve radial projectiles")
	var directions: Array = []
	for bullet in bullets.get_children():
		directions.append(bullet.direction.angle())
		directions.sort()
	for index in range(1, directions.size()):
		_check(is_equal_approx(directions[index] - directions[index - 1], TAU / 12.0), "Radial directions are evenly spaced")
	boss.take_damage(100.0)
	_check(game.get_node("HUD/Layout/BossPanel/Health").value == 1900.0, "Boss health bar tracks damage")
	_clear_bullets(game)

	# Hostile bullets use swept collision against the player and the arena.
	game.player._invulnerability_left = 0.0
	game.player.current_health = 100.0
	var bullet = BulletScene.instantiate()
	bullet.position = Vector2(100, 0)
	bullet.direction = Vector2.LEFT
	bullet.speed = 30000.0
	bullets.add_child(bullet)
	for frame in range(4):
		await physics_frame
	_check(game.player.current_health == 88.0 and not is_instance_valid(bullet), "Fast hostile bullet hits player once and disappears")
	bullet = BulletScene.instantiate()
	bullet.position = Vector2(80, 0)
	bullet.direction = Vector2.LEFT
	bullet.speed = 30000.0
	bullets.add_child(bullet)
	for frame in range(4):
		await physics_frame
	_check(game.player.current_health == 88.0, "Player invulnerability protects against a simultaneous barrage")
	bullet = BulletScene.instantiate()
	bullet.position = Vector2(2180, 0)
	bullet.speed = 10000.0
	bullets.add_child(bullet)
	for frame in range(4):
		await physics_frame
	_check(not is_instance_valid(bullet), "Arena walls absorb hostile bullets")
	bullet = BulletScene.instantiate()
	bullet.position = Vector2(700, 700)
	bullet.speed = 0.0
	bullet.lifetime = 0.05
	bullets.add_child(bullet)
	for frame in range(8):
		await physics_frame
	_check(not is_instance_valid(bullet), "Hostile bullets expire")
	boss.fire_radial()
	boss.take_damage(10000.0)
	await process_frame
	_check(game.boss_defeated and not game.get_node("HUD/Layout/BossPanel").visible and bullets.get_child_count() == 0, "Boss death clears projectiles and its health UI")
	_check(game.kills == 1, "Boss death counts exactly one kill")
	game.difficulty.set_elapsed_time(500.0)
	_check(game.boss_spawned and game.spawner.enemy_container.get_child_count() == 0, "Defeated boss never respawns")

	game.experience.add_experience(6)
	await process_frame
	await _escape()
	_check(game.state == game.State.LEVEL_UP and paused and not game.pause_menu.visible, "Escape cannot dismiss mandatory upgrade selection")
	game.upgrade_menu.cards[0].pressed.emit()
	await process_frame
	game.difficulty.set_elapsed_time(600.0)
	_check(game.state == game.State.VICTORY and game.death_overlay.visible and not game.player.is_dead, "Surviving until dawn shows victory")
	_check(game.player.run_finished and not game.spawner.enabled and not game.experience.enabled, "Victory terminates spawning and progression")
	_check(game.death_overlay.get_node("Center/Content/Heading").text == "DAWN HAS RETURNED" and game.death_overlay.get_node("Center/Content/Stats").text.contains("10:00"), "Victory result displays its heading and time")
	_check(session.last_run_result == "victory" and session.last_run_time == 600.0 and session.last_run_kills == 1 and session.boss_defeated, "Result statistics persist across scenes")
	_check(not game.player.take_damage(1000.0), "Dawn victory cannot be overwritten by late damage")
	game._finish_run(false)
	_check(game.state == game.State.VICTORY and session.last_run_result == "victory", "Terminal result is committed once")
	game.death_overlay.get_node("Center/Content/MainMenu").pressed.emit()
	await scene_changed
	await process_frame
	menu = current_scene
	_check(menu.name == &"MainMenu" and not paused and menu.get_node("Left/LastRun").text.contains("10:00"), "Result returns to main menu with last-run summary")
	_check(is_equal_approx(menu.get_node("Left/Volume").value, 0.37), "Audio preference survives result/menu transitions")
	menu.get_node("Left/Start").pressed.emit()
	await scene_changed
	await process_frame
	game = current_scene
	_isolate(game)
	game.difficulty.set_elapsed_time(37.0)
	game.player.take_damage(1000.0)
	_check(game.state == game.State.GAME_OVER and game.death_overlay.get_node("Center/Content/Heading").text == "THE LIGHT HAS FADED", "Death shows the loss result")
	_check(session.last_run_result == "death" and session.last_run_time == 37.0 and not session.boss_defeated, "Death replaces the last result with this run's statistics")
	game.retry_button.pressed.emit()
	await scene_changed
	await process_frame
	game = current_scene
	_isolate(game)
	_check(game.state == game.State.PLAYING and game.player.current_health == 100.0 and not game.player.run_finished and not game.boss_spawned, "Play Again starts a clean run")
	await _escape()
	game.pause_menu.get_node("Center/Content/MainMenu").pressed.emit()
	await scene_changed
	await process_frame
	_check(current_scene.name == &"MainMenu" and not paused and session.last_run_result == "death", "Leaving a paused run releases pause and preserves the previous result")
	current_scene.get_node("Left/Start").pressed.emit()
	await scene_changed
	await process_frame
	game = current_scene
	_isolate(game)
	game.difficulty.set_elapsed_time(599.0)
	_check(game.boss_spawned and not game.boss_defeated, "Final minute can contain a living boss")
	game.difficulty.set_elapsed_time(600.0)
	_check(game.state == game.State.VICTORY and not game.boss_defeated, "Boss defeat is optional for dawn victory")
	print("DAY 6: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	# Let the audio mixing thread release its stopped playback references.
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
