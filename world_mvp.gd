extends Node2D

# GREEN TOWN MVP — полноценный игровой вертикальный срез для телефона.
# Карта собрана в духе уютных мобильных ферм, но с собственным дизайном.
# Внутри: плавная камера, многослойная трава, вода и дороги, пустые грядки,
# посадка/рост/сбор, уровни, амбар, заказы, покупка пекарни и производство хлеба.

const WORLD_SIZE := Vector2(3900.0, 2450.0)
const MIN_ZOOM := 0.48
const MAX_ZOOM := 1.36
const START_ZOOM := 0.84
const START_CAMERA := Vector2(1680.0, 1090.0)
const SAVE_PATH := "user://green_town_world_v2.json"
const BARN_CAPACITY := 100
const BAKERY_PRICE := 120
const BAKERY_SITE := Vector2(2620.0, 805.0)
const CHICKEN_SITE := Vector2(2810.0, 1485.0)
const BAKERY_BUILD_POSITION := Vector2(2620.0, 690.0)

const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/grass_tile.webp")

const BARN_TEXTURE: Texture2D = preload("res://assets/farm_hd/barn.png")
const HOUSE_TEXTURE: Texture2D = preload("res://assets/farm_hd/house.png")
const BAKERY_TEXTURE: Texture2D = preload("res://assets/farm_hd/bakery.png")
const SILO_TEXTURE: Texture2D = preload("res://assets/farm_hd/silo.png")

const FIELD_EMPTY_TEXTURE: Texture2D = preload("res://assets/farm_hd/field_empty.png")
const FIELD_WHEAT_TEXTURE: Texture2D = preload("res://assets/farm_hd/field_wheat.png")
const FIELD_CORN_TEXTURE: Texture2D = preload("res://assets/farm_hd/field_corn.png")
const FIELD_TOMATO_TEXTURE: Texture2D = preload("res://assets/farm_hd/field_tomato.png")
const FIELD_CARROT_TEXTURE: Texture2D = preload("res://assets/farm_hd/field_carrot.png")

const TREE_APPLE_TEXTURE: Texture2D = preload("res://assets/farm_hd/tree_apple.png")
const TREE_ROUND_TEXTURE: Texture2D = preload("res://assets/farm_hd/tree_round.png")
const TREE_PINE_TEXTURE: Texture2D = preload("res://assets/farm_hd/tree_pine.png")
const ROCK_FENCE_TEXTURE: Texture2D = preload("res://assets/farm_hd/rock_fence.png")

const CROP_ORDER := ["wheat", "corn", "tomato", "carrot"]
const STORAGE_ORDER := ["wheat", "corn", "tomato", "carrot", "bread"]

const SELL_PRICES := {
	"wheat": 3,
	"corn": 5,
	"tomato": 7,
	"carrot": 6,
	"bread": 16
}

const PRODUCT_NAMES := {
	"wheat": "Пшеница",
	"corn": "Кукуруза",
	"tomato": "Томаты",
	"carrot": "Морковь",
	"bread": "Хлеб"
}

const CROP_DATA := {
	"wheat": {
		"name": "ПШЕНИЦА",
		"texture": FIELD_WHEAT_TEXTURE,
		"grow_time": 12.0,
		"unlock_level": 1,
		"plant_cost": 0,
		"harvest_count": 2,
		"xp": 3,
		"card_color": Color("#f5c84b")
	},
	"corn": {
		"name": "КУКУРУЗА",
		"texture": FIELD_CORN_TEXTURE,
		"grow_time": 20.0,
		"unlock_level": 2,
		"plant_cost": 1,
		"harvest_count": 2,
		"xp": 5,
		"card_color": Color("#8dcb55")
	},
	"tomato": {
		"name": "ТОМАТЫ",
		"texture": FIELD_TOMATO_TEXTURE,
		"grow_time": 30.0,
		"unlock_level": 3,
		"plant_cost": 2,
		"harvest_count": 2,
		"xp": 7,
		"card_color": Color("#ec6c55")
	},
	"carrot": {
		"name": "МОРКОВЬ",
		"texture": FIELD_CARROT_TEXTURE,
		"grow_time": 24.0,
		"unlock_level": 4,
		"plant_cost": 2,
		"harvest_count": 2,
		"xp": 6,
		"card_color": Color("#f19a45")
	}
}

var world_camera: Camera2D
var active_touches: Dictionary = {}
var touch_can_pan: Dictionary = {}
var touch_distance: Dictionary = {}
var last_pinch_distance := 0.0
var mouse_dragging := false
var mouse_can_pan := false
var rng := RandomNumberGenerator.new()

var field_plots: Array[Dictionary] = []
var selected_field := -1

var coins := 551
var gems := 12
var level := 1
var xp := 0
var inventory := {
	"wheat": 0,
	"corn": 0,
	"tomato": 0,
	"carrot": 0,
	"bread": 0
}
var wheat_harvested := 0
var first_task_completed := false
var bakery_built := false
var bakery_job_active := false
var bakery_job_end := 0.0
var order_index := 0
var current_order: Dictionary = {}

var coins_label: Label
var gems_label: Label
var level_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var task_progress_bar: ProgressBar
var task_progress_label: Label
var warehouse_label: Label

var ui_root: Control
var seed_panel: PanelContainer
var seed_buttons: Dictionary = {}
var modal_layer: Control
var barn_dialog: PanelContainer
var build_dialog: PanelContainer
var order_dialog: PanelContainer
var bakery_dialog: PanelContainer
var bakery_world_root: Node2D
var bakery_build_button: Button
var bakery_card_status: Label
var order_summary_label: Label
var bakery_summary_label: Label
var bakery_site_label: Label
var chicken_site_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer


func _ready() -> void:
	rng.seed = 4202407
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	create_camera()
	create_world_objects()
	create_field_plots()
	create_world_labels()
	create_interface()
	load_game()
	ensure_current_order()
	update_building_visuals()
	update_all_fields()
	update_hud()
	update_all_dialogs()
	create_growth_timer()
	queue_redraw()

func create_camera() -> void:
	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.enabled = true
	world_camera.position = START_CAMERA
	world_camera.zoom = Vector2(START_ZOOM, START_ZOOM)
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 11.0
	world_camera.limit_left = 0
	world_camera.limit_top = 0
	world_camera.limit_right = int(WORLD_SIZE.x)
	world_camera.limit_bottom = int(WORLD_SIZE.y)
	add_child(world_camera)


func _input(event: InputEvent) -> void:
	# Используем _input, а не _unhandled_input: так жесты карты не пропадают
	# из-за полноэкранного интерфейса Android-версии Godot.
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			touch_can_pan[event.index] = not is_ui_position(event.position) and not is_any_panel_open()
			touch_distance[event.index] = 0.0
		else:
			active_touches.erase(event.index)
			touch_can_pan.erase(event.index)
			touch_distance.erase(event.index)
			if active_touches.size() < 2:
				last_pinch_distance = 0.0

	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		touch_distance[event.index] = float(touch_distance.get(event.index, 0.0)) + event.relative.length()

		if is_any_panel_open():
			return

		if active_touches.size() == 1:
			if bool(touch_can_pan.get(event.index, false)) and float(touch_distance.get(event.index, 0.0)) > 5.0:
				world_camera.position -= event.relative / world_camera.zoom.x
				clamp_camera()

		elif active_touches.size() == 2:
			var ids := active_touches.keys()
			if not bool(touch_can_pan.get(ids[0], false)) or not bool(touch_can_pan.get(ids[1], false)):
				return

			var first: Vector2 = active_touches[ids[0]]
			var second: Vector2 = active_touches[ids[1]]
			var current_distance := first.distance_to(second)

			if last_pinch_distance > 0.0:
				var ratio := current_distance / last_pinch_distance
				set_camera_zoom(world_camera.zoom.x * ratio)

			last_pinch_distance = current_distance

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_dragging = event.pressed
			mouse_can_pan = event.pressed and not is_ui_position(event.position) and not is_any_panel_open()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_zoom(world_camera.zoom.x + 0.08)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_zoom(world_camera.zoom.x - 0.08)

	elif event is InputEventMouseMotion and mouse_dragging and mouse_can_pan and not is_any_panel_open():
		world_camera.position -= event.relative / world_camera.zoom.x
		clamp_camera()


