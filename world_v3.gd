extends Node2D

# GREEN TOWN — стартовая ферма в духе уютных мобильных градостроительных игр.
# Здесь уже используются настоящие прозрачные игровые ассеты, пустые грядки,
# выбор семян, рост по таймеру, сбор урожая, опыт и сохранение.

const WORLD_SIZE := Vector2(3000.0, 1900.0)
const MIN_ZOOM := 0.58
const MAX_ZOOM := 1.35
const SAVE_PATH := "user://green_town_world_v2.json"

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

const CROP_DATA := {
	"wheat": {
		"name": "ПШЕНИЦА",
		"texture": FIELD_WHEAT_TEXTURE,
		"grow_time": 12.0,
		"unlock_level": 1,
		"plant_cost": 0,
		"harvest_count": 2,
		"xp": 3
	},
	"corn": {
		"name": "КУКУРУЗА",
		"texture": FIELD_CORN_TEXTURE,
		"grow_time": 20.0,
		"unlock_level": 2,
		"plant_cost": 1,
		"harvest_count": 2,
		"xp": 5
	},
	"tomato": {
		"name": "ТОМАТЫ",
		"texture": FIELD_TOMATO_TEXTURE,
		"grow_time": 30.0,
		"unlock_level": 3,
		"plant_cost": 2,
		"harvest_count": 2,
		"xp": 7
	},
	"carrot": {
		"name": "МОРКОВЬ",
		"texture": FIELD_CARROT_TEXTURE,
		"grow_time": 24.0,
		"unlock_level": 4,
		"plant_cost": 2,
		"harvest_count": 2,
		"xp": 6
	}
}

var world_camera: Camera2D
var active_touches: Dictionary = {}
var last_pinch_distance := 0.0
var mouse_dragging := false
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
	"carrot": 0
}
var wheat_harvested := 0
var first_task_completed := false

var coins_label: Label
var gems_label: Label
var level_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var task_progress_bar: ProgressBar
var task_progress_label: Label
var warehouse_label: Label
var seed_panel: PanelContainer
var seed_buttons: Dictionary = {}
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer


func _ready() -> void:
	rng.seed = 4202407
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	create_camera()
	create_world_objects()
	create_field_plots()
	create_world_labels()
	create_interface()
	load_game()
	update_all_fields()
	update_hud()
	create_growth_timer()
	queue_redraw()


func create_camera() -> void:
	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.enabled = true
	world_camera.position = Vector2(1390.0, 930.0)
	world_camera.zoom = Vector2(0.78, 0.78)
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
	world_camera.position.x = clampf(world_camera.position.x, 320.0, WORLD_SIZE.x - 320.0)
	world_camera.position.y = clampf(world_camera.position.y, 250.0, WORLD_SIZE.y - 250.0)


func _draw() -> void:
	draw_ground()
	draw_water()
	draw_roads()
	draw_start_area()
	draw_build_areas()
	draw_world_border()


func draw_ground() -> void:
	draw_texture_rect(
		GRASS_TEXTURE,
		Rect2(Vector2.ZERO, WORLD_SIZE),
		true,
		Color.WHITE
	)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 914722

	for i in range(130):
		var pos := Vector2(
			local_rng.randf_range(60.0, WORLD_SIZE.x - 60.0),
			local_rng.randf_range(60.0, WORLD_SIZE.y - 60.0)
		)
		var radius := local_rng.randf_range(25.0, 78.0)
		var patch_color := Color("#d7ef76") if i % 2 == 0 else Color("#2d8f3f")
		patch_color.a = 0.045
		draw_circle(pos, radius, patch_color)

	# Маленькие цветы и травинки не дают земле выглядеть плоской.
	for i in range(170):
		var pos := Vector2(
			local_rng.randf_range(70.0, WORLD_SIZE.x - 70.0),
			local_rng.randf_range(70.0, WORLD_SIZE.y - 70.0)
		)
		if pos.distance_to(Vector2(1450, 1050)) < 700.0:
			continue
		var grass_color := Color("#3c9b42") if i % 3 else Color("#f7e567")
		draw_circle(pos, local_rng.randf_range(2.0, 4.5), grass_color)


