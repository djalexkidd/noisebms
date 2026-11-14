extends Control

# Result screen of the solo and local versus plays, like on IIDX: 1P on the left, 2P on the right,
# the song in the middle. START or a key goes back to the music select.

const ResultPanel = preload("res://scripts/result/result_panel.gd")
const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const FONT = preload("res://assets/font/FT2FONT.TTF")
const SONG_FONT = preload("res://assets/font/monofonto.otf")
# Applause with the lamp banner when a player cleared the song
const CLEAR_SOUND = preload("res://assets/bgm/clear.ogg")

const BACKGROUND_TOP = Color(0.02, 0.02, 0.06)
const BACKGROUND_BOTTOM = Color(0.07, 0.03, 0.12)
const TITLE_GLOW = Color(0.35, 0.5, 1, 0.6)
const TEXT_DIM = Color(0.6, 0.62, 0.7)
const MARGIN = 16.0
const PANEL_TOP = 74.0
# Rings turning behind the middle, in place of the IIDX character art
const RING_CENTER = Vector2(640, 360)
const RING_RADII = [70.0, 105.0, 140.0, 175.0]
# Clear lamp banner shown before the panels: time on screen, sliding in, closing
const LAMP_TIME = 2.2
const LAMP_IN = 0.35
const LAMP_OUT = 0.3
const LAMP_BAND_HEIGHT = 120.0
# Lamps with rainbow letters (FULL COMBO, PERFECT)
const RAINBOW_LAMP = 5

var panels : Array = []
var elapsed := 0.0
var versus := false
# The lamp banner closes at this time, the panels come after it
var lamp_end := LAMP_TIME

func _ready() -> void:
	versus = Global.p1_joined and Global.p2_joined
	var players = [1, 2] if versus else [1 if Global.p1_joined else 2]
	for player in players:
		var panel = ResultPanel.new()
		panel.player = player
		add_child(panel)
		panel.position = Vector2(MARGIN if player == 1 else get_viewport_rect().size.x - MARGIN - panel.size.x, PANEL_TOP)
		panels.append(panel)
		# The panels wait for the end of the lamp banner
		panel.elapsed = -LAMP_TIME
		panel.visible = false
	if panels.any(func(panel): return panel.lamp > 0):
		var applause = AudioStreamPlayer.new()
		applause.stream = CLEAR_SOUND
		add_child(applause)
		applause.play()
	# The panels have read the results
	Global.failed = false
	Global.p2_failed = false

func _process(delta: float) -> void:
	elapsed += delta
	for panel in panels:
		panel.visible = panel.elapsed >= 0.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var confirm = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for action in ["ui_accept", "p1_start", "p2_start", "p1_key1", "p2_key1", "p1_key7", "p2_key7"]:
		if event.is_action_pressed(action):
			confirm = true
	if not confirm:
		return
	get_viewport().set_input_as_handled()
	# The first press closes the lamp banner
	if elapsed < lamp_end - LAMP_OUT:
		skip_lamp()
		return
	# The first press ends the reveal, the next one leaves
	if not panels.all(func(panel): return panel.revealed()):
		for panel in panels:
			panel.skip_reveal()
		return
	for player in [1, 2]:
		Global.set_player_var(player, "score", 0)
		Global.set_player_var(player, "ex_score", 0)
		Global.set_player_var(player, "combo_max", 0)
	if Arcade.active and Arcade.game_over():
		get_tree().change_scene_to_file("res://scenes/arcade/game_over.tscn")
	elif Arcade.active and Arcade.finished():
		get_tree().change_scene_to_file("res://scenes/arcade/name_entry.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/music_select.tscn")

# The banner closes now, the panels start right after
func skip_lamp() -> void:
	lamp_end = elapsed + LAMP_OUT
	for panel in panels:
		panel.elapsed = maxf(panel.elapsed, -LAMP_OUT)