func is_ui_position(screen_position: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size

	if screen_position.y < 108.0:
		return true
	if screen_position.y > viewport_size.y - 108.0:
		return true
	if screen_position.x < 355.0 and screen_position.y < 330.0:
		return true
	if screen_position.x > viewport_size.x - 105.0:
		return true

	return false


func is_any_panel_open() -> bool:
	return (
		(seed_panel != null and seed_panel.visible)
		or (modal_layer != null and modal_layer.visible)
	)


func set_camera_zoom(value: float) -> void:
	var clamped_value := clampf(value, MIN_ZOOM, MAX_ZOOM)
	world_camera.zoom = Vector2(clamped_value, clamped_value)
	clamp_camera()


func clamp_camera() -> void:
	var viewport_size := get_viewport_rect().size
	var half_visible := viewport_size * 0.5 / world_camera.zoom.x
	var minimum := half_visible
	var maximum := WORLD_SIZE - half_visible

	if minimum.x > maximum.x:
		world_camera.position.x = WORLD_SIZE.x * 0.5
	else:
		world_camera.position.x = clampf(world_camera.position.x, minimum.x, maximum.x)

	if minimum.y > maximum.y:
		world_camera.position.y = WORLD_SIZE.y * 0.5
	else:
		world_camera.position.y = clampf(world_camera.position.y, minimum.y, maximum.y)


func focus_camera(target: Vector2, zoom_value: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(world_camera, "position", target, 0.45)
	tween.tween_property(world_camera, "zoom", Vector2(zoom_value, zoom_value), 0.45)
	tween.finished.connect(clamp_camera)


# -----------------------------------------------------------------------------
# РИСОВАНИЕ МИРА
# -----------------------------------------------------------------------------

func _draw() -> void:
	draw_ground()
	draw_water()
	draw_farm_clearing()
	draw_roads()
	draw_building_pads()
	draw_fences()
	draw_small_decor()
	draw_locked_build_spots()
	draw_world_border()

func draw_ground() -> void:
	# База спокойнее и ближе к рисованным мобильным фермам.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#68ad45"))
	draw_texture_rect(
		GRASS_TEXTURE,
		Rect2(Vector2.ZERO, WORLD_SIZE),
		true,
		Color(0.94, 1.0, 0.88, 0.32)
	)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 918273

	# Большие полупрозрачные пятна убирают ощущение плоской заливки.
	for i in range(165):
		var pos := Vector2(
			local_rng.randf_range(90.0, WORLD_SIZE.x - 90.0),
			local_rng.randf_range(90.0, WORLD_SIZE.y - 90.0)
		)
		var radius := local_rng.randf_range(55.0, 190.0)
		var patch_color := Color("#a8d55d") if i % 3 != 0 else Color("#397f37")
		patch_color.a = local_rng.randf_range(0.025, 0.082)
		draw_circle(pos, radius, patch_color)

	# Кластеры травы и цветов. В игровой зоне они редкие, по краям — гуще.
	for i in range(510):
		var pos := Vector2(
			local_rng.randf_range(52.0, WORLD_SIZE.x - 52.0),
			local_rng.randf_range(52.0, WORLD_SIZE.y - 52.0)
		)
		var gameplay_area := Rect2(500, 260, 2600, 1600).has_point(pos)
		if gameplay_area and i % 4 != 0:
			continue

		if i % 11 == 0:
			var flower_colors: Array[Color] = [
				Color("#fff1a8"),
				Color("#f8a9c2"),
				Color("#b9d9ff"),
				Color("#fff8e4")
			]
			var flower_color: Color = flower_colors[i % flower_colors.size()]
			draw_circle(pos + Vector2(-4, 0), 2.7, flower_color)
			draw_circle(pos + Vector2(4, 0), 2.7, flower_color)
			draw_circle(pos + Vector2(0, -4), 2.7, flower_color)
			draw_circle(pos, 1.8, Color("#f2c64c"))
		else:
			var blade := Color(0.13, 0.40, 0.14, local_rng.randf_range(0.25, 0.52))
			draw_line(pos + Vector2(-4, 5), pos + Vector2(-1, -5), blade, 2.0, true)
			draw_line(pos + Vector2(1, 5), pos + Vector2(3, -3), blade, 2.0, true)
			if i % 5 == 0:
				draw_line(pos + Vector2(5, 5), pos + Vector2(7, -1), blade, 1.7, true)

	# Мягкая виньетка по краям карты.
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 145), Color(0.04, 0.23, 0.08, 0.17))
	draw_rect(Rect2(0, WORLD_SIZE.y - 150, WORLD_SIZE.x, 150), Color(0.04, 0.23, 0.08, 0.14))
	draw_rect(Rect2(0, 0, 145, WORLD_SIZE.y), Color(0.04, 0.23, 0.08, 0.15))
	draw_rect(Rect2(WORLD_SIZE.x - 145, 0, 145, WORLD_SIZE.y), Color(0.04, 0.23, 0.08, 0.15))

func draw_farm_clearing() -> void:
	# Светлая игровая поляна объединяет дом, амбар и грядки в одну сцену.
	var shadow := PackedVector2Array([
		Vector2(500, 350), Vector2(980, 245), Vector2(1570, 275),
		Vector2(2210, 385), Vector2(2790, 700), Vector2(2880, 1300),
		Vector2(2530, 1730), Vector2(1960, 1880), Vector2(1210, 1815),
		Vector2(620, 1540), Vector2(405, 940)
	])
	var light := PackedVector2Array()
	for point in shadow:
		light.append(point - Vector2(0, 14))

	draw_colored_polygon(shadow, Color(0.06, 0.24, 0.08, 0.12))
	draw_colored_polygon(light, Color(0.78, 0.94, 0.48, 0.11))

	# Небольшие светлые пятна вокруг ключевых зон.
	draw_ellipse_shape(Vector2(1110, 720), Vector2(620, 430), Color(0.85, 0.96, 0.58, 0.055))
	draw_ellipse_shape(Vector2(1870, 1220), Vector2(610, 500), Color(0.85, 0.96, 0.58, 0.05))

func draw_water() -> void:
	# Живой берег в нижнем левом углу, как отдельная зона отдыха.
	var outer_shore := PackedVector2Array([
		Vector2(0, 1540), Vector2(160, 1470), Vector2(355, 1478),
		Vector2(535, 1565), Vector2(665, 1715), Vector2(735, 1905),
		Vector2(720, 2140), Vector2(645, 2450), Vector2(0, 2450)
	])
	var sand := PackedVector2Array([
		Vector2(0, 1600), Vector2(165, 1530), Vector2(330, 1540),
		Vector2(485, 1615), Vector2(590, 1750), Vector2(645, 1920),
		Vector2(630, 2140), Vector2(550, 2450), Vector2(0, 2450)
	])
	var water := PackedVector2Array([
		Vector2(0, 1650), Vector2(165, 1595), Vector2(305, 1605),
		Vector2(430, 1670), Vector2(510, 1785), Vector2(550, 1940),
		Vector2(535, 2135), Vector2(455, 2450), Vector2(0, 2450)
	])

	draw_colored_polygon(outer_shore, Color(0.12, 0.25, 0.08, 0.18))
	draw_colored_polygon(sand, Color("#d9bd70"))
	draw_polyline(sand, Color("#af8643"), 15.0, true)
	draw_colored_polygon(water, Color("#0e8fb8"))
	draw_polyline(water, Color(0.83, 0.98, 0.98, 0.55), 7.0, true)

	var shallow := PackedVector2Array([
		Vector2(0, 1650), Vector2(160, 1597), Vector2(300, 1608),
		Vector2(405, 1665), Vector2(456, 1725), Vector2(0, 1795)
	])
	draw_colored_polygon(shallow, Color(0.26, 0.78, 0.88, 0.42))

	for wave_pos in [Vector2(105, 1740), Vector2(310, 1860), Vector2(145, 2070), Vector2(385, 2220)]:
		draw_arc(wave_pos, 34.0, 0.15, 2.9, 20, Color(1, 1, 1, 0.35), 3.5, true)

	# Камни у воды.
	for rock in [Vector2(570, 1665), Vector2(620, 1775), Vector2(585, 2050), Vector2(510, 2230)]:
		draw_circle(rock + Vector2(5, 8), 17.0, Color(0.08, 0.16, 0.08, 0.16))
		draw_circle(rock, 16.0, Color("#a69a78"))
		draw_circle(rock + Vector2(-4, -5), 7.0, Color(0.86, 0.83, 0.69, 0.52))

	# Причал.
	draw_rect(Rect2(430, 1568, 250, 52), Color(0.08, 0.15, 0.07, 0.20))
	draw_rect(Rect2(420, 1555, 250, 48), Color("#8f5c33"))
	for x in range(433, 660, 36):
		draw_rect(Rect2(x, 1548, 10, 83), Color("#654020"))
		draw_line(Vector2(x - 3, 1572), Vector2(x + 26, 1572), Color("#d9a45e"), 3.0)

func draw_roads() -> void:
	# Дорожки образуют мягкую петлю вокруг стартовой фермы.
	draw_road(PackedVector2Array([
		Vector2(500, 1215), Vector2(720, 1140), Vector2(970, 1125),
		Vector2(1220, 1140), Vector2(1450, 1230), Vector2(1660, 1340),
		Vector2(1910, 1380), Vector2(2160, 1345), Vector2(2420, 1250),
		Vector2(2750, 1185), Vector2(3070, 1205)
	]), 52.0)

	draw_road(PackedVector2Array([
		Vector2(970, 1125), Vector2(930, 955), Vector2(970, 790), Vector2(1040, 670)
	]), 43.0)

	draw_road(PackedVector2Array([
		Vector2(1450, 1230), Vector2(1580, 1100), Vector2(1715, 1010)
	]), 39.0)

	draw_road(PackedVector2Array([
		Vector2(2160, 1345), Vector2(2350, 1165), Vector2(2495, 995), Vector2(2580, 840)
	]), 38.0)

	# Тропинка к воде.
	draw_road(PackedVector2Array([
		Vector2(720, 1140), Vector2(630, 1280), Vector2(560, 1435), Vector2(515, 1555)
	]), 34.0)

