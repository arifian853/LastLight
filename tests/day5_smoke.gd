extends SceneTree

const GameScene = preload("res://scenes/main/game.tscn")
const EnemyScript = preload("res://scripts/enemies/enemy_base.gd")
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


func _enemy(point: Vector2) -> EnemyScript:
	var enemy: EnemyScript = _game.spawner.ENEMY_SCENES[2].instantiate()
	enemy.position = point
	_game.spawner.enemy_container.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _clear_combat() -> void:
	for container in [_game.spawner.enemy_container, _game.get_node("World/EffectContainer"), _game.get_node("World/ProjectileContainer")]:
		for child in container.get_children():
			child.free()


func _choose(id: StringName) -> void:
	_game.experience.add_experience(_game.experience.required_experience() - _game.experience.experience)
	await process_frame
	var index: int = -1
	for attempt in range(60):
		for slot in range(_game.upgrades.current_offers.size()):
			if _game.upgrades.current_offers[slot].id == id:
				index = slot
		if index >= 0:
			break
		_game.upgrades.roll_choices()
	_check(index >= 0, "Upgrade can be offered: " + str(id))
	_game.upgrade_menu.show_choices(_game.upgrades.current_offers, _game.upgrades.ranks, _game.pending_levels[0])
	if index >= 0:
		_game.upgrade_menu.cards[index].pressed.emit()
	await process_frame
	_check(not paused, "Upgrade resumes gameplay: " + str(id))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_game = GameScene.instantiate()
	root.add_child(_game)
	current_scene = _game
	# Test the difficulty curve independently from the Day 6 boss/end triggers.
	_game.run_duration = INF
	_game.boss_spawn_time = INF
	_game.spawner.set_physics_process(false)
	_game.difficulty.set_physics_process(false)
	var orb = _game.player.get_node("WeaponPivot/LightOrb")
	var halo = _game.player.get_node("WeaponPivot/Halo")
	var frost = _game.player.get_node("WeaponPivot/FrostPulse")
	for weapon in [orb, halo, frost]:
		weapon.enabled = false
		weapon.set_physics_process(false)
	await process_frame
	_check(_game.upgrades.CATALOG.size() == 10, "Ten data-defined upgrades exist")
	var near := _enemy(Vector2(40, 0))
	var far := _enemy(Vector2(90, 0))
	halo.enabled = true
	_check(halo.damage_tick() == 1 and near.current_health == 54.0 and far.current_health == 60.0, "Halo damages enemies inside its radius only")
	halo._cooldown_left = halo.cooldown
	halo.set_physics_process(true)
	for frame in range(80):
		await physics_frame
	halo.set_physics_process(false)
	_check(near.current_health >= 36.0 and near.current_health <= 42.0, "Halo's automatic damage is timer-driven, not applied every frame")
	halo.enabled = false
	_clear_combat()
	near = _enemy(Vector2(100, 0))
	far = _enemy(Vector2(200, 0))
	frost.enabled = true
	_check(frost.trigger() == 1 and near.current_health == 48.0 and far.current_health == 60.0, "Frost Pulse damages only enemies within its radius")
	_check(near.slow_multiplier == 0.5, "Frost Pulse applies a fifty-percent slow")
	near.position = Vector2(500, 0)
	near.set_physics_process(true)
	for frame in range(4):
		await physics_frame
	_check(is_equal_approx(near.velocity.length(), 30.0), "Slow affects actual chase speed")
	near.apply_slow(0.5, 1.5)
	_check(near.slow_multiplier == 0.5, "Repeated slows refresh without multiplying")
	for frame in range(100):
		await physics_frame
	_check(near.slow_multiplier == 1.0 and is_equal_approx(near.velocity.length(), 60.0), "Slow expires and restores original speed")
	_check(near.sprite.self_modulate == Color.WHITE, "Slow tint clears on expiry")
	_check(_game.get_node("World/EffectContainer").get_child_count() == 0, "Pulse and hit effects clean up")
	_clear_combat()
	near = _enemy(Vector2(120, 0))
	frost.damage = 1.0
	frost.cooldown = 0.2
	frost._cooldown_left = 0.2
	frost.set_physics_process(true)
	for frame in range(35):
		await physics_frame
	frost.set_physics_process(false)
	_check(near.current_health >= 57.0 and near.current_health <= 58.0 and near.slow_multiplier == 0.5, "Frost Pulse automatically repeats on cooldown")
	frost.damage = 12.0
	frost.cooldown = 4.0
	frost.enabled = false
	_clear_combat()

	# Slow duration, weapon cooldown, and difficulty clock all freeze for choices.
	near = _enemy(Vector2(500, 0))
	near.apply_slow(0.5, 1.5)
	near.set_physics_process(true)
	_game.difficulty.set_physics_process(true)
	_game.experience.add_experience(6)
	await process_frame
	var slow_before: float = near._slow_remaining
	var clock_before: float = _game.difficulty.elapsed_time
	var cooldown_before: float = frost._cooldown_left
	for frame in range(20):
		await physics_frame
	_check(near._slow_remaining == slow_before and _game.difficulty.elapsed_time == clock_before and frost._cooldown_left == cooldown_before, "Upgrade pause freezes slow, cooldown, and survival time")
	halo.enabled = true
	frost.enabled = true
	orb.enabled = true
	_check(halo.damage_tick() == 0 and frost.trigger() == 0 and not orb.fire(), "Weapons cannot fire during upgrade selection")
	_game.upgrade_menu.cards[0].pressed.emit()
	await process_frame
	_game.difficulty.set_physics_process(false)
	_game.difficulty.set_elapsed_time(0.0)
	for weapon in [orb, halo, frost]:
		weapon.enabled = false
	_clear_combat()

	# Both area weapons use the ordinary death/drop/XP path.
	var xp_before: int = _game.experience.experience
	var victim = _game.spawner.spawn_enemy(0)
	victim.position = Vector2(40, 0)
	victim.set_physics_process(false)
	halo.enabled = true
	var halo_damage: float = halo.damage
	halo.damage = 1000.0
	halo.damage_tick()
	halo.damage = halo_damage
	halo.enabled = false
	victim = _game.spawner.spawn_enemy(2)
	victim.position = Vector2(90, 0)
	victim.set_physics_process(false)
	frost.enabled = true
	var frost_damage: float = frost.damage
	frost.damage = 1000.0
	frost.trigger()
	frost.damage = frost_damage
	frost.enabled = false
	for frame in range(60):
		await physics_frame
	_check(_game.experience.experience == xp_before + 4, "Halo and Frost kills grant the correct collected XP")
	_clear_combat()

	# Apply each new upgrade through the selection UI.
	for upgrade in _game.upgrades.CATALOG.slice(5):
		var before: Array = [halo.damage, halo.radius, frost.damage, frost.radius, orb.projectile_count]
		await _choose(upgrade.id)
		match upgrade.upgrade_type:
			5: _check(is_equal_approx(halo.damage, before[0] * 1.2), "Searing Halo increases damage")
			6: _check(is_equal_approx(halo.radius, before[1] * 1.2), "Winter Crown increases radius")
			7: _check(is_equal_approx(frost.damage, before[2] * 1.2), "Deep Freeze increases damage")
			8: _check(is_equal_approx(frost.radius, before[3] * 1.2), "Frozen Horizon increases radius")
			9: _check(orb.projectile_count == before[4] + 1, "Twin Flame adds a projectile")
	var cooldowns: Array = [orb.cooldown, halo.cooldown, frost.cooldown]
	await _choose(&"quickening")
	_check(is_equal_approx(orb.cooldown, cooldowns[0] / 1.15) and is_equal_approx(halo.cooldown, cooldowns[1] / 1.15) and is_equal_approx(frost.cooldown, cooldowns[2] / 1.15), "Quickening affects all three weapons")
	while int(_game.upgrades.ranks.get(&"twin_flame", 0)) < 3:
		await _choose(&"twin_flame")
	_check(orb.projectile_count == 4, "Twin Flame caps at four total projectiles")
	var target := _enemy(Vector2(300, 0))
	target.current_health = 1000.0
	orb.enabled = true
	orb.fire()
	_check(_game.get_node("World/ProjectileContainer").get_child_count() == 4, "A volley creates four projectiles")
	for frame in range(50):
		await physics_frame
	_check(is_equal_approx(target.current_health, 1000.0 - orb.damage * 4.0), "All volley lanes can hit an isolated target")
	orb.enabled = false
	_clear_combat()

	# Deterministic checkpoints test the complete ten-minute difficulty curve.
	var previous_interval: float = 100.0
	var previous_cap: int = 0
	for seconds in [0.0, 119.0, 120.0, 239.0, 240.0, 360.0, 480.0, 600.0, 1000.0]:
		_game.difficulty.set_elapsed_time(seconds)
		var spawner = _game.spawner
		_check(spawner.spawn_interval <= previous_interval and spawner.max_enemies >= previous_cap, "Spawn pressure rises monotonically at " + str(seconds))
		previous_interval = spawner.spawn_interval
		previous_cap = spawner.max_enemies
		spawner._rng.seed = 5512
		var variants: Dictionary = {}
		for sample in range(300):
			variants[spawner._choose_variant()] = true
		var expected_types: int = 1 if seconds < 120.0 else (2 if seconds < 240.0 else 3)
		_check(variants.size() == expected_types, "Enemy composition follows its stage at " + str(seconds))
		for index in range(3):
			var enemy = spawner.spawn_enemy(index)
			_check(enemy != null, "A scaled enemy can spawn")
			var base_hp: float = [20.0, 12.0, 60.0][index]
			var base_speed: float = [90.0, 150.0, 60.0][index]
			var base_damage: float = [10.0, 7.0, 20.0][index]
			_check(is_equal_approx(enemy.current_health, base_hp * spawner.health_multiplier) and is_equal_approx(enemy.movement_speed, base_speed * spawner.speed_multiplier) and is_equal_approx(enemy.contact_damage, base_damage * spawner.damage_multiplier), "New enemy receives the current stage's stats")
			enemy.free()
	_check(is_equal_approx(_game.spawner.spawn_interval, 0.32) and _game.spawner.max_enemies == 150, "Late-run pressure remains bounded")
	_game.difficulty.set_elapsed_time(600.0)
	_check(_game.get_node("HUD/Layout/SurvivalTimer").text == "10:00" and _game.get_node("HUD/Layout/PressureLabel").text == "LAST LIGHT", "HUD shows survival time and pressure stage")
	_game.difficulty.set_elapsed_time(0.0)
	var existing = _game.spawner.spawn_enemy(0)
	existing.take_damage(5.0)
	_game.difficulty.set_elapsed_time(600.0)
	_check(existing.current_health == 15.0, "Difficulty changes do not heal or rescale existing enemies")
	_clear_combat()

	_game.difficulty.set_physics_process(true)
	_game.player.take_damage(10000.0)
	var death_time: float = _game.difficulty.elapsed_time
	for frame in range(20):
		await physics_frame
	_check(_game.difficulty.elapsed_time == death_time, "Survival time stops on death")
	halo.enabled = true
	frost.enabled = true
	_check(halo.damage_tick() == 0 and frost.trigger() == 0, "Area weapons cannot attack after player death")
	_game.retry_button.pressed.emit()
	await scene_changed
	await process_frame
	_game = current_scene
	_check(_game.difficulty.elapsed_time < 0.1 and _game.spawner.enemy_weights == Vector3(1, 0, 0), "Retry restores the opening difficulty stage")
	_check(_game.player.get_node("WeaponPivot/Halo").damage == 6.0 and _game.player.get_node("WeaponPivot/FrostPulse").damage == 12.0 and _game.player.get_node("WeaponPivot/LightOrb").projectile_count == 1, "Retry restores base weapon stats")
	print("DAY 5: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
