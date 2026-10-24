extends Node2D
## Seeded decorative landscape, generated once. The clearing stays navigable.

const ARENA_HALF_SIZE := Vector2(2200.0, 1600.0)
const FIR_TEXTURE: Texture2D = preload("res://assets/sprites/fir.svg")


func _ready() -> void:
	_create_trees()
	_create_boundaries()


func _create_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8417
	var environment: Node2D = $"../Environment"
	for index in range(210):
		var point := Vector2(rng.randf_range(-2160.0, 2160.0), rng.randf_range(-1560.0, 1560.0))
		# Preserve a generous clearing around the player's starting position.
		if point.length() < 280.0:
			continue
		var tree := Sprite2D.new()
		tree.name = "Fir%03d" % index
		tree.texture = FIR_TEXTURE
		tree.position = point
		tree.offset = Vector2(0.0, -80.0)
		tree.scale = Vector2.ONE * rng.randf_range(0.65, 1.35)
		tree.modulate = Color.WHITE * rng.randf_range(0.8, 1.1)
		tree.modulate.a = 1.0
		environment.add_child(tree)


func _create_boundaries() -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "ArenaBounds"
	bounds.collision_layer = 1
	bounds.collision_mask = 0
	add_child(bounds)
	for side in range(4):
		var wall := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		if side < 2:
			shape.size = Vector2(80.0, ARENA_HALF_SIZE.y * 2.0 + 160.0)
			wall.position.x = (-1.0 if side == 0 else 1.0) * (ARENA_HALF_SIZE.x + 40.0)
		else:
			shape.size = Vector2(ARENA_HALF_SIZE.x * 2.0, 80.0)
			wall.position.y = (-1.0 if side == 2 else 1.0) * (ARENA_HALF_SIZE.y + 40.0)
		wall.shape = shape
		bounds.add_child(wall)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2308
	draw_rect(Rect2(-ARENA_HALF_SIZE - Vector2(200.0, 200.0), ARENA_HALF_SIZE * 2.0 + Vector2(400.0, 400.0)), Color("344d5f"))
	# Wide translucent snow banks keep the ground from reading as a flat fill.
	for index in range(160):
		var point := Vector2(rng.randf_range(-2300.0, 2300.0), rng.randf_range(-1700.0, 1700.0))
		draw_set_transform(point, rng.randf_range(-0.3, 0.3), Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, rng.randf_range(35.0, 200.0), Color(0.65, 0.78, 0.82, rng.randf_range(0.02, 0.07)))
	draw_set_transform(Vector2.ZERO)
	_draw_ice(Vector2(470.0, -190.0), Vector2(150.0, 72.0))
	_draw_ice(Vector2(-590.0, 410.0), Vector2(210.0, 95.0))
	_draw_ice(Vector2(900.0, 780.0), Vector2(260.0, 120.0))
	# Scattered rocks and fine wind-scoured snow strokes.
	for index in range(700):
		var point := Vector2(rng.randf_range(-2170.0, 2170.0), rng.randf_range(-1570.0, 1570.0))
		if index % 7 == 0 and point.length() > 180.0:
			var size := rng.randf_range(5.0, 15.0)
			draw_colored_polygon(PackedVector2Array([point + Vector2(-size, 0), point + Vector2(-size * 0.5, -size * 0.8), point + Vector2(size * 0.5, -size), point + Vector2(size, 0), point + Vector2(0, size * 0.3)]), Color("273e4d"))
			draw_line(point + Vector2(-size * 0.5, -size * 0.8), point + Vector2(size * 0.5, -size), Color("8099a3"), 2.0, true)
		else:
			draw_line(point, point + Vector2(rng.randf_range(3.0, 13.0), -1.0), Color(0.68, 0.8, 0.86, 0.12), 1.0, true)
	# An old stone circle serves as the first landmark.
	draw_arc(Vector2.ZERO, 115.0, 0.0, TAU, 80, Color(0.6, 0.71, 0.7, 0.2), 2.0, true)
	for index in range(12):
		var point := Vector2.RIGHT.rotated(float(index) * TAU / 12.0) * 116.0
		draw_set_transform(point, float(index) * TAU / 12.0)
		draw_rect(Rect2(-7.0, -12.0, 14.0, 24.0), Color("213743"))
		draw_line(Vector2(-6.0, -10.0), Vector2(5.0, -10.0), Color("8b9e9f"), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_ice(center: Vector2, size: Vector2) -> void:
	var points := PackedVector2Array()
	for index in range(18):
		var angle := float(index) * TAU / 18.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size * (1.0 + sin(angle * 5.0) * 0.08))
	draw_colored_polygon(points, Color("294658"))
	points.append(points[0])
	draw_polyline(points, Color(0.55, 0.73, 0.8, 0.25), 3.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(-size.x * 0.65, -4), center + Vector2(-20, 9), center + Vector2(8, -14), center + Vector2(size.x * 0.6, -8)]), Color(0.5, 0.7, 0.8, 0.25), 1.5, true)
