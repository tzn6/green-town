extends Node2D

# GREEN TOWN — большая интерактивная карта-прототип.
# Основа земли использует бесшовную рисованную текстуру, остальные элементы
# пока рисуются кодом поверх неё.

const WORLD_SIZE := Vector2(3600.0, 2200.0)
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.35
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/grass_tile.webp")
const TREE_ROUND_TEXTURE: Texture2D = preload("res://assets/environment/tree_round.svg")
const TREE_PINE_TEXTURE: Texture2D = preload("res://assets/environment/tree_pine.svg")
const BUSH_TEXTURE: Texture2D = preload("res://assets/environment/bush_flowers.svg")
const FLOWERS_TEXTURE: Texture2D = preload("res://assets/environment/flower_patch.svg")
const ROCK_TEXTURE: Texture2D = preload("res://assets/environment/rock_cluster.svg")
const STUMP_TEXTURE: Texture2D = preload("res://assets/environment/stump.svg")
const REEDS_TEXTURE: Texture2D = preload("res://assets/environment/reeds.svg")

var world_camera: Camera2D
var active_touches: Dictionary = {}
var last_pinch_distance := 0.0
var mouse_dragging := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4202407
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	create_camera()
	create_world_labels()
	create_interface()
	queue_redraw()


func create_camera() -> void:
	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.enabled = true
	world_camera.position = Vector2(1600.0, 1050.0)
	world_camera.zoom = Vector2(0.72, 0.72)
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 8.0
	world_camera.limit_left = 0
	world_camera.limit_top = 0
	world_camera.limit_right = int(WORLD_SIZE.x)
	world_camera.limit_bottom = int(WORLD_SIZE.y)
	add_child(world_camera)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
		else:
			active_touches.erase(event.index)
			if active_touches.size() < 2:
				last_pinch_distance = 0.0

	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position

		if active_touches.size() == 1:
			world_camera.position -= event.relative / world_camera.zoom.x
			clamp_camera()

		elif active_touches.size() == 2:
			var points := active_touches.values()
			var current_distance: float = points[0].distance_to(points[1])

			if last_pinch_distance > 0.0:
				var ratio := current_distance / last_pinch_distance
				set_camera_zoom(world_camera.zoom.x * ratio)

			last_pinch_distance = current_distance

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_zoom(world_camera.zoom.x + 0.08)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_zoom(world_camera.zoom.x - 0.08)

	elif event is InputEventMouseMotion and mouse_dragging:
		world_camera.position -= event.relative / world_camera.zoom.x
		clamp_camera()


func set_camera_zoom(value: float) -> void:
	var clamped_value := clampf(value, MIN_ZOOM, MAX_ZOOM)
	world_camera.zoom = Vector2(clamped_value, clamped_value)
	clamp_camera()


func clamp_camera() -> void:
	world_camera.position.x = clampf(world_camera.position.x, 280.0, WORLD_SIZE.x - 280.0)
	world_camera.position.y = clampf(world_camera.position.y, 220.0, WORLD_SIZE.y - 220.0)


func _draw() -> void:
	draw_ground()
	draw_water()
	draw_roads()
	draw_farm_zone()
	draw_town_zone()
	draw_buildings()
	draw_decorations()
	draw_world_border()


func draw_ground() -> void:
	draw_texture_rect(
		GRASS_TEXTURE,
		Rect2(Vector2.ZERO, WORLD_SIZE),
		true,
		Color.WHITE
	)

	# Полупрозрачные пятна ломают повтор рисунка на очень большой карте.
	for i in range(180):
		var pos := Vector2(
			rng.randf_range(80.0, WORLD_SIZE.x - 80.0),
			rng.randf_range(80.0, WORLD_SIZE.y - 80.0)
		)
		var radius := rng.randf_range(35.0, 95.0)
		var color := Color("#84d565") if i % 2 == 0 else Color("#6abd4e")
		color.a = 0.07
		draw_circle(pos, radius, color)