func draw_water() -> void:
	var center := Vector2(250.0, 1590.0)
	draw_colored_polygon(ellipse_points(center + Vector2(18, 18), 560.0, 350.0), Color(0.08, 0.22, 0.16, 0.18))
	draw_colored_polygon(ellipse_points(center, 560.0, 350.0), Color("#e7cf82"))
	draw_colored_polygon(ellipse_points(center, 525.0, 320.0), Color("#168cb8"))
	draw_colored_polygon(ellipse_points(center + Vector2(-15, -12), 495.0, 290.0), Color("#39b8dc"))
	draw_colored_polygon(ellipse_points(center + Vector2(-120, -80), 270.0, 130.0), Color(0.45, 0.90, 0.96, 0.44))

	for wave_pos in [Vector2(75, 1505), Vector2(260, 1680), Vector2(430, 1510), Vector2(160, 1770)]:
		draw_arc(wave_pos, 34.0, 0.2, 2.7, 16, Color(1, 1, 1, 0.38), 5.0, true)

	# Небольшой деревянный причал.
	draw_rect(Rect2(390, 1370, 300, 48), Color("#8c5a33"))
	for x in range(405, 680, 42):
		draw_rect(Rect2(x, 1358, 12, 82), Color("#684126"))
		draw_line(Vector2(x - 7, 1380), Vector2(x + 31, 1380), Color("#d89d58"), 4.0)


func ellipse_points(center: Vector2, radius_x: float, radius_y: float, count := 64) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func draw_roads() -> void:
	var main_path := PackedVector2Array([
		Vector2(540, 1090),
		Vector2(900, 970),
		Vector2(1250, 980),
		Vector2(1510, 1110),
		Vector2(1990, 1120),
		Vector2(2460, 1010)
	])
	draw_road(main_path, 92.0)

	var barn_path := PackedVector2Array([
		Vector2(930, 970),
		Vector2(860, 760),
		Vector2(920, 560)
	])
	draw_road(barn_path, 72.0)

	var field_path := PackedVector2Array([
		Vector2(1500, 1090),
		Vector2(1680, 900),
		Vector2(1860, 740)
	])
	draw_road(field_path, 68.0)


func draw_road(points: PackedVector2Array, width: float) -> void:
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(8, 11))
	draw_polyline(shadow_points, Color(0.18, 0.23, 0.11, 0.18), width + 25.0, true)
	draw_polyline(points, Color("#a46c3b"), width + 18.0, true)
	draw_polyline(points, Color("#e2b865"), width + 8.0, true)
	draw_polyline(points, Color("#f1cf82"), width - 4.0, true)
	draw_polyline(points, Color(1, 0.96, 0.72, 0.18), width * 0.33, true)


func draw_start_area() -> void:
	# Мягкая зона вокруг стартовых зданий. Она не выглядит отдельной плитой,
	# но слегка выделяет центр фермы.
	draw_rounded_rect(
		Rect2(545, 285, 1090, 710),
		70.0,
		Color(0.66, 0.88, 0.38, 0.20),
		Color(0.30, 0.62, 0.20, 0.20),
		8.0
	)


func draw_build_areas() -> void:
	draw_build_pad(Rect2(2250, 510, 420, 290), "ПЕКАРНЯ", 2)
	draw_build_pad(Rect2(2270, 1170, 430, 300), "КУРОВНИК", 3)


func draw_build_pad(rect: Rect2, title: String, required_level: int) -> void:
	draw_rounded_rect(Rect2(rect.position + Vector2(12, 14), rect.size), 38.0, Color(0, 0, 0, 0.12), Color.TRANSPARENT, 0.0)
	draw_rounded_rect(rect, 38.0, Color(0.93, 0.83, 0.53, 0.45), Color("#d9b65a"), 7.0)

	for x in range(int(rect.position.x + 35), int(rect.end.x - 20), 58):
		draw_circle(Vector2(x, rect.get_center().y), 7.0, Color(0.56, 0.38, 0.20, 0.32))

	var sign_rect := Rect2(rect.get_center() - Vector2(115, 38), Vector2(230, 76))
	draw_rounded_rect(sign_rect, 18.0, Color("#fff1c8"), Color("#9f7042"), 5.0)


