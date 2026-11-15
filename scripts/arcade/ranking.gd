extends Control

# Ranking of the arcade games after the NAME ENTRY: the best total EX scores,
# the new games blinking (one per player in versus). A key or the time goes back to the title menu.
# Opened from the STATS menu (ARCADE not active), the ranking is browsed: turntable: a game of the 100,
# its songs at the bottom; white key: SINGLE PLAY / DOUBLE PLAY; black key: back to the STATS menu.

const TITLE_FONT = preload("res://assets/font/04B_20__.TTF")
const SONG_FONT = preload("res://assets/font/monofonto.otf")
const INFO_BAR = preload("res://assets/music_select/music_select_info.png")
const INFO_BAR_LEFT = -1888.0

const PANEL = Color(0, 0, 0, 0.7)
const ROW = Color(0.05, 0.05, 0.05)
const TAG_BORDER = Color(0.45, 0.45, 0.45)
const ORANGE = Color(1, 0.55, 0.05)
const YELLOW = Color(1, 0.82, 0.1)
const PALE_BLUE = Color(0.6, 0.7, 1)
const TEXT_DIM = Color(0.6, 0.62, 0.7)
# Gold, silver and bronze
const PODIUM_COLORS = [Color(1, 0.85, 0.2), Color(0.8, 0.85, 0.9), Color(0.85, 0.5, 0.25)]
const HEADER_HEIGHT = 113.0
const FOOTER_HEIGHT = 64.0
const SHOWN = 10
const ROW_HEIGHT = 36.0
const ROW_GAP = 4.0
const TABLE_TOP = 168.0
# Columns: rank, DJ name, DJ LEVEL, EX score, date (x from the left of the table)
const COLUMNS = [24, 110, 330, 560, 700]
const SHOW_TIME = 20.0
# Rows sliding in one after the other
const ROW_DELAY = 0.06
const ROW_SLIDE = 0.25

const STATS_MENU_SCENE = "res://scenes/menu/stats_menu.tscn"

# Style shown when browsing, kept across scene changes
static var browse_double := false
var entries: Array = []
var elapsed := 0.0
var leaving = false
var browsing := false
var double := false
# Game under the cursor and first row shown, when browsing
var cursor := 0
var first_row := 0
var turntable: MenuTurntable
var scroll_sound: AudioStreamPlayer
var cancel_sound: AudioStreamPlayer

func _ready() -> void:
	browsing = not Arcade.active
	double = browse_double if browsing else Arcade.is_double()
	entries = Arcade.load_ranking(double)
	if browsing:
		turntable = MenuTurntable.new()
		scroll_sound = add_sound(preload("res://assets/music_select/scroll.wav"))
		cancel_sound = add_sound(preload("res://assets/music_select/cancel.wav"))

func add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -10.0
	add_child(player)
	return player

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if browsing:
		process_browse(delta)
	elif elapsed >= SHOW_TIME:
		leave()

func process_browse(delta: float) -> void:
	var steps = turntable.poll(delta)
	if leaving:
		return
	if steps != 0:
		move_cursor(steps)
	if MenuTurntable.white_pressed():
		toggle_style()
	elif MenuTurntable.black_pressed():
		leave()

func move_cursor(steps: int) -> void:
	if entries.is_empty():
		return
	var new_cursor = clampi(cursor + steps, 0, entries.size() - 1)
	if new_cursor == cursor:
		return
	cursor = new_cursor
	first_row = clampi(first_row, cursor - SHOWN + 1, cursor)
	scroll_sound.play()

func toggle_style() -> void:
	double = not double
	browse_double = double
	entries = Arcade.load_ranking(double)
	cursor = 0
	first_row = 0
	elapsed = 0.0
	scroll_sound.play()