func draw_water() -> void:
	var river := PackedVector2Array([
		Vector2(2500, -80),
		Vector2(2440, 240),
		Vector2(2550, 520),
		Vector2(2490, 800),
		Vector2(2610, 1080),
		Vector2(2520, 1370),
		Vector2(2660, 1680),
		Vector2(2590, 1980),
		Vector2(2650, 2280)
	])

	# Мягкая тень, песчаный берег и несколько слоёв воды создают глубину.
	var river_shadow := PackedVector2Array()
	for point in river:
		river_shadow.append(point + Vector2(14, 18))
	draw_polyline(river_shadow, Color(0.07, 0.28, 0.20, 0.20), 316.0, true)
	draw_polyline(river, Color("#8fca67"), 306.0, true)
	draw_polyline(river, Color("#efd28a"), 286.0, true)
	draw_polyline(river, Color("#168bbd"), 258.0, true)
	draw_polyline(river, Color("#2eb4df"), 229.0, true)
	draw_polyline(river, Color("#6bd5ee"), 156.0, true)

	# Озеро в нижней части карты.
	draw_circle(Vector2(3085, 1730), 326.0, Color(0.07, 0.25, 0.18, 0.18))
	draw_circle(Vector2(3070, 1710), 318.0, Color("#8fca67"))
	draw_circle(Vector2(3070, 1710), 297.0, Color("#efd28a"))
	draw_circle(Vector2(3070, 1710), 271.0, Color("#168fbe"))
	draw_circle(Vector2(3060, 1695), 240.0, Color("#35b9df"))
	draw_circle(Vector2(3000, 1635), 121.0, Color("#72d8ee"))

	for x in range(0, 5):
		var y := 320.0 + x * 355.0
		draw_arc(Vector2(2535, y), 43.0, 0.2, 2.4, 18, Color(1, 1, 1, 0.43), 7.0, true)
		draw_arc(Vector2(2508, y + 38.0), 26.0, 0.1, 2.7, 14, Color(0.75, 0.96, 1.0, 0.28), 5.0, true)

	for wave in [Vector2(2920, 1630), Vector2(3070, 1800), Vector2(3195, 1680), Vector2(2990, 1870)]:
		draw_arc(wave, 36.0, 0.15, 2.65, 16, Color(1, 1, 1, 0.35), 6.0, true)


func draw_roads() -> void:
	var main_road := PackedVector2Array([
		Vector2(100, 1080),
		Vector2(620, 1040),
		Vector2(1120, 1090),
		Vector2(1640, 1010),
		Vector2(2100, 1050),
		Vector2(2380, 1000)
	])
	draw_road(main_road, 120.0)

	var farm_road := PackedVector2Array([
		Vector2(690, 1040),
		Vector2(720, 760),
		Vector2(670, 430),
		Vector2(820, 180)
	])
	draw_road(farm_road, 95.0)

	var town_road := PackedVector2Array([
		Vector2(1570, 1030),
		Vector2(1580, 760),
		Vector2(1750, 530),
		Vector2(2010, 370)
	])
	draw_road(town_road, 100.0)

	var lower_road := PackedVector2Array([
		Vector2(1150, 1090),
		Vector2(1260, 1370),
		Vector2(1530, 1560),
		Vector2(1850, 1710),
		Vector2(2220, 1770)
	])
	draw_road(lower_road, 95.0)


func draw_road(points: PackedVector2Array, width: float) -> void:
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(10, 14))
	draw_polyline(shadow_points, Color(0.16, 0.25, 0.12, 0.22), width + 32.0, true)
	draw_polyline(points, Color("#9a673d"), width + 24.0, true)
	draw_polyline(points, Color("#e4b967"), width + 10.0, true)
	draw_polyline(points, Color("#f3d083"), width - 4.0, true)
	draw_polyline(points, Color(1, 0.96, 0.75, 0.24), width * 0.42, true)