func draw_world_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.08, 0.28, 0.13, 0.34), false, 18.0)


func draw_rounded_rect(rect: Rect2, radius: float, fill: Color, border: Color, border_width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_width_left = int(border_width)
	style.border_width_right = int(border_width)
	style.border_width_top = int(border_width)
	style.border_width_bottom = int(border_width)
	style.border_color = border
	draw_style_box(style, rect)


func create_world_objects() -> void:
	# На старте только базовый дом и складской кластер. Остальные здания
	# игрок позже будет покупать через меню строительства.
	add_world_sprite(BARN_TEXTURE, Vector2(930, 590), 430.0)
	add_world_sprite(SILO_TEXTURE, Vector2(610, 655), 190.0)
	add_world_sprite(HOUSE_TEXTURE, Vector2(1350, 590), 370.0)

	# Деревья и камни создают богатую картинку, но центр оставлен свободным.
	var round_trees := [
		Vector2(260, 300), Vector2(420, 500), Vector2(260, 810),
		Vector2(2680, 250), Vector2(2800, 510), Vector2(2750, 880),
		Vector2(760, 1500), Vector2(1040, 1650), Vector2(2440, 1640)
	]
	for pos in round_trees:
		add_world_sprite(TREE_ROUND_TEXTURE, pos, 230.0)

	for pos in [Vector2(110, 500), Vector2(2850, 720), Vector2(520, 1760), Vector2(2710, 1720)]:
		add_world_sprite(TREE_PINE_TEXTURE, pos, 175.0)

	for pos in [Vector2(470, 970), Vector2(2050, 430), Vector2(2140, 1570)]:
		add_world_sprite(TREE_APPLE_TEXTURE, pos, 235.0)

	for pos in [Vector2(530, 1280), Vector2(2070, 760), Vector2(2520, 1530)]:
		add_world_sprite(ROCK_FENCE_TEXTURE, pos, 300.0)


func add_world_sprite(texture: Texture2D, position: Vector2, target_width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position
	sprite.z_index = int(position.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var texture_size := texture.get_size()
	if texture_size.x > 0.0:
		var scale_value := target_width / texture_size.x
		sprite.scale = Vector2(scale_value, scale_value)
	add_child(sprite)
	return sprite


func create_field_plots() -> void:
	var positions := [
		Vector2(1570, 900),
		Vector2(1950, 900),
		Vector2(1570, 1190),
		Vector2(1950, 1190)
	]

	for index in range(positions.size()):
		create_field_plot(index, positions[index])


func create_field_plot(index: int, position: Vector2) -> void:
	var root := Node2D.new()
	root.name = "Field_%d" % index
	root.position = position
	root.z_index = int(position.y)
	add_child(root)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = FIELD_EMPTY_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(sprite)
	set_sprite_width(sprite, FIELD_EMPTY_TEXTURE, 355.0)

	var button := Button.new()
	button.name = "TouchArea"
	button.position = Vector2(-190, -112)
	button.size = Vector2(380, 225)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(on_field_pressed.bind(index))
	root.add_child(button)

	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(-104, -143)
	status.size = Vector2(208, 57)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 19)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_stylebox_override("normal", make_style(Color("#168b52"), Color("#0b653b"), 18, 3))
	status.visible = false
	root.add_child(status)

	field_plots.append({
		"root": root,
		"sprite": sprite,
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
	var field: Dictionary = field_plots[index]
	var state: String = str(field.get("state", "empty"))

	if state == "empty":
		open_seed_panel(index)
	elif state == "growing":
		var remaining := maxi(0, int(ceil(float(field["end_time"]) - Time.get_unix_time_from_system())))
		show_toast("Урожай ещё растёт: %d сек." % remaining)
	elif state == "ready":
		harvest_field(index)


func open_seed_panel(index: int) -> void:
	selected_field = index
	seed_panel.visible = true
	update_seed_buttons()
	show_toast("Выбери, что посадить")


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
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(update_growth)
	add_child(timer)


func update_growth() -> void:
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


func update_all_fields() -> void:
	for index in range(field_plots.size()):
		update_field(index)


func update_field(index: int) -> void:
	var field: Dictionary = field_plots[index]
	var sprite: Sprite2D = field["sprite"]
	var status: Label = field["status"]
	var state: String = str(field.get("state", "empty"))

	if state == "empty":
		set_sprite_width(sprite, FIELD_EMPTY_TEXTURE, 355.0)
		sprite.modulate = Color.WHITE
		sprite.position = Vector2.ZERO
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
		var width := lerpf(275.0, 355.0, progress)
		set_sprite_width(sprite, texture, width)
		sprite.modulate = Color(1.0, 1.0, 1.0, lerpf(0.72, 1.0, progress))
		sprite.position.y = lerpf(12.0, 0.0, progress)
		var remaining := maxi(0, int(ceil(end_time - now)))
		status.text = "%s\n%d сек." % [str(crop["name"]), remaining]
		status.add_theme_stylebox_override("normal", make_style(Color("#b6782c"), Color("#83511d"), 18, 3))
		status.visible = true
	else:
		set_sprite_width(sprite, texture, 365.0)
		sprite.modulate = Color.WHITE
		sprite.position.y = -4.0
		status.text = "ГОТОВО!\nСОБРАТЬ"
		status.add_theme_stylebox_override("normal", make_style(Color("#21a45b"), Color("#0b713d"), 18, 3))
		status.visible = true


func create_world_labels() -> void:
	create_world_sign("СТАРТОВАЯ ФЕРМА", Vector2(790, 255), Vector2(470, 66), Color("#fff1bf"))
	create_world_sign("ПОЛЯ", Vector2(1590, 690), Vector2(310, 58), Color("#eaf7b5"))
	create_world_sign("ПЕКАРНЯ\nУРОВЕНЬ 2", Vector2(2345, 615), Vector2(230, 86), Color("#fff1c8"))
	create_world_sign("КУРОВНИК\nУРОВЕНЬ 3", Vector2(2370, 1278), Vector2(230, 86), Color("#fff1c8"))


func create_world_sign(text: String, position: Vector2, size: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("#69472f"))
	label.add_theme_stylebox_override("normal", make_style(color, Color("#a97b45"), 18, 4))
	label.z_index = int(position.y)
	add_child(label)


func create_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)

	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	create_top_hud(root)
	create_task_panel(root)
	create_bottom_menu(root)
	create_zoom_buttons(root)
	create_seed_panel(root)
	create_toast(root)


func create_top_hud(root: Control) -> void:
	var top := PanelContainer.new()
	top.anchor_left = 0.02
	top.anchor_right = 0.98
	top.anchor_top = 0.02
	top.anchor_bottom = 0.02
	top.offset_bottom = 78.0
	top.add_theme_stylebox_override("panel", make_style(Color("#087c43"), Color("#075d36"), 28, 5))
	root.add_child(top)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	top.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var level_box := VBoxContainer.new()
	level_box.custom_minimum_size = Vector2(285, 0)
	row.add_child(level_box)

	var level_row := HBoxContainer.new()
	level_box.add_child(level_row)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 25)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_row.add_child(level_label)

	var level_space := Control.new()
	level_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level_space)

	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 17)
	xp_label.add_theme_color_override("font_color", Color("#eaffbf"))
	level_row.add_child(xp_label)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(285, 17)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", make_style(Color("#365b34"), Color.TRANSPARENT, 8, 0))
	xp_bar.add_theme_stylebox_override("fill", make_style(Color("#7edb46"), Color.TRANSPARENT, 8, 0))
	level_box.add_child(xp_bar)

	var title := Label.new()
	title.text = "GREEN TOWN"
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	warehouse_label = Label.new()
	warehouse_label.add_theme_font_size_override("font_size", 17)
	warehouse_label.add_theme_color_override("font_color", Color("#eaffbf"))
	row.add_child(warehouse_label)

	var coins_panel := make_resource_panel("МОНЕТЫ")
	row.add_child(coins_panel)
	coins_label = coins_panel.get_node("Margin/Row/Value") as Label

	var gems_panel := make_resource_panel("АЛМАЗЫ")
	row.add_child(gems_panel)
	gems_label = gems_panel.get_node("Margin/Row/Value") as Label


