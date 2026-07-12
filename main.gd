extends Node2D

const EMPTY := 0
const GROWING := 1
const READY := 2

const PLOT_COUNT := 12
const GROW_TIME := 10.0
const PLANT_PRICE := 2
const WHEAT_SELL_PRICE := 5
const SAVE_PATH := "user://farm_save.json"

var coins := 100
var wheat := 0

var plot_states: Array = []
var grow_end_times: Array = []
var plot_buttons: Array = []

var coins_label: Label
var wheat_label: Label
var barn_label: Label
var hint_label: Label


func _ready() -> void:
	load_game()
	create_farm()
	update_resources()
	update_all_plots()

	var update_timer := Timer.new()
	update_timer.wait_time = 0.25
	update_timer.autostart = true
	update_timer.timeout.connect(update_growing_plants)
	add_child(update_timer)


func load_game() -> void:
	var saved_states: Array = []
	var saved_times: Array = []

	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

		if file:
			var data = JSON.parse_string(file.get_as_text())

			if data is Dictionary:
				coins = int(data.get("coins", 100))
				wheat = int(data.get("wheat", 0))

				var states_data = data.get("plot_states", [])
				var times_data = data.get("grow_end_times", [])

				if states_data is Array:
					saved_states = states_data

				if times_data is Array:
					saved_times = times_data

	for i in range(PLOT_COUNT):
		plot_states.append(
			int(saved_states[i]) if i < saved_states.size() else EMPTY
		)

		grow_end_times.append(
			float(saved_times[i]) if i < saved_times.size() else 0.0
		)


func save_game() -> void:
	var data := {
		"coins": coins,
		"wheat": wheat,
		"plot_states": plot_states,
		"grow_end_times": grow_end_times
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(data))


func create_farm() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var background := ColorRect.new()
	background.color = Color("#7bc856")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page_margin := MarginContainer.new()
	canvas.add_child(page_margin)
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 16)
	page_margin.add_theme_constant_override("margin_right", 16)
	page_margin.add_theme_constant_override("margin_top", 12)
	page_margin.add_theme_constant_override("margin_bottom", 12)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page_margin.add_child(page)

	# Верхняя панель.
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 64)
	set_panel_style(header, Color("#2f8747"), 18)
	page.add_child(header)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 18)
	header_margin.add_theme_constant_override("margin_right", 18)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	header_margin.add_child(header_row)

	var title := Label.new()
	title.text = "GREEN TOWN"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(title)

	var level_badge := Label.new()
	level_badge.text = "  УРОВЕНЬ 1  "
	level_badge.add_theme_font_size_override("font_size", 16)
	level_badge.add_theme_color_override("font_color", Color("#184d2b"))
	level_badge.add_theme_stylebox_override(
		"normal",
		create_style(Color("#dff4a7"), 14, Color("#b6d779"), 2)
	)
	level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(level_badge)

	var header_space := Control.new()
	header_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_space)

	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 21)
	coins_label.add_theme_color_override("font_color", Color("#fff1a1"))
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(coins_label)

	wheat_label = Label.new()
	wheat_label.add_theme_font_size_override("font_size", 21)
	wheat_label.add_theme_color_override("font_color", Color("#fff1a1"))
	wheat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(wheat_label)

	# Основная область: поля слева, постройки справа.
	var world_row := HBoxContainer.new()
	world_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_row.add_theme_constant_override("separation", 12)
	page.add_child(world_row)

	var fields_panel := PanelContainer.new()
	fields_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields_panel.size_flags_stretch_ratio = 1.75
	set_panel_style(fields_panel, Color("#95d96a"), 22)
	world_row.add_child(fields_panel)

	var fields_margin := MarginContainer.new()
	fields_margin.add_theme_constant_override("margin_left", 14)
	fields_margin.add_theme_constant_override("margin_right", 14)
	fields_margin.add_theme_constant_override("margin_top", 10)
	fields_margin.add_theme_constant_override("margin_bottom", 10)
	fields_panel.add_child(fields_margin)

	var fields_column := VBoxContainer.new()
	fields_column.add_theme_constant_override("separation", 8)
	fields_margin.add_child(fields_column)

	var fields_title := Label.new()
	fields_title.text = "ПОЛЯ ПШЕНИЦЫ"
	fields_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields_title.add_theme_font_size_override("font_size", 21)
	fields_title.add_theme_color_override("font_color", Color("#245b2e"))
	fields_column.add_child(fields_title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	fields_column.add_child(grid)

	for i in range(PLOT_COUNT):
		var plot := Button.new()
		plot.custom_minimum_size = Vector2(0, 76)
		plot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plot.focus_mode = Control.FOCUS_NONE
		plot.add_theme_font_size_override("font_size", 17)
		plot.add_theme_color_override("font_color", Color.WHITE)
		plot.pressed.connect(plot_pressed.bind(i))
		grid.add_child(plot)
		plot_buttons.append(plot)

	var village_column := VBoxContainer.new()
	village_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	village_column.size_flags_stretch_ratio = 0.95
	village_column.add_theme_constant_override("separation", 10)
	world_row.add_child(village_column)

	var house := create_building_card(
		"ФЕРМЕРСКИЙ ДОМ",
		"Уровень 1\nЗдесь живёт фермер",
		Color("#f3d186"),
		Color("#a9573f")
	)
	village_column.add_child(house)

	var barn := create_building_card(
		"АМБАР",
		"Склад урожая",
		Color("#efaa62"),
		Color("#9f4037")
	)
	village_column.add_child(barn)

	barn_label = barn.get_node("Margin/Content/Description") as Label

	var orders := create_building_card(
		"ДОСКА ЗАКАЗОВ",
		"Откроется на уровне 2",
		Color("#d9b987"),
		Color("#7c5a38")
	)
	village_column.add_child(orders)

	var coming_soon := Label.new()
	coming_soon.text = "Скоро здесь появятся:\nморковь, коровы и заводы"
	coming_soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming_soon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coming_soon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coming_soon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coming_soon.add_theme_font_size_override("font_size", 17)
	coming_soon.add_theme_color_override("font_color", Color("#245b2e"))
	village_column.add_child(coming_soon)

	# Нижняя панель действий.
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 62)
	set_panel_style(bottom, Color("#3b9853"), 18)
	page.add_child(bottom)

	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 16)
	bottom_margin.add_theme_constant_override("margin_right", 12)
	bottom_margin.add_theme_constant_override("margin_top", 7)
	bottom_margin.add_theme_constant_override("margin_bottom", 7)
	bottom.add_child(bottom_margin)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	bottom_margin.add_child(bottom_row)

	hint_label = Label.new()
	hint_label.text = "Нажми на пустую грядку, чтобы посадить пшеницу"
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	bottom_row.add_child(hint_label)

	var sell_button := Button.new()
	sell_button.text = "ПРОДАТЬ ПШЕНИЦУ"
	sell_button.custom_minimum_size = Vector2(250, 48)
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.add_theme_font_size_override("font_size", 17)
	sell_button.add_theme_color_override("font_color", Color.WHITE)
	set_button_color(sell_button, Color("#247dcc"), Color("#15548c"))
	sell_button.pressed.connect(sell_wheat)
	bottom_row.add_child(sell_button)