func draw_farm_zone() -> void:
	# Большой участок фермы.
	draw_rounded_rect(Rect2(210, 180, 1240, 760), 55.0, Color("#9add70"), Color("#4f9c3c"), 12.0)

	# Поля с разными культурами.
	draw_field(Rect2(300, 270, 310, 220), Color("#b8753b"), Color("#f4cc45"), 7)
	draw_field(Rect2(650, 270, 310, 220), Color("#a96935"), Color("#f4b84a"), 7)
	draw_field(Rect2(1000, 270, 340, 220), Color("#9d6335"), Color("#73bd4b"), 7)
	draw_field(Rect2(300, 545, 310, 260), Color("#a96537"), Color("#e98c42"), 8)
	draw_field(Rect2(650, 545, 310, 260), Color("#9e6136"), Color("#f0d453"), 8)

	# Загон для животных.
	draw_rounded_rect(Rect2(1010, 545, 330, 260), 35.0, Color("#cce89c"), Color("#8b6a43"), 8.0)
	draw_fence(Rect2(1035, 570, 280, 210))
	for p in [Vector2(1100, 640), Vector2(1220, 700), Vector2(1145, 755)]:
		draw_circle(p + Vector2(7, 8), 25.0, Color(0, 0, 0, 0.12))
		draw_circle(p, 24.0, Color("#fff9e8"))
		draw_circle(p + Vector2(16, -4), 10.0, Color("#f1d5a7"))
		draw_circle(p + Vector2(-8, 2), 7.0, Color("#6b5139"))


func draw_field(rect: Rect2, soil: Color, crop: Color, rows: int) -> void:
	draw_rounded_rect(rect, 28.0, soil, Color("#80512e"), 8.0)
	var row_gap := rect.size.y / float(rows + 1)
	for row in range(1, rows + 1):
		var y := rect.position.y + row_gap * row
		draw_line(
			Vector2(rect.position.x + 22.0, y),
			Vector2(rect.end.x - 22.0, y),
			soil.lightened(0.18),
			5.0,
			true
		)
		for x in range(int(rect.position.x + 35.0), int(rect.end.x - 25.0), 38):
			draw_circle(Vector2(x, y - 4.0), 8.0, crop.darkened(0.12))
			draw_circle(Vector2(x + 5.0, y - 9.0), 7.0, crop)


func draw_town_zone() -> void:
	# Площадь.
	draw_rounded_rect(Rect2(1510, 250, 720, 600), 65.0, Color("#bfe78e"), Color("#4f9c3c"), 12.0)
	draw_circle(Vector2(1850, 610), 150.0, Color("#d8bf8a"))
	draw_circle(Vector2(1850, 610), 118.0, Color("#f0d79c"))
	draw_circle(Vector2(1850, 610), 58.0, Color("#76cde5"))
	draw_circle(Vector2(1850, 600), 32.0, Color("#4fb4d7"))

	# Тропинки вокруг площади.
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		var start := Vector2(1850, 610) + Vector2(cos(angle), sin(angle)) * 140.0
		var end := Vector2(1850, 610) + Vector2(cos(angle), sin(angle)) * 320.0
		draw_line(start, end, Color("#e7c47b"), 65.0, true)


func draw_buildings() -> void:
	# Фермерский дом и амбар.
	draw_house(Rect2(930, 875, 300, 210), Color("#ffe6a3"), Color("#d9583b"), Color("#6ba8d9"))
	draw_barn(Rect2(340, 870, 300, 230))
	draw_silo(Vector2(700, 905), 84.0, 190.0)

	# Городские здания.
	draw_shop(Rect2(1515, 250, 270, 190), Color("#f9c96c"), Color("#d86c45"))
	draw_shop(Rect2(1940, 250, 270, 190), Color("#9bd7f0"), Color("#4b8ac0"))
	draw_house(Rect2(1500, 770, 270, 190), Color("#ffd7b0"), Color("#d95d69"), Color("#86b8d7"))
	draw_house(Rect2(1950, 770, 270, 190), Color("#eee4aa"), Color("#8d6bc1"), Color("#85b7d6"))

	# Нижняя производственная зона.
	draw_rounded_rect(Rect2(1050, 1330, 1210, 620), 58.0, Color("#a8d877"), Color("#4f9c3c"), 12.0)
	draw_factory(Rect2(1160, 1450, 360, 250), Color("#f5c46c"), Color("#c95d3e"))
	draw_factory(Rect2(1650, 1450, 390, 250), Color("#a8d3e7"), Color("#477ea5"))

	# Причал у озера.
	draw_rect(Rect2(2780, 1510, 330, 46), Color("#8b5a35"))
	for x in range(2800, 3100, 55):
		draw_rect(Rect2(x, 1500, 15, 82), Color("#674329"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2890, 1470), Vector2(3040, 1470), Vector2(3010, 1530), Vector2(2920, 1530)
	]), Color("#f8f0d8"))