func draw_road(points: PackedVector2Array, width: float) -> void:
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(4, 8))

	draw_polyline(shadow_points, Color(0.08, 0.17, 0.06, 0.17), width + 16.0, true)
	draw_polyline(points, Color("#9f713f"), width + 11.0, true)
	draw_polyline(points, Color("#d9ad61"), width + 5.0, true)
	draw_polyline(points, Color("#efcf89"), width, true)
	draw_polyline(points, Color(1.0, 0.98, 0.83, 0.18), maxf(4.0, width * 0.16), true)

func draw_building_pads() -> void:
	# Небольшие каменные основания визуально связывают здания с землёй.
	draw_ellipse_shape(Vector2(1020, 755), Vector2(270, 110), Color(0.18, 0.25, 0.12, 0.13))
	draw_ellipse_shape(Vector2(1395, 742), Vector2(225, 92), Color(0.18, 0.25, 0.12, 0.11))
	draw_ellipse_shape(Vector2(746, 808), Vector2(110, 62), Color(0.18, 0.25, 0.12, 0.11))

	for pos in [Vector2(965, 830), Vector2(1015, 842), Vector2(1065, 832), Vector2(1115, 842)]:
		draw_rect(Rect2(pos - Vector2(22, 10), Vector2(44, 20)), Color("#b7a178"))
		draw_rect(Rect2(pos - Vector2(19, 8), Vector2(38, 15)), Color("#d8c79e"))


func draw_small_decor() -> void:
	# Почтовый ящик возле развилки.
	draw_rect(Rect2(1482, 1127, 12, 66), Color("#75502f"))
	draw_rect(Rect2(1456, 1108, 68, 38), Color("#2e78a4"))
	draw_rect(Rect2(1462, 1114, 56, 25), Color("#55a9cf"))
	draw_rect(Rect2(1512, 1102, 7, 27), Color("#d34d43"))

	# Скамейка у воды.
	draw_rect(Rect2(760, 1507, 110, 17), Color("#87572f"))
	draw_rect(Rect2(770, 1474, 90, 15), Color("#a86c38"))
	draw_line(Vector2(782, 1488), Vector2(782, 1540), Color("#654020"), 9.0)
	draw_line(Vector2(848, 1488), Vector2(848, 1540), Color("#654020"), 9.0)

	# Несколько камней и клумб в центре.
	for pos in [Vector2(1320, 965), Vector2(1510, 895), Vector2(2280, 1045), Vector2(2350, 1515)]:
		draw_circle(pos + Vector2(4, 6), 13.0, Color(0.07, 0.14, 0.06, 0.15))
		draw_circle(pos, 12.0, Color("#a69a7b"))
		draw_circle(pos + Vector2(-3, -4), 5.0, Color(0.90, 0.86, 0.72, 0.45))

	for pos in [Vector2(1240, 875), Vector2(1555, 790), Vector2(2210, 920), Vector2(2370, 1425)]:
		draw_circle(pos, 10.0, Color("#4a9b3d"))
		draw_circle(pos + Vector2(-7, -2), 5.0, Color("#f3a8c0"))
		draw_circle(pos + Vector2(6, -5), 5.0, Color("#fff1a5"))
		draw_circle(pos + Vector2(2, 6), 4.0, Color("#b7d9ff"))


func draw_fences() -> void:
	draw_fence_line(PackedVector2Array([
		Vector2(1510, 860), Vector2(2200, 860), Vector2(2280, 940)
	]))
	draw_fence_line(PackedVector2Array([
		Vector2(1480, 1570), Vector2(2150, 1570), Vector2(2260, 1510)
	]))
	draw_fence_line(PackedVector2Array([
		Vector2(660, 420), Vector2(700, 770)
	]))


func draw_fence_line(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return

	draw_polyline(points, Color(0.12, 0.19, 0.08, 0.16), 15.0, true)
	draw_polyline(points, Color("#d8c39a"), 9.0, true)
	draw_polyline(points, Color("#fff2d1"), 4.0, true)

	for segment in range(points.size() - 1):
		var start := points[segment]
		var finish := points[segment + 1]
		var length := start.distance_to(finish)
		var steps := maxi(1, int(length / 72.0))
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var pos := start.lerp(finish, t)
			draw_line(pos + Vector2(4, 15), pos + Vector2(4, -18), Color(0.12, 0.18, 0.08, 0.16), 10.0, true)
			draw_line(pos, pos + Vector2(0, -31), Color("#eee0bf"), 8.0, true)
			draw_circle(pos + Vector2(0, -31), 4.5, Color("#fff7df"))


func draw_locked_build_spots() -> void:
	if not bakery_built:
		draw_build_marker(BAKERY_SITE, "ПЕКАРНЯ", 2)
	draw_build_marker(CHICKEN_SITE, "КУРОВНИК", 3)

func draw_build_marker(center: Vector2, title: String, required_level: int) -> void:
	draw_ellipse_shape(center + Vector2(6, 14), Vector2(150, 66), Color(0.05, 0.15, 0.05, 0.12))
	draw_ellipse_shape(center, Vector2(143, 61), Color(0.86, 0.76, 0.48, 0.25))

	var post_color := Color("#7c5232")
	draw_rect(Rect2(center + Vector2(-7, -2), Vector2(14, 92)), post_color)
	draw_rect(Rect2(center + Vector2(-112, -68), Vector2(224, 78)), Color("#98663a"))
	draw_rect(Rect2(center + Vector2(-105, -61), Vector2(210, 64)), Color("#fff0c5"))

	# Текст рисуется отдельным Label в мире, а здесь оставляем аккуратную площадку.
	draw_circle(center + Vector2(-92, 34), 5.0, Color("#9dcf59"))
	draw_circle(center + Vector2(94, 28), 4.0, Color("#f2c759"))

func draw_ellipse_shape(center: Vector2, radius: Vector2, color: Color, count: int = 48) -> void:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func draw_world_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.05, 0.22, 0.10, 0.25), false, 18.0)


# -----------------------------------------------------------------------------
# ОБЪЕКТЫ МИРА
# -----------------------------------------------------------------------------

func create_world_objects() -> void:
	# Минимальный старт: амбар, силос и дом. Остальное игрок открывает сам.
	add_world_sprite(BARN_TEXTURE, Vector2(1010, 650), 405.0)
	add_world_sprite(SILO_TEXTURE, Vector2(720, 755), 160.0)
	add_world_sprite(HOUSE_TEXTURE, Vector2(1400, 665), 338.0)

	# Пекарня создаётся заранее, но видна только после покупки.
	bakery_world_root = Node2D.new()
	bakery_world_root.position = BAKERY_BUILD_POSITION
	bakery_world_root.z_index = int(BAKERY_BUILD_POSITION.y)
	add_child(bakery_world_root)
	add_sprite_to_root(bakery_world_root, BAKERY_TEXTURE, 300.0)

	# Деревья образуют естественную рамку, а центр остаётся свободным для игры.
	var round_trees: Array[Vector2] = [
		Vector2(250, 250), Vector2(420, 445), Vector2(275, 760),
		Vector2(315, 1125), Vector2(830, 1930), Vector2(1110, 2110),
		Vector2(1490, 2075), Vector2(2260, 2030), Vector2(3220, 1920),
		Vector2(3470, 1460), Vector2(3490, 820), Vector2(3350, 390),
		Vector2(3000, 260)
	]
	for pos in round_trees:
		add_world_sprite(TREE_ROUND_TEXTURE, pos, 205.0)

	for pos in [
		Vector2(100, 515), Vector2(145, 1010), Vector2(525, 2200),
		Vector2(1930, 2220), Vector2(2910, 2160), Vector2(3740, 1050),
		Vector2(3650, 340), Vector2(2700, 210)
	]:
		add_world_sprite(TREE_PINE_TEXTURE, pos, 160.0)

	for pos in [Vector2(505, 900), Vector2(2285, 535), Vector2(3130, 1570)]:
		add_world_sprite(TREE_APPLE_TEXTURE, pos, 215.0)

	for pos in [Vector2(510, 1435), Vector2(2340, 760), Vector2(2980, 1840)]:
		add_world_sprite(ROCK_FENCE_TEXTURE, pos, 265.0)

func add_world_sprite(texture: Texture2D, position: Vector2, target_width: float) -> Sprite2D:
	var root := Node2D.new()
	root.position = position
	root.z_index = int(position.y)
	add_child(root)

	var texture_size := texture.get_size()
	var scale_value := 1.0
	if texture_size.x > 0.0:
		scale_value = target_width / texture_size.x

	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.position = Vector2(16, 22)
	shadow.scale = Vector2(scale_value * 1.02, scale_value * 0.96)
	shadow.modulate = Color(0.04, 0.10, 0.04, 0.23)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.z_index = -1
	root.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(sprite)

	return sprite


# -----------------------------------------------------------------------------
# ГРЯДКИ И УРОЖАЙ
# -----------------------------------------------------------------------------

func add_sprite_to_root(root: Node2D, texture: Texture2D, target_width: float) -> Sprite2D:
	var texture_size := texture.get_size()
	var scale_value := 1.0
	if texture_size.x > 0.0:
		scale_value = target_width / texture_size.x

	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.position = Vector2(15, 21)
	shadow.scale = Vector2(scale_value * 1.02, scale_value * 0.96)
	shadow.modulate = Color(0.03, 0.08, 0.03, 0.22)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.z_index = -1
	root.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(sprite)
	return sprite


