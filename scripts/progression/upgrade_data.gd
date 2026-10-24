extends Resource
## Shared definitions stay immutable; ranks belong to each run's manager.

enum Type { ORB_DAMAGE, ATTACK_SPEED, MOVEMENT_SPEED, MAX_HEALTH, PICKUP_RADIUS, HALO_DAMAGE, HALO_RADIUS, FROST_DAMAGE, FROST_RADIUS, EXTRA_PROJECTILE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var max_level: int = 5 # Zero means repeatable.
@export var upgrade_type: Type = Type.ORB_DAMAGE
@export var value: float = 0.2
