extends Control

# GAME OVER of the ARCADE mode, after a stage failed by every player or after the ranking: the letters of GAME OVER fall
# one by one on a red grid floor, then THANKS FOR PLAYING ! is typed under them and the screen fades
# to black, back to the title menu. A key skips to the fade.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")

const TITLE = "GAME OVER"
const TITLE_SIZE = 96
const TITLE_Y = 330.0
const TITLE_COLOR = Color(1, 0.15, 0.1)
const TITLE_GLOW = Color(1, 0.05, 0, 0.45)
const THANKS = "THANKS FOR PLAYING !"
const THANKS_SIZE = 30
const THANKS_Y = 440.0
const THANKS_COLOR = Color(1, 0.85, 0.2)
# A red line opens like an old screen turning on
const OPEN_TIME = 0.3
# Letters falling one after the other
const LETTER_DELAY = 0.13
const LETTER_FALL = 0.35
const LETTER_HEIGHT = 420.0
const SHAKE = 7.0
const SHAKE_TIME = 0.2
const SPARKS_PER_LETTER = 14
const SPARK_GRAVITY = 900.0
const SPARK_LIFE = 0.7
# THANKS FOR PLAYING ! typed letter by letter
const THANKS_START = 2.4
const THANKS_LETTER_TIME = 0.06
const FADE_START = 7.0
const FADE_TIME = 0.8
# Keys skip to the fade after this time
const SKIP_AFTER = 1.0
# Floor grid going to the horizon
const HORIZON_Y = 470.0
const GRID_COLOR = Color(0.7, 0.05, 0.02)
const GRID_COLUMNS = 24
const GRID_ROWS = 14
const GRID_SPEED = 0.35

var elapsed := 0.0
var fade_at := FADE_START
var leaving := false
var landed := 0
var sparks : Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Arcade.stop()

func _process(delta: float) -> void:
	elapsed += delta
	# Sparks where each letter lands
	while landed < TITLE.length() and elapsed >= letter_land_time(landed):
		spawn_sparks(landed)
		landed += 1
	for spark in sparks:
		spark["velocity"].y += SPARK_GRAVITY * delta
		spark["position"] += spark["velocity"] * delta
		spark["age"] += delta
	sparks = sparks.filter(func(spark): return spark["age"] < SPARK_LIFE)
	queue_redraw()
	if not leaving and elapsed >= fade_at + FADE_TIME:
		leaving = true
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	var confirm = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for action in ["ui_accept", "ui_cancel", "p1_start", "p2_start"]:
		if event.is_action_pressed(action):
			confirm = true
	for player in [1, 2]:
		for key in 7:
			if event.is_action_pressed("p%d_key%d" % [player, key + 1]):
				confirm = true
	if not confirm:
		return
	get_viewport().set_input_as_handled()
	if elapsed >= SKIP_AFTER:
		fade_at = minf(fade_at, elapsed)

func letter_land_time(i: int) -> float:
	return OPEN_TIME + i * LETTER_DELAY + LETTER_FALL

func title_left() -> float:
	return (size.x - TITLE_FONT.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x) / 2