func create_field_plots() -> void:
	var positions: Array[Vector2] = [
		Vector2(1710, 1045),
		Vector2(2055, 1045),
		Vector2(1710, 1335),
		Vector2(2055, 1335)
	]

	for index in range(positions.size()):
		create_field_plot(index, positions[index])

func create_field_plot(index: int, position: Vector2) -> void:
	var root := Node2D.new()
	root.name = "Field_%d" % index
	root.position = position
	root.z_index = int(position.y)
	add_child(root)

	var shadow := Sprite2D.new()
	shadow.texture = FIELD_EMPTY_TEXTURE
	shadow.position = Vector2(10, 16)
	shadow.modulate = Color(0.03, 0.10, 0.03, 0.22)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(shadow)
	set_sprite_width(shadow, FIELD_EMPTY_TEXTURE, 326.0)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = FIELD_EMPTY_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(sprite)
	set_sprite_width(sprite, FIELD_EMPTY_TEXTURE, 320.0)

	var button := Button.new()
	button.name = "TouchArea"
	button.position = Vector2(-176, -105)
	button.size = Vector2(352, 210)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(on_field_pressed.bind(index))
	root.add_child(button)

	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(-95, -137)
	status.size = Vector2(190, 51)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_stylebox_override("normal", make_style(Color("#168b52"), Color("#0b653b"), 17, 3, true))
	status.visible = false
	root.add_child(status)

	field_plots.append({
		"root": root,
		"sprite": sprite,
		"shadow": shadow,
		"status": status,
		"state": "empty",
		"crop": "",
		"start_time": 0.0,
		"end_time": 0.0
	})


func set_sprite_width(sprite: Sprite2D, texture: Texture2D, target_width: float) -> void:
	sprite.texture = texture
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0:
		return
	var scale_value := target_width / texture_size.x
	sprite.scale = Vector2(scale_value, scale_value)


func on_field_pressed(index: int) -> void:
	if is_any_panel_open():
		return

	animate_field_tap(index)
	var field: Dictionary = field_plots[index]
	var state: String = str(field.get("state", "empty"))

	if state == "empty":
		open_seed_panel(index)
	elif state == "growing":
		var remaining := maxi(0, int(ceil(float(field["end_time"]) - Time.get_unix_time_from_system())))
		show_toast("Урожай ещё растёт: %d сек." % remaining)
	elif state == "ready":
		harvest_field(index)


func animate_field_tap(index: int) -> void:
	var root: Node2D = field_plots[index]["root"]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector2(1.035, 1.035), 0.09)
	tween.tween_property(root, "scale", Vector2.ONE, 0.14)


func open_seed_panel(index: int) -> void:
	selected_field = index
	seed_panel.visible = true
	update_seed_buttons()
	show_toast("Выбери семена")


func close_seed_panel() -> void:
	selected_field = -1
	seed_panel.visible = false


func plant_crop(crop_id: String) -> void:
	if selected_field < 0 or selected_field >= field_plots.size():
		return

	var crop: Dictionary = CROP_DATA[crop_id]
	var required_level := int(crop["unlock_level"])
	var cost := int(crop["plant_cost"])

	if level < required_level:
		show_toast("Откроется на %d уровне" % required_level)
		return

	if coins < cost:
		show_toast("Не хватает монет")
		return

	coins -= cost
	var now := Time.get_unix_time_from_system()
	var field: Dictionary = field_plots[selected_field]
	field["state"] = "growing"
	field["crop"] = crop_id
	field["start_time"] = now
	field["end_time"] = now + float(crop["grow_time"])
	field_plots[selected_field] = field

	update_field(selected_field)
	update_hud()
	save_game()
	show_toast("%s посажена" % str(crop["name"]).capitalize())
	close_seed_panel()


func harvest_field(index: int) -> void:
	var field: Dictionary = field_plots[index]
	var crop_id: String = str(field.get("crop", "wheat"))
	var crop: Dictionary = CROP_DATA[crop_id]
	var count := int(crop["harvest_count"])

	if inventory_total() + count > BARN_CAPACITY:
		show_toast("Амбар заполнен — продай часть урожая")
		return

	inventory[crop_id] = int(inventory.get(crop_id, 0)) + count
	if crop_id == "wheat":
		wheat_harvested += count

	field["state"] = "empty"
	field["crop"] = ""
	field["start_time"] = 0.0
	field["end_time"] = 0.0
	field_plots[index] = field

	add_xp(int(crop["xp"]))
	check_first_task()
	update_field(index)
	update_hud()
	update_barn_dialog()
	save_game()
	show_toast("+%d %s в амбар" % [count, str(crop["name"]).to_lower()])


func add_xp(amount: int) -> void:
	xp += amount
	var leveled_up := false

	while xp >= xp_needed_for_level(level):
		xp -= xp_needed_for_level(level)
		level += 1
		coins += 25
		leveled_up = true

	if leveled_up:
		show_toast("Новый уровень %d! +25 монет" % level)
		update_seed_buttons()
		update_build_dialog_state()
		queue_redraw()


func xp_needed_for_level(current_level: int) -> int:
	return 20 + (current_level - 1) * 15


func check_first_task() -> void:
	if first_task_completed:
		return

	if wheat_harvested >= 10:
		first_task_completed = true
		coins += 50
		show_toast("Цель выполнена! +50 монет")


func create_growth_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.35
	timer.autostart = true
	timer.timeout.connect(update_growth)
	add_child(timer)


func update_growth() -> void:
	update_bakery_job()
	var now := Time.get_unix_time_from_system()
	var changed := false

	for index in range(field_plots.size()):
		var field: Dictionary = field_plots[index]
		if str(field.get("state", "empty")) != "growing":
			continue

		if now >= float(field.get("end_time", 0.0)):
			field["state"] = "ready"
			field_plots[index] = field
			changed = true

		update_field(index)

	if changed:
		save_game()

	if bakery_dialog != null and bakery_dialog.visible:
		update_bakery_dialog()


func update_all_fields() -> void:
	for index in range(field_plots.size()):
		update_field(index)


func update_field(index: int) -> void:
	var field: Dictionary = field_plots[index]
	var sprite: Sprite2D = field["sprite"]
	var shadow: Sprite2D = field["shadow"]
	var status: Label = field["status"]
	var state: String = str(field.get("state", "empty"))

	if state == "empty":
		set_sprite_width(sprite, FIELD_EMPTY_TEXTURE, 320.0)
		set_sprite_width(shadow, FIELD_EMPTY_TEXTURE, 326.0)
		sprite.modulate = Color.WHITE
		sprite.position = Vector2.ZERO
		shadow.position = Vector2(10, 16)
		status.visible = false
		return

	var crop_id: String = str(field.get("crop", "wheat"))
	if not CROP_DATA.has(crop_id):
		crop_id = "wheat"
	var crop: Dictionary = CROP_DATA[crop_id]
	var texture: Texture2D = crop["texture"]

	if state == "growing":
		var now := Time.get_unix_time_from_system()
		var start_time := float(field.get("start_time", now))
		var end_time := float(field.get("end_time", now + 1.0))
		var duration := maxf(1.0, end_time - start_time)
		var progress := clampf((now - start_time) / duration, 0.0, 1.0)
		var width := lerpf(245.0, 322.0, progress)
		set_sprite_width(sprite, texture, width)
		set_sprite_width(shadow, texture, width + 6.0)
		sprite.modulate = Color(1.0, 1.0, 1.0, lerpf(0.76, 1.0, progress))
		sprite.position.y = lerpf(15.0, 0.0, progress)
		shadow.position = sprite.position + Vector2(10, 16)
		var remaining := maxi(0, int(ceil(end_time - now)))
		status.text = "%s  •  %d сек." % [str(crop["name"]), remaining]
		status.add_theme_stylebox_override("normal", make_style(Color("#b97c34"), Color("#85551f"), 17, 3, true))
		status.visible = true
	else:
		set_sprite_width(sprite, texture, 332.0)
		set_sprite_width(shadow, texture, 338.0)
		sprite.modulate = Color.WHITE
		sprite.position.y = -4.0
		shadow.position = Vector2(10, 14)
		status.text = "ГОТОВО  •  СОБРАТЬ"
		status.add_theme_stylebox_override("normal", make_style(Color("#22a65e"), Color("#0b713d"), 17, 3, true))
		status.visible = true


# -----------------------------------------------------------------------------
# ПОДПИСИ В МИРЕ
# -----------------------------------------------------------------------------

func create_world_labels() -> void:
	create_world_sign("GREEN TOWN FARM", Vector2(785, 292), Vector2(430, 58), Color("#fff0b8"), 20)
	create_world_sign("ПОЛЯ", Vector2(1745, 805), Vector2(225, 46), Color("#e8f5b4"), 18)
	bakery_site_label = create_world_sign("ПЕКАРНЯ\nУРОВЕНЬ 2", Vector2(2508, 712), Vector2(224, 74), Color("#fff1c8"), 16)
	chicken_site_label = create_world_sign("КУРОВНИК\nУРОВЕНЬ 3", Vector2(2698, 1390), Vector2(224, 74), Color("#fff1c8"), 16)