func browse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: move_cursor(-1)
			MOUSE_BUTTON_WHEEL_DOWN: move_cursor(1)
			MOUSE_BUTTON_LEFT: toggle_style()
			MOUSE_BUTTON_RIGHT: leave()
		return
	if not (event is InputEventKey and event.pressed) or MenuTurntable.is_player_input(event):
		return
	match event.keycode:
		KEY_UP: move_cursor(-1)
		KEY_DOWN: move_cursor(1)
		KEY_PAGEUP: move_cursor(-SHOWN)
		KEY_PAGEDOWN: move_cursor(SHOWN)
		KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: toggle_style()
		KEY_ESCAPE, KEY_BACKSPACE: leave()

func _unhandled_input(event: InputEvent) -> void:
	if browsing:
		if not leaving:
			browse_input(event)
		return
	var confirm = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for action in ["ui_accept", "ui_cancel", "p1_start", "p2_start"]:
		if event.is_action_pressed(action):
			confirm = true
	for player in [1, 2]:
		for key in 7:
			if event.is_action_pressed("p%d_key%d" % [player, key + 1]):
				confirm = true
	if confirm:
		get_viewport().set_input_as_handled()
		leave()

func leave() -> void:
	if leaving:
		return
	leaving = true
	if browsing:
		cancel_sound.play()
		await get_tree().create_timer(0.25).timeout
		get_tree().change_scene_to_file(STATS_MENU_SCENE)
		return
	# End of an ARCADE game, cleared or not: GAME OVER, then the main menu
	get_tree().change_scene_to_file("res://scenes/arcade/game_over.tscn")

func draw_text(font: Font, at: Vector2, text: String, font_size: int, text_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, outline_color := Color.BLACK) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x = at.x - (width if alignment == HORIZONTAL_ALIGNMENT_RIGHT else width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _draw() -> void:
	var bottom = size.y - FOOTER_HEIGHT - 8
	draw_rect(Rect2(0, HEADER_HEIGHT, size.x, bottom - HEADER_HEIGHT), PANEL)
	draw_rect(Rect2(0, HEADER_HEIGHT + 4, size.x, 3), ORANGE)
	draw_rect(Rect2(0, bottom - 7, size.x, 3), ORANGE)
	draw_table()
	draw_header()
	draw_footer(bottom)

func draw_table() -> void:
	var table = Rect2(160, TABLE_TOP, size.x - 320, ROW_HEIGHT)
	var heads = ["RANK", "DJ NAME", "DJ LEVEL", "EX SCORE", "DATE"]
	for column in heads.size():
		draw_text(TITLE_FONT, Vector2(table.position.x + COLUMNS[column], TABLE_TOP - 14), heads[column], 12, ORANGE)
	if entries.is_empty():
		draw_text(TITLE_FONT, Vector2(size.x / 2, TABLE_TOP + 120), "NO RECORD", 32, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# The new games are shown under the 10 best when they are not in them
	var rows = range(first_row, mini(entries.size(), first_row + SHOWN))
	var below = Arcade.last_ranks.values().filter(func(rank): return rank >= SHOWN and rank < entries.size())
	below.sort()
	if not browsing:
		rows.append_array(below)
	else:
		draw_scrollbar(table)
	for slot in rows.size():
		var y = TABLE_TOP + slot * (ROW_HEIGHT + ROW_GAP)
		if slot == SHOWN:
			y += 12
		var slide = 1.0 - ease(clampf((elapsed - slot * ROW_DELAY) / ROW_SLIDE, 0.0, 1.0), 0.3)
		draw_row(Rect2(table.position.x + slide * 120, y, table.size.x, ROW_HEIGHT), rows[slot], 1.0 - slide)

# Position of the rows shown in the 100 games, when browsing
func draw_scrollbar(table: Rect2) -> void:
	if entries.size() <= SHOWN:
		return
	var track = Rect2(table.end.x + 16, TABLE_TOP, 6, SHOWN * (ROW_HEIGHT + ROW_GAP) - ROW_GAP)
	draw_rect(track, ROW)
	var height = track.size.y * SHOWN / entries.size()
	var top = track.position.y + (track.size.y - height) * first_row / (entries.size() - SHOWN)
	draw_rect(Rect2(track.position.x, top, track.size.x, height), ORANGE)

func draw_row(row: Rect2, rank: int, alpha: float) -> void:
	var entry: Dictionary = entries[rank]
	var new_game = rank in Arcade.last_ranks.values()
	var lit = new_game and Time.get_ticks_msec() % 600 < 400
	draw_rect(row, Color(Color(ORANGE, 0.45) if lit else ROW, alpha))
	if browsing and rank == cursor:
		draw_rect(row.grow(2), Color(YELLOW, alpha), false, 3.0)
	var accent = PODIUM_COLORS[rank] if rank < PODIUM_COLORS.size() else TAG_BORDER
	draw_rect(Rect2(row.position, Vector2(4, row.size.y)), Color(YELLOW if new_game else accent, alpha))
	var baseline = row.end.y - 10
	var x = row.position.x
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[0], baseline), "%d" % (rank + 1), 20, Color(accent if rank < 3 else Color.WHITE, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[1], baseline), entry.get("name", ""), 20, Color(Color.WHITE, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[2], baseline), Scores.rank(entry.get("rate", 0.0)), 20, Color(YELLOW, alpha), HORIZONTAL_ALIGNMENT_LEFT, 4)
	draw_text(TITLE_FONT, Vector2(x + COLUMNS[3] + 100, baseline), "%d" % entry.get("ex_score", 0), 20, Color(PALE_BLUE, alpha), HORIZONTAL_ALIGNMENT_RIGHT, 4)
	draw_text(SONG_FONT, Vector2(x + COLUMNS[4], baseline + 2), entry.get("date", ""), 22, Color(Color.WHITE if lit else TEXT_DIM, alpha))
	if new_game:
		var tag = "NEW"
		if Arcade.last_ranks.size() > 1:
			tag = "%dP" % Arcade.last_ranks.find_key(rank)
		draw_text(TITLE_FONT, Vector2(row.end.x + 12, baseline), tag, 14, Color(YELLOW, alpha))