func create_building_card(
	title_text: String,
	description_text: String,
	body_color: Color,
	roof_color: Color
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_panel_style(card, body_color, 20)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var roof := ColorRect.new()
	roof.color = roof_color
	roof.custom_minimum_size = Vector2(0, 12)
	roof.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(roof)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#533527"))
	content.add_child(title)

	var description := Label.new()
	description.name = "Description"
	description.text = description_text
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", Color("#654536"))
	content.add_child(description)

	return card


func plot_pressed(index: int) -> void:
	if plot_states[index] == EMPTY:
		if coins < PLANT_PRICE:
			hint_label.text = "Не хватает монет для посадки"
			return

		coins -= PLANT_PRICE
		plot_states[index] = GROWING
		grow_end_times[index] = Time.get_unix_time_from_system() + GROW_TIME
		hint_label.text = "Пшеница посажена. Ждём урожай"
		update_resources()
		update_plot(index)
		save_game()

	elif plot_states[index] == READY:
		wheat += 1
		plot_states[index] = EMPTY
		grow_end_times[index] = 0.0
		hint_label.text = "Урожай отправлен в амбар"
		update_resources()
		update_plot(index)
		save_game()


func update_growing_plants() -> void:
	var current_time := Time.get_unix_time_from_system()
	var changed := false

	for i in range(PLOT_COUNT):
		if plot_states[i] == GROWING:
			var remaining := int(ceil(grow_end_times[i] - current_time))

			if remaining <= 0:
				plot_states[i] = READY
				update_plot(i)
				changed = true
			else:
				plot_buttons[i].text = "ПШЕНИЦА РАСТЁТ\n" + str(remaining) + " сек."

	if changed:
		save_game()


func sell_wheat() -> void:
	if wheat <= 0:
		hint_label.text = "В амбаре пока нет пшеницы"
		return

	var earned := wheat * WHEAT_SELL_PRICE
	coins += earned
	wheat = 0
	hint_label.text = "Пшеница продана: +" + str(earned) + " монет"
	update_resources()
	save_game()


func update_resources() -> void:
	coins_label.text = "МОНЕТЫ: " + str(coins)
	wheat_label.text = "ПШЕНИЦА: " + str(wheat)

	if barn_label:
		barn_label.text = (
			"На складе: "
			+ str(wheat)
			+ " пшеницы\nЦена продажи: "
			+ str(WHEAT_SELL_PRICE)
			+ " монет"
		)


func update_all_plots() -> void:
	for i in range(PLOT_COUNT):
		update_plot(i)


func update_plot(index: int) -> void:
	var plot: Button = plot_buttons[index]

	match plot_states[index]:
		EMPTY:
			plot.text = "ПУСТАЯ ЗЕМЛЯ\nПОСАДИТЬ: " + str(PLANT_PRICE)
			set_button_color(plot, Color("#92522f"), Color("#68391f"))

		GROWING:
			var remaining := int(
				ceil(
					grow_end_times[index]
					- Time.get_unix_time_from_system()
				)
			)
			remaining = max(remaining, 0)
			plot.text = "ПШЕНИЦА РАСТЁТ\n" + str(remaining) + " сек."
			set_button_color(plot, Color("#bf8737"), Color("#855c24"))

		READY:
			plot.text = "УРОЖАЙ ГОТОВ\nСОБРАТЬ"
			set_button_color(plot, Color("#ddb42f"), Color("#a17e15"))


func set_panel_style(
	panel: PanelContainer,
	color: Color,
	radius: int
) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		create_style(color, radius, color.darkened(0.18), 3)
	)


func set_button_color(
	button: Button,
	color: Color,
	border_color: Color
) -> void:
	button.add_theme_stylebox_override(
		"normal",
		create_style(color, 17, border_color, 3)
	)

	button.add_theme_stylebox_override(
		"hover",
		create_style(color.lightened(0.04), 17, border_color, 3)
	)

	button.add_theme_stylebox_override(
		"pressed",
		create_style(color.darkened(0.16), 17, border_color, 3)
	)


func create_style(
	color: Color,
	radius: int,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	return style
