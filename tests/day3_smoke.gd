extends SceneTree
## Run: Godot --headless --path . --script tests/day3_smoke.gd

const GameScene = preload("res://scenes/main/game.tscn")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")
const ProjectileScene = preload("res://scenes/weapons/light_projectile.tscn")

var _game
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _enemy(index: int, point: Vector2) -> EnemyScript:
	var enemy: EnemyScript = _game.spawner.ENEMY_SCENES[index].instantiate()
	enemy.target = _game.player
	enemy.position = point
	_game.spawner.enemy_container.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _clear_combat() -> void:
	for container in [_game.spawner.enemy_container, _game.get_node("World/ProjectileContainer"), _game.get_node("World/EffectContainer")]:
		for child in container.get_children():
			child.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_game = GameScene.instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.spawner.set_physics_process(false)
	_game.difficulty.set_physics_process(false)
	_game.player.get_node("WeaponPivot/Halo").enabled = false
	_game.player.get_node("WeaponPivot/FrostPulse").enabled = false
	var weapon = _game.player.get_node("WeaponPivot/LightOrb")
	var projectiles: Node2D = _game.get_node("World/ProjectileContainer")
	var effects: Node2D = _game.get_node("World/EffectContainer")
	weapon.set_physics_process(false)
	await process_frame
	var shots: Array = []
	weapon.shot_fired.connect(func(target: Node2D): shots.append(target.get_instance_id()))
	_check(weapon.find_target() == null and not weapon.fire(), "No target means no shot")
	_check(projectiles.get_child_count() == 0, "No idle projectile buildup")

	var far := _enemy(0, Vector2(400, 0))
	var near := _enemy(0, Vector2(160, 0))
	var outside := _enemy(0, Vector2(800, 0))
	_check(weapon.find_target() == near, "Nearest enemy chosen independently of insertion order")
	_check(weapon.fire(), "Weapon fires without aiming input")
	_check(shots.size() == 1 and shots[0] == near.get_instance_id(), "Shot signal identifies selected target")
	_check(projectiles.get_child_count() == 1, "One projectile created per shot")
	for frame in range(30):
		await physics_frame
	_check(near.current_health == 5.0, "Projectile removes exactly 15 HP from selected enemy")
	_check(far.current_health == 20.0 and outside.current_health == 20.0, "Other enemies remain unharmed")
	_check(projectiles.get_child_count() == 0, "Projectile removed after its first impact")
	_check(not near.take_damage(-5.0) and near.current_health == 5.0, "Negative enemy damage rejected")
	var deaths: Array = []
	near.enemy_died.connect(func(point: Vector2, xp: int): deaths.append({"point": point, "xp": xp}))
	_check(near.take_damage(100.0), "Lethal enemy damage accepted")
	_check(near.current_health == 0.0 and near.is_dead and not near.is_in_group("enemies"), "Dead enemy has zero HP and leaves targeting group immediately")
	_check(not near.take_damage(15.0) and deaths.size() == 1, "Repeated lethal hits cannot emit duplicate deaths")
	_check(deaths[0].point == Vector2(160, 0) and deaths[0].xp == 1, "Death event preserves world position and XP value for Day 4")
	_check(weapon.find_target() == far, "Targeting skips a dying enemy before deferred deletion")
	_check(effects.get_child_count() >= 2, "Lethal hit creates hit and death feedback")
	await process_frame
	_check(not is_instance_valid(near), "Dead enemy node freed")
	far.queue_free()
	_check(weapon.find_target() == null, "Queued enemies and targets outside range are ignored")
	for frame in range(75):
		await physics_frame
	_check(effects.get_child_count() == 0, "Burst effects clean themselves up")
	_clear_combat()

	var watcher := _enemy(2, Vector2(200, 0))
	watcher.take_damage(15.0)
	_check(watcher.current_health == 45.0 and watcher.sprite.modulate != Color.WHITE, "Nonlethal damage flashes the enemy")
	for frame in range(15):
		await physics_frame
	_check(watcher.sprite.modulate.is_equal_approx(Color.WHITE), "Hit flash returns to normal")
	_check(watcher.take_damage(15.0) and watcher.current_health == 30.0, "Separate valid shots can damage the same enemy")
	_clear_combat()

	# A swept collision must hit the first body even when one step crosses both.
	var first := _enemy(0, Vector2(100, 0))
	var second := _enemy(0, Vector2(200, 0))
	var fast = ProjectileScene.instantiate()
	fast.speed = 30000.0
	projectiles.add_child(fast)
	fast.position = Vector2.ZERO
	for frame in range(4):
		await physics_frame
	_check(first.current_health == 5.0, "Fast projectile cannot tunnel through the nearest enemy; HP=" + str(first.current_health))
	_check(second.current_health == 20.0, "One projectile does not damage a second enemy; HP=" + str(second.current_health))
	_check(not is_instance_valid(fast), "Fast impact removes the projectile")
	_clear_combat()
	var wall_shot = ProjectileScene.instantiate()
	wall_shot.speed = 10000.0
	projectiles.add_child(wall_shot)
	wall_shot.position = Vector2(2180, 0)
	for frame in range(4):
		await physics_frame
	_check(not is_instance_valid(wall_shot), "Arena border absorbs a projectile")
	var expired = ProjectileScene.instantiate()
	expired.speed = 0.0
	expired.lifetime = 0.05
	projectiles.add_child(expired)
	expired.position = Vector2(0, -500)
	for frame in range(8):
		await physics_frame
	_check(not is_instance_valid(expired), "Missed projectiles expire")

	# Exercise real cooldown, targeting, projectile hits, and death for every type.
	for index in range(3):
		_clear_combat()
		var enemy := _enemy(index, Vector2(200, 0))
		var name_before_death: String = enemy.display_name
		var expected_shots := ceili(enemy.max_health / weapon.damage)
		var before: int = shots.size()
		weapon._cooldown_left = 0.0
		weapon.set_physics_process(true)
		for frame in range(240):
			await physics_frame
			if not is_instance_valid(enemy):
				break
		weapon.set_physics_process(false)
		_check(not is_instance_valid(enemy), "Automatic attacks kill " + name_before_death)
		_check(shots.size() - before == expected_shots, "Expected shots and cooldown for " + name_before_death)
		_check(_game.player.current_health == 100.0, "Weapon cannot harm the player")
	_clear_combat()

	# Freeing a target in flight must leave no stale node reference or stray shot.
	var removed_target := _enemy(0, Vector2(300, 0))
	weapon.fire()
	removed_target.free()
	for frame in range(170):
		await physics_frame
	_check(projectiles.get_child_count() == 0, "Projectile survives target removal and then expires")
	_game.spawner.max_enemies = 1
	var casualty = _game.spawner.spawn_enemy()
	_check(casualty != null, "Spawner creates an enemy in the available slot")
	casualty.take_damage(1000.0)
	await process_frame
	var replacement = _game.spawner.spawn_enemy()
	_check(replacement != null, "Enemy death frees a spawn population slot")
	_clear_combat()

	# Death stops future fire and removes projectiles already in flight.
	_enemy(0, Vector2(300, 0))
	weapon.fire()
	_check(projectiles.get_child_count() == 1, "Shot exists before player death")
	_game.player.take_damage(1000.0)
	_check(not weapon.fire(), "Dead player cannot fire")
	await process_frame
	_check(projectiles.get_child_count() == 0, "Player death clears in-flight projectiles")
	_game.retry_button.pressed.emit()
	await scene_changed
	await process_frame
	_game = current_scene
	_game.spawner.set_physics_process(false)
	var new_weapon = _game.player.get_node("WeaponPivot/LightOrb")
	_check(new_weapon.enabled and new_weapon.is_physics_processing(), "Retry restores an active automatic weapon")
	_check(_game.get_node("World/ProjectileContainer").get_child_count() == 0 and _game.get_node("World/EffectContainer").get_child_count() == 0, "Retry removes old projectiles and effects")
	print("DAY 3: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