func letter_x(i: int) -> float:
	return title_left() + TITLE_FONT.get_string_size(TITLE.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x

func spawn_sparks(i: int) -> void:
	if TITLE[i] == " ":
		return
	var width = TITLE_FONT.get_string_size(TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	for n in SPARKS_PER_LETTER:
		var angle = rng.randf_range(-PI * 0.95, -PI * 0.05)
		sparks.append({
			"position": Vector2(letter_x(i) + rng.randf() * width, TITLE_Y),
			"velocity": Vector2.from_angle(angle) * rng.randf_range(150.0, 420.0),
			"age": 0.0,
		})

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var open = clampf(elapsed / OPEN_TIME, 0.0, 1.0)
	if open < 1.0:
		# A thin red line across the middle, opening from the centre
		draw_rect(Rect2(size.x / 2 * (1.0 - open), size.y / 2 - 1, size.x * open, 2), TITLE_COLOR)
		return

	# The last landed letters shake the screen
	var shake = Vector2.ZERO
	for i in TITLE.length():
		var since = elapsed - letter_land_time(i)
		if TITLE[i] != " " and since >= 0.0 and since < SHAKE_TIME:
			shake.y += SHAKE * (1.0 - since / SHAKE_TIME) * sin(since * 80.0)
	draw_set_transform(shake)
	draw_floor()

	# GAME OVER: each letter falls and bounces, then the whole word glows
	var glow = 0.5 + 0.5 * sin(elapsed * 3.0) if landed == TITLE.length() else 0.0
	for i in TITLE.length():
		var t = (elapsed - OPEN_TIME - i * LETTER_DELAY) / LETTER_FALL
		if t <= 0.0 or TITLE[i] == " ":
			continue
		var fall = 1.0 - bounce(minf(t, 1.0))
		var at = Vector2(letter_x(i), TITLE_Y - fall * LETTER_HEIGHT)
		var alpha = clampf(t * 3.0, 0.0, 1.0)
		draw_string_outline(TITLE_FONT, at, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 10 + int(glow * 14), Color(TITLE_GLOW, TITLE_GLOW.a * alpha))
		draw_string_outline(TITLE_FONT, at, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 6, Color(0.2, 0, 0, alpha))
		draw_string(TITLE_FONT, at, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(TITLE_COLOR.lightened(glow * 0.25), alpha))
	for spark in sparks:
		var life = 1.0 - spark["age"] / SPARK_LIFE
		draw_rect(Rect2(spark["position"] - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.5 + 0.4 * life, 0.2, life))
	draw_set_transform(Vector2.ZERO)

	# A white flash when the last letter lands
	var flash = 1.0 - (elapsed - letter_land_time(TITLE.length() - 1)) / 0.4
	if flash > 0.0 and flash <= 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.35))

	draw_thanks()
	draw_scanlines()

	var fade = (elapsed - fade_at) / FADE_TIME
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, minf(fade, 1.0)))

# THANKS FOR PLAYING ! typed letter by letter, with a blinking cursor
func draw_thanks() -> void:
	var typed = int((elapsed - THANKS_START) / THANKS_LETTER_TIME)
	if typed < 0:
		return
	var text = THANKS.left(typed)
	var width = TITLE_FONT.get_string_size(THANKS, HORIZONTAL_ALIGNMENT_LEFT, -1, THANKS_SIZE).x
	var at = Vector2((size.x - width) / 2, THANKS_Y)
	draw_string_outline(TITLE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, THANKS_SIZE, 6, Color(0.3, 0.15, 0, 0.9))
	draw_string(TITLE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, THANKS_SIZE, THANKS_COLOR)
	if fmod(elapsed, 0.5) < 0.3:
		var cursor_x = at.x + TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, THANKS_SIZE).x + 8
		draw_rect(Rect2(cursor_x, at.y - THANKS_SIZE * 0.8, THANKS_SIZE * 0.5, THANKS_SIZE * 0.85), THANKS_COLOR)

# Red grid floor going to the horizon, rows coming closer
func draw_floor() -> void:
	var appear = clampf((elapsed - OPEN_TIME) / 0.6, 0.0, 1.0)
	var bottom = size.y + 20.0
	draw_rect(Rect2(0, HORIZON_Y - 2, size.x, 3), Color(1, 0.3, 0.1, 0.7 * appear))
	var center = size.x / 2
	for column in range(-GRID_COLUMNS, GRID_COLUMNS + 1):
		var spread = float(column) / GRID_COLUMNS
		draw_line(Vector2(center + spread * size.x * 0.25, HORIZON_Y), Vector2(center + spread * size.x * 2.5, bottom),
			Color(GRID_COLOR, 0.5 * appear), 1.5)
	var scroll = fmod(elapsed * GRID_SPEED, 1.0)
	for row in GRID_ROWS:
		# Depth from 1 (horizon) to 0 (bottom), rows bunch up near the horizon
		var depth = 1.0 - (row + scroll) / GRID_ROWS
		var y = HORIZON_Y + (bottom - HORIZON_Y) * pow(1.0 - depth, 2.2)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(GRID_COLOR, 0.6 * appear * (1.0 - depth * 0.8)), 1.5)

func draw_scanlines() -> void:
	for y in range(0, int(size.y), 4):
		draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.18))

# Falling then bouncing twice, 0 at the top and 1 on the ground
static func bounce(t: float) -> float:
	if t < 0.6:
		return pow(t / 0.6, 2)
	if t < 0.85:
		var b = (t - 0.725) / 0.125
		return 1.0 - 0.12 * (1.0 - b * b)
	var c = (t - 0.925) / 0.075
	return 1.0 - 0.03 * (1.0 - c * c)