func make_resource_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(185, 52)
	panel.add_theme_stylebox_override("panel", make_style(Color("#075f3b"), Color("#16935b"), 18, 3))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 18)
	dot.add_theme_color_override("font_color", Color("#ffda45") if title_text == "МОНЕТЫ" else Color("#67ddf2"))
	row.add_child(dot)

	var title := Label.new()
	title.text = title_text + ":"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	var value := Label.new()
	value.name = "Value"
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color("#fff0a4"))
	row.add_child(value)

	return panel


func create_task_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.02
	panel.anchor_top = 0.13
	panel.anchor_right = 0.02
	panel.anchor_bottom = 0.13
	panel.offset_right = 330.0
	panel.offset_bottom = 158.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#fff0c9"), Color("#bd8650"), 23, 5))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ПЕРВАЯ ЦЕЛЬ"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(title)

	var description := Label.new()
	description.text = "Соберите 10 пшеницы"
	description.add_theme_font_size_override("font_size", 20)
	description.add_theme_color_override("font_color", Color("#503725"))
	column.add_child(description)

	task_progress_label = Label.new()
	task_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	task_progress_label.add_theme_font_size_override("font_size", 16)
	task_progress_label.add_theme_color_override("font_color", Color("#765038"))
	column.add_child(task_progress_label)

	task_progress_bar = ProgressBar.new()
	task_progress_bar.max_value = 10
	task_progress_bar.show_percentage = false
	task_progress_bar.custom_minimum_size = Vector2(290, 20)
	task_progress_bar.add_theme_stylebox_override("background", make_style(Color("#d9b57a"), Color.TRANSPARENT, 9, 0))
	task_progress_bar.add_theme_stylebox_override("fill", make_style(Color("#35b34f"), Color.TRANSPARENT, 9, 0))
	column.add_child(task_progress_bar)