func create_world_sign(text: String, position: Vector2, size: Vector2, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#69472f"))
	label.add_theme_stylebox_override("normal", make_style(color, Color("#a97b45"), 17, 3, true))
	label.z_index = int(position.y)
	add_child(label)
	return label

# -----------------------------------------------------------------------------
# ИНТЕРФЕЙС
# -----------------------------------------------------------------------------

func create_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)

	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	create_top_hud(ui_root)
	create_task_panel(ui_root)
	create_bottom_menu(ui_root)
	create_zoom_buttons(ui_root)
	create_seed_panel(ui_root)
	create_modal_layer(ui_root)
	create_toast(ui_root)


func create_top_hud(root: Control) -> void:
	var top := PanelContainer.new()
	top.anchor_left = 0.018
	top.anchor_right = 0.982
	top.anchor_top = 0.018
	top.anchor_bottom = 0.018
	top.offset_bottom = 82.0
	top.add_theme_stylebox_override("panel", make_style(Color("#087b43"), Color("#075b35"), 28, 5, true))
	root.add_child(top)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	top.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var level_box := VBoxContainer.new()
	level_box.custom_minimum_size = Vector2(255, 0)
	row.add_child(level_box)

	var level_row := HBoxContainer.new()
	level_box.add_child(level_row)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_row.add_child(level_label)

	var level_space := Control.new()
	level_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level_space)

	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 16)
	xp_label.add_theme_color_override("font_color", Color("#eaffbf"))
	level_row.add_child(xp_label)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(255, 15)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", make_style(Color("#365b34"), Color.TRANSPARENT, 8, 0))
	xp_bar.add_theme_stylebox_override("fill", make_style(Color("#8ade4d"), Color.TRANSPARENT, 8, 0))
	level_box.add_child(xp_bar)

	var title := Label.new()
	title.text = "GREEN TOWN"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	warehouse_label = Label.new()
	warehouse_label.add_theme_font_size_override("font_size", 16)
	warehouse_label.add_theme_color_override("font_color", Color("#eaffbf"))
	row.add_child(warehouse_label)

	var coins_panel := make_resource_panel("МОНЕТЫ", Color("#f8d046"))
	row.add_child(coins_panel)
	coins_label = coins_panel.get_node("Margin/Row/Value") as Label

	var gems_panel := make_resource_panel("АЛМАЗЫ", Color("#67ddf2"))
	row.add_child(gems_panel)
	gems_label = gems_panel.get_node("Margin/Row/Value") as Label


func make_resource_panel(title_text: String, dot_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(176, 52)
	panel.add_theme_stylebox_override("panel", make_style(Color("#075f3b"), Color("#16935b"), 18, 3))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 17)
	dot.add_theme_color_override("font_color", dot_color)
	row.add_child(dot)

	var title := Label.new()
	title.text = title_text + ":"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	var value := Label.new()
	value.name = "Value"
	value.add_theme_font_size_override("font_size", 19)
	value.add_theme_color_override("font_color", Color("#fff0a4"))
	row.add_child(value)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(30, 30)
	plus.focus_mode = Control.FOCUS_NONE
	plus.add_theme_font_size_override("font_size", 17)
	plus.add_theme_color_override("font_color", Color.WHITE)
	plus.add_theme_stylebox_override("normal", make_style(Color("#63b94b"), Color("#3f8f34"), 10, 2))
	plus.add_theme_stylebox_override("pressed", make_style(Color("#4e9f3e"), Color("#367c2d"), 10, 2))
	plus.pressed.connect(show_toast.bind("Магазин валюты добавим позже"))
	row.add_child(plus)

	return panel


func create_task_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.135
	panel.anchor_right = 0.02
	panel.anchor_bottom = 0.135
	panel.offset_right = 310.0
	panel.offset_bottom = 142.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff0c9"), Color("#bd8650"), 22, 5, true))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ПЕРВАЯ ЦЕЛЬ"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(title)

	var description := Label.new()
	description.text = "Соберите 10 пшеницы"
	description.add_theme_font_size_override("font_size", 18)
	description.add_theme_color_override("font_color", Color("#503725"))
	column.add_child(description)

	var progress_row := HBoxContainer.new()
	column.add_child(progress_row)

	task_progress_bar = ProgressBar.new()
	task_progress_bar.max_value = 10
	task_progress_bar.show_percentage = false
	task_progress_bar.custom_minimum_size = Vector2(225, 18)
	task_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_progress_bar.add_theme_stylebox_override("background", make_style(Color("#d9b57a"), Color.TRANSPARENT, 9, 0))
	task_progress_bar.add_theme_stylebox_override("fill", make_style(Color("#35b34f"), Color.TRANSPARENT, 9, 0))
	progress_row.add_child(task_progress_bar)

	task_progress_label = Label.new()
	task_progress_label.custom_minimum_size = Vector2(52, 0)
	task_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	task_progress_label.add_theme_font_size_override("font_size", 15)
	task_progress_label.add_theme_color_override("font_color", Color("#765038"))
	progress_row.add_child(task_progress_label)


func create_bottom_menu(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -91.0
	panel.offset_bottom = -13.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#087644"), Color("#ead9a5"), 28, 5, true))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	for data in [
		["ФЕРМА", Color("#f3bd39")],
		["СТРОИТЬ", Color("#f08b48")],
		["АМБАР", Color("#5dc2e8")],
		["ЗАКАЗЫ", Color("#dc83bd")],
		["КАРТА", Color("#84ca62")]
	]:
		var button_color: Color = data[1]
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(142, 57)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("#493b2d"))
		button.add_theme_stylebox_override("normal", make_style(button_color, button_color.darkened(0.28), 18, 4, true))
		button.add_theme_stylebox_override("hover", make_style(button_color.lightened(0.07), button_color.darkened(0.28), 18, 4, true))
		button.add_theme_stylebox_override("pressed", make_style(button_color.darkened(0.10), button_color.darkened(0.32), 18, 4))
		button.pressed.connect(on_bottom_button_pressed.bind(str(data[0])))
		row.add_child(button)


func on_bottom_button_pressed(action: String) -> void:
	match action:
		"ФЕРМА":
			close_all_panels()
			focus_camera(START_CAMERA, START_ZOOM)
			show_toast("Ферма в центре")
		"СТРОИТЬ":
			open_build_dialog()
		"АМБАР":
			open_barn_dialog()
		"ЗАКАЗЫ":
			open_order_dialog()
		"КАРТА":
			close_all_panels()
			focus_camera(WORLD_SIZE * 0.5, MIN_ZOOM)


func create_zoom_buttons(root: Control) -> void:
	var column := VBoxContainer.new()
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_top = 0.55
	column.anchor_bottom = 0.55
	column.offset_left = -83.0
	column.offset_right = -20.0
	column.offset_top = -66.0
	column.offset_bottom = 72.0
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)

	for data in [["+", 0.10], ["−", -0.10]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(63, 61)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 28)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", make_style(Color("#087b55"), Color.WHITE, 19, 4, true))
		button.add_theme_stylebox_override("pressed", make_style(Color("#075f43"), Color.WHITE, 19, 4))
		button.pressed.connect(on_zoom_pressed.bind(float(data[1])))
		column.add_child(button)


func on_zoom_pressed(delta: float) -> void:
	set_camera_zoom(world_camera.zoom.x + delta)


# -----------------------------------------------------------------------------
# ПАНЕЛЬ СЕМЯН
# -----------------------------------------------------------------------------

func create_seed_panel(root: Control) -> void:
	seed_panel = PanelContainer.new()
	seed_panel.anchor_left = 0.5
	seed_panel.anchor_right = 0.5
	seed_panel.anchor_top = 1.0
	seed_panel.anchor_bottom = 1.0
	seed_panel.offset_left = -485.0
	seed_panel.offset_right = 485.0
	seed_panel.offset_top = -281.0
	seed_panel.offset_bottom = -104.0
	seed_panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 24, 5, true))
	seed_panel.visible = false
	root.add_child(seed_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 11)
	seed_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "ВЫБЕРИ СЕМЕНА"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(space)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(46, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_stylebox_override("normal", make_style(Color("#e98a68"), Color("#a14e35"), 12, 3))
	close_button.pressed.connect(close_seed_panel)
	title_row.add_child(close_button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 9)
	column.add_child(row)

	for crop_id in CROP_ORDER:
		var crop: Dictionary = CROP_DATA[crop_id]
		var card_color: Color = crop["card_color"]
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 91)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("#4d3525"))
		button.add_theme_stylebox_override("normal", make_style(card_color.lightened(0.19), card_color.darkened(0.25), 17, 4, true))
		button.add_theme_stylebox_override("hover", make_style(card_color.lightened(0.28), card_color.darkened(0.25), 17, 4, true))
		button.add_theme_stylebox_override("pressed", make_style(card_color, card_color.darkened(0.32), 17, 4))
		button.pressed.connect(plant_crop.bind(crop_id))
		row.add_child(button)
		seed_buttons[crop_id] = button

	update_seed_buttons()