func draw_house(rect: Rect2, wall: Color, roof: Color, window: Color) -> void:
	draw_rounded_rect(Rect2(rect.position + Vector2(16, 18), rect.size), 24.0, Color(0, 0, 0, 0.17), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(rect, 24.0, wall, Color("#8a613c"), 7.0)
	draw_rect(Rect2(rect.position + Vector2(12, rect.size.y - 24), Vector2(rect.size.x - 24, 24)), wall.darkened(0.16))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 70, -26), Vector2(34, 72)), Color("#925238"))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 76, -32), Vector2(46, 14)), Color("#6f3b2c"))
	var roof_points := PackedVector2Array([
		Vector2(rect.position.x - 18, rect.position.y + 46),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 60),
		Vector2(rect.end.x + 18, rect.position.y + 46),
		Vector2(rect.end.x - 6, rect.position.y + 78),
		Vector2(rect.position.x + 6, rect.position.y + 78)
	])
	var roof_shadow := PackedVector2Array()
	for point in roof_points:
		roof_shadow.append(point + Vector2(0, 13))
	draw_colored_polygon(roof_shadow, roof.darkened(0.34))
	draw_colored_polygon(roof_points, roof)
	draw_polyline(roof_points, roof.darkened(0.26), 7.0, true)
	draw_line(roof_points[0] + Vector2(18, 11), roof_points[1] + Vector2(0, 13), roof.lightened(0.26), 8.0, true)

	var left_window := Rect2(rect.position + Vector2(36, 94), Vector2(70, 60))
	var right_window := Rect2(rect.position + Vector2(rect.size.x - 106, 94), Vector2(70, 60))
	for window_rect in [left_window, right_window]:
		draw_rounded_rect(window_rect, 10.0, window, Color("#ffffff"), 6.0)
		draw_line(Vector2(window_rect.get_center().x, window_rect.position.y + 5), Vector2(window_rect.get_center().x, window_rect.end.y - 5), Color(1, 1, 1, 0.7), 4.0, true)
		draw_line(Vector2(window_rect.position.x + 5, window_rect.get_center().y), Vector2(window_rect.end.x - 5, window_rect.get_center().y), Color(1, 1, 1, 0.7), 4.0, true)
		draw_rect(Rect2(window_rect.position + Vector2(-4, window_rect.size.y - 2), Vector2(window_rect.size.x + 8, 12)), Color("#9f5f34"))
		for flower_x in range(int(window_rect.position.x + 10), int(window_rect.end.x - 4), 18):
			draw_circle(Vector2(flower_x, window_rect.end.y + 1), 5.0, Color("#ff668f"))
	draw_rounded_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 30, 105), Vector2(60, 105)), 10.0, Color("#9b623b"), Color("#70452b"), 5.0)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.5 - 43, rect.size.y - 3), Vector2(86, 14)), Color("#8a6848"))
	draw_circle(rect.position + Vector2(rect.size.x * 0.5 + 17, 160), 5.0, Color("#f4d25b"))


func draw_barn(rect: Rect2) -> void:
	draw_rounded_rect(Rect2(rect.position + Vector2(16, 18), rect.size), 28.0, Color(0, 0, 0, 0.18), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(rect, 28.0, Color("#d94f3f"), Color("#7d3d2d"), 8.0)
	for plank_x in range(int(rect.position.x + 30), int(rect.end.x - 20), 48):
		draw_line(Vector2(plank_x, rect.position.y + 80), Vector2(plank_x, rect.end.y - 16), Color(1, 0.68, 0.5, 0.16), 4.0)
	var roof := PackedVector2Array([
		Vector2(rect.position.x - 16, rect.position.y + 55),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 72),
		Vector2(rect.end.x + 16, rect.position.y + 55),
		Vector2(rect.end.x - 4, rect.position.y + 86),
		Vector2(rect.position.x + 4, rect.position.y + 86)
	])
	var roof_shadow := PackedVector2Array()
	for point in roof:
		roof_shadow.append(point + Vector2(0, 14))
	draw_colored_polygon(roof_shadow, Color("#51281f"))
	draw_colored_polygon(roof, Color("#7a382c"))
	draw_polyline(roof, Color("#51281f"), 7.0, true)
	draw_line(roof[0] + Vector2(20, 11), roof[1] + Vector2(0, 14), Color("#ad5a43"), 8.0, true)
	draw_rounded_rect(Rect2(rect.position + Vector2(82, 96), Vector2(136, 134)), 8.0, Color("#f2e2b6"), Color("#713729"), 8.0)
	draw_line(rect.position + Vector2(90, 106), rect.position + Vector2(210, 222), Color("#c45d44"), 10.0, true)
	draw_line(rect.position + Vector2(210, 106), rect.position + Vector2(90, 222), Color("#c45d44"), 10.0, true)
	draw_circle(rect.position + Vector2(rect.size.x * 0.5, 58), 18.0, Color("#f5d884"))
	draw_line(rect.position + Vector2(rect.size.x * 0.5 - 10, 58), rect.position + Vector2(rect.size.x * 0.5 + 10, 58), Color("#7d3d2d"), 4.0)


