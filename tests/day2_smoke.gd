extends SceneTree
## Run: Godot --headless --path . --script tests/day2_smoke.gd

const GameScene = preload("res://scenes/main/game.tscn")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _clear_enemies(container: Node) -> void:
	for enemy in container.get_children():
		enemy.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = GameScene.instantiate()
	root.add_child(game)
	current_scene = game
	var player = game.player
	# Isolate contact/spawning checks from the Day 3 automatic weapon.
	player.get_node("WeaponPivot/LightOrb").enabled = false
	player.get_node("WeaponPivot/Halo").enabled = false
	player.get_node("WeaponPivot/FrostPulse").enabled = false
	game.difficulty.set_physics_process(false)
	var spawner = game.spawner
	var camera: Camera2D = player.get_node("Camera2D")
	spawner.set_physics_process(false)
	await process_frame
	_check(player.current_health == 100.0 and not player.is_dead, "Fresh player has 100 HP")

	# Camera-edge spawning, including corners, camera lag, and changed zoom.
	var variants: Dictionary = {}
	for point in [Vector2.ZERO, Vector2(2100, 1500), Vector2(-2100, -1500), Vector2(2100, -1500), Vector2(-2100, 1500)]:
		player.position = point
		camera.reset_smoothing()
		camera.force_update_scroll()
		await process_frame
		for index in range(9):
			var enemy = spawner.spawn_enemy(index % 3)
			_check(enemy != null, "Spawn candidate exists at " + str(point))
			if enemy != null:
				variants[enemy.display_name] = true
				_check(not spawner.visible_world_rect().grow(70.0).has_point(enemy.global_position), "Enemy spawns fully outside camera")
				_check(absf(enemy.position.x) <= 2172.1 and absf(enemy.position.y) <= 1572.1, "Enemy spawns inside arena")
		_clear_enemies(spawner.enemy_container)
	_check(variants.size() == 3, "All three variants spawn")
	player.position = Vector2.ZERO
	camera.zoom = Vector2(0.8, 0.8)
	camera.reset_smoothing()
	camera.force_update_scroll()
	await process_frame
	var zoom_enemy = spawner.spawn_enemy()
	_check(zoom_enemy != null and not spawner.visible_world_rect().grow(70.0).has_point(zoom_enemy.global_position), "Zoomed-out camera spawn stays offscreen")
	_clear_enemies(spawner.enemy_container)
	camera.zoom = Vector2(0.1, 0.1)
	camera.force_update_scroll()
	await process_frame
	_check(spawner.spawn_enemy() == null, "Skip spawning if the camera covers the entire arena")
	camera.zoom = Vector2.ONE
	camera.reset_smoothing()
	camera.force_update_scroll()
	await process_frame
	spawner.max_enemies = 3
	for index in range(3):
		spawner.spawn_enemy()
	_check(spawner.enemy_container.get_child_count() == 3 and spawner.spawn_enemy() == null, "Population cap enforced")
	_clear_enemies(spawner.enemy_container)
	spawner.max_enemies = 45
	spawner.spawn_interval = 0.1
	spawner.set_physics_process(true)
	for frame in range(30):
		await physics_frame
	spawner.set_physics_process(false)
	_check(spawner.enemy_container.get_child_count() >= 3, "Timer spawns enemies automatically")
	var timed_variants: Dictionary = {}
	for enemy in spawner.enemy_container.get_children():
		timed_variants[enemy.display_name] = true
	_check(timed_variants.size() == 1 and timed_variants.has("Wraith"), "Automatic spawning follows the early-run composition")
	_clear_enemies(spawner.enemy_container)
	spawner.spawn_interval = 2.4

	# Each variant actually chases and deals its configured contact damage.
	for packed in spawner.ENEMY_SCENES:
		player.position = Vector2.ZERO
		player.current_health = player.max_health
		player._invulnerability_left = 0.0
		var enemy: EnemyScript = packed.instantiate()
		enemy.target = player
		spawner.enemy_container.add_child(enemy)
		enemy.position = Vector2(200, 0)
		for frame in range(20):
			await physics_frame
		_check(enemy.position.x < 190.0 and is_equal_approx(enemy.velocity.length(), enemy.movement_speed), enemy.display_name + " chases at configured speed")
		_check(player.current_health == player.max_health, "Distant enemies cannot damage the player")
		enemy.position = Vector2(25, 0)
		for frame in range(6):
			await physics_frame
		_check(is_equal_approx(player.current_health, player.max_health - enemy.contact_damage), enemy.display_name + " contact damage applied once during invulnerability")
		_check(not player.take_damage(20.0), "Immediate second hit rejected")
		var hp_after_hit: float = player.current_health
		for frame in range(54):
			await physics_frame
		_check(player.current_health < hp_after_hit, "Ongoing contact damages again after protection expires")
		_check(enemy.is_on_wall() and enemy.position.distance_to(player.position) >= 21.0, "Enemy and player bodies collide without overlapping")
		enemy.free()

	# Death must be terminal and stop both spawning and enemy movement.
	player.current_health = 10.0
	player._invulnerability_left = 0.0
	var observer = spawner.spawn_enemy()
	_check(observer != null, "Enemy exists before death")
	_check(not player.take_damage(-10.0), "Negative damage cannot heal the player")
	_check(player.take_damage(1000.0), "Lethal damage accepted")
	_check(player.current_health == 0.0 and player.is_dead, "Health clamps to zero and player dies")
	_check(game.state == game.State.GAME_OVER and game.death_overlay.visible, "Game-over state and retry UI shown")
	_check(not spawner.enabled and spawner.spawn_enemy() == null, "Spawning stops on death")
	_check(observer != null and not observer.is_physics_processing(), "Enemy movement stops on death")
	_check(not player.take_damage(10.0), "Dead player cannot take more damage")
	var death_position: Vector2 = player.position
	Input.action_press("move_right")
	for frame in range(6):
		await physics_frame
	Input.action_release("move_right")
	_check(player.position == death_position and player.velocity == Vector2.ZERO, "Dead player cannot move")
	_check(game.health_bar.value == 0.0, "Health display reflects lethal hit")

	# Exercise the real retry button and scene reload, rather than resetting fields.
	game.retry_button.pressed.emit()
	await scene_changed
	await process_frame
	var restarted = current_scene
	restarted.spawner.set_physics_process(false)
	_check(restarted != game, "Retry replaces the old scene")
	_check(restarted.state == restarted.State.PLAYING and restarted.player.current_health == 100.0 and not restarted.player.is_dead, "Retry restores a living player and playing state")
	_check(restarted.spawner.enabled and restarted.spawner.enemy_container.get_child_count() == 0 and not restarted.death_overlay.visible, "Retry resets enemies, spawning, and overlay")
	print("DAY 2: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
