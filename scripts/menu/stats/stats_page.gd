extends Control

# Common part of the STATS menu screens (stats_menu.gd, stats.gd), drawn like the MENU SELECT:
# the info bar on top with OK and EXIT, a dark panel over the background, a help line at the bottom.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0
# Tags of the info bar, in its pixels: OPTIONS (hidden), OK, EXIT
const INFO_TAGS = [Rect2(1313, 14, 189, 79), Rect2(1577, 14, 105, 79), Rect2(1755, 14, 103, 79)]

const PANEL = Color(0, 0, 0, 0.7)
const ROW = Color(0.05, 0.05, 0.05)
const ROW_LIGHT = Color(0.12, 0.12, 0.12)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const DARK_ORANGE = Color(0.45, 0.18, 0)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)
const TEXT_DIM = Color(0.6, 0.62, 0.7)

const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const LEAVE_TIME = 0.25
const SOUND_VOLUME_DB = -10.0

const MAIN_MENU_SCENE = "res://scenes/menu/main_menu.tscn"
const STATS_MENU_SCENE = "res://scenes/menu/stats_menu.tscn"

var turntable := MenuTurntable.new()
var scroll_sound: AudioStreamPlayer
var decide_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer
var leaving = false

func _ready() -> void:
	scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
	decide_sound = add_sound(preload("res://assets/music_select/decide.wav"))
	cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUND_VOLUME_DB
	player.max_polyphony = 4
	add_child(player)
	return player

func leave_to(scene: String, sound: AudioStreamPlayer) -> void:
	if leaving:
		return
	leaving = true
	sound.play()
	await get_tree().create_timer(LEAVE_TIME).timeout
	get_tree().change_scene_to_file(scene)

func body_bottom() -> float:
	return size.y - FOOTER_HEIGHT - 8

# OK and EXIT in the header
func header_tag_rect(i: int) -> Rect2:
	var tag: Rect2 = INFO_TAGS[i]
	return Rect2(tag.position + Vector2(size.x + INFO_BAR_LEFT, 0), tag.size)

func draw_text(at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = at.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(TITLE_FONT, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(TITLE_FONT, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

# Text made smaller until it fits the width
func fit_size(text: String, font_size: int, width: float) -> int:
	while font_size > 8 and TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size

func blink() -> bool:
	return Time.get_ticks_msec() % 500 < 300

func draw_body() -> void:
	draw_rect(Rect2(0, HEADER_HEIGHT, size.x, body_bottom() - HEADER_HEIGHT), PANEL)
	draw_rect(Rect2(0, HEADER_HEIGHT + 4, size.x, 3), ORANGE)
	draw_rect(Rect2(0, body_bottom() - 7, size.x, 3), ORANGE)

# The info bar with the screen name, a subtitle under it and a big title next to it
func draw_header(screen_name: String, subtitle: String, title: String) -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	var baseline = 16 + TITLE_FONT.get_ascent(32)
	draw_text(Vector2(16, baseline), screen_name, 32, Color.WHITE)
	if subtitle != "":
		draw_text(Vector2(18, baseline + 30), subtitle, 14, YELLOW)
	if title != "":
		var left = 40 + TITLE_FONT.get_string_size(screen_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var right = header_tag_rect(0).position.x - 30
		draw_text(Vector2(left, 78), title, fit_size(title, 40, right - left), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6)
	# No OPTIONS tag here
	var tag = header_tag_rect(0)
	draw_rect(Rect2(tag.position - Vector2(10, 14), tag.size + Vector2(20, 18)), Color.BLACK)

# Help line in a black bar, like the explanation of the IIDX menus
func draw_footer(text: String) -> void:
	var top = body_bottom()
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	var bar = Rect2(20, top + 10, size.x - 40, FOOTER_HEIGHT - 8)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	draw_text(Vector2(bar.position.x + 24, bar.get_center().y + 9), text, fit_size(text, 20, bar.size.x - 48), Color.WHITE)

func draw_corners(rect: Rect2, length: float, line_color: Color, width := 2.0) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var dx = length if corner.x == rect.position.x else -length
		var dy = length if corner.y == rect.position.y else -length
		draw_polyline([corner + Vector2(dx, 0), corner, corner + Vector2(0, dy)], line_color, width)