func create_bottom_menu(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.20
	panel.anchor_right = 0.80
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -88.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", make_style(Color("#087644"), Color("#e9d79c"), 28, 5))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	for data in [
		["ФЕРМА", Color("#f3bd39")],
		["СТРОИТЬ", Color("#f38a43")],
		["АМБАР", Color("#5dc2e8")],
		["ЗАКАЗЫ", Color("#df82bf")],
		["КАРТА", Color("#84ca62")]
	]:
		var button_color: Color = data[1]
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(150, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("#493b2d"))
		button.add_theme_stylebox_override("normal", make_style(button_color, button_color.darkened(0.28), 19, 4))
		button.add_theme_stylebox_override("hover", make_style(button_color.lightened(0.08), button_color.darkened(0.28), 19, 4))
		button.add_theme_stylebox_override("pressed", make_style(button_color.darkened(0.10), button_color.darkened(0.32), 19, 4))
		button.pressed.connect(on_bottom_button_pressed.bind(str(data[0])))
		row.add_child(button)


func on_bottom_button_pressed(action: String) -> void:
	match action:
		"ФЕРМА":
			world_camera.position = Vector2(1390, 930)
			set_camera_zoom(0.78)
			show_toast("Вернулись на ферму")
		"СТРОИТЬ":
			show_toast("Следующим патчем добавим покупку и размещение зданий")
		"АМБАР":
			show_toast(inventory_text())
		"ЗАКАЗЫ":
			show_toast("Доска заказов откроется на 2 уровне")
		"КАРТА":
			set_camera_zoom(MIN_ZOOM)
			world_camera.position = WORLD_SIZE * 0.5