func draw_silo(pos: Vector2, width: float, height: float) -> void:
	draw_rounded_rect(Rect2(pos + Vector2(-width * 0.5 + 12, 15), Vector2(width, height)), 28.0, Color(0, 0, 0, 0.16), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(Rect2(pos + Vector2(-width * 0.5, 0), Vector2(width, height)), 28.0, Color("#d9e0df"), Color("#87908e"), 6.0)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-width * 0.55, 24),
		pos + Vector2(0, -38),
		pos + Vector2(width * 0.55, 24)
	]), Color("#b85c44"))
	draw_line(pos + Vector2(-width * 0.32, 24), pos + Vector2(-width * 0.32, height - 22), Color(1, 1, 1, 0.5), 7.0, true)
	for y in range(int(pos.y + 34), int(pos.y + height - 20), 34):
		draw_line(Vector2(pos.x - width * 0.42, y), Vector2(pos.x + width * 0.42, y), Color(1, 1, 1, 0.35), 3.0)


func draw_shop(rect: Rect2, wall: Color, awning: Color) -> void:
	draw_rounded_rect(Rect2(rect.position + Vector2(14, 17), rect.size), 24.0, Color(0, 0, 0, 0.17), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(rect, 24.0, wall, Color("#7d5b3d"), 7.0)
	draw_rounded_rect(Rect2(rect.position + Vector2(54, -35), Vector2(rect.size.x - 108, 58)), 16.0, Color("#fff1c5"), Color("#8a5b39"), 6.0)
	draw_circle(rect.position + Vector2(rect.size.x * 0.5, -6), 9.0, awning)
	draw_rect(Rect2(rect.position + Vector2(-8, 36), Vector2(rect.size.x + 16, 58)), awning)
	for i in range(6):
		if i % 2 == 0:
			draw_rect(Rect2(rect.position + Vector2(-8 + i * ((rect.size.x + 16) / 6.0), 36), Vector2((rect.size.x + 16) / 6.0, 58)), Color("#fff3cf"))
	for scallop_x in range(int(rect.position.x + 12), int(rect.end.x), 42):
		draw_circle(Vector2(scallop_x, rect.position.y + 93), 11.0, awning if int(scallop_x / 42) % 2 == 0 else Color("#fff3cf"))
	draw_rounded_rect(Rect2(rect.position + Vector2(30, 112), Vector2(82, 58)), 9.0, Color("#80c6e6"), Color.WHITE, 5.0)
	draw_line(rect.position + Vector2(71, 117), rect.position + Vector2(71, 165), Color(1, 1, 1, 0.7), 4.0)
	draw_rounded_rect(Rect2(rect.position + Vector2(rect.size.x - 90, 100), Vector2(58, 90)), 8.0, Color("#95633f"), Color("#6c472f"), 5.0)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 101, rect.size.y - 3), Vector2(80, 13)), Color("#8b6848"))