func draw_header() -> void:
	draw_texture(INFO_BAR, Vector2(size.x + INFO_BAR_LEFT, 0))
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32)), "ranking", 32, Color.WHITE)
	# Single play and double play games have their own ranking
	draw_text(TITLE_FONT, Vector2(16, 16 + TITLE_FONT.get_ascent(32) + 30), "DOUBLE PLAY" if double else "SINGLE PLAY", 16, YELLOW)
	# No tag here
	draw_rect(Rect2(size.x + INFO_BAR_LEFT + 1303, 0, 600, 98), Color.BLACK)

# Songs of the new game, then the key to go on
func draw_footer(top: float) -> void:
	draw_rect(Rect2(0, top, size.x, size.y - top), Color.BLACK)
	draw_rect(Rect2(0, top, size.x, 4), Color.RED)
	var bar = Rect2(20, top + 10, size.x - 40, FOOTER_HEIGHT - 8)
	draw_rect(bar, TAG_BORDER, false, 2.0)
	var ranks = Arcade.last_ranks.values().filter(func(rank): return rank < entries.size())
	if browsing:
		ranks = [cursor] if cursor < entries.size() else []
	var songs = " / ".join(entries[ranks.min()].get("songs", [])) if not ranks.is_empty() else ""
	var help_width = 420 if browsing else 260
	var font_size = 24
	while font_size > 8 and SONG_FONT.get_string_size(songs, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bar.size.x - help_width:
		font_size -= 1
	draw_text(SONG_FONT, Vector2(bar.position.x + 20, bar.get_center().y + 9), songs, font_size, TEXT_DIM)
	if browsing:
		var help = "WHITE KEY: %s    BLACK KEY: BACK" % ("SP" if double else "DP")
		draw_text(TITLE_FONT, Vector2(bar.end.x - 20, bar.get_center().y + 7), help, 14, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
	elif Time.get_ticks_msec() % 1000 < 650:
		draw_text(TITLE_FONT, Vector2(bar.end.x - 20, bar.get_center().y + 8), "PRESS START", 18, YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
