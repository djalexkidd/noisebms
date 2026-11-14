extends "res://scripts/menu/stats/stats_page.gd"

# STATS of the main menu: two big panels, RANKING (the ARCADE rankings) and STATS (the player's statistics).
# Turntable or arrows: choose; white key: decide; black key: back to the main menu.

const CHOICES = [
	{"name": "RANKING", "scene": "res://scenes/arcade/ranking.tscn", "desc": "THE BEST ARCADE GAMES, SINGLE PLAY AND DOUBLE PLAY."},
	{"name": "STATS", "scene": "res://scenes/menu/stats.tscn", "desc": "YOUR PLAY TIME, YOUR NOTES, YOUR JUDGEMENTS AND YOUR CLEARS."},
]
const PANEL_SIZE = Vector2(440, 300)
const PANEL_GAP = 80.0
const PANEL_TOP = 190.0
const SELECT_TIME = 0.15

# Last choice, kept across scene changes
static var last_index = 0
var index = last_index
# 1 on the panel just chosen, eased to 0
var pulse = 0.0
var pulse_tween: Tween

func _process(delta: float) -> void:
	queue_redraw()
	var steps = turntable.poll(delta)
	if leaving:
		return
	if steps != 0:
		choose(index + steps)
	if MenuTurntable.white_pressed():
		decide()
	elif MenuTurntable.black_pressed():
		back()

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: choose(index - 1)
			MOUSE_BUTTON_WHEEL_DOWN: choose(index + 1)
			MOUSE_BUTTON_LEFT: click(event.position)
		return
	if not (event is InputEventKey and event.pressed) or MenuTurntable.is_player_input(event):
		return
	match event.keycode:
		KEY_LEFT, KEY_UP: choose(index - 1)
		KEY_RIGHT, KEY_DOWN: choose(index + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: decide()
		KEY_ESCAPE, KEY_BACKSPACE: back()

func click(at: Vector2) -> void:
	if header_tag_rect(1).has_point(at):
		decide()
	elif header_tag_rect(2).has_point(at):
		back()
	for i in CHOICES.size():
		if panel_rect(i).has_point(at):
			if i == index:
				decide()
			else:
				choose(i)

func choose(new_index: int) -> void:
	new_index = posmod(new_index, CHOICES.size())
	if new_index == index:
		return
	index = new_index
	scroll_sound.play()
	if pulse_tween:
		pulse_tween.kill()
	pulse = 1.0
	pulse_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(self, "pulse", 0.0, SELECT_TIME)

func decide() -> void:
	last_index = index
	# The rankings are browsed, not shown after a game
	Arcade.last_ranks.clear()
	leave_to(CHOICES[index]["scene"], decide_sound)

func back() -> void:
	last_index = index
	leave_to(MAIN_MENU_SCENE, cancel_sound)

func panel_rect(i: int) -> Rect2:
	var left = (size.x - PANEL_SIZE.x * CHOICES.size() - PANEL_GAP * (CHOICES.size() - 1)) / 2
	return Rect2(left + i * (PANEL_SIZE.x + PANEL_GAP), PANEL_TOP, PANEL_SIZE.x, PANEL_SIZE.y)

func _draw() -> void:
	draw_body()
	var help = "TURNTABLE: SELECT    WHITE KEY: DECIDE    BLACK KEY: BACK"
	draw_text(Vector2(size.x / 2, HEADER_HEIGHT + 36), help, 14, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	for i in CHOICES.size():
		draw_choice(i)
	draw_header("stats", "PLAYER DATA", "")
	draw_footer(CHOICES[index]["desc"])

func draw_choice(i: int) -> void:
	var rect = panel_rect(i)
	var selected = i == index
	if selected:
		rect = rect.grow(10.0 * (1.0 - pulse))
	draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size), Color(0, 0, 0, 0.5))
	draw_rect(rect, Color.BLACK)
	# Orange stripes in the corner, like the MENU INFORMATION screen
	var stripes_color = Color(ORANGE, 0.75 if selected else 0.25)
	for stripe in 3:
		var x = rect.end.x - 150 + stripe * 36
		draw_colored_polygon([Vector2(x, rect.position.y), Vector2(x + 18, rect.position.y), Vector2(x + 18 - 60, rect.position.y + 60), Vector2(x - 60, rect.position.y + 60)], stripes_color)
	var center = rect.get_center() - Vector2(0, 30)
	var icon_color = YELLOW if selected else TAG_BORDER
	if i == 0:
		draw_podium(center, icon_color)
	else:
		draw_chart_icon(center, icon_color)
	var name_ = CHOICES[i]["name"]
	var name_color = YELLOW if selected else Color.WHITE
	if selected and leaving and Time.get_ticks_msec() % 100 < 50:
		name_color = Color.WHITE
	draw_text(Vector2(rect.get_center().x, rect.end.y - 40), name_, 44, name_color, HORIZONTAL_ALIGNMENT_CENTER, 10, DARK_ORANGE if selected else Color.BLACK)
	draw_rect(rect, ORANGE if selected else TAG_BORDER, false, 4.0 if selected else 2.0)
	if selected:
		draw_corners(rect.grow(10), 24.0, Color.WHITE)
		if not leaving or blink():
			draw_text(Vector2(rect.end.x - 12, rect.position.y + 26), "DECIDE?", 14, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT, 4)

# Podium of the rankings: three steps, 1 in the middle
func draw_podium(center: Vector2, icon_color: Color) -> void:
	var steps = [[-1, 50.0, "2"], [0, 80.0, "1"], [1, 34.0, "3"]]
	for step in steps:
		var rect = Rect2(center.x + step[0] * 70 - 32, center.y + 40 - step[1], 64, step[1])
		draw_rect(rect, Color(icon_color, 0.25))
		draw_rect(rect, icon_color, false, 3.0)
		draw_text(Vector2(rect.get_center().x, rect.position.y + 30), step[2], 24, icon_color, HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(center.x - 120, center.y + 40), Vector2(center.x + 120, center.y + 40), icon_color, 3.0)

# Bars and a pie, for the statistics
func draw_chart_icon(center: Vector2, icon_color: Color) -> void:
	var heights = [30.0, 56.0, 42.0, 74.0]
	for bar in heights.size():
		var rect = Rect2(center.x - 120 + bar * 28, center.y + 40 - heights[bar], 20, heights[bar])
		draw_rect(rect, Color(icon_color, 0.25))
		draw_rect(rect, icon_color, false, 3.0)
	var pie_center = center + Vector2(70, 2)
	draw_circle(pie_center, 40, Color(icon_color, 0.25))
	draw_circle(pie_center, 40, icon_color, false, 3.0)
	var slice = PackedVector2Array([pie_center])
	for step in 9:
		slice.append(pie_center + Vector2.from_angle(-PI / 2 + step * TAU * 0.3 / 8) * 40)
	draw_colored_polygon(slice, icon_color)
	draw_line(Vector2(center.x - 130, center.y + 40), Vector2(center.x + 120, center.y + 40), icon_color, 3.0)