func draw_factory(rect: Rect2, wall: Color, roof: Color) -> void:
	draw_rounded_rect(Rect2(rect.position + Vector2(17, 19), rect.size), 28.0, Color(0, 0, 0, 0.18), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(rect, 28.0, wall, Color("#6e543c"), 8.0)
	draw_rect(Rect2(rect.position + Vector2(-8, 28), Vector2(rect.size.x + 16, 58)), roof)
	draw_rect(Rect2(rect.position + Vector2(-8, 28), Vector2(rect.size.x + 16, 12)), roof.lightened(0.22))
	for brick_y in range(int(rect.position.y + 100), int(rect.end.y - 18), 34):
		draw_line(Vector2(rect.position.x + 18, brick_y), Vector2(rect.end.x - 18, brick_y), wall.darkened(0.10), 3.0)
	for i in range(3):
		draw_rounded_rect(Rect2(rect.position + Vector2(45 + i * 102, 112), Vector2(70, 62)), 10.0, Color("#80c6e6"), Color("#ffffff"), 5.0)
		draw_line(rect.position + Vector2(80 + i * 102, 118), rect.position + Vector2(80 + i * 102, 168), Color(1, 1, 1, 0.65), 4.0)
	draw_rounded_rect(Rect2(rect.position + Vector2(rect.size.x - 94, 100), Vector2(62, 140)), 8.0, Color("#8b5a37"), Color("#5f3d29"), 5.0)
	draw_rect(Rect2(rect.position + Vector2(32, -70), Vector2(52, 105)), Color("#8a6250"))
	draw_rect(Rect2(rect.position + Vector2(24, -82), Vector2(68, 22)), Color("#65463a"))
	draw_circle(rect.position + Vector2(57, -101), 22.0, Color(0.86, 0.93, 0.90, 0.36))
	draw_circle(rect.position + Vector2(75, -124), 16.0, Color(0.90, 0.96, 0.93, 0.25))


func draw_decorations() -> void:
	# Камыши формируют живую кромку реки и озера.
	for reed_pos in [
		Vector2(2395, 310), Vector2(2620, 610), Vector2(2390, 910), Vector2(2690, 1220),
		Vector2(2425, 1510), Vector2(2750, 1810), Vector2(2890, 1900), Vector2(3280, 1830)
	]:
		draw_environment_sprite(REEDS_TEXTURE, reed_pos, Vector2(102, 112), 0.92)

	# Камни и пни создают крупные точки интереса вместо случайных кружков.
	for rock_pos in [Vector2(2360, 520), Vector2(2690, 770), Vector2(2390, 1360), Vector2(2790, 1910), Vector2(3330, 1580)]:
		draw_environment_sprite(ROCK_TEXTURE, rock_pos, Vector2(128, 90), 0.88)
	for stump_pos in [Vector2(280, 1460), Vector2(990, 1230), Vector2(2290, 1160), Vector2(3310, 970), Vector2(2350, 1980)]:
		draw_environment_sprite(STUMP_TEXTURE, stump_pos, Vector2(88, 79), 0.88)

	# Кусты расставлены вручную, поэтому не перекрывают поля и здания.
	var bush_positions := [
		Vector2(210, 1080), Vector2(300, 1185), Vector2(550, 1195), Vector2(840, 1180),
		Vector2(1090, 1210), Vector2(1370, 1080), Vector2(1460, 930), Vector2(2250, 930),
		Vector2(2300, 1250), Vector2(2780, 470), Vector2(3100, 520), Vector2(3350, 860),
		Vector2(2860, 1120), Vector2(3210, 1180), Vector2(3350, 1430), Vector2(2920, 1370),
		Vector2(910, 1840), Vector2(570, 1900), Vector2(1040, 2050), Vector2(2260, 2020),
		Vector2(2740, 2070), Vector2(3200, 2020)
	]
	for i in range(bush_positions.size()):
		var bush_scale := 0.86 + float(i % 3) * 0.08
		var bush_tint := Color.WHITE if i % 2 == 0 else Color("#e9ffe5")
		draw_environment_sprite(BUSH_TEXTURE, bush_positions[i], Vector2(132, 93) * bush_scale, 0.87, bush_tint)

	for flower_pos in [
		Vector2(260, 1260), Vector2(610, 1265), Vector2(870, 1320), Vector2(1400, 1240),
		Vector2(1460, 890), Vector2(2240, 890), Vector2(2780, 1040), Vector2(3190, 1010),
		Vector2(2870, 1980), Vector2(3250, 1920), Vector2(820, 1980), Vector2(1780, 2010)
	]:
		draw_environment_sprite(FLOWERS_TEXTURE, flower_pos, Vector2(112, 70), 0.90)

	# Деревья по границе карты и между функциональными зонами.
	var tree_positions := [
		Vector2(90, 150), Vector2(145, 350), Vector2(85, 585), Vector2(140, 820),
		Vector2(90, 1320), Vector2(120, 1580), Vector2(105, 1860), Vector2(250, 2070),
		Vector2(360, 1280), Vector2(540, 1370), Vector2(790, 1270), Vector2(930, 1910),
		Vector2(660, 2070), Vector2(1400, 1190), Vector2(1450, 2070), Vector2(2280, 160),
		Vector2(2350, 430), Vector2(2290, 770), Vector2(2760, 220), Vector2(2970, 260),
		Vector2(3210, 320), Vector2(3440, 480), Vector2(3400, 750), Vector2(3390, 1070),
		Vector2(3460, 1310), Vector2(3390, 1890), Vector2(2860, 1020), Vector2(3180, 1080),
		Vector2(2720, 2070), Vector2(2460, 2090), Vector2(1990, 2080)
	]
	for i in range(tree_positions.size()):
		var tree_scale := 0.84 + float(i % 4) * 0.07
		var tree_variant := 1 if i % 5 == 1 or i % 5 == 4 else 0
		draw_tree(tree_positions[i], tree_scale, tree_variant)


func draw_tree(pos: Vector2, scale_value: float, variant: int) -> void:
	var texture := TREE_PINE_TEXTURE if variant == 1 else TREE_ROUND_TEXTURE
	var ground_pos := pos + Vector2(0, 65) * scale_value
	draw_environment_sprite(texture, ground_pos, Vector2(188, 235) * scale_value, 0.91)


func draw_environment_sprite(
	texture: Texture2D,
	ground_pos: Vector2,
	size: Vector2,
	anchor_y: float = 0.9,
	modulate_color: Color = Color.WHITE
) -> void:
	var top_left := ground_pos - Vector2(size.x * 0.5, size.y * anchor_y)
	draw_texture_rect(texture, Rect2(top_left, size), false, modulate_color)


func draw_fence(rect: Rect2) -> void:
	for x in range(int(rect.position.x), int(rect.end.x) + 1, 36):
		draw_rect(Rect2(x - 5, rect.position.y - 7, 10, rect.size.y + 14), Color("#9b6b3f"))
	for y in [rect.position.y + 12.0, rect.end.y - 22.0]:
		draw_rect(Rect2(rect.position.x, y, rect.size.x, 10), Color("#bd8b55"))


func draw_world_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#3d8438"), false, 26.0)


func draw_rounded_rect(rect: Rect2, radius: float, fill: Color, border: Color, border_width: float) -> void:
	# Для прототипа используем StyleBoxFlat — он даёт аккуратные скругления.
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(border_width))
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	draw_style_box(style, rect)


