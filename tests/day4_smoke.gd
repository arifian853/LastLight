extends SceneTree
## Run: Godot --headless --path . --script tests/day4_smoke.gd

const GameScene = preload("res://scenes/main/game.tscn")
const ProjectileScene = preload("res://scenes/weapons/light_projectile.tscn")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _rank_count(ranks: Dictionary) -> int:
	var total: int = 0
	for value in ranks.values():
		total += int(value)
	return total


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = GameScene.instantiate()
	root.add_child(game)
	current_scene = game
	game.spawner.set_physics_process(false)
	game.difficulty.set_physics_process(false)
	game.player.get_node("WeaponPivot/Halo").enabled = false
	game.player.get_node("WeaponPivot/FrostPulse").enabled = false
	var weapon = game.player.get_node("WeaponPivot/LightOrb")
	weapon.enabled = false
	var pickups: Node2D = game.get_node("World/PickupContainer")
	var projectiles: Node2D = game.get_node("World/ProjectileContainer")
	await process_frame
	_check(game.experience.level == 1 and game.experience.experience == 0 and game.experience.required_experience() == 6, "Fresh run starts at level 1 with a six-XP threshold")
	game.experience.add_experience(-1)
	game.experience.add_experience(0)
	_check(game.experience.experience == 0, "Nonpositive XP ignored")

	# Kill actual spawned enemies so the production death/drop signal is tested.
	for index in range(3):
		var enemy = game.spawner.spawn_enemy(index)
		enemy.set_physics_process(false)
		enemy.position = Vector2(420 + 30 * index, 0)
		enemy.take_damage(1000.0)
		_check(not enemy.take_damage(1000.0), "Repeated death cannot award another shard")
		await process_frame
		_check(pickups.get_child_count() == index + 1, "Exactly one shard drops per enemy")
		var shard = pickups.get_child(index)
		_check(shard.position == Vector2(420 + 30 * index, 0), "Shard spawns at the enemy's death position")
	_check(game.experience.experience == 0, "Drops outside pickup radius do not grant XP")
	var values: Array = []
	for shard in pickups.get_children():
		values.append(shard.experience_value)
	values.sort()
	_check(values == [1, 1, 3], "Wraith/Crawler drop one XP and Watcher drops three")
	for shard in pickups.get_children():
		shard.position = Vector2(65, 0)
	for frame in range(60):
		await physics_frame
	_check(pickups.get_child_count() == 0 and game.experience.experience == 5, "Pickup area attracts shards, grants XP once, and removes them")
	_check(game.get_node("HUD/Layout/ExperienceBar").value == 5, "XP bar follows collected XP")

	# Verify real gameplay freezes while the menu remains interactive.
	var observer = game.spawner.spawn_enemy()
	observer.position = Vector2(300, 0)
	var shot = ProjectileScene.instantiate()
	shot.position = Vector2(-300, -200)
	projectiles.add_child(shot)
	game.spawner.set_physics_process(true)
	game.experience.add_experience(1)
	await process_frame
	_check(paused and game.state == game.State.LEVEL_UP and game.upgrade_menu.visible, "Crossing the threshold pauses gameplay and opens the upgrade menu")
	_check(game.experience.level == 2 and game.experience.experience == 0 and game.experience.required_experience() == 8, "Level advances and next threshold grows")
	_check(game.upgrades.current_offers.size() == 3 and game.upgrade_menu.cards.size() == 3, "Exactly three upgrade cards appear")
	var ids: Dictionary = {}
	for offer in game.upgrades.current_offers:
		ids[offer.id] = true
	_check(ids.size() == 3 and game.upgrades.CATALOG.size() >= 5, "Offers are unique and the initial upgrades remain available")
	var player_point: Vector2 = game.player.position
	var enemy_point: Vector2 = observer.position
	var shot_point: Vector2 = shot.position
	var spawn_elapsed: float = game.spawner._elapsed
	Input.action_press("move_right")
	for frame in range(12):
		await physics_frame
	Input.action_release("move_right")
	_check(game.player.position == player_point and observer.position == enemy_point and shot.position == shot_point, "Player, enemies, and projectiles stop while selecting")
	_check(game.spawner._elapsed == spawn_elapsed and game.upgrade_menu.can_process(), "Spawner is paused while menu processes")
	_check(not game.player.take_damage(10.0), "Player cannot take damage during selection")
	game._on_upgrade_chosen(&"invalid_upgrade")
	_check(paused and _rank_count(game.upgrades.ranks) == 0, "Invalid selection cannot grant an upgrade or resume")
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	_check(not paused and game.state == game.State.PLAYING and not game.upgrade_menu.visible, "Number-key selection resumes gameplay")
	_check(_rank_count(game.upgrades.ranks) == 1, "One selection grants exactly one rank")
	game.upgrade_menu._choose(0)
	_check(_rank_count(game.upgrades.ranks) == 1, "Hidden menu cannot apply another choice")
	game.spawner.set_physics_process(false)
	for enemy in game.spawner.enemy_container.get_children():
		enemy.free()
	for projectile in projectiles.get_children():
		projectile.free()

	# Two earned levels must yield two menus and preserve XP overflow.
	game.experience.add_experience(19)
	await process_frame
	_check(game.experience.level == 4 and game.experience.experience == 1 and game.pending_levels.size() == 2, "Burst XP crosses multiple thresholds without losing the remainder")
	var before_ranks := _rank_count(game.upgrades.ranks)
	game.upgrade_menu.cards[0].pressed.emit()
	game.upgrade_menu.cards[0].pressed.emit()
	_check(paused and game.pending_levels.size() == 1, "First choice keeps gameplay paused for the next earned level")
	await process_frame
	_check(_rank_count(game.upgrades.ranks) == before_ranks + 1 and game.upgrade_menu.visible, "Duplicate button event cannot consume the next queued choice")
	game.upgrade_menu.cards[1].pressed.emit()
	await process_frame
	_check(not paused and game.pending_levels.is_empty() and _rank_count(game.upgrades.ranks) == before_ranks + 2, "Last queued choice resumes gameplay with one rank per level")

	# Select every data-defined upgrade through the menu and verify real stats.
	for upgrade in game.upgrades.CATALOG.slice(0, 5):
		if upgrade.id == &"steadfast":
			game.player.current_health = 50.0
		var before: Array = [weapon.damage, weapon.cooldown, game.player.movement_speed, game.player.max_health, game.player.pickup_radius, game.player.current_health]
		game.experience.add_experience(game.experience.required_experience() - game.experience.experience)
		await process_frame
		for attempt in range(40):
			if game.upgrades.current_offers.has(upgrade):
				break
			game.upgrades.roll_choices()
		game.upgrade_menu.show_choices(game.upgrades.current_offers, game.upgrades.ranks, game.pending_levels[0])
		var index: int = game.upgrades.current_offers.find(upgrade)
		_check(index >= 0, "Eligible upgrade can be offered: " + upgrade.display_name)
		if index >= 0:
			game.upgrade_menu.cards[index].pressed.emit()
		await process_frame
		match upgrade.upgrade_type:
			0: _check(is_equal_approx(weapon.damage, before[0] * 1.2), "Pale Flame increases real weapon damage by 20 percent")
			1: _check(is_equal_approx(weapon.cooldown, before[1] / 1.15), "Quickening increases attack rate by 15 percent")
			2: _check(is_equal_approx(game.player.movement_speed, before[2] * 1.2), "Winter Stride increases movement speed by 20 percent")
			3: _check(game.player.max_health == before[3] + 20.0 and game.player.current_health == 70.0 and game.health_bar.max_value == game.player.max_health, "Steadfast raises max HP, heals 20, and updates HUD")
			4:
				_check(is_equal_approx(game.player.pickup_radius, before[4] * 1.15), "Moon's Reach increases pickup radius by 15 percent")
				_check(is_equal_approx(game.player.get_node("PickupArea/CollisionShape2D").shape.radius, game.player.pickup_radius), "Pickup collision shape matches upgraded stat")
				game._drop_shard(Vector2((before[4] + game.player.pickup_radius) * 0.5, 0), 1)
				for frame in range(60):
					await physics_frame
				_check(pickups.get_child_count() == 0 and game.experience.experience == 1, "Upgraded radius attracts a shard beyond the previous radius")
		_check(not paused, "Upgrade returns to gameplay: " + upgrade.display_name)

	var rank_snapshot: Dictionary = game.upgrades.ranks.duplicate()
	for upgrade in game.upgrades.CATALOG:
		if upgrade.max_level > 0:
			game.upgrades.ranks[upgrade.id] = upgrade.max_level
	for attempt in range(10):
		var choices = game.upgrades.roll_choices()
		_check(choices.size() == 3, "Three choices remain after capped upgrades are exhausted")
		for option in choices:
			_check(option.max_level == 0, "Capped upgrades are excluded")
	game.upgrades.ranks = rank_snapshot
	var target = game.spawner.spawn_enemy()
	target.set_physics_process(false)
	target.position = Vector2(300, 0)
	weapon.enabled = true
	weapon.fire()
	_check(projectiles.get_child_count() == weapon.projectile_count and is_equal_approx(projectiles.get_child(0).damage, weapon.damage), "New projectiles use upgraded weapon damage and volley size")
	weapon.enabled = false
	game.player.take_damage(1000.0)
	var old_level: int = game.experience.level
	game.experience.add_experience(10000)
	_check(game.state == game.State.GAME_OVER and game.experience.level == old_level and not paused, "Dead runs cannot gain XP or reopen upgrade selection")
	game.retry_button.pressed.emit()
	await scene_changed
	await process_frame
	game = current_scene
	game.spawner.set_physics_process(false)
	weapon = game.player.get_node("WeaponPivot/LightOrb")
	_check(game.experience.level == 1 and game.experience.experience == 0 and game.upgrades.ranks.is_empty(), "Retry clears all XP and upgrade ranks")
	_check(game.player.max_health == 100.0 and game.player.movement_speed == 240.0 and game.player.pickup_radius == 96.0 and weapon.damage == 15.0 and weapon.cooldown == 0.8, "Retry restores all base player and weapon stats")
	_check(not paused and not game.upgrade_menu.visible and game.get_node("World/PickupContainer").get_child_count() == 0, "Retry removes pickups and clears pause/menu state")
	game.experience.add_experience(6)
	await process_frame
	reload_current_scene()
	await scene_changed
	await process_frame
	_check(not paused and current_scene.state == current_scene.State.PLAYING, "Replacing a paused upgrade scene cannot leave the new run paused")
	print("DAY 4: %d checks, %d failures" % [_checks, _failures])
	call_group("game_audio", "stop_all")
	OS.delay_msec(100)
	quit(0 if _failures == 0 else 1)