func update_seed_buttons() -> void:
	if seed_buttons.is_empty():
		return

	for crop_id in CROP_ORDER:
		var button: Button = seed_buttons[crop_id]
		var crop: Dictionary = CROP_DATA[crop_id]
		var required_level := int(crop["unlock_level"])
		var cost := int(crop["plant_cost"])

		if level >= required_level:
			var cost_text := "БЕСПЛАТНО" if cost == 0 else "%d МОН." % cost
			button.text = "%s\n%s  •  %d СЕК." % [str(crop["name"]), cost_text, int(crop["grow_time"])]
			button.disabled = false
		else:
			button.text = "%s\nОТКРОЕТСЯ НА УР. %d" % [str(crop["name"]), required_level]
			button.disabled = true


# -----------------------------------------------------------------------------
# МОДАЛЬНЫЕ ОКНА: АМБАР И СТРОИТЕЛЬСТВО
# -----------------------------------------------------------------------------

func create_modal_layer(root: Control) -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.visible = false
	root.add_child(modal_layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.10, 0.06, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)

	barn_dialog = create_barn_dialog(modal_layer)
	build_dialog = create_build_dialog(modal_layer)
	order_dialog = create_order_dialog(modal_layer)
	bakery_dialog = create_bakery_dialog(modal_layer)


func create_barn_dialog(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390.0
	panel.offset_right = 390.0
	panel.offset_top = -245.0
	panel.offset_bottom = 245.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 28, 6, true))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "АМБАР"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(space)

	var close := make_close_button()
	close.pressed.connect(close_all_panels)
	title_row.add_child(close)

	var capacity := Label.new()
	capacity.name = "Capacity"
	capacity.add_theme_font_size_override("font_size", 19)
	capacity.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(capacity)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)

	for crop_id in CROP_ORDER:
		var crop: Dictionary = CROP_DATA[crop_id]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(350, 132)
		var card_color: Color = crop["card_color"]
		card.add_theme_stylebox_override("panel", make_style(card_color.lightened(0.28), card_color.darkened(0.26), 19, 4, true))
		grid.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 18)
		card_margin.add_theme_constant_override("margin_right", 18)
		card_margin.add_theme_constant_override("margin_top", 13)
		card_margin.add_theme_constant_override("margin_bottom", 13)
		card.add_child(card_margin)

		var card_row := HBoxContainer.new()
		card_row.add_theme_constant_override("separation", 14)
		card_margin.add_child(card_row)

		var preview := TextureRect.new()
		preview.texture = crop["texture"]
		preview.custom_minimum_size = Vector2(120, 92)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_row.add_child(preview)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		card_row.add_child(info)

		var name_label := Label.new()
		name_label.text = str(crop["name"])
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", Color("#4e3524"))
		info.add_child(name_label)

		var value := Label.new()
		value.name = "Value_%s" % crop_id
		value.add_theme_font_size_override("font_size", 28)
		value.add_theme_color_override("font_color", Color("#2d5f31"))
		info.add_child(value)

	var bread_card := PanelContainer.new()
	bread_card.custom_minimum_size = Vector2(350, 132)
	bread_card.add_theme_stylebox_override("panel", make_style(Color("#f7d99a"), Color("#b77a37"), 19, 4, true))
	grid.add_child(bread_card)

	var bread_margin := MarginContainer.new()
	bread_margin.add_theme_constant_override("margin_left", 18)
	bread_margin.add_theme_constant_override("margin_right", 18)
	bread_margin.add_theme_constant_override("margin_top", 13)
	bread_margin.add_theme_constant_override("margin_bottom", 13)
	bread_card.add_child(bread_margin)

	var bread_row := HBoxContainer.new()
	bread_row.add_theme_constant_override("separation", 14)
	bread_margin.add_child(bread_row)

	var bread_icon := Label.new()
	bread_icon.text = "ХЛЕБ"
	bread_icon.custom_minimum_size = Vector2(120, 92)
	bread_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bread_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bread_icon.add_theme_font_size_override("font_size", 21)
	bread_icon.add_theme_color_override("font_color", Color("#7f4e20"))
	bread_row.add_child(bread_icon)

	var bread_info := VBoxContainer.new()
	bread_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bread_info.alignment = BoxContainer.ALIGNMENT_CENTER
	bread_row.add_child(bread_info)

	var bread_name := Label.new()
	bread_name.text = "ХЛЕБ"
	bread_name.add_theme_font_size_override("font_size", 19)
	bread_name.add_theme_color_override("font_color", Color("#4e3524"))
	bread_info.add_child(bread_name)

	var bread_value := Label.new()
	bread_value.name = "Value_bread"
	bread_value.add_theme_font_size_override("font_size", 28)
	bread_value.add_theme_color_override("font_color", Color("#2d5f31"))
	bread_info.add_child(bread_value)

	var sell_card := PanelContainer.new()
	sell_card.custom_minimum_size = Vector2(350, 132)
	sell_card.add_theme_stylebox_override("panel", make_style(Color("#d9efd1"), Color("#6b9a5b"), 19, 4, true))
	grid.add_child(sell_card)

	var sell_margin := MarginContainer.new()
	sell_margin.add_theme_constant_override("margin_left", 16)
	sell_margin.add_theme_constant_override("margin_right", 16)
	sell_margin.add_theme_constant_override("margin_top", 14)
	sell_margin.add_theme_constant_override("margin_bottom", 14)
	sell_card.add_child(sell_margin)

	var sell_column := VBoxContainer.new()
	sell_column.alignment = BoxContainer.ALIGNMENT_CENTER
	sell_column.add_theme_constant_override("separation", 7)
	sell_margin.add_child(sell_column)

	var sell_title := Label.new()
	sell_title.text = "БЫСТРАЯ ПРОДАЖА"
	sell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_title.add_theme_font_size_override("font_size", 18)
	sell_title.add_theme_color_override("font_color", Color("#315f31"))
	sell_column.add_child(sell_title)

	var sell_button := Button.new()
	sell_button.text = "ПРОДАТЬ 1 ПШЕНИЦУ  +3"
	sell_button.custom_minimum_size = Vector2(300, 47)
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.add_theme_font_size_override("font_size", 16)
	sell_button.add_theme_stylebox_override("normal", make_style(Color("#79c95d"), Color("#4c8d3c"), 14, 3, true))
	sell_button.pressed.connect(sell_one_item.bind("wheat"))
	sell_column.add_child(sell_button)

	var hint := Label.new()
	hint.text = "Урожай из грядок автоматически попадает сюда"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(hint)

	return panel


func create_build_dialog(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470.0
	panel.offset_right = 470.0
	panel.offset_top = -270.0
	panel.offset_bottom = 270.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 28, 6, true))
	panel.visible = false
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "СТРОИТЕЛЬСТВО"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(space)

	var close := make_close_button()
	close.pressed.connect(close_all_panels)
	title_row.add_child(close)

	var subtitle := Label.new()
	subtitle.text = "Покупай здания по уровню. В MVP они автоматически занимают подготовленную площадку."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 14)
	column.add_child(cards)

	create_bakery_build_card(cards)
	create_locked_build_card(cards, BARN_TEXTURE, "КУРОВНИК", "Уровень 3", "250 монет")
	create_locked_build_card(cards, SILO_TEXTURE, "МОЛОЧНЫЙ ЦЕХ", "Уровень 5", "480 монет")

	var hint := Label.new()
	hint.text = "После покупки пекарня появится на карте и начнёт производить хлеб из пшеницы."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(hint)

	return panel

func create_bakery_build_card(parent: Control) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 336)
	card.add_theme_stylebox_override("panel", make_style(Color("#fff6dc"), Color("#b78955"), 21, 4, true))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var preview := TextureRect.new()
	preview.texture = BAKERY_TEXTURE
	preview.custom_minimum_size = Vector2(235, 170)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	column.add_child(preview)

	var title := Label.new()
	title.text = "ПЕКАРНЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#4e3524"))
	column.add_child(title)

	bakery_card_status = Label.new()
	bakery_card_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bakery_card_status.add_theme_font_size_override("font_size", 17)
	bakery_card_status.add_theme_color_override("font_color", Color("#815a39"))
	column.add_child(bakery_card_status)

	bakery_build_button = Button.new()
	bakery_build_button.custom_minimum_size = Vector2(220, 47)
	bakery_build_button.focus_mode = Control.FOCUS_NONE
	bakery_build_button.add_theme_font_size_override("font_size", 17)
	bakery_build_button.add_theme_stylebox_override("normal", make_style(Color("#78c957"), Color("#4d9539"), 15, 3, true))
	bakery_build_button.add_theme_stylebox_override("pressed", make_style(Color("#62b646"), Color("#3d7d2e"), 15, 3))
	bakery_build_button.add_theme_stylebox_override("disabled", make_style(Color("#bbb5a6"), Color("#8e887a"), 15, 3))
	bakery_build_button.pressed.connect(on_bakery_build_button_pressed)
	column.add_child(bakery_build_button)