func create_world_labels() -> void:
	add_world_label("ПОЛЯ", Vector2(560, 205), Vector2(540, 60), 34)
	add_world_label("ФЕРМА", Vector2(370, 930), Vector2(220, 50), 30)
	add_world_label("ГОРОДСКАЯ ПЛОЩАДЬ", Vector2(1600, 485), Vector2(500, 55), 30)
	add_world_label("ПРОИЗВОДСТВО", Vector2(1395, 1360), Vector2(520, 55), 30)
	add_world_label("ОЗЕРО", Vector2(2860, 1935), Vector2(430, 55), 28)


func add_world_label(text_value: String, pos: Vector2, label_size: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#315d2f"))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.72))
	label.add_theme_constant_override("outline_size", 7)
	add_child(label)


func create_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	create_top_bar(root)
	create_objective_card(root)
	create_bottom_menu(root)
	create_zoom_buttons(root)


func create_top_bar(root: Control) -> void:
	var top := PanelContainer.new()
	top.anchor_left = 0.018
	top.anchor_top = 0.018
	top.anchor_right = 0.982
	top.anchor_bottom = 0.115
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_theme_stylebox_override("panel", make_panel_style(Color("#078f49"), 30, Color("#056c39"), 5))
	root.add_child(top)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	top.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var title := Label.new()
	title.text = "GREEN TOWN"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	var level := Label.new()
	level.text = "  УРОВЕНЬ 1  "
	level.add_theme_font_size_override("font_size", 17)
	level.add_theme_color_override("font_color", Color("#315c2d"))
	level.add_theme_stylebox_override("normal", make_panel_style(Color("#dff3a5"), 18, Color("#b4d66c"), 3))
	row.add_child(level)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(make_resource_chip("МОНЕТЫ", "551", Color("#ffd95b")))
	row.add_child(make_resource_chip("АЛМАЗЫ", "12", Color("#8ee6ff")))


func make_resource_chip(caption: String, value: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(175, 52)
	chip.add_theme_stylebox_override("panel", make_panel_style(Color(0.02, 0.32, 0.18, 0.72), 18, Color(1, 1, 1, 0.12), 2))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 22)
	dot.add_theme_color_override("font_color", accent)
	row.add_child(dot)

	var text := Label.new()
	text.text = caption + ": " + value
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(text)
	return chip


func create_objective_card(root: Control) -> void:
	var card := PanelContainer.new()
	card.anchor_left = 0.025
	card.anchor_top = 0.145
	card.anchor_right = 0.25
	card.anchor_bottom = 0.285
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", make_panel_style(Color(1, 0.96, 0.79, 0.96), 24, Color("#c59b52"), 4))
	root.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ПЕРВАЯ ЦЕЛЬ"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#76522f"))
	column.add_child(title)

	var task := Label.new()
	task.text = "Соберите 10 пшеницы"
	task.add_theme_font_size_override("font_size", 17)
	task.add_theme_color_override("font_color", Color("#493a2b"))
	column.add_child(task)

	var progress_bg := ProgressBar.new()
	progress_bg.value = 30
	progress_bg.show_percentage = false
	progress_bg.custom_minimum_size = Vector2(0, 18)
	progress_bg.add_theme_stylebox_override("background", make_panel_style(Color("#e2c58b"), 10, Color.TRANSPARENT, 0))
	progress_bg.add_theme_stylebox_override("fill", make_panel_style(Color("#57b74e"), 10, Color.TRANSPARENT, 0))
	column.add_child(progress_bg)


