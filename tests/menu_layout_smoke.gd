extends SceneTree
## Run against the embedded export with --main-pack, not only the source scene.
## Optional rendered evidence: -- --capture-dir=<absolute directory>

const GameScene = preload("res://scenes/main/game.tscn")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("FAIL: " + description)


func _verify(panel: Control, description: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var content: Control = panel.get_node("Center/Content")
	var rect := content.get_global_rect()
	print(description, " viewport=", viewport, " panel=", panel.get_global_rect(), " content=", rect)
	_check(rect.get_center().distance_to(viewport.get_center()) <= 2.0, description + " centered")
	_check(viewport.grow(1.0).encloses(rect), description + " content fully visible")
	_check(panel.get_node("Shade").get_global_rect().is_equal_approx(viewport), description + " shade covers viewport")


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _capture(name: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			var directory := argument.trim_prefix("--capture-dir=")
			var result := root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
			_check(result == OK, "Rendered " + name + " screenshot saved")


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1280, 720)
	var game = GameScene.instantiate()
	root.add_child(game)
	current_scene = game
	game.spawner.set_physics_process(false)
	game.difficulty.set_physics_process(false)
	for weapon in game.player.get_node("WeaponPivot").get_children():
		weapon.enabled = false
	await _settle()
	for size in [Vector2i(1280, 720), Vector2i(1918, 991), Vector2i(1024, 768), Vector2i(960, 540), Vector2i(2560, 1080), Vector2i(1280, 720)]:
		root.size = size
		await _settle()
		game._toggle_pause()
		await _settle()
		_verify(game.pause_menu, "Pause " + str(size))
		if size == Vector2i(1918, 991):
			await _capture("packed-pause")
		# Resize while the game is paused, as with maximize/restore.
		root.size = Vector2i(size.x - 80, size.y - 60)
		await _settle()
		_verify(game.pause_menu, "Paused resize " + str(size))
		game._toggle_pause()
		root.size = size
		await _settle()
		game.experience.add_experience(game.experience.required_experience() - game.experience.experience)
		await _settle()
		_verify(game.upgrade_menu, "Upgrade " + str(size))
		if size == Vector2i(1918, 991):
			await _capture("packed-upgrade")
		root.size = Vector2i(size.x - 80, size.y - 60)
		await _settle()
		_verify(game.upgrade_menu, "Upgrade resize " + str(size))
		for card in game.upgrade_menu.cards:
			_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1.0).encloses(card.get_global_rect()), "Upgrade card fits")
		game.upgrade_menu.cards[0].pressed.emit()
		await _settle()
	game.player._invulnerability_left = 0.0
	game.player.take_damage(10000.0)
	await _settle()
	_verify(game.death_overlay, "Results")
	print("MENU LAYOUT: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