func create_locked_build_card(parent: Control, texture: Texture2D, title_text: String, level_text: String, price_text: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 336)
	card.add_theme_stylebox_override("panel", make_style(Color("#e4ddc9"), Color("#a39a86"), 21, 4, true))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(235, 170)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview.modulate = Color(0.72, 0.72, 0.72, 0.86)
	column.add_child(preview)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#5d5549"))
	column.add_child(title)

	var unlock := Label.new()
	unlock.text = level_text + "  •  " + price_text
	unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock.add_theme_font_size_override("font_size", 16)
	unlock.add_theme_color_override("font_color", Color("#7b7468"))
	column.add_child(unlock)

	var button := Button.new()
	button.text = "СКОРО"
	button.custom_minimum_size = Vector2(220, 47)
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("disabled", make_style(Color("#bbb5a6"), Color("#8e887a"), 15, 3))
	column.add_child(button)

func make_close_button() -> Button:
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(52, 43)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 27)
	close.add_theme_stylebox_override("normal", make_style(Color("#e98a68"), Color("#a14e35"), 14, 3))
	close.add_theme_stylebox_override("pressed", make_style(Color("#d97556"), Color("#923f2c"), 14, 3))
	return close


func open_barn_dialog() -> void:
	close_seed_panel()
	modal_layer.visible = true
	barn_dialog.visible = true
	build_dialog.visible = false
	order_dialog.visible = false
	bakery_dialog.visible = false
	update_barn_dialog()

func open_build_dialog() -> void:
	close_seed_panel()
	modal_layer.visible = true
	barn_dialog.visible = false
	order_dialog.visible = false
	bakery_dialog.visible = false
	build_dialog.visible = true
	update_build_dialog_state()

func close_all_panels() -> void:
	close_seed_panel()
	if modal_layer != null:
		modal_layer.visible = false


func update_barn_dialog() -> void:
	if barn_dialog == null:
		return

	var capacity := barn_dialog.find_child("Capacity", true, false) as Label
	if capacity != null:
		capacity.text = "Заполнено: %d / %d" % [inventory_total(), BARN_CAPACITY]

	for crop_id in STORAGE_ORDER:
		var value := barn_dialog.find_child("Value_%s" % crop_id, true, false) as Label
		if value != null:
			value.text = str(int(inventory.get(crop_id, 0)))


# -----------------------------------------------------------------------------
# MVP: ПОСТРОЙКИ, ПЕКАРНЯ И ЗАКАЗЫ
# -----------------------------------------------------------------------------

func update_building_visuals() -> void:
	if bakery_world_root != null:
		bakery_world_root.visible = bakery_built
	if bakery_site_label != null:
		bakery_site_label.visible = not bakery_built
	queue_redraw()
	update_build_dialog_state()


func update_build_dialog_state() -> void:
	if bakery_build_button == null or bakery_card_status == null:
		return

	if bakery_built:
		bakery_card_status.text = "ПОСТРОЕНО"
		bakery_build_button.text = "ОТКРЫТЬ ПЕКАРНЮ"
		bakery_build_button.disabled = false
	elif level < 2:
		bakery_card_status.text = "ОТКРОЕТСЯ НА 2 УРОВНЕ"
		bakery_build_button.text = "ЗАКРЫТО"
		bakery_build_button.disabled = true
	else:
		bakery_card_status.text = "СТОИМОСТЬ: %d МОНЕТ" % BAKERY_PRICE
		bakery_build_button.text = "ПОСТРОИТЬ"
		bakery_build_button.disabled = coins < BAKERY_PRICE


func on_bakery_build_button_pressed() -> void:
	if bakery_built:
		open_bakery_dialog()
		return

	if level < 2:
		show_toast("Пекарня откроется на 2 уровне")
		return
	if coins < BAKERY_PRICE:
		show_toast("Нужно %d монет" % BAKERY_PRICE)
		return

	coins -= BAKERY_PRICE
	bakery_built = true
	update_building_visuals()
	update_hud()
	save_game()
	close_all_panels()
	focus_camera(BAKERY_BUILD_POSITION, 1.02)
	show_toast("Пекарня построена!")


func create_bakery_dialog(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390.0
	panel.offset_right = 390.0
	panel.offset_top = -235.0
	panel.offset_bottom = 235.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 28, 6, true))
	panel.visible = false
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "ПЕКАРНЯ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	var close := make_close_button()
	close.pressed.connect(close_all_panels)
	title_row.add_child(close)

	bakery_summary_label = Label.new()
	bakery_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bakery_summary_label.add_theme_font_size_override("font_size", 20)
	bakery_summary_label.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(bakery_summary_label)

	var recipe := PanelContainer.new()
	recipe.add_theme_stylebox_override("panel", make_style(Color("#f8dca2"), Color("#bb7d39"), 22, 4, true))
	column.add_child(recipe)

	var recipe_margin := MarginContainer.new()
	recipe_margin.add_theme_constant_override("margin_left", 20)
	recipe_margin.add_theme_constant_override("margin_right", 20)
	recipe_margin.add_theme_constant_override("margin_top", 18)
	recipe_margin.add_theme_constant_override("margin_bottom", 18)
	recipe.add_child(recipe_margin)

	var recipe_row := HBoxContainer.new()
	recipe_row.add_theme_constant_override("separation", 18)
	recipe_margin.add_child(recipe_row)

	var recipe_text := Label.new()
	recipe_text.text = "2 ПШЕНИЦЫ  →  1 ХЛЕБ\nВремя: 15 секунд"
	recipe_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recipe_text.add_theme_font_size_override("font_size", 22)
	recipe_text.add_theme_color_override("font_color", Color("#5a3a22"))
	recipe_row.add_child(recipe_text)

	var start_button := Button.new()
	start_button.name = "StartBread"
	start_button.text = "ПРИГОТОВИТЬ"
	start_button.custom_minimum_size = Vector2(220, 62)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_size_override("font_size", 18)
	start_button.add_theme_stylebox_override("normal", make_style(Color("#79c957"), Color("#4d9539"), 17, 3, true))
	start_button.add_theme_stylebox_override("disabled", make_style(Color("#bbb5a6"), Color("#8e887a"), 17, 3))
	start_button.pressed.connect(start_bread_production)
	recipe_row.add_child(start_button)

	var hint := Label.new()
	hint.text = "Хлеб попадает в амбар. Его можно использовать в заказах или продать."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(hint)

	return panel


func open_bakery_dialog() -> void:
	if not bakery_built:
		show_toast("Сначала построй пекарню")
		return
	close_seed_panel()
	modal_layer.visible = true
	barn_dialog.visible = false
	build_dialog.visible = false
	order_dialog.visible = false
	bakery_dialog.visible = true
	update_bakery_dialog()


func start_bread_production() -> void:
	if bakery_job_active:
		show_toast("Пекарня уже работает")
		return
	if int(inventory.get("wheat", 0)) < 2:
		show_toast("Нужно 2 пшеницы")
		return
	if inventory_total() >= BARN_CAPACITY:
		show_toast("Освободи место в амбаре")
		return

	inventory["wheat"] = int(inventory.get("wheat", 0)) - 2
	bakery_job_active = true
	bakery_job_end = Time.get_unix_time_from_system() + 15.0
	update_all_dialogs()
	update_hud()
	save_game()
	show_toast("Пекарня начала готовить хлеб")


func update_bakery_job() -> void:
	if not bakery_job_active:
		return
	if Time.get_unix_time_from_system() < bakery_job_end:
		return

	bakery_job_active = false
	bakery_job_end = 0.0
	inventory["bread"] = int(inventory.get("bread", 0)) + 1
	update_all_dialogs()
	update_hud()
	save_game()
	show_toast("Хлеб готов и отправлен в амбар")


func get_bakery_summary() -> String:
	if not bakery_built:
		return "Пекарня ещё не построена"
	if not bakery_job_active:
		return "Пекарня свободна"
	var remaining := maxi(0, int(ceil(bakery_job_end - Time.get_unix_time_from_system())))
	return "Готовим хлеб: %d сек." % remaining


func update_bakery_dialog() -> void:
	if bakery_dialog == null:
		return
	if bakery_summary_label != null:
		bakery_summary_label.text = get_bakery_summary()
	var start_button := bakery_dialog.find_child("StartBread", true, false) as Button
	if start_button != null:
		start_button.disabled = bakery_job_active or int(inventory.get("wheat", 0)) < 2 or inventory_total() >= BARN_CAPACITY
		start_button.text = "ГОТОВИМ..." if bakery_job_active else "ПРИГОТОВИТЬ"


func ensure_current_order() -> void:
	if current_order.is_empty():
		generate_new_order()


func generate_new_order() -> void:
	var templates: Array[Dictionary] = [
		{"item": "wheat", "amount": 6, "reward": 42, "xp": 8},
		{"item": "corn", "amount": 4, "reward": 48, "xp": 10},
		{"item": "tomato", "amount": 3, "reward": 56, "xp": 12},
		{"item": "carrot", "amount": 4, "reward": 54, "xp": 11},
		{"item": "bread", "amount": 2, "reward": 72, "xp": 15}
	]

	var available: Array[Dictionary] = []
	for template in templates:
		var item_id := str(template.get("item", "wheat"))
		if item_id == "bread" and not bakery_built:
			continue
		if item_id == "corn" and level < 2:
			continue
		if item_id == "tomato" and level < 3:
			continue
		if item_id == "carrot" and level < 4:
			continue
		available.append(template)

	if available.is_empty():
		available.append(templates[0])

	current_order = available[order_index % available.size()].duplicate(true)
	order_index += 1