func create_zoom_buttons(root: Control) -> void:
	var column := VBoxContainer.new()
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_top = 0.55
	column.anchor_bottom = 0.55
	column.offset_left = -92.0
	column.offset_right = -22.0
	column.offset_top = -70.0
	column.offset_bottom = 80.0
	column.add_theme_constant_override("separation", 9)
	root.add_child(column)

	for data in [["+", 0.10], ["−", -0.10]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(70, 66)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 31)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", make_style(Color("#087b55"), Color.WHITE, 20, 4))
		button.add_theme_stylebox_override("pressed", make_style(Color("#075f43"), Color.WHITE, 20, 4))
		button.pressed.connect(on_zoom_pressed.bind(float(data[1])))
		column.add_child(button)


func on_zoom_pressed(delta: float) -> void:
	set_camera_zoom(world_camera.zoom.x + delta)


func create_seed_panel(root: Control) -> void:
	seed_panel = PanelContainer.new()
	seed_panel.anchor_left = 0.5
	seed_panel.anchor_right = 0.5
	seed_panel.anchor_top = 1.0
	seed_panel.anchor_bottom = 1.0
	seed_panel.offset_left = -500.0
	seed_panel.offset_right = 500.0
	seed_panel.offset_top = -286.0
	seed_panel.offset_bottom = -103.0
	seed_panel.add_theme_stylebox_override("panel", make_style(Color("#fff1cf"), Color("#9b6b40"), 25, 5))
	seed_panel.visible = false
	root.add_child(seed_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 12)
	seed_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)

	var title := Label.new()
	title.text = "ЧТО ПОСАДИТЬ?"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#5b3d28"))
	title_row.add_child(title)

	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(space)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 38)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 25)
	close_button.add_theme_stylebox_override("normal", make_style(Color("#e98a68"), Color("#a14e35"), 13, 3))
	close_button.pressed.connect(close_seed_panel)
	title_row.add_child(close_button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	for crop_id in CROP_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(225, 92)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("#4d3525"))
		button.add_theme_stylebox_override("normal", make_style(Color("#f5ce6a"), Color("#a96f32"), 18, 4))
		button.add_theme_stylebox_override("hover", make_style(Color("#ffe28b"), Color("#a96f32"), 18, 4))
		button.add_theme_stylebox_override("pressed", make_style(Color("#e8b952"), Color("#8f5726"), 18, 4))
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
			button.text = "%s\n%s • %d СЕК." % [str(crop["name"]), cost_text, int(crop["grow_time"])]
			button.disabled = false
		else:
			button.text = "%s\nОТКРОЕТСЯ: УР. %d" % [str(crop["name"]), required_level]
			button.disabled = true


func create_toast(root: Control) -> void:
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.14
	toast_panel.anchor_bottom = 0.14
	toast_panel.offset_left = -270.0
	toast_panel.offset_right = 270.0
	toast_panel.offset_bottom = 62.0
	toast_panel.add_theme_stylebox_override("panel", make_style(Color(0.05, 0.33, 0.20, 0.94), Color("#6ed36d"), 20, 3))
	toast_panel.visible = false
	root.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_panel.add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 2.4
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

	warehouse_label.text = "АМБАР: %d" % inventory_total()
	task_progress_bar.value = mini(wheat_harvested, 10)
	if first_task_completed:
		task_progress_label.text = "ВЫПОЛНЕНО ✓"
	else:
		task_progress_label.text = "%d/10" % mini(wheat_harvested, 10)


func inventory_total() -> int:
	var total := 0
	for crop_id in CROP_ORDER:
		total += int(inventory.get(crop_id, 0))
	return total


func inventory_text() -> String:
	return "Амбар: пшеница %d • кукуруза %d • томаты %d • морковь %d" % [
		int(inventory.get("wheat", 0)),
		int(inventory.get("corn", 0)),
		int(inventory.get("tomato", 0)),
		int(inventory.get("carrot", 0))
	]


func make_style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
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
	return style


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

	var saved_inventory = parsed.get("inventory", {})
	if saved_inventory is Dictionary:
		for crop_id in CROP_ORDER:
			inventory[crop_id] = maxi(0, int(saved_inventory.get(crop_id, 0)))

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
