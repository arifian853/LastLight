extends Node

const UpgradeData = preload("res://scripts/progression/upgrade_data.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const WeaponScript = preload("res://scripts/weapons/light_orb.gd")

const CATALOG: Array[UpgradeData] = [
	preload("res://resources/upgrades/pale_flame.tres"),
	preload("res://resources/upgrades/quickening.tres"),
	preload("res://resources/upgrades/winter_stride.tres"),
	preload("res://resources/upgrades/steadfast.tres"),
	preload("res://resources/upgrades/moons_reach.tres"),
	preload("res://resources/upgrades/searing_halo.tres"),
	preload("res://resources/upgrades/winter_crown.tres"),
	preload("res://resources/upgrades/deep_freeze.tres"),
	preload("res://resources/upgrades/frozen_horizon.tres"),
	preload("res://resources/upgrades/twin_flame.tres"),
]

var ranks: Dictionary = {}
var current_offers: Array[UpgradeData] = []

@onready var player: PlayerScript = $"../World/Environment/Player"
@onready var weapon: WeaponScript = player.get_node("WeaponPivot/LightOrb")
@onready var halo = player.get_node("WeaponPivot/Halo")
@onready var frost = player.get_node("WeaponPivot/FrostPulse")


func roll_choices() -> Array[UpgradeData]:
	var eligible: Array[UpgradeData] = []
	for upgrade in CATALOG:
		if upgrade.max_level == 0 or int(ranks.get(upgrade.id, 0)) < upgrade.max_level:
			eligible.append(upgrade)
	eligible.shuffle()
	current_offers.clear()
	for index in range(mini(3, eligible.size())):
		current_offers.append(eligible[index])
	return current_offers


func choose_upgrade(id: StringName) -> bool:
	if player.is_dead:
		return false
	for upgrade in current_offers:
		if upgrade.id != id:
			continue
		if upgrade.max_level > 0 and int(ranks.get(id, 0)) >= upgrade.max_level:
			return false
		match upgrade.upgrade_type:
			UpgradeData.Type.ORB_DAMAGE:
				weapon.damage *= 1.0 + upgrade.value
			UpgradeData.Type.ATTACK_SPEED:
				for equipped in [weapon, halo, frost]:
					equipped.cooldown /= 1.0 + upgrade.value
					equipped._cooldown_left = minf(equipped._cooldown_left, equipped.cooldown)
			UpgradeData.Type.MOVEMENT_SPEED:
				player.movement_speed *= 1.0 + upgrade.value
			UpgradeData.Type.MAX_HEALTH:
				player.max_health += upgrade.value
				player.current_health = minf(player.max_health, player.current_health + upgrade.value)
				player.health_changed.emit(player.current_health, player.max_health)
			UpgradeData.Type.PICKUP_RADIUS:
				player.set_pickup_radius(player.pickup_radius * (1.0 + upgrade.value))
			UpgradeData.Type.HALO_DAMAGE:
				halo.damage *= 1.0 + upgrade.value
			UpgradeData.Type.HALO_RADIUS:
				halo.radius *= 1.0 + upgrade.value
			UpgradeData.Type.FROST_DAMAGE:
				frost.damage *= 1.0 + upgrade.value
			UpgradeData.Type.FROST_RADIUS:
				frost.radius *= 1.0 + upgrade.value
			UpgradeData.Type.EXTRA_PROJECTILE:
				weapon.projectile_count += int(upgrade.value)
		ranks[id] = int(ranks.get(id, 0)) + 1
		current_offers.clear()
		return true
	return false