func create_order_dialog(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -410.0
	panel.offset_right = 410.0
	panel.offset_top = -235.0
	panel.offset_bottom = 235.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 28, 6, true))
	panel.visible = false
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "ДОСКА ЗАКАЗОВ"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	var close := make_close_button()
	close.pressed.connect(close_all_panels)
	title_row.add_child(close)

	var order_card := PanelContainer.new()
	order_card.add_theme_stylebox_override("panel", make_style(Color("#f7dfaa"), Color("#bb7d39"), 24, 4, true))
	column.add_child(order_card)

	var order_margin := MarginContainer.new()
	order_margin.add_theme_constant_override("margin_left", 24)
	order_margin.add_theme_constant_override("margin_right", 24)
	order_margin.add_theme_constant_override("margin_top", 22)
	order_margin.add_theme_constant_override("margin_bottom", 22)
	order_card.add_child(order_margin)

	var order_column := VBoxContainer.new()
	order_column.add_theme_constant_override("separation", 12)
	order_margin.add_child(order_column)

	order_summary_label = Label.new()
	order_summary_label.name = "OrderSummary"
	order_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_summary_label.add_theme_font_size_override("font_size", 25)
	order_summary_label.add_theme_color_override("font_color", Color("#573923"))
	order_column.add_child(order_summary_label)

	var progress := Label.new()
	progress.name = "OrderProgress"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 20)
	progress.add_theme_color_override("font_color", Color("#765038"))
	order_column.add_child(progress)

	var deliver := Button.new()
	deliver.name = "DeliverOrder"
	deliver.text = "ОТПРАВИТЬ ЗАКАЗ"
	deliver.custom_minimum_size = Vector2(350, 58)
	deliver.focus_mode = Control.FOCUS_NONE
	deliver.add_theme_font_size_override("font_size", 19)
	deliver.add_theme_stylebox_override("normal", make_style(Color("#69bd52"), Color("#438a34"), 17, 3, true))
	deliver.add_theme_stylebox_override("disabled", make_style(Color("#bbb5a6"), Color("#8e887a"), 17, 3))
	deliver.pressed.connect(fulfill_current_order)
	order_column.add_child(deliver)

	var hint := Label.new()
	hint.text = "Заказы — главный источник монет и опыта в MVP."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(hint)

	return panel


func open_order_dialog() -> void:
	ensure_current_order()
	close_seed_panel()
	modal_layer.visible = true
	barn_dialog.visible = false
	build_dialog.visible = false
	bakery_dialog.visible = false
	order_dialog.visible = true
	update_order_dialog()


func get_order_summary() -> String:
	ensure_current_order()
	var item_id := str(current_order.get("item", "wheat"))
	var amount := int(current_order.get("amount", 1))
	var reward := int(current_order.get("reward", 1))
	var xp_reward := int(current_order.get("xp", 1))
	return "%d × %s   →   +%d монет, +%d опыта" % [amount, PRODUCT_NAMES.get(item_id, item_id), reward, xp_reward]


func update_order_dialog() -> void:
	if order_dialog == null:
		return
	ensure_current_order()
	if order_summary_label != null:
		order_summary_label.text = get_order_summary()

	var item_id := str(current_order.get("item", "wheat"))
	var amount := int(current_order.get("amount", 1))
	var have := int(inventory.get(item_id, 0))
	var progress := order_dialog.find_child("OrderProgress", true, false) as Label
	if progress != null:
		progress.text = "В амбаре: %d / %d" % [have, amount]
	var deliver := order_dialog.find_child("DeliverOrder", true, false) as Button
	if deliver != null:
		deliver.disabled = have < amount


func fulfill_current_order() -> void:
	ensure_current_order()
	var item_id := str(current_order.get("item", "wheat"))
	var amount := int(current_order.get("amount", 1))
	if int(inventory.get(item_id, 0)) < amount:
		show_toast("Не хватает товара для заказа")
		return

	inventory[item_id] = int(inventory.get(item_id, 0)) - amount
	coins += int(current_order.get("reward", 0))
	add_xp(int(current_order.get("xp", 0)))
	generate_new_order()
	update_all_dialogs()
	update_hud()
	save_game()
	show_toast("Заказ отправлен!")


func sell_one_item(item_id: String) -> void:
	if int(inventory.get(item_id, 0)) <= 0:
		show_toast("В амбаре нет товара")
		return
	var price := int(SELL_PRICES.get(item_id, 1))
	inventory[item_id] = int(inventory.get(item_id, 0)) - 1
	coins += price
	update_all_dialogs()
	update_hud()
	save_game()
	show_toast("Продано: +%d монет" % price)


func update_all_dialogs() -> void:
	update_barn_dialog()
	update_bakery_dialog()
	update_order_dialog()
	update_build_dialog_state()


# -----------------------------------------------------------------------------
# TOAST, HUD И СТИЛИ
# -----------------------------------------------------------------------------

func create_toast(root: Control) -> void:
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.14
	toast_panel.anchor_bottom = 0.14
	toast_panel.offset_left = -260.0
	toast_panel.offset_right = 260.0
	toast_panel.offset_bottom = 58.0
	toast_panel.add_theme_stylebox_override("panel", make_style(Color(0.05, 0.33, 0.20, 0.95), Color("#6ed36d"), 19, 3, true))
	toast_panel.visible = false
	root.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 19)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_panel.add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 2.25
	toast_timer.timeout.connect(hide_toast)
	add_child(toast_timer)


func show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_panel.visible = true
	toast_timer.start()


func hide_toast() -> void:
	toast_panel.visible = false


func update_hud() -> void:
	if coins_label == null:
		return

	coins_label.text = str(coins)
	gems_label.text = str(gems)
	level_label.text = "УРОВЕНЬ %d" % level
	var required_xp := xp_needed_for_level(level)
	xp_label.text = "%d/%d" % [xp, required_xp]
	xp_bar.max_value = required_xp
	xp_bar.value = xp

	warehouse_label.text = "АМБАР: %d/%d" % [inventory_total(), BARN_CAPACITY]
	if order_summary_label != null:
		order_summary_label.text = get_order_summary()
	if bakery_summary_label != null:
		bakery_summary_label.text = get_bakery_summary()
	task_progress_bar.value = mini(wheat_harvested, 10)
	if first_task_completed:
		task_progress_label.text = "ГОТОВО ✓"
	else:
		task_progress_label.text = "%d/10" % mini(wheat_harvested, 10)


func inventory_total() -> int:
	var total := 0
	for item_id in STORAGE_ORDER:
		total += int(inventory.get(item_id, 0))
	return total

func make_style(fill: Color, border: Color, radius: int, border_width: int, with_shadow := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border

	if with_shadow:
		style.shadow_color = Color(0.05, 0.12, 0.05, 0.22)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)

	return style


# -----------------------------------------------------------------------------
# СОХРАНЕНИЕ
# -----------------------------------------------------------------------------

func save_game() -> void:
	var saved_fields: Array = []
	for field in field_plots:
		saved_fields.append({
			"state": field.get("state", "empty"),
			"crop": field.get("crop", ""),
			"start_time": field.get("start_time", 0.0),
			"end_time": field.get("end_time", 0.0)
		})

	var data := {
		"coins": coins,
		"gems": gems,
		"level": level,
		"xp": xp,
		"inventory": inventory,
		"wheat_harvested": wheat_harvested,
		"first_task_completed": first_task_completed,
		"bakery_built": bakery_built,
		"bakery_job_active": bakery_job_active,
		"bakery_job_end": bakery_job_end,
		"order_index": order_index,
		"current_order": current_order,
		"fields": saved_fields
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	coins = int(parsed.get("coins", coins))
	gems = int(parsed.get("gems", gems))
	level = maxi(1, int(parsed.get("level", level)))
	xp = maxi(0, int(parsed.get("xp", xp)))
	wheat_harvested = maxi(0, int(parsed.get("wheat_harvested", wheat_harvested)))
	first_task_completed = bool(parsed.get("first_task_completed", first_task_completed))
	bakery_built = bool(parsed.get("bakery_built", bakery_built))
	bakery_job_active = bool(parsed.get("bakery_job_active", bakery_job_active))
	bakery_job_end = float(parsed.get("bakery_job_end", bakery_job_end))
	order_index = maxi(0, int(parsed.get("order_index", order_index)))
	var saved_order = parsed.get("current_order", {})
	if saved_order is Dictionary:
		current_order = saved_order

	var saved_inventory = parsed.get("inventory", {})
	if saved_inventory is Dictionary:
		for item_id in STORAGE_ORDER:
			inventory[item_id] = maxi(0, int(saved_inventory.get(item_id, 0)))

	var saved_fields = parsed.get("fields", [])
	if saved_fields is Array:
		for index in range(mini(saved_fields.size(), field_plots.size())):
			var saved = saved_fields[index]
			if not (saved is Dictionary):
				continue
			var field: Dictionary = field_plots[index]
			field["state"] = str(saved.get("state", "empty"))
			field["crop"] = str(saved.get("crop", ""))
			field["start_time"] = float(saved.get("start_time", 0.0))
			field["end_time"] = float(saved.get("end_time", 0.0))
			if str(field["state"]) == "growing" and Time.get_unix_time_from_system() >= float(field["end_time"]):
				field["state"] = "ready"
			field_plots[index] = field


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