func create_bottom_menu(root: Control) -> void:
	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.11
	bottom.anchor_top = 0.855
	bottom.anchor_right = 0.89
	bottom.anchor_bottom = 0.985
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_theme_stylebox_override("panel", make_panel_style(Color(0.04, 0.38, 0.22, 0.96), 32, Color("#e7d28b"), 5))
	root.add_child(bottom)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bottom.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	for item in [
		["ПОЛЯ", Color("#f1c54d")],
		["СТРОИТЬ", Color("#f29a52")],
		["СКЛАД", Color("#7bc6e6")],
		["ЗАКАЗЫ", Color("#d990c4")],
		["ДРУЗЬЯ", Color("#91d276")]
	]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(145, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("#3f352a"))
		button.add_theme_stylebox_override("normal", make_panel_style(item[1], 20, item[1].darkened(0.28), 4))
		button.add_theme_stylebox_override("pressed", make_panel_style(item[1].darkened(0.12), 20, item[1].darkened(0.34), 4))
		button.pressed.connect(show_coming_soon.bind(item[0]))
		row.add_child(button)


func create_zoom_buttons(root: Control) -> void:
	var column := VBoxContainer.new()
	column.anchor_left = 0.925
	column.anchor_top = 0.66
	column.anchor_right = 0.985
	column.anchor_bottom = 0.83
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)

	for data in [["+", 0.12], ["−", -0.12]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(64, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 30)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", make_panel_style(Color(0.03, 0.45, 0.26, 0.94), 18, Color.WHITE, 3))
		button.pressed.connect(change_zoom.bind(data[1]))
		column.add_child(button)


func change_zoom(amount: float) -> void:
	set_camera_zoom(world_camera.zoom.x + amount)


func show_coming_soon(section_name: String) -> void:
	var canvas := get_node("Interface") as CanvasLayer
	var toast := Label.new()
	toast.text = section_name + " — добавим на следующем этапе"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.position = Vector2(0, 0)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-260, 110)
	toast.size = Vector2(520, 58)
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast.add_theme_stylebox_override("normal", make_panel_style(Color(0.06, 0.29, 0.18, 0.95), 20, Color("#d9c778"), 3))
	canvas.add_child(toast)

	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(toast.queue_free)


func make_panel_style(fill: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_detail = 12
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.shadow_color = Color(0.03, 0.14, 0.08, 0.24)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 4)
	return style