func _draw() -> void:
	# Background: a dark gradient and slanted stripes
	var gradient = PackedColorArray([BACKGROUND_TOP, BACKGROUND_TOP, BACKGROUND_BOTTOM, BACKGROUND_BOTTOM])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), gradient)
	var shift = fmod(elapsed * 20.0, 48.0)
	for x in range(-int(size.y), int(size.x) + 48, 48):
		draw_line(Vector2(x + shift, size.y), Vector2(x + shift + size.y * 0.5, 0), Color(1, 1, 1, 0.025), 2.0)

	# Turning rings in the middle
	for i in RING_RADII.size():
		var radius : float = RING_RADII[i]
		var turn = elapsed * (0.4 if i % 2 == 0 else -0.25) * (1.0 + i * 0.2)
		for arc in 3:
			var start = turn + arc * TAU / 3.0
			draw_arc(RING_CENTER, radius, start, start + TAU / 5.0, 32, Color(0.4, 0.5, 1, 0.12 + 0.04 * i), 3.0 + i, true)
	draw_circle(RING_CENTER, 34, Color(0.4, 0.5, 1, 0.12))

	# Title
	var title = "STAGE RESULT" if not Netplay.active else "RESULT"
	if Arcade.active and not Arcade.stages.is_empty():
		title = Arcade.stage_name(Arcade.stages.size() - 1) + " RESULT"
	var title_size = 32
	var title_width = TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_pos = Vector2((size.x - title_width) / 2, 50)
	draw_string_outline(TITLE_FONT, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 8, TITLE_GLOW)
	draw_string(TITLE_FONT, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	# Versus: WIN, LOSE or DRAW on each side of the middle
	if versus:
		var shown = clampf((panels[0].elapsed - 1.2) / 0.3, 0.0, 1.0)
		for player in [1, 2]:
			var result = Global.get_versus_result(player)
			var color : Color = Global.VERSUS_RESULT_COLORS[result]
			var column = Rect2(640 - 170 if player == 1 else 640, 84, 170, 20)
			draw_centered(TITLE_FONT, column, "%dP" % player, 16, Color(TEXT_DIM, shown))
			draw_centered(TITLE_FONT, Rect2(column.position + Vector2(0, 30), Vector2(column.size.x, 50)), result, 40, Color(color, shown))

	# Song: title, artist, then the key to go on
	var info : Dictionary = Global.song_info
	var song_title : String = info.get("title", "")
	if song_title == "":
		song_title = Loader.file_path.get_file().get_basename()
	var middle = Rect2(470, 600, 340, 40)
	draw_centered(SONG_FONT, middle, song_title, 36, Color.WHITE, 8, Color(0.2, 0.25, 0.6))
	draw_centered(SONG_FONT, Rect2(middle.position + Vector2(0, 38), middle.size), info.get("artist", ""), 24, TEXT_DIM)
	if panels.all(func(panel): return panel.revealed()) and Time.get_ticks_msec() % 1000 < 650:
		draw_centered(TITLE_FONT, Rect2(470, 684, 340, 24), "PRESS START", 14, Color(1, 0.85, 0.2))

	if elapsed < lamp_end:
		draw_lamp_banner()

# The clear lamp of the play (CLEAR, HARD CLEAR, FAILED...) in a band across the middle:
# it slides in from the left, a light sweeps over it, then it closes. In versus, one half per player.
func draw_lamp_banner() -> void:
	var slide = ease(clampf(elapsed / LAMP_IN, 0.0, 1.0), 0.3)
	var close = clampf((elapsed - (lamp_end - LAMP_OUT)) / LAMP_OUT, 0.0, 1.0)
	var open = 1.0 - close
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6 * slide * open))
	var height = LAMP_BAND_HEIGHT * open
	var band = Rect2(-size.x * (1.0 - slide), size.y / 2 - height / 2, size.x, height)
	var lamps = panels.map(func(panel): return panel.lamp)
	var best_lamp : int = lamps.max()
	var color : Color = Scores.LAMP_COLORS[best_lamp]
	draw_rect(band, Color(color.darkened(0.8), 0.85))
	# Light sweeping from left to right, inside the band
	var sweep = band.position.x + fmod(elapsed * 900.0, size.x + 400.0) - 200.0
	var skew = height * 0.4
	draw_colored_polygon(PackedVector2Array([Vector2(sweep, band.position.y), Vector2(sweep + 80, band.position.y),
		Vector2(sweep + 80 - skew, band.end.y), Vector2(sweep - skew, band.end.y)]), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(band.position.x, band.position.y - 3, band.size.x, 3), color)
	draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 3), color)
	if height < 40.0:
		return
	if lamps.size() == 1:
		draw_lamp_text(band, Scores.LAMPS[lamps[0]], 72, lamps[0])
		return
	for i in panels.size():
		var half = Rect2(band.position.x + band.size.x / 2 * i, band.position.y, band.size.x / 2, band.size.y)
		draw_centered(TITLE_FONT, Rect2(half.position + Vector2(0, 8), Vector2(half.size.x, 20)), "%dP" % panels[i].player, 16, TEXT_DIM)
		draw_lamp_text(half.grow_individual(-24, -16, -24, 0), Scores.LAMPS[lamps[i]], 44, lamps[i])

# A lamp name centered in a box, made smaller if it does not fit, with rainbow letters for FULL COMBO and PERFECT
func draw_lamp_text(rect: Rect2, text: String, font_size: int, lamp: int) -> void:
	var color : Color = Scores.LAMP_COLORS[lamp]
	if lamp < RAINBOW_LAMP:
		draw_centered(TITLE_FONT, rect, text, font_size, color, 12, Color(color.darkened(0.75), 0.9))
		return
	while font_size > 8 and TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + TITLE_FONT.get_ascent(font_size) - TITLE_FONT.get_descent(font_size)) / 2
	var x = rect.get_center().x - width / 2
	draw_string_outline(TITLE_FONT, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, Color(0.05, 0.05, 0.1, 0.9))
	for i in text.length():
		var at = Vector2(x + TITLE_FONT.get_string_size(text.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, baseline)
		# PERFECT is paler than FULL COMBO
		var letter_color = Color.from_hsv(fmod(elapsed * 0.6 + i * 0.07, 1.0), 0.45 if lamp > RAINBOW_LAMP else 0.8, 1.0)
		draw_string(TITLE_FONT, at, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, letter_color)

# Text centered in a box, made smaller if it does not fit
func draw_centered(font: Font, rect: Rect2, text: String, font_size: int, color: Color, outline := 0, outline_color := Color.BLACK) -> void:
	while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	var pos = Vector2(rect.get_center().x - width / 2, baseline)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
